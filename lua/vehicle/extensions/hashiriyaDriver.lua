-- Hashiriya Driver: eigener Renn-Fahrer für Straßenrennen im Verkehr (läuft im Gegnerauto)
--
-- Kartenunabhängig: nutzt nur das Straßennetz der Karte (mapmgr) und die Positionen aller Autos.
-- Der Fahrer bedient Lenkung, Gas und Bremse selbst (die BeamNG-KI ist dabei aus).
--
-- Ablauf (10x pro Sekunde wird neu geplant, gelenkt und Gas gegeben wird in jedem Frame):
--  1. Route: Straße vor dem Auto, an Abzweigen die natürliche Fortsetzung (oder der Weg, den das Ziel gefahren ist)
--  2. Stützpunkte alle sampleStep m mit Straßenmitte, Breite und befahrbarer Spanne (eigene Fahrtrichtung)
--  3. Verkehr: jedes Auto wird auf die Strecke projiziert; der Fahrer entscheidet links vorbei, rechts vorbei
--     oder (wenn keine Lücke) dahinter bleiben. Vorbeifahren engt die erlaubte Spanne an dieser Stelle ein.
--  4. Ideallinie: glatteste Linie (wenig Krümmung) innerhalb der erlaubten Spanne -> weicht automatisch aus
--  5. Tempo: Kurventempo aus Krümmung und Grip, Bremspunkte rückwärts gerechnet, Verkehr ohne Lücke = Tempolimit
--  6. Regler: Lenkung auf einen Punkt der Linie, Gas/Bremse auf das geplante Tempo; erst lupfen, dann bremsen
--
-- Steuerung von außen (GE-Lua per veh:queueLuaCommand):
--   ai.setMode('disabled') extensions.load('hashiriyaDriver') hashiriyaDriver.start({ targetId = 123, skill = 0.6, ... })
--   hashiriyaDriver.setRace({ gap = 35, ownSp = 0.8, otherSp = 0.5 })   -- gap > 0: dieser Fahrer liegt vorne
--   hashiriyaDriver.stop()
-- Meldet sich bei Problemen im GE mit extensions.hook('onHashiriyaDriverFailed', vehId, grund).

local M = {}

local abs, min, max, sqrt, floor, asin = math.abs, math.min, math.max, math.sqrt, math.floor, math.asin
local g = 9.81

local function clamp(x, a, b) return min(max(x, a), b) end
local function lerp(a, b, t) return a + (b - a) * t end
local computeWheelBase

-- Grundwerte; start() überschreibt einzelne Werte -------------------------------------------
local defaults = {
  -- Fahrer-Werte 0..1 (siehe Konzept): Können, Mut, Aggression, Nerven, Fairness
  skill = 0.5,
  courage = 0.6,
  aggression = 0.5,
  nerves = 0.5,
  fairness = 0.8,
  boss = false,          -- Bosse: kein Gummiband
  targetId = -1,         -- Gegner im Rennen (Spieler): Abzweige folgen ihm, wenn er vorne fährt
  -- Planung
  sampleStep = 3,        -- m zwischen zwei Stützpunkten
  minLook = 120,         -- m Planungsweite mindestens
  maxLook = 420,         -- m höchstens
  lookTime = 7,          -- s Planungsweite = Tempo * lookTime
  smoothIter = 24,       -- Glättungsdurchgänge der Ideallinie pro Planung
  replan = 0.1,          -- s zwischen zwei Planungen
  maxSpeed = 95,         -- m/s absolute Obergrenze (342 km/h)
  -- Ränder und Abstände (m)
  edgeMarginMin = 0.15,  -- Abstand zum Fahrbahnrand bei vollem Mut
  edgeMarginMax = 0.6,   -- ... bei null Mut
  sideGapMin = 0.3,      -- seitlicher Abstand zu Verkehr bei vollem Mut (pro Seite)
  sideGapMax = 1.0,      -- ... bei null Mut
  playerSideGap = 0.5,   -- seitlicher Abstand zum Spieler (faire Fahrer)
  -- Tempo
  cornerUseMin = 0.82,   -- Anteil des Grips in Kurven bei Können 0
  cornerUseMax = 0.93,   -- ... bei Können 1
  brakeUseMin = 0.72,    -- Anteil des Grips beim Bremsen bei Können 0
  brakeUseMax = 0.95,
  followDecel = 4.0,     -- m/s² geplante Verzögerung hinter Verkehr ohne Lücke (mutige Fahrer: mehr)
  headwayMin = 0.35,     -- s Abstand hinter Verkehr ohne Lücke bei vollem Mut
  headwayMax = 0.9,
  liftBand = 1.6,        -- m/s: so viel zu schnell = nur Gas weg, erst darüber bremsen
  emergencyTtcMin = 0.6, -- s bis zum Aufprall: Notbremse bei vollem Mut
  emergencyTtcMax = 1.0, -- ... bei null Mut
  -- Wahrnehmung
  perceiveMin = 80,      -- m Sichtweite für Verkehr bei Können 0
  perceiveMax = 170,     -- ... bei Können 1
  reactionMin = 0.2,     -- s Reaktionszeit bei Können 1
  reactionMax = 0.8,     -- ... bei Können 0
  -- Gummiband (nur außerhalb von Bossen)
  rubberDist = 200,      -- m Abstand, ab dem das Gummiband voll wirkt
  rubberPace = 0.06,     -- vorne bis zu 6 % langsamer in Kurven
  rubberCourage = 0.25,  -- hinten bis zu so viel mehr Mut
  -- Lenkung
  steerGain = 1.0,       -- Faktor auf den berechneten Lenkausschlag
  steerLookBase = 5,     -- m Vorschau der Lenkung im Stand
  steerLookTime = 0.5,   -- s Vorschau pro m/s (BeamNG-KI: 0.6)
  steerRate = 6,         -- Lenkeinschlag pro Sekunde höchstens (Anteil voller Einschlag)
  -- Duell (Stufe 3)
  blockMinAggression = 0.55, -- ab dieser Aggression macht er dir vorne die Linie zu
  blockCooldown = 8,     -- s zwischen zwei Blockversuchen (eine Reaktion pro Gerade)
  draftDist = 45,        -- m: so nah hinter dir hängt er sich in den Windschatten
  brakeCheckFairness = 0.35, -- unter dieser Fairness: Bremstests möglich
  brakeCheckCooldown = 25,   -- s zwischen zwei Bremstests
  -- Fehler (Stufe 4), pro Minute bei Können 0 / 1, unter Druck mit schwachen Nerven bis 2,5x so oft
  errorRateMax = 1.0,
  errorRateMin = 0.03,
  errorCooldown = 12,    -- s nach einem Fehler kein neuer
  debug = false,         -- Linie und Verkehr im Spiel einzeichnen
}

local p = {}             -- aktive Werte
local active = false
local mapData, graph
local race = { gap = 0, ownSp = 1, otherSp = 1 }

-- Zustand des Fahrers
local ego = { pos = vec3(), center = vec3(), dir = vec3(), up = vec3(), right = vec3(), vel = vec3(), speed = 0, width = 2, length = 4.5 }
local route = {}         -- Knoten-IDs, route[1] liegt hinter dem Auto
local plan = nil         -- letzte Planung
local planTimer = 0
local waitMap = 0
local seen = {}          -- id -> Zeit seit erster Wahrnehmung
local followTime = {}    -- id -> s, so lange hängt er schon hinter diesem Auto
local sideChoice = {}    -- id -> -1 (links vorbei) | 1 (rechts vorbei)
local trail = {}         -- Knoten, über die das Ziel gefahren ist -> Zeitstempel
local trailTimer = 0
local simTime = 0
local lastSteer, lastThrottle, lastBrake = 0, 0, 0
-- Lenkübersetzung: Radeinschlag (rad) bei vollem Lenkausschlag, wird während der Fahrt gemessen
local steerAngleEst = 0.55
local wheelBase = 2.6
local prevDir = vec3()
local yawRate = 0
local stuckTime, reverseTime = 0, 0
local offRouteTime = 0
local savedGearbox
local status = 'idle'
local failedReported = false
-- Duell und Fehler
local duel = { blockTime = 0, blockCool = 0, blockLat = nil, blockMoves = 0, brakeCheck = 0, brakeCool = 10 }
local mistake = { kind = nil, time = 0, cool = 0, scared = {} }
local startDelay = 0
local function dlog(text) if p.debug then log('I', 'hashiriyaDriver', text) end end

-- Hilfen -------------------------------------------------------------------------------

local function driveCar(steering, throttle, brake, parkingbrake)
  input.event('steering', steering, 'FILTER_AI', nil, nil, nil, 'ai')
  input.event('throttle', throttle, 'FILTER_AI', nil, nil, nil, 'ai')
  input.event('brake', brake, 'FILTER_AI', nil, nil, nil, 'ai')
  input.event('parkingbrake', parkingbrake, 'FILTER_AI', nil, nil, nil, 'ai')
  lastSteer, lastThrottle, lastBrake = steering, throttle, brake
end

local function report(reason)
  if failedReported then return end
  failedReported = true
  log('W', 'hashiriyaDriver', 'Fahrer gibt ab: ' .. tostring(reason))
  obj:queueGameEngineLua(string.format('extensions.hook(%q, %d, %q)', 'onHashiriyaDriverFailed', objectId, tostring(reason)))
end

-- Werte, die vom Rennstand abhängen (Gummiband, SP-Lage)
local function effective()
  local courage, nerves, pace = p.courage, p.nerves, 1
  if not p.boss then
    local f = min(abs(race.gap or 0) / p.rubberDist, 1)
    if (race.gap or 0) > 0 then
      pace = 1 - p.rubberPace * f
    else
      courage = courage + p.rubberCourage * f
    end
  end
  -- Wenig eigene SP: verzweifelt, mehr Mut, schwächere Nerven
  if (race.ownSp or 1) < 0.25 then
    courage = courage + 0.2
    nerves = nerves - 0.2
  end
  -- Er führt und der Gegner hat kaum noch SP: sicher nach Hause fahren
  if (race.gap or 0) > 0 and (race.otherSp or 1) < 0.2 then
    courage = courage - 0.15
    pace = pace * 0.97
  end
  -- Fehler: zu spät gebremst / zu vorsichtig
  if mistake.kind == 'late' then pace = pace * 1.08 end
  if mistake.kind == 'timid' then pace = pace * 0.85 end
  return clamp(courage, 0, 1), clamp(nerves, 0, 1), pace
end

-- Spuren einer Kante in Fahrtrichtung a -> b: befahrbare Spanne (0 = linker Rand, 1 = rechter Rand)
local laneBuf = {}
local function flipLanes(lanes)
  local n = #lanes
  for i = 1, n do
    local c = lanes:byte(n - i + 1)
    laneBuf[i] = c == 43 and '-' or (c == 45 and '+' or '0')
  end
  for i = n + 1, #laneBuf do laneBuf[i] = nil end
  return table.concat(laneBuf)
end

local function laneSpan(a, b)
  local e = graph[a][b]
  local lanes = e.lanes
  if not lanes or lanes == '' then
    if e.oneWay then return 0, 1, 1, true end
    local ra, rb = mapData:getEdgeRadii(a, b)
    local n = max(1, floor(min(ra, rb) * 2 / 3.61 * 0.5 + 0.5))
    if mapmgr.rules and mapmgr.rules.rightHandDrive then
      lanes = string.rep('+', n) .. string.rep('-', n)
    else
      lanes = string.rep('-', n) .. string.rep('+', n)
    end
  end
  if e.inNode ~= a then lanes = flipLanes(lanes) end
  local n = #lanes
  local left, right, plus = nil, nil, 0
  for i = 1, n do
    if lanes:byte(i) == 43 then
      plus = plus + 1
      left = left or i
      right = i
    end
  end
  if not left then return 0, 1, n, e.oneWay end
  -- Touge / Landstraße (eine Spur je Richtung): die ganze Straße gehört dem Racer, Gegenverkehr ist ein Hindernis
  if not e.oneWay and plus == 1 and n <= 2 then return 0, 1, n, false end
  return (left - 1) / n, right / n, n, e.oneWay
end

-- Darf man von cur nach k fahren (Einbahn in Gegenrichtung = nein)?
local function edgeAllowed(cur, k)
  local e = graph[cur][k]
  if not e then return false end
  if e.oneWay and e.inNode ~= cur then return false end
  if (e.drivability or 1) < 0.1 then return false end
  return true
end

-- Route ---------------------------------------------------------------------------------

local function initRoute()
  table.clear(route)
  local n1, n2 = mapmgr.findBestRoad(ego.pos, ego.dir)
  if not n1 or not n2 then return false end
  local p1, p2 = mapData.positions[n1], mapData.positions[n2]
  if (p2 - p1):dot(ego.dir) < 0 then n1, n2 = n2, n1 end
  route[1], route[2] = n1, n2
  plan = nil
  return true
end

local function chooseNext(prev, cur)
  local pc = mapData.positions[cur]
  local inDir = pc - mapData.positions[prev]
  inDir.z = 0
  inDir:normalize()
  local best, bestScore = nil, -math.huge
  for k in pairs(graph[cur]) do
    if k ~= prev and edgeAllowed(cur, k) then
      local outDir = mapData.positions[k] - pc
      outDir.z = 0
      outDir:normalize()
      local dot = inDir:dot(outDir)
      if dot > -0.3 then
        local ra, rb = mapData:getEdgeRadii(cur, k)
        local e = graph[cur][k]
        local score = dot * 3 + min(ra, rb) * 0.4 + (e.drivability or 1)
        if trail[k] then score = score + 6 end -- das Ziel ist hier entlanggefahren
        if score > bestScore then best, bestScore = k, score end
      end
    end
  end
  return best
end

local function extendRoute(needed)
  local len = 0
  for i = 1, #route - 1 do
    len = len + mapData.positions[route[i]]:distance(mapData.positions[route[i + 1]])
  end
  local guard = 0
  while len < needed and guard < 200 do
    guard = guard + 1
    local n = #route
    local nxt = chooseNext(route[n - 1], route[n])
    if not nxt then break end
    route[n + 1] = nxt
    len = len + mapData.positions[route[n]]:distance(mapData.positions[nxt])
  end
end

-- Wirft Knoten hinter dem Auto weg; gibt den Abstand zur Route zurück
local function trimRoute()
  local bestI, bestD = nil, math.huge
  for i = 1, min(#route - 1, 8) do
    local a, b = mapData:getEdgePositions(route[i], route[i + 1])
    local xn = clamp(ego.pos:xnormOnLine(a, b), 0, 1)
    local q = a + (b - a) * xn
    local d = q:squaredDistance(ego.pos)
    if d < bestD then bestI, bestD = i, d end
  end
  if not bestI then return math.huge end
  for _ = 1, bestI - 1 do table.remove(route, 1) end
  return sqrt(bestD)
end

-- Spur des Ziels merken (für Abzweige)
local function updateTrail(dt)
  trailTimer = trailTimer - dt
  if trailTimer > 0 then return end
  trailTimer = 0.3
  for k, t in pairs(trail) do
    if simTime - t > 40 then trail[k] = nil end
  end
  local o = mapmgr.objects[p.targetId]
  if not o or not o.pos then return end
  -- nur wenn das Ziel vorne fährt, folgt man seiner Wahl
  if (race.gap or 0) > 0 then return end
  local n1, n2 = mapmgr.findClosestRoad(o.pos)
  if n1 then trail[n1] = simTime end
  if n2 then trail[n2] = simTime end
end

-- Planung -------------------------------------------------------------------------------

local function newPlan()
  return { n = 0, s = {}, cx = {}, cy = {}, cz = {}, tx = {}, ty = {}, nx = {}, ny = {},
    baseLo = {}, baseHi = {}, lo = {}, hi = {}, off = {}, px = {}, py = {}, kappa = {}, v = {},
    obstacles = {} }
end

-- Stützpunkte entlang der Route ab dem Auto
local function buildSamples(pl, look, edgeMargin)
  local step = p.sampleStep
  local halfW = ego.width * 0.5
  -- Start: Projektion des Autos auf das erste Stück
  local a, b = mapData:getEdgePositions(route[1], route[2])
  local xn = clamp(ego.pos:xnormOnLine(a, b), 0, 1)
  local segStart = (b - a):length() * xn
  local n = 0
  local s = 0
  local i = 1
  local along = segStart
  while i < #route and s <= look do
    local na, nb = route[i], route[i + 1]
    local pa, pb = mapData:getEdgePositions(na, nb)
    local ra, rb = mapData:getEdgeRadii(na, nb)
    local segLen = pa:distance(pb)
    local xl, xr = laneSpan(na, nb)
    while along <= segLen and s <= look do
      local t = segLen > 1e-3 and along / segLen or 0
      n = n + 1
      pl.s[n] = s
      pl.cx[n] = pa.x + (pb.x - pa.x) * t
      pl.cy[n] = pa.y + (pb.y - pa.y) * t
      pl.cz[n] = pa.z + (pb.z - pa.z) * t
      local r = ra + (rb - ra) * t
      local left, right = -r + xl * 2 * r, -r + xr * 2 * r
      local lo, hi = left + halfW + edgeMargin, right - halfW - edgeMargin
      if lo > hi then lo, hi = (left + right) * 0.5, (left + right) * 0.5 end
      pl.baseLo[n], pl.baseHi[n] = lo, hi
      along = along + step
      s = s + step
    end
    along = along - segLen
    i = i + 1
  end
  pl.n = n
  if n < 4 then return false end
  -- Richtung und Normale aus den Nachbarpunkten (glatt über die Knoten hinweg)
  for k = 1, n do
    local k0, k1 = max(1, k - 1), min(n, k + 1)
    local dx, dy = pl.cx[k1] - pl.cx[k0], pl.cy[k1] - pl.cy[k0]
    local l = sqrt(dx * dx + dy * dy)
    if l < 1e-6 then dx, dy, l = ego.dir.x, ego.dir.y, 1 end
    dx, dy = dx / l, dy / l
    pl.tx[k], pl.ty[k] = dx, dy
    pl.nx[k], pl.ny[k] = dy, -dx -- rechts
    pl.lo[k], pl.hi[k] = pl.baseLo[k], pl.baseHi[k]
  end
  return true
end

-- Seitlicher Versatz eines Weltpunkts zum Stützpunkt k
local function lateralAt(pl, k, x, y)
  return (x - pl.cx[k]) * pl.nx[k] + (y - pl.cy[k]) * pl.ny[k]
end

-- Index des Stützpunkts bei Weg s (abgerundet)
local function indexAt(pl, s)
  return clamp(floor(s / p.sampleStep) + 1, 1, pl.n)
end

local function valueAt(pl, arr, s)
  local f = s / p.sampleStep + 1
  local i = clamp(floor(f), 1, pl.n)
  local j = min(i + 1, pl.n)
  local t = clamp(f - i, 0, 1)
  return arr[i] + (arr[j] - arr[i]) * t
end

-- Versatz aus der letzten Planung übernehmen (Warmstart), sonst aktuelle Querlage
local function initOffsets(pl, egoLat)
  local prev = plan
  local shift = nil
  if prev and prev.n > 3 then
    -- wo steht das Auto auf der alten Planung?
    local bestK, bestD = 1, math.huge
    for k = 1, min(prev.n, 40) do
      local dx, dy = prev.px[k] - ego.pos.x, prev.py[k] - ego.pos.y
      local d = dx * dx + dy * dy
      if d < bestD then bestK, bestD = k, d end
    end
    if bestD < 100 then shift = prev.s[bestK] end
  end
  for k = 1, pl.n do
    local o = egoLat
    if shift then
      local sp = pl.s[k] + shift
      if sp <= prev.s[prev.n] then o = valueAt(prev, prev.off, sp) end
    end
    pl.off[k] = clamp(o, pl.lo[k], pl.hi[k])
  end
end

-- Verkehr einlesen und vorbeifahren planen ---------------------------------------------
local function planTraffic(pl, courage, nerves, dt, egoLat)
  local objs = mapmgr.getObjects()
  local list = pl.obstacles
  table.clear(list)
  local perceive = lerp(p.perceiveMin, p.perceiveMax, p.skill)
  -- Reaktionszeit: Können, unter Druck (Gegner dicht dran) mit schwachen Nerven langsamer
  local pressure = clamp(1 - abs(race.gap or 0) / 40, 0, 1)
  local reaction = lerp(p.reactionMax, p.reactionMin, p.skill) * (1 + pressure * (1 - nerves) * 0.5)
  local lastS = pl.s[pl.n]
  local present = {}
  for id, o in pairs(objs) do
    if id ~= objectId and o.pos then
      local cpos = obj:getObjectCenterPosition(id)
      local dx, dy = cpos.x - ego.pos.x, cpos.y - ego.pos.y
      local dist2 = dx * dx + dy * dy
      if dist2 < (lastS + 30) ^ 2 then
        -- nächster Stützpunkt
        local bestK, bestD = nil, math.huge
        for k = 1, pl.n, 2 do
          local ex, ey = cpos.x - pl.cx[k], cpos.y - pl.cy[k]
          local d = ex * ex + ey * ey
          if d < bestD then bestK, bestD = k, d end
        end
        if bestK then
          for k = max(1, bestK - 1), min(pl.n, bestK + 1) do
            local ex, ey = cpos.x - pl.cx[k], cpos.y - pl.cy[k]
            local d = ex * ex + ey * ey
            if d < bestD then bestK, bestD = k, d end
          end
          local lat = lateralAt(pl, bestK, cpos.x, cpos.y)
          local roadHalf = max(abs(pl.baseLo[bestK]), abs(pl.baseHi[bestK])) + ego.width
          -- andere Ebene (Brücke, Tunnel darunter) oder andere Straße: ignorieren
          if abs(cpos.z - pl.cz[bestK]) < 4 and abs(lat) < roadHalf + 2 then
            local sObs = pl.s[bestK] + (cpos.x - pl.cx[bestK]) * pl.tx[bestK] + (cpos.y - pl.cy[bestK]) * pl.ty[bestK]
            local oLen = obj:getObjectInitialLength(id)
            local oWid = obj:getObjectInitialWidth(id)
            -- Gegenverkehr kommt doppelt so schnell näher: weiter vorausschauen
            local oncoming = o.vel.x * pl.tx[bestK] + o.vel.y * pl.ty[bestK] < -1
            if sObs + oLen * 0.5 > -ego.length and sObs < perceive * (oncoming and 1.7 or 1) then
              present[id] = true
              seen[id] = (seen[id] or 0) + dt
              local isTarget = id == p.targetId
              -- direkt daneben oder ganz nah: sofort bemerkt
              if seen[id] >= reaction or sObs < 15 or isTarget then
                local tx, ty = pl.tx[bestK], pl.ty[bestK]
                list[#list + 1] = {
                  id = id, s = sObs, d = lat, len = oLen, wid = oWid,
                  vAlong = o.vel.x * tx + o.vel.y * ty,
                  vLat = o.vel.x * pl.nx[bestK] + o.vel.y * pl.ny[bestK],
                  target = isTarget,
                }
              end
            end
          end
        end
      end
    end
  end
  for id in pairs(seen) do if not present[id] then seen[id] = nil; sideChoice[id] = nil end end
  table.sort(list, function(a, b) if a.s ~= b.s then return a.s < b.s end return a.id < b.id end)

  local v0 = max(ego.speed, 1)
  local mu = obj:getStaticFrictionCoef()
  local sideGap = lerp(p.sideGapMax, p.sideGapMin, courage)
  local reserve = 0.15 -- Reserve für Lenkfehler
  if mistake.kind == 'gap' then sideGap, reserve = 0, -0.1 end -- Lücke verschätzt: es wird ganz eng
  local headway = lerp(p.headwayMax, p.headwayMin, courage)
  local passDelta = lerp(4, 9, courage) -- m/s schneller als der Vordermann beim Überholen
  local followCaps = {}
  local nearestTtc = math.huge
  -- Kein Vorbeikommen: dahinter bleiben (Abstand nach Mut, zu dicht = etwas langsamer als der Vordermann)
  local function addFollow(ob, gapLong)
    if ob.capped then return end
    ob.capped = true
    local vO = max(ob.vAlong, 0)
    -- hängt er länger dahinter, lässt er sich etwas zurückfallen: Anlauf für die nächste Lücke
    local back = clamp(((followTime[ob.id] or 0) - 2) * 0.25, 0, 0.7)
    local want = vO * (headway + back) + 2
    local v = max(vO - max(want - gapLong, 0) * 0.6, 0)
    followCaps[#followCaps + 1] = { s = max(gapLong - want, 0), v = v, d = ob.d, gap = gapLong, ob = ob }
  end

  -- 1. Jedes Auto: wann und wo trifft er es, welche Querlage ist blockiert
  local latLimit = mu * g * lerp(0.4, 0.65, courage) -- wie hart er für eine Lücke querziehen will
  local cand = {}
  for _, ob in ipairs(list) do
    local halfLen = (ob.len + ego.length) * 0.5
    local gapLong = ob.s - ob.len * 0.5 -- Front des Fahrers bis Heck des anderen
    local alongside = gapLong <= 0
    ob.gapLong = gapLong
    -- Er will vorbei: auch wenn er gerade gleich schnell hinterherfährt, plant er mit Überholtempo
    local rel = v0 - ob.vAlong
    if ob.vAlong <= v0 + 1 or (gapLong < 60 and ob.vAlong > 0) then rel = max(rel, passDelta) end
    local tMeet
    if alongside then
      tMeet = 0
    elseif rel > 0.3 then
      tMeet = gapLong / rel
    end
    ob.tMeet = tMeet

    -- Seitlicher Abstand: Spieler fair (playerSideGap), Fieslinge (Fairness niedrig) drängen dichter
    local gap = sideGap
    if ob.target then gap = lerp(min(sideGap, 0.15), max(sideGap, p.playerSideGap), p.fairness) end
    local half = ob.wid * 0.5 + ego.width * 0.5 + gap + reserve
    ob.half = half

    if tMeet and tMeet < p.lookTime + 2 then
      local sMeet = alongside and ob.s or (ob.s + ob.vAlong * tMeet)
      local dMeet = ob.d + clamp(ob.vLat * min(tMeet, 2), -3.6, 3.6)
      local tPass = (ob.len + ego.length) / max(rel, 1)
      local s0 = max(sMeet - halfLen - 1.5 - v0 * 0.25, 0)
      local s1 = alongside and (max(ob.s + halfLen, 0) + 6) or (sMeet + halfLen + 1.5 + max(ob.vAlong, 0) * min(tPass, 4))
      s1 = min(s1, s0 + 120)
      ob.sMeet, ob.dMeet, ob.half, ob.alongside = sMeet, dMeet, half, alongside
      ob.s0, ob.s1 = s0, s1
      cand[#cand + 1] = ob
    elseif not tMeet and gapLong < 40 and abs(ob.d - egoLat) < half then
      -- fährt davon, aber direkt vor ihm: nicht auffahren
      addFollow(ob, gapLong)
    end

    -- Notbremse: Auto genau in der aktuellen Fahrlinie und Aufprall in Kürze
    local closing = v0 - ob.vAlong
    if not alongside and closing > 0.5 then
      local myLat = pl.off[indexAt(pl, min(gapLong, 30))] or 0
      if abs(ob.d - myLat) < ob.wid * 0.5 + ego.width * 0.5 + 0.1 then
        nearestTtc = min(nearestTtc, gapLong / closing)
      end
    end
  end

  -- 2. Autos, die er zur selben Zeit passiert, gemeinsam betrachten (zwei nebeneinander = eine Lücke dazwischen?)
  table.sort(cand, function(a, b) if a.s0 ~= b.s0 then return a.s0 < b.s0 end return a.id < b.id end)
  local ci = 1
  local blocks = {}
  local groups = {}
  pl.groups = groups
  while ci <= #cand do
    local group = { cand[ci] }
    local gs0, gs1 = cand[ci].s0, cand[ci].s1
    ci = ci + 1
    while ci <= #cand and cand[ci].s0 <= gs1 do
      group[#group + 1] = cand[ci]
      gs1 = max(gs1, cand[ci].s1)
      ci = ci + 1
    end
    local i0, i1 = max(indexAt(pl, gs0), 2), indexAt(pl, gs1)
    if i1 >= i0 then
      -- engste Stelle im Fenster mit bisherigen Einschränkungen
      local loW, hiW = -math.huge, math.huge
      for k = i0, i1 do loW = max(loW, pl.lo[k]); hiW = min(hiW, pl.hi[k]) end
      -- blockierte Querlagen (sortiert, zusammengefasst)
      table.clear(blocks)
      local tReach, alongside = math.huge, false
      for _, ob in ipairs(group) do
        blocks[#blocks + 1] = { ob.dMeet - ob.half, ob.dMeet + ob.half }
        tReach = min(tReach, max(ob.tMeet or 0, 0.05))
        alongside = alongside or ob.alongside
      end
      table.sort(blocks, function(a, b) return a[1] < b[1] end)
      -- freie Lücken dazwischen
      local best, bestCost = nil, math.huge
      local cursor = loW
      local function inGroup(o)
        for _, ob in ipairs(group) do if ob == o then return true end end
        return false
      end
      local function sameSide(a, b)
        for _, ob in ipairs(group) do
          if ob.alongside then
            local mySide = egoLat < ob.d and -1 or 1
            if (mySide == -1 and a > ob.d) or (mySide == 1 and b < ob.d) then return false end
          end
        end
        return true
      end
      local function consider(a, b)
        if b < a then return end
        local target = clamp(egoLat, a, b)
        local need = abs(target - egoLat)
        local ok
        -- seitlicher Versatz in der Zeit bis dorthin (Sinus-Spurwechsel: a = pi²/2 * Weg / t²)
        -- direkt daneben: nur auf der Seite bleiben, auf der er schon ist (wegdrücken geht immer)
        if alongside then ok = sameSide(a, b) else ok = 4.93 * need / max(tReach - 0.3, 0.05) ^ 2 <= latLimit end
        if not ok then return end
        -- Gegenverkehr: kommt er, bevor das Überholen vorbei ist, in diese Lücke? Dann nicht.
        local tEnd = gs1 / max(v0 + passDelta * 0.5, 1) + 1
        for _, on in ipairs(list) do
          if on.vAlong < -1 and on.gapLong > 0 then
            local tO = on.gapLong / (v0 + abs(on.vAlong))
            if tO < tEnd and on.d + on.half > a and on.d - on.half < b and not inGroup(on) then return end
          end
        end
        local cost = need
        -- bei der letzten Wahl bleiben (kein Hin und Her)
        for _, ob in ipairs(group) do
          local last = sideChoice[ob.id]
          if last and last >= a - 0.3 and last <= b + 0.3 then cost = cost - 1.5 break end
        end
        if cost < bestCost then best, bestCost = { a, b, target }, cost end
      end
      for _, bl in ipairs(blocks) do
        consider(cursor, min(bl[1], hiW))
        cursor = max(cursor, bl[2])
      end
      consider(cursor, hiW)
      for _, ob in ipairs(group) do
        sideChoice[ob.id] = best and best[3] or nil
        ob.side = best and (best[3] < ob.dMeet and -1 or 1) or nil
      end
      if best then
        for k = i0, i1 do
          pl.lo[k] = max(pl.lo[k], best[1])
          pl.hi[k] = min(pl.hi[k], best[2])
        end
        groups[#groups + 1] = { members = group, i0 = i0, i1 = i1 }
      else
        -- keine Lücke: hinter dem bleiben, hinter dem er quer am ehesten steht
        local fob = nil
        for _, ob in ipairs(group) do
          if not ob.alongside and (not fob or abs(ob.d - egoLat) < abs(fob.d - egoLat)) then fob = ob end
        end
        if fob and fob.vAlong > -1 then addFollow(fob, fob.gapLong) end
        -- wer direkt daneben fährt: auf der eigenen Seite bleiben
        for _, ob in ipairs(group) do
          if ob.alongside then
            local i1b = indexAt(pl, max(ob.s + (ob.len + ego.length) * 0.5, 0) + 6)
            for k = 2, i1b do
              if egoLat < ob.d then pl.hi[k] = max(min(pl.hi[k], ob.dMeet - ob.half), pl.lo[k])
              else pl.lo[k] = min(max(pl.lo[k], ob.dMeet + ob.half), pl.hi[k]) end
            end
          end
        end
        -- Gegenverkehr ohne Lücke: weg von seiner Seite (notfalls eng an ein anderes Auto) und Tempo raus
        for _, ob in ipairs(group) do
          if ob.vAlong <= -1 and ob.gapLong > 0 then
            local away = ob.dMeet < egoLat and 1 or -1
            local i1b = indexAt(pl, ob.gapLong + 10)
            for k = 2, i1b do
              if away == 1 then
                pl.lo[k] = min(max(pl.lo[k], ob.dMeet + ob.half), pl.baseHi[k])
                pl.hi[k] = max(pl.hi[k], pl.lo[k])
              else
                pl.hi[k] = max(min(pl.hi[k], ob.dMeet - ob.half), pl.baseLo[k])
                pl.lo[k] = min(pl.lo[k], pl.hi[k])
              end
            end
            followCaps[#followCaps + 1] = { s = 0, v = v0 * 0.6, d = ob.d, gap = math.huge, ob = ob }
          end
        end
      end
    end
  end
  -- hinter dem Vordermann einordnen (der nächste, den er nicht überholen kann), bereit für die nächste Lücke
  -- bei mehreren (Wand aus Autos): der, hinter dem er quer gerade am ehesten steht
  local fc = nil
  for _, c in ipairs(followCaps) do
    if c.gap < math.huge and (not fc or abs(c.d - egoLat) + c.gap * 0.05 < abs(fc.d - egoLat) + fc.gap * 0.05) then fc = c end
  end
  if fc then
    local i1 = indexAt(pl, max(fc.gap, 0))
    for k = 3, i1 do
      local lo, hi = max(pl.lo[k], fc.d - 0.6), min(pl.hi[k], fc.d + 0.6)
      if lo <= hi then pl.lo[k], pl.hi[k] = lo, hi end
    end
  end
  pl.followCaps = followCaps
  local nowFollow = {}
  for _, c in ipairs(followCaps) do
    if c.ob and c.gap < math.huge then nowFollow[c.ob.id] = (followTime[c.ob.id] or 0) + dt end
  end
  followTime = nowFollow
  pl.ttc = nearestTtc
end

-- Glatteste Linie in der erlaubten Spanne (minimale Krümmung) --------------------------
local function smoothLine(pl, egoLat, prefOverride, pullOverride, prefUntil)
  local n = pl.n
  local off, px, py = pl.off, pl.px, pl.py
  local cx, cy, nx, ny, lo, hi = pl.cx, pl.cy, pl.nx, pl.ny, pl.lo, pl.hi
  -- Anfang: wo das Auto ist und wohin es zeigt
  off[1] = egoLat
  for k = 1, n do px[k] = cx[k] + off[k] * nx[k]; py[k] = cy[k] + off[k] * ny[k] end
  -- Anfänger nutzen die Straße weniger aus: Zug zur eigenen Querlage
  local pull = (1 - p.skill) * 0.35
  local pref = egoLat
  local kPref = prefUntil and indexAt(pl, prefUntil) or n
  for it = 1, p.smoothIter do
    -- abwechselnd vorwärts und rückwärts, damit Einschränkungen weiter vorne schnell bis zum Auto wirken
    local k0, k1, ks = 2, n - 2, 1
    if it % 2 == 0 then k0, k1, ks = n - 2, 2, -1 end
    for k = k0, k1, ks do
      local km2 = max(k - 2, 1)
      local tx = (-px[km2] + 4 * px[k - 1] + 4 * px[k + 1] - px[k + 2]) / 6
      local ty = (-py[km2] + 4 * py[k - 1] + 4 * py[k + 1] - py[k + 2]) / 6
      local o = (tx - cx[k]) * nx[k] + (ty - cy[k]) * ny[k]
      if prefOverride and k <= kPref then
        o = (o + pullOverride * clamp(prefOverride, lo[k], hi[k])) / (1 + pullOverride)
      else
        o = (o + pull * clamp(pref, lo[k], hi[k])) / (1 + pull)
      end
      o = clamp(o, lo[k], hi[k])
      off[k] = o
      px[k] = cx[k] + o * nx[k]
      py[k] = cy[k] + o * ny[k]
    end
  end
  for k = n - 1, n do
    off[k] = clamp(off[n - 2], lo[k], hi[k])
    px[k] = cx[k] + off[k] * nx[k]
    py[k] = cy[k] + off[k] * ny[k]
  end
end

-- Schafft die geglättete Linie das Vorbeifahren wirklich? Sonst dahinter bleiben -------
local function checkPasses(pl, courage)
  local headway = lerp(p.headwayMax, p.headwayMin, courage)
  for _, gr in ipairs(pl.groups or {}) do
    local bad = nil
    for _, ob in ipairs(gr.members) do
      local minHalf = ob.wid * 0.5 + ego.width * 0.5 + 0.1
      local k = indexAt(pl, max(ob.sMeet, 0))
      if abs(pl.off[k] - ob.dMeet) < minHalf and not ob.alongside then
        if not bad or ob.gapLong < bad.gapLong then bad = ob end
      end
    end
    if bad then
      local vO = max(bad.vAlong, 0)
      local want = vO * headway + 2
      local v = max(vO - max(want - bad.gapLong, 0) * 0.6, 0)
      pl.followCaps[#pl.followCaps + 1] = { s = max(bad.gapLong - want, 0), v = v, d = bad.d, gap = bad.gapLong, ob = bad }
      bad.side = nil
    end
  end
  table.sort(pl.followCaps, function(a, b) return a.s < b.s end)
end

-- Tempo-Profil ---------------------------------------------------------------------------
local function speedProfile(pl, courage, pace)
  local n = pl.n
  local px, py, kappa, v = pl.px, pl.py, pl.kappa, pl.v
  local mu = obj:getStaticFrictionCoef()
  local cornerUse = lerp(p.cornerUseMin, p.cornerUseMax, p.skill) * pace
  local brakeUse = lerp(p.brakeUseMin, p.brakeUseMax, p.skill) + courage * 0.04
  local aBrake = mu * g * brakeUse
  -- Krümmung über drei Punkte (Abstand 2 Stützpunkte, glatter)
  for k = 1, n do
    local a, b = max(1, k - 2), min(n, k + 2)
    if b - a < 2 then
      kappa[k] = 0
    else
      local ax, ay = px[k] - px[a], py[k] - py[a]
      local bx, by = px[b] - px[k], py[b] - py[k]
      local cx2, cy2 = px[b] - px[a], py[b] - py[a]
      local cross = ax * by - ay * bx
      local la, lb, lc = sqrt(ax * ax + ay * ay), sqrt(bx * bx + by * by), sqrt(cx2 * cx2 + cy2 * cy2)
      kappa[k] = abs(2 * cross / max(la * lb * lc, 1e-6))
    end
  end
  for k = 1, n do
    local kk = max(kappa[k], 1e-5)
    v[k] = min(sqrt(mu * g * cornerUse / kk), p.maxSpeed)
  end
  -- Verkehr ohne Lücke: Tempolimit ab der Stelle
  for _, c in ipairs(pl.followCaps or {}) do
    for k = indexAt(pl, c.s), n do v[k] = min(v[k], c.v) end
  end
  -- Bremspunkte: rückwärts; hinter Verkehr mit sanfterer Verzögerung (erst lupfen)
  local aFollow = min(aBrake, p.followDecel * (0.8 + courage * 0.6))
  local hasCap = pl.followCaps and #pl.followCaps > 0
  local firstCap = hasCap and indexAt(pl, pl.followCaps[1].s) or math.huge
  for k = n - 1, 1, -1 do
    local ds = pl.s[k + 1] - pl.s[k]
    local a = (k < firstCap and hasCap) and aFollow or aBrake
    v[k] = min(v[k], sqrt(v[k + 1] * v[k + 1] + 2 * a * ds))
  end
  pl.aBrake = aBrake
end

-- Wo ist das Ziel (Spieler) relativ zur Planung? s < 0 = hinter dem Fahrer
local function targetOnPlan(pl)
  local o = mapmgr.objects[p.targetId]
  if not o or not o.pos then return nil end
  local c = obj:getObjectCenterPosition(p.targetId)
  local bestK, bestD = 1, math.huge
  for k = 1, min(pl.n, 40) do
    local dx, dy = c.x - pl.cx[k], c.y - pl.cy[k]
    local d = dx * dx + dy * dy
    if d < bestD then bestK, bestD = k, d end
  end
  if bestD > 60 * 60 or abs(c.z - pl.cz[bestK]) > 4 then return nil end
  local sT = pl.s[bestK] + (c.x - pl.cx[bestK]) * pl.tx[bestK] + (c.y - pl.cy[bestK]) * pl.ty[bestK]
  return {
    s = sT, d = lateralAt(pl, bestK, c.x, c.y),
    vAlong = o.vel.x * pl.tx[bestK] + o.vel.y * pl.ty[bestK],
    len = obj:getObjectInitialLength(p.targetId),
  }
end

-- Stufe 3: Windschatten (hinten), Blocken und Bremstest (vorne). Gibt bevorzugte Querlage zurück.
local function planDuel(pl, egoLat, dt)
  duel.blockCool = max(duel.blockCool - dt, 0)
  duel.blockTime = max(duel.blockTime - dt, 0)
  duel.brakeCool = max(duel.brakeCool - dt, 0)
  if p.targetId == nil or p.targetId < 0 then return nil end
  local t = targetOnPlan(pl)
  if not t then return nil end
  local v0 = ego.speed
  -- gerade Strecke voraus? (alte Planung: Krümmung der nächsten 60 m)
  local straight = true
  if plan and plan.kappa then
    for k = 1, min(plan.n, indexAt(plan, 60)) do if (plan.kappa[k] or 0) > 0.004 then straight = false break end end
  end
  local tailLen = (t.len + ego.length) * 0.5
  if (race.gap or 0) < 0 and t.s > tailLen + 3 and t.s < p.draftDist and abs(t.vAlong - v0) < 8 then
    -- hinter dem Spieler: in den Windschatten, das Überholen regelt die Lückensuche
    return t.d, 0.6, t.s
  end
  if (race.gap or 0) > 0 and t.s < -tailLen and t.s > -(tailLen + 30) then
    local behindLat = t.d
    -- Blocken: Aggressive machen die Linie zu, auf der Geraden, eine Reaktion pro Versuch
    if p.aggression >= p.blockMinAggression and straight then
      if duel.blockTime <= 0 and duel.blockCool <= 0 and t.vAlong > v0 - 1 then
        duel.blockTime = lerp(1.5, 3, p.aggression)
        duel.blockCool = p.blockCooldown
        duel.blockLat = behindLat
        duel.blockMoves = 0
        dlog('blockt')
      elseif duel.blockTime > 0 and duel.blockLat and abs(behindLat - duel.blockLat) > 2 and duel.blockMoves < 1 then
        duel.blockLat = behindLat -- er zieht einmal nach
        duel.blockMoves = duel.blockMoves + 1
      end
    end
    -- Bremstest: nur Fieslinge, du direkt hinter ihm
    if p.fairness < p.brakeCheckFairness and duel.brakeCool <= 0 and duel.brakeCheck <= 0
        and t.s > -(tailLen + 18) and abs(behindLat - egoLat) < 1.2 and v0 > 20 then
      local chance = 0.25 * (1 - p.fairness / p.brakeCheckFairness) * dt
      if math.random() < chance then
        duel.brakeCheck = 0.7
        duel.brakeCool = p.brakeCheckCooldown
        dlog('Bremstest')
      end
    end
    if duel.blockTime > 0 and duel.blockLat then return duel.blockLat, 0.8, 60 end
  end
  return nil
end

-- Stufe 4: Fehler auslösen (Können, Druck, Nerven)
local function planMistakes(pl, courage, nerves, dt)
  if mistake.time > 0 then
    mistake.time = mistake.time - dt
    if mistake.time <= 0 then mistake.kind = nil end
  end
  mistake.cool = max(mistake.cool - dt, 0)
  if mistake.kind or mistake.cool > 0 then return end
  local pressure = clamp(1 - abs(race.gap or 0) / 40, 0, 1)
  -- Schreckreaktion: ein Auto zieht dicht vor ihm plötzlich rüber
  for _, ob in ipairs(pl.obstacles) do
    if abs(ob.vLat) > 0.8 and ob.s > 0 and ob.s < 40 and not mistake.scared[ob.id] then
      mistake.scared[ob.id] = true
      if math.random() < (1 - nerves) * 0.4 * (1 - p.skill * 0.5) then
        mistake.kind, mistake.time, mistake.cool = 'scare', 0.45, p.errorCooldown
        mistake.dir = ob.d > 0 and -1 or 1
        dlog('Fehler: Schreckreaktion')
        return
      end
    end
  end
  local perMin = lerp(p.errorRateMax, p.errorRateMin, p.skill) * (1 + pressure * (1 - nerves) * 1.5)
  if math.random() >= perMin / 60 * dt then return end
  local w = {
    late = courage,
    timid = 1 - courage,
    gap = courage * (1 - p.skill),
    wobble = (1 - nerves) * 0.7,
  }
  local total = 0
  for _, x in pairs(w) do total = total + x end
  local r = math.random() * total
  local kind = 'late'
  for _, k in ipairs({ 'late', 'timid', 'gap', 'wobble' }) do
    r = r - w[k]
    if r <= 0 then kind = k break end
  end
  local dur = { late = 4, timid = 3, gap = 3, wobble = 1.5 }
  mistake.kind, mistake.time, mistake.cool = kind, dur[kind], p.errorCooldown
  dlog('Fehler: ' .. kind)
end

local function makePlan(dt)
  local courage, nerves, pace = effective()
  local look = clamp(ego.speed * p.lookTime, p.minLook, p.maxLook)
  extendRoute(look + 60)
  local pl = newPlan()
  local edgeMargin = lerp(p.edgeMarginMax, p.edgeMarginMin, courage)
  if not buildSamples(pl, look, edgeMargin) then return nil end
  local egoLat = lateralAt(pl, 1, ego.pos.x, ego.pos.y)
  initOffsets(pl, egoLat)
  planTraffic(pl, courage, nerves, dt, egoLat)
  planMistakes(pl, courage, nerves, dt)
  local prefLat, prefPull, prefUntil = planDuel(pl, egoLat, dt)
  smoothLine(pl, egoLat, prefLat, prefPull, prefUntil)
  checkPasses(pl, courage)
  speedProfile(pl, courage, pace)
  pl.egoLat = egoLat
  pl.courage = courage
  return pl
end

-- Regler ---------------------------------------------------------------------------------

local function wheelCoefs()
  local tcs, abs_ = 1, 1
  local speed = max(abs(ego.vel:dot(ego.dir)), 3)
  local lwheels = wheels.wheels
  local totalSlip, totalDown, propSlip = 0, 0, 0
  for i = 0, tableSizeC(lwheels) - 1 do
    local wd = lwheels[i]
    if wd and not wd.isBroken then
      local slip = wd.lastSlip or 0
      local down = wd.downForceRaw or 0
      totalSlip = totalSlip + slip * down
      totalDown = totalDown + down
      if wd.isPropulsed then propSlip = max(propSlip, slip) end
    end
  end
  if totalDown > 0 then
    totalSlip = totalSlip / totalDown
    abs_ = min(1, 1.5 * (max(0, speed - totalSlip) / speed) ^ 8)
    tcs = max(0.05, speed - propSlip * propSlip) / speed
  end
  return tcs, abs_
end

local function control(dt)
  local pl = plan
  if not pl then driveCar(0, 0, 0.3, 0) return end
  local v = ego.speed

  -- wo steht das Auto jetzt auf der Planung (sie ist bis zu 0.1 s alt)?
  local bestK, bestD = 1, math.huge
  for k = 1, min(pl.n, 30) do
    local dx, dy = pl.px[k] - ego.pos.x, pl.py[k] - ego.pos.y
    local d = dx * dx + dy * dy
    if d < bestD then bestK, bestD = k, d end
  end
  local sNow = pl.s[bestK]

  -- Lenkung: Punkt auf der Linie in Vorschau-Entfernung anpeilen
  local ld = clamp(p.steerLookBase + v * p.steerLookTime, 6, 45)
  local sT = min(sNow + ld, pl.s[pl.n])
  local tx, ty = valueAt(pl, pl.px, sT), valueAt(pl, pl.py, sT)
  local tz = valueAt(pl, pl.cz, sT)
  local tv = vec3(tx - ego.pos.x, ty - ego.pos.y, tz - ego.pos.z)
  tv:normalize()
  -- Pure Pursuit: Kreisbogen durch Auto und Zielpunkt -> nötiger Radeinschlag -> Lenkausschlag
  local alpha = asin(clamp(ego.right:dot(tv), -1, 1))
  local delta = math.atan(2 * wheelBase * math.sin(alpha) / ld)
  local steer = delta / steerAngleEst * p.steerGain
  if ego.dir:dot(tv) < 0 then steer = steer >= 0 and 1 or -1 end
  steer = clamp(steer, -1, 1)
  local rate = p.steerRate * dt
  steer = lastSteer + clamp(steer - lastSteer, -rate, rate)

  -- Tempo: was die Planung kurz voraus erlaubt (Reaktion/Trägheit)
  local sV = sNow + v * 0.25 + 1.5
  local vT = valueAt(pl, pl.v, min(sV, pl.s[pl.n]))
  local err = vT - v
  local throttle, brake = 0, 0
  if err >= 0 then
    throttle = err > 2 and 1 or clamp(0.35 + err * 0.35, 0, 1)
  elseif err > -p.liftBand then
    throttle, brake = 0, 0 -- nur Gas weg
  else
    brake = clamp(0.15 + (-err - p.liftBand) * 0.22, 0, 1)
  end

  -- Rennstart: Reaktionszeit, erst dann Vollgas
  if startDelay > 0 then
    startDelay = startDelay - dt
    throttle = min(throttle, 0.3)
  end
  -- Bremstest (Fieslinge)
  if duel.brakeCheck > 0 then
    duel.brakeCheck = duel.brakeCheck - dt
    throttle, brake = 0, max(brake, 0.45)
  end
  -- Fehler: Schreckreaktion (Bremse rein, Lenkrad zuckt) und Überkorrektur (Schlingern)
  if mistake.kind == 'scare' then
    throttle, brake = 0, max(brake, 0.6)
    steer = clamp(steer + (mistake.dir or 1) * 0.05, -1, 1)
  elseif mistake.kind == 'wobble' then
    steer = clamp(steer + math.sin(simTime * 7) * 0.06, -1, 1)
  end

  -- Notbremse
  local emergency = lerp(p.emergencyTtcMax, p.emergencyTtcMin, pl.courage or p.courage)
  if (pl.ttc or math.huge) < emergency then
    throttle, brake = 0, 1
  end

  local tcs, absC = wheelCoefs()
  throttle = throttle * tcs
  brake = brake * absC
  if brake > 0 then throttle = 0 end
  driveCar(steer, throttle, brake, 0)
end

-- Festgefahren: kurz zurücksetzen und neu ausrichten ------------------------------------
local function handleStuck(dt)
  if reverseTime > 0 then
    reverseTime = reverseTime - dt
    -- im Arcade-Getriebe fährt "Bremse" im Stand rückwärts; gegengelenkt
    driveCar(-lastSteer, 0, 0.6, 0)
    if reverseTime <= 0 then stuckTime = 0 end
    return true
  end
  if lastThrottle > 0.4 and ego.speed < 1.2 then
    stuckTime = stuckTime + dt
  else
    stuckTime = max(0, stuckTime - dt)
  end
  if stuckTime > 2.5 then
    reverseTime = 1.6
    stuckTime = 0
    return true
  end
  return false
end

-- Debug-Anzeige ----------------------------------------------------------------------------
local function debugDraw()
  local pl = plan
  if not pl then return end
  local dd = obj.debugDrawProxy
  for k = 1, pl.n, 3 do
    local vmax = pl.v[k]
    local r = clamp(1 - vmax / 50, 0, 1)
    dd:drawSphere(0.25, vec3(pl.px[k], pl.py[k], pl.cz[k] + 0.4), color(255 * r, 255 * (1 - r), 40, 200))
  end
  for _, ob in ipairs(pl.obstacles) do
    local cpos = obj:getObjectCenterPosition(ob.id)
    local c = ob.side == -1 and color(60, 140, 255, 220) or (ob.side == 1 and color(255, 200, 40, 220) or color(255, 40, 40, 220))
    dd:drawSphere(0.6, cpos + vec3(0, 0, 1.8), c)
  end
end

-- Ablauf -----------------------------------------------------------------------------------

local function updateEgo()
  ego.pos:set(obj:getFrontPositionXYZ())
  ego.dir:set(obj:getDirectionVectorXYZ())
  ego.up:set(obj:getDirectionVectorUpXYZ())
  ego.right:setCross(ego.dir, ego.up)
  ego.right:normalize()
  ego.vel:set(obj:getSmoothRefVelocityXYZ())
  ego.speed = ego.vel:length()
end

-- Gierrate messen und daraus die Lenkübersetzung schätzen (jedes Auto lenkt anders stark ein)
local function learnSteering(dt)
  if dt <= 0 then return end
  local yr = (ego.dir - prevDir):dot(ego.right) / dt -- + = dreht nach rechts
  prevDir:set(ego.dir)
  yawRate = yawRate + (yr - yawRate) * min(1, dt * 10)
  local v = ego.speed
  if v > 8 and abs(lastSteer) > 0.04 and abs(lastSteer) < 0.6 and abs(yawRate * v) < 0.45 * g * obj:getStaticFrictionCoef() then
    local meas = math.atan(yawRate * wheelBase / v) / lastSteer
    if meas > 0.12 and meas < 1.3 then
      steerAngleEst = steerAngleEst + (meas - steerAngleEst) * min(1, dt * 0.6)
    end
  end
end

local function updateGFX(dt)
  if not active then return end
  simTime = simTime + dt
  mapData = mapmgr.mapData
  if not mapData then
    waitMap = waitMap + dt
    driveCar(0, 0, 0, 0)
    if waitMap > 6 then report('keine Straßendaten (mapmgr.mapData)') end
    return
  end
  graph = mapData.graph
  updateEgo()
  learnSteering(dt)
  updateTrail(dt)

  if #route < 2 then
    if not initRoute() then
      driveCar(0, 0, 0.5, 0)
      offRouteTime = offRouteTime + dt
      if offRouteTime > 6 then report('keine Straße gefunden') end
      return
    end
  end

  if handleStuck(dt) then return end

  planTimer = planTimer - dt
  if planTimer <= 0 or not plan then
    planTimer = p.replan
    local dRoute = trimRoute()
    if dRoute > 25 then
      offRouteTime = offRouteTime + p.replan
      if offRouteTime > 1 then initRoute(); offRouteTime = 0 end
    else
      offRouteTime = 0
    end
    if #route >= 2 then
      local ok, res = pcall(makePlan, p.replan)
      if ok then
        plan = res
      else
        log('E', 'hashiriyaDriver', 'Planung: ' .. tostring(res))
        plan = nil
      end
    end
    status = plan and 'drive' or 'noplan'
  end

  control(dt)
  if p.debug then debugDraw() end
end

-- Radstand aus den Radpositionen (wie die BeamNG-KI)
computeWheelBase = function()
  local ok, wb = pcall(function()
    local dir = vec3(obj:getDirectionVectorXYZ())
    local sum, n = 0, 0
    for _, wheel in pairs(wheels.wheels) do sum = sum + obj:getNodePosition(wheel.node1):dot(dir); n = n + 1 end
    if n < 2 then return nil end
    local avg = sum / n
    local f, fn, r, rn = 0, 0, 0, 0
    for _, wheel in pairs(wheels.wheels) do
      local d = obj:getNodePosition(wheel.node1):dot(dir)
      if d > avg then f = f + d; fn = fn + 1 else r = r + d; rn = rn + 1 end
    end
    if fn == 0 or rn == 0 then return nil end
    return f / fn - r / rn
  end)
  if ok and wb and wb > 1.5 and wb < 6 then return wb end
  return 2.6
end

-- Öffentliche Funktionen ---------------------------------------------------------------

function M.start(params)
  p = {}
  for k, v in pairs(defaults) do p[k] = v end
  for k, v in pairs(params or {}) do p[k] = v end
  table.clear(route)
  table.clear(seen)
  table.clear(sideChoice)
  followTime = {}
  table.clear(trail)
  plan = nil
  planTimer, waitMap, stuckTime, reverseTime, offRouteTime, simTime = 0, 0, 0, 0, 0, 0
  lastSteer, lastThrottle, lastBrake = 0, 0, 0
  failedReported = false
  race.gap, race.ownSp, race.otherSp = 0, 1, 1
  duel.blockTime, duel.blockCool, duel.blockLat, duel.blockMoves, duel.brakeCheck, duel.brakeCool = 0, 3, nil, 0, 0, 10
  mistake.kind, mistake.time, mistake.cool = nil, 0, 5
  table.clear(mistake.scared)
  startDelay = lerp(p.reactionMax, p.reactionMin, p.skill)
  ego.width = obj:getInitialWidth()
  wheelBase = computeWheelBase()
  prevDir:set(obj:getDirectionVectorXYZ())
  ego.length = obj:getInitialLength()
  if not mapmgr.mapData then mapmgr.requestMap() end
  if controller.mainController and not savedGearbox then
    savedGearbox = electrics.values.gearboxMode
    controller.mainController.setGearboxMode('arcade')
  end
  input.event('parkingbrake', 0, 'FILTER_AI', nil, nil, nil, 'ai')
  active = true
  M.updateGFX = updateGFX
  status = 'start'
end

function M.stop()
  if not active then return end
  active = false
  driveCar(0, 0, 0, 0)
  M.updateGFX = nop
  if savedGearbox and controller.mainController then
    controller.mainController.setGearboxMode(savedGearbox)
  end
  savedGearbox = nil
  plan = nil
  status = 'idle'
end

function M.setRace(info)
  if type(info) ~= 'table' then return end
  if info.gap then race.gap = info.gap end
  if info.ownSp then race.ownSp = info.ownSp end
  if info.otherSp then race.otherSp = info.otherSp end
end

function M.setParams(params)
  for k, v in pairs(params or {}) do p[k] = v end
end

function M.isActive() return active end
function M.getStatus() return status end

M.updateGFX = nop
M.onReset = function()
  -- Fahrzeug zurückgesetzt: Route neu suchen
  table.clear(route)
  plan = nil
end

-- intern, für Offline-Tests
M._internal = { defaults = defaults, laneSpan = laneSpan, getPlan = function() return plan end, route = route }

return M
