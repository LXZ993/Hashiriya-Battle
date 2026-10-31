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
  cornerUseMin = 0.8,   -- Anteil des Grips in Kurven bei Können 0
  cornerUseMax = 0.9,   -- ... bei Können 1
  brakeUseMin = 0.68,    -- Anteil des Grips beim Bremsen bei Können 0
  brakeUseMax = 0.9,
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
  highSpeedBrakeReserve = 0.2, -- bei hohem Tempo bis zu 20 % weniger Bremsweg-Verzögerung eingeplant (ab 90 km/h, voll bei 270 km/h)
  highSpeedReserve = 0.15, -- schnelle Kurven: bis zu 15 % weniger Querbeschleunigung (ab 90 km/h zunehmend, voll bei 234 km/h)
  driftTol = 0.3,        -- m: so weit darf es ihn in der Kurve nach außen tragen, darüber nimmt er Tempo raus und merkt es sich
  edgeMarginSpeed = 0.012, -- m mehr Abstand zum Rand pro m/s über 20 m/s (230 km/h: +0,5 m)
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
  logBrakes = true,
  shoulderMax = 4,       -- m: so weit neben der Fahrbahn (Standstreifen, Abfahrtsspur) darf er an Verkehr vorbei, 0 = nie      -- jeden Bremsgrund (max. 1x pro s) ins beamng.log schreiben
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
local planAge, errLogTime = 0, -10
local brakeCap = 9.8     -- m/s²: gelernte Verzögerung bei Vollbremsung (wird beim Start auf mu*g gesetzt)
local brakeTime, prevSpeed = 0, nil
local primeSeen = false
local gripEst = 1        -- gelernter Anteil des Grips, den das Auto wirklich schafft (Untersteuern)
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
local brakeLogTime = 0 -- Bremsgrund höchstens 1x pro Sekunde ins Log

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
  if not e.oneWay and plus == 1 and n <= 2 then return 0, 1, n, false, (left - 1) / n, right / n end
  return (left - 1) / n, right / n, n, e.oneWay, (left - 1) / n, right / n
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
    baseLo = {}, baseHi = {}, wideLo = {}, wideHi = {}, ownLo = {}, ownHi = {}, edgeL = {}, edgeR = {}, rad = {}, lo = {}, hi = {}, off = {}, px = {}, py = {}, kappa = {}, v = {},
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
    local xl, xr, _, _, ol, orr = laneSpan(na, nb)
    ol, orr = ol or xl, orr or xr
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
      pl.edgeL[n], pl.edgeR[n], pl.rad[n] = xl < 0.01, xr > 0.99, r
      pl.ownLo[n], pl.ownHi[n] = -r + ol * 2 * r, -r + orr * 2 * r -- eigene Fahrspuren (Rest = Gegenverkehr)
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
  pl.prevShift = shift
  for k = 1, pl.n do
    local o = egoLat
    if shift then
      local sp = pl.s[k] + shift
      if sp <= prev.s[prev.n] then o = valueAt(prev, prev.off, sp) end
    end
    pl.off[k] = clamp(o, pl.lo[k], pl.hi[k])
  end
end

-- Echte Breite messen (Standstreifen, Abfahrtsspur): Strahl zur Wand, Boden prüfen ---------
-- Die Straßendaten der Karte enden oft an der Spur, der Standstreifen daneben ist aber befahrbar.
-- Nur zum Vorbeifahren am Verkehr, die Ideallinie bleibt auf der Fahrbahn.
local rayFrom, rayDir = vec3(), vec3()
local function freeSide(pl, k, side)
  local nx, ny = pl.nx[k] * side, pl.ny[k] * side
  local r = pl.rad[k]
  local maxD = r + p.shoulderMax
  -- zwei Höhen: niedrige Leitplanke und hohe Wand
  rayDir:set(nx, ny, 0)
  rayFrom:set(pl.cx[k], pl.cy[k], pl.cz[k] + 0.45)
  local wall = obj:castRayStatic(rayFrom, rayDir, maxD)
  rayFrom:set(pl.cx[k], pl.cy[k], pl.cz[k] + 0.9)
  wall = min(wall, obj:castRayStatic(rayFrom, rayDir, maxD))
  local free = min(wall, maxD) - r
  if free < 0.5 then return 0 end
  -- Boden am äußeren Rand: kein Abhang, kein Graben
  local o = r + free - 0.3
  rayFrom:set(pl.cx[k] + nx * o, pl.cy[k] + ny * o, pl.cz[k] + 1.5)
  rayDir:set(0, 0, -1)
  local down = obj:castRayStatic(rayFrom, rayDir, 3)
  if abs(down - 1.5) > 0.4 then return 0 end
  return free
end

local function measureWidth(pl, courage)
  local n = pl.n
  local margin = lerp(0.6, 0.3, courage) + ego.width * 0.5
  local every = 3
  local lastL, lastR = 0, 0
  for k = 1, n do
    pl.wideLo[k], pl.wideHi[k] = pl.baseLo[k], pl.baseHi[k]
  end
  if p.shoulderMax <= 0 or not obj.castRayStatic then return end
  for k = 1, n do
    if k % every == 1 or k == n then
      lastL = pl.edgeL[k] and freeSide(pl, k, -1) or 0
      lastR = pl.edgeR[k] and freeSide(pl, k, 1) or 0
    end
    local r = pl.rad[k]
    if lastL > 0 then pl.wideLo[k] = min(pl.baseLo[k], -(r + lastL) + margin) end
    if lastR > 0 then pl.wideHi[k] = max(pl.baseHi[k], r + lastR - margin) end
  end
end

-- Ausweichen: Kandidaten durchrechnen (Querlage x Spurwechseldauer x Gas/Bremse) ------------
-- Jeder Kandidat ist ein Weg für die nächsten Sekunden. Alle Autos werden in die Zukunft
-- vorausgesagt; was irgendwann zu nah kommt, fällt raus. Vom Rest gewinnt der, mit dem er am
-- weitesten kommt (wenig bremsen, Ideallinie, nicht hin und her). Kein Sonderfall für
-- Lücken, Standstreifen, zwischen zwei Autos oder Gegenverkehr: das ergibt sich von selbst.
local latTrack = {}
local lastChoice = { kind = 'free', dT = 0, acc = 0, t0 = 0, T = 1 }
local planLattice
local trajT, trajS, trajD = {}, {}, {}
local bestT, bestS, bestD = {}, {}, {}

-- Quintischer Spurwechsel von (d0, Quergeschwindigkeit dv0) nach dT in T Sekunden
local function quintic(d0, dv0, dT, T, t)
  if t >= T then return dT end
  local x = t / T
  local x3 = x * x * x
  local base = d0 + (dT - d0) * x3 * (10 - 15 * x + 6 * x * x)
  -- Quergeschwindigkeit am Anfang klingt weich aus
  local h = dv0 * T * x * (1 - x) * (1 - x) * (1 - x)
  return base + h
end

planLattice = function(pl, courage, list, egoLat)
  local v0 = max(ego.speed, 0.5)
  local mu = obj:getStaticFrictionCoef()
  local latLimit = mu * g * lerp(0.35, 0.6, courage) * gripEst
  local sideGap = lerp(p.sideGapMax, p.sideGapMin, courage)
  local reserve = 0.15
  if mistake.kind == 'gap' then sideGap, reserve = 0, -0.1 end
  local twoWay = false
  for _, ob in ipairs(list) do if ob.vAlong < -1 then twoWay = true end end
  local H = twoWay and 6 or 4
  local dtc = 0.25
  local nSteps = floor(H / dtc + 0.5)
  local lastS = pl.s[pl.n]
  -- Quergeschwindigkeit jetzt
  local dv0 = (ego.dir.x * pl.nx[1] + ego.dir.y * pl.ny[1]) * v0
  -- Tempo der Ideallinie aus der letzten Planung (Kurven), sonst Höchsttempo
  local prev, shift = plan, pl.prevShift
  local function raceV(sq)
    if prev and shift and prev.vRace and sq + shift <= prev.s[prev.n] then return valueAt(prev, prev.vRace, sq + shift) end
    return p.maxSpeed
  end
  local aGo = clamp(3.2 * (1 - v0 / 90), 0.6, 3.2)
  local accs = { aGo, 0, -2.5, -6 }
  -- Abstände je Auto
  for _, ob in ipairs(list) do
    local gap = sideGap
    if ob.target then gap = lerp(min(sideGap, 0.15), max(sideGap, p.playerSideGap), p.fairness) end
    ob.latNeed = (ob.wid + ego.width) * 0.5 + gap + reserve
    ob.lenHalf = (ob.len + ego.length) * 0.5
    ob.side = nil
  end

  -- Querlagen: über die ganze freie Breite (inkl. Standstreifen), dazu die Ideallinie ("free")
  local loAll, hiAll = math.huge, -math.huge
  for k = 1, pl.n do
    if pl.s[k] > v0 * H + 20 then break end
    loAll = min(loAll, pl.wideLo[k]); hiAll = max(hiAll, pl.wideHi[k])
  end
  local targets = {}
  local step = 0.6
  local dq = loAll
  while dq <= hiAll + 1e-6 do targets[#targets + 1] = dq; dq = dq + step end
  targets[#targets + 1] = clamp(egoLat, loAll, hiAll)
  local Ts = { 1.0, 1.6, 2.4, 3.4 }

  local bestCost, bestTColl, best = math.huge, -1, nil
  local tight = false
  local nOk = 0

  -- Steht er schon außerhalb der Fahrbahn: so weit ist das am Anfang erlaubt (er muss erst zurück)
  local outLo0 = max(valueAt(pl, pl.wideLo, 0) - egoLat, 0)
  local outHi0 = max(egoLat - valueAt(pl, pl.wideHi, 0), 0)
  if outLo0 < 0.5 then outLo0 = 0 end
  if outHi0 < 0.5 then outHi0 = 0 end
  -- Autos, mit denen es schon jetzt zu eng ist (z. B. steht er direkt hinter einem stehenden Auto):
  -- dort zählt nur, dass es nicht noch enger wird, sonst käme er nie mehr weg
  for _, ob in ipairs(list) do
    local ds0 = -ego.length * 0.5 - ob.s
    ob.lat0 = abs(egoLat - ob.d)
    ob.conf0 = abs(ds0) < ob.lenHalf + 0.8 and ob.lat0 < ob.latNeed
  end

  local function evaluate(kind, dT, T, acc, cont, force)
    -- Tempo- und Weg-Verlauf
    local s, v = 0, v0
    local cost = 0
    local tColl = nil
    local bad = false
    local minClear = math.huge
    for i = 0, nSteps do
      local t = i * dtc
      if i > 0 then
        local vr = raceV(s)
        local a = acc
        if a > 0 and v >= vr then a = 0 end
        v = max(v + a * dtc, 0)
        if acc > 0 then v = min(v, max(vr, v0)) end
        s = s + v * dtc
      end
      local d
      if kind == 'free' then
        d = s <= lastS and valueAt(pl, pl.off, s) or pl.off[pl.n]
      else
        d = quintic(egoLat, dv0, dT, T, t)
      end
      trajT[i + 1], trajS[i + 1], trajD[i + 1] = t, s, d
      -- Fahrbahn (mit Standstreifen) nicht verlassen
      if s <= lastS then
        local wlo, whi = valueAt(pl, pl.wideLo, s), valueAt(pl, pl.wideHi, s)
        local tol = 0.1 + max(1 - t, 0) * (d < wlo and outLo0 or outHi0)
        if d < wlo - tol or d > whi + tol then
          if not force then return nil end
          bad = true
        end
        local blo, bhi = valueAt(pl, pl.baseLo, s), valueAt(pl, pl.baseHi, s)
        if d < blo then cost = cost + (blo - d) * 1.5 * dtc elseif d > bhi then cost = cost + (d - bhi) * 1.5 * dtc end
        if twoWay then
          -- Gegenfahrbahn: kostet, und am Ende der Vorausschau muss er wieder drüben sein
          local olo, ohi = valueAt(pl, pl.ownLo, s), valueAt(pl, pl.ownHi, s)
          local out = max(olo - d - ego.width * 0.5, d + ego.width * 0.5 - ohi, 0)
          if out > 0 then
            cost = cost + out * 2 * dtc
            if i == nSteps and out > 0.8 then
              if not force then return nil end
              bad = true
            end
          end
        end
      end
      -- Autos
      for _, ob in ipairs(list) do
        local so = ob.s + ob.vAlong * t
        -- Querbewegung (Spurwechsel) ist unsicher: belegt ist alles zwischen jetzt und vorausgesagt
        local dShift = abs(ob.vLat) > 0.5 and clamp(ob.vLat * min(t, 1.2), -2, 2) or 0
        local dob = ob.d + dShift * 0.5
        local ds = (s - ego.length * 0.5) - so
        local longNeed = ob.lenHalf + 0.8
        if ds < 0 then longNeed = longNeed + max(v - ob.vAlong, 0) * 0.25 -- hinter ihm: Bremsweg-Puffer
        else longNeed = longNeed + max(ob.vAlong - v, 0) * 0.35 end      -- vor ihm: er kommt von hinten
        if abs(ds) < longNeed then
          local lat = abs(d - dob)
          local need = ob.latNeed + abs(dShift) * 0.5 + 0.06 * t -- Unsicherheit wächst mit der Zeit
          -- Ideallinie nur, wenn der Verkehr gar nicht im Weg ist (Ausweichen machen die Spurwechsel)
          if kind == 'free' then need = need + 0.8 end
          -- schon zu dicht dran: nur noch echte Berührung zählt (lieber knapp vorbei als hart bremsen)
          if tight then need = (ob.wid + ego.width) * 0.5 + 0.12 + abs(dShift) * 0.3 end
          -- schon jetzt zu eng: in Ordnung, solange es weiter auseinander geht
          if ob.conf0 and t < 2 and lat >= ob.lat0 - 0.05 then need = min(need, lat) end
          if lat < need and not tColl then
            tColl = t
            if not force then break end
          end
          minClear = min(minClear, lat - need)
        end
      end
      if tColl and not force then break end
    end
    if force then return nil, tColl end
    if tColl then
      if tColl > bestTColl and not best then
        -- Notlösung merken: der Weg, auf dem es am längsten gut geht
        bestTColl = tColl
      end
      return nil, tColl
    end
    -- Kosten: Weg (Fortschritt), Querweg, Hin und Her, Abstand, Ideallinie
    cost = cost - s
    if kind == 'lane' then
      cost = cost + abs(dT - egoLat) * 0.6 + (cont and 0 or 2 / T)
      if cont then cost = cost - 8 end -- begonnenen Spurwechsel durchziehen
    else
      cost = cost - 3
      if lastChoice.kind == 'free' then cost = cost - 6 end
    end
    if acc == lastChoice.acc then cost = cost - 1 end
    if minClear < math.huge then cost = cost + 1.5 / (minClear + 0.25) end
    return cost
  end

  local function consider(kind, dT, T, acc, cont)
    local cost, tColl = evaluate(kind, dT, T, acc, cont)
    if cost then
      nOk = nOk + 1
      if cost < bestCost then
        bestCost = cost
        best = { kind = kind, dT = dT, T = T, acc = acc, n = nSteps + 1, cont = cont }
        for i = 1, nSteps + 1 do bestT[i], bestS[i], bestD[i] = trajT[i], trajS[i], trajD[i] end
      end
    elseif tColl and not best and tColl >= bestTColl then
      bestTColl = tColl
      pl.fallback = { kind = kind, dT = dT, T = T, acc = acc, tColl = tColl }
    end
  end

  pl.fallback = nil
  -- laufender Spurwechsel: mit der Restzeit weiterführen (sonst fängt er jedes Mal von vorn an)
  local contT = nil
  if lastChoice.kind == 'lane' then
    contT = max(lastChoice.T - (simTime - lastChoice.t0), 0.4)
    if abs(lastChoice.dT - egoLat) < 0.15 then contT = nil end
  end
  local function searchAll()
  for _, acc in ipairs(accs) do
    consider('free', 0, 1, acc)
    if contT then consider('lane', clamp(lastChoice.dT, loAll, hiAll), contT, acc, true) end
    for _, dT in ipairs(targets) do
      local dd = abs(dT - egoLat)
      for _, T in ipairs(Ts) do
        -- Spurwechsel muss fahrbar sein (Spitzen-Querbeschleunigung eines quintischen Wechsels)
        if 5.77 * dd / (T * T) <= latLimit or dd < 0.3 then
          consider('lane', dT, T, acc)
        end
        if dd < 0.3 then break end
      end
    end
  end
  end
  searchAll()
  if not best then
    -- alles innerhalb der Sicherheitsabstände: mit knappem Abstand nochmal suchen
    tight = true
    searchAll()
    tight = false
  end
  pl.groups = { n = nOk }
  for i = 1, nOk do pl.groups[i] = true end

  if not best then
    -- nichts geht ohne Berührung: Notlösung mit voller Bremse
    local fb = pl.fallback or { kind = 'free', dT = egoLat, T = 1, acc = -6, tColl = 0 }
    -- voll bremsen, außer der Weg ohne Bremse geht deutlich länger gut (er ist schon neben dem Auto)
    local _, tBrake = evaluate(fb.kind, fb.dT, fb.T, -6, false, true)
    if not (tBrake and fb.acc > -6 and fb.tColl > tBrake + 0.5) then fb.acc = -6 end
    evaluate(fb.kind, fb.dT, fb.T, fb.acc, false, true) -- füllt den ganzen Weg
    best = { kind = fb.kind, dT = fb.dT, T = fb.T, acc = fb.acc, n = nSteps + 1 }
    for i = 1, nSteps + 1 do bestT[i], bestS[i], bestD[i] = trajT[i], trajS[i], trajD[i] end
    pl.ttc = fb.tColl or 0
  end
  if best.kind == 'lane' and not best.cont then lastChoice.t0, lastChoice.T = simTime, best.T end
  lastChoice.kind, lastChoice.dT, lastChoice.acc = best.kind, best.dT, best.acc
  pl.choice = best

  -- Gewählten Weg als Korridor in die Planung übernehmen (die Glättung bleibt darin)
  local sEnd = bestS[best.n]
  pl.laneEnd = nil
  if best.kind == 'lane' then
    for i = 1, best.n do if bestT[i] >= best.T then pl.laneEnd = bestS[i] + 10 break end end
  end
  local j = 1
  for k = 1, pl.n do
    local sk = pl.s[k]
    if sk > sEnd then break end
    while j < best.n and bestS[j + 1] < sk do j = j + 1 end
    local d
    if j >= best.n then d = bestD[best.n]
    else
      local s0, s1 = bestS[j], bestS[j + 1]
      local f = s1 > s0 and clamp((sk - s0) / (s1 - s0), 0, 1) or 0
      d = bestD[j] + (bestD[j + 1] - bestD[j]) * f
    end
    local w = best.kind == 'free' and 0.4 or 0.2
    pl.lo[k] = clamp(d - w, pl.wideLo[k], pl.wideHi[k])
    pl.hi[k] = clamp(d + w, pl.wideLo[k], pl.wideHi[k])
    if pl.lo[k] > pl.hi[k] then pl.lo[k], pl.hi[k] = d, d end
    pl.off[k] = clamp(pl.off[k], pl.lo[k], pl.hi[k])
  end
  -- Nach dem Wechsel noch auf der Seite bleiben, bis die Autos dort hinten sind
  if best.kind == 'lane' then
    local holdUntil = sEnd
    for _, ob in ipairs(list) do
      if abs(ob.d - best.dT) < ob.latNeed + 1.5 and ob.vAlong > 0 and ob.s > -ob.lenHalf then
        -- wo überholt er ihn ungefähr?
        local rel = max(v0 - ob.vAlong, 1)
        local sPass = ob.s + ob.lenHalf + 2 + ob.vAlong * (ob.s + ob.lenHalf) / rel
        holdUntil = max(holdUntil, min(sPass, sEnd + 150))
      end
    end
    for k = 1, pl.n do
      if pl.s[k] > sEnd and pl.s[k] <= holdUntil then
        pl.lo[k] = clamp(best.dT - 0.4, pl.wideLo[k], pl.wideHi[k])
        pl.hi[k] = clamp(best.dT + 0.4, pl.wideLo[k], pl.wideHi[k])
        pl.off[k] = clamp(pl.off[k], pl.lo[k], pl.hi[k])
      end
    end
  end
  -- Für Anzeige und Log: an wem fährt er wie vorbei
  for _, ob in ipairs(list) do
    if ob.s > -ob.lenHalf and ob.s < sEnd then
      local dAt = best.dT
      ob.side = dAt < ob.d and -1 or 1
    end
  end
  -- Tempo: nicht "Vollgas" gewählt -> Grenze ab sofort (Rest macht das Tempo-Profil)
  if best.acc < aGo - 0.01 then
    local blocker = nil
    for _, ob in ipairs(list) do
      if ob.s > 0 and abs(ob.d - bestD[1]) < ob.latNeed + 0.5 and (not blocker or ob.s < blocker.s) then blocker = ob end
    end
    if blocker then blocker.side = nil end -- Anzeige: rot = dahinter bleiben
    local vCap = max(v0 + best.acc * 1.0, 0)
    pl.followCaps[1] = { s = 0, v = vCap, d = blocker and blocker.d or 0, gap = blocker and (blocker.s - blocker.len * 0.5) or math.huge, ob = blocker }
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
              if primeSeen then seen[id] = max(seen[id], 10) end
              local isTarget = id == p.targetId
              -- direkt daneben oder ganz nah: sofort bemerkt
              if seen[id] >= reaction or sObs < 15 or isTarget then
                local tx, ty = pl.tx[bestK], pl.ty[bestK]
                -- Querbewegung zur Straße: aus der Änderung der Querlage (gefiltert). Die
                -- Projektion der Geschwindigkeit wackelt in Kurven (Tangente nur alle 3 m),
                -- dann sähe ein Gegenverkehrsauto so aus, als würde es herüberziehen.
                local tr = latTrack[id]
                local vLatRaw = o.vel.x * pl.nx[bestK] + o.vel.y * pl.ny[bestK]
                if tr and simTime - tr.t > 0.02 and simTime - tr.t < 1 then
                  local est = clamp((lat - tr.d) / (simTime - tr.t), -6, 6)
                  tr.v = tr.v + (est - tr.v) * min((simTime - tr.t) / 0.35, 1)
                  tr.d, tr.t = lat, simTime
                elseif not tr or simTime - tr.t >= 1 then
                  tr = { d = lat, t = simTime, v = clamp(vLatRaw, -1, 1) * 0.5 }
                  latTrack[id] = tr
                end
                list[#list + 1] = {
                  id = id, s = sObs, d = lat, len = oLen, wid = oWid,
                  vAlong = o.vel.x * tx + o.vel.y * ty,
                  vLat = tr.v,
                  target = isTarget,
                }
              end
            end
          end
        end
      end
    end
  end
  for id in pairs(seen) do if not present[id] then seen[id] = nil; sideChoice[id] = nil; latTrack[id] = nil end end
  primeSeen = false
  table.sort(list, function(a, b) if a.s ~= b.s then return a.s < b.s end return a.id < b.id end)

  pl.groups = {}
  pl.followCaps = {}
  pl.ttc = math.huge
  if #list == 0 then lastChoice.kind = 'free'; pl.choice = nil return end
  planLattice(pl, courage, list, egoLat)
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

-- Tempo-Profil ---------------------------------------------------------------------------
local function speedProfile(pl, courage, pace)
  local n = pl.n
  local px, py, kappa, v = pl.px, pl.py, pl.kappa, pl.v
  local mu = obj:getStaticFrictionCoef()
  local cornerUse = lerp(p.cornerUseMin, p.cornerUseMax, p.skill) * pace * gripEst
  local brakeUse = (lerp(p.brakeUseMin, p.brakeUseMax, p.skill) + courage * 0.04) * (0.5 + 0.5 * gripEst)
  -- gelernte echte Bremsleistung des Autos (Vollbremsungen gemessen)
  local aBrake = min(mu * g * brakeUse, brakeCap * brakeUse / 0.95)
  local aLatMax = mu * g * cornerUse
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
    local vk = sqrt(mu * g * cornerUse / kk)
    -- schnelle Kurven: Reserve (Bodenwellen, Lenkfehler, weniger Grip bei Tempo)
    vk = vk * sqrt(1 - clamp((vk - 25) / 40, 0, 1) * p.highSpeedReserve)
    v[k] = min(vk, p.maxSpeed)
  end
  -- Spurwechsel zum Überholen: der Schlenker selbst soll ihn nicht einbremsen (er ist nur so stark
  -- geplant, wie das Auto quer schafft). Hängt er dem Wechsel hinterher, wird die Linie ein Knick,
  -- dann zählt dort das Kurventempo der Straße selbst.
  if pl.laneEnd then
    for k = 2, n - 1 do
      if pl.s[k] > pl.laneEnd then break end
      local a, b = max(1, k - 2), min(n, k + 2)
      local ax, ay = pl.cx[k] - pl.cx[a], pl.cy[k] - pl.cy[a]
      local bx, by = pl.cx[b] - pl.cx[k], pl.cy[b] - pl.cy[k]
      local cx2, cy2 = pl.cx[b] - pl.cx[a], pl.cy[b] - pl.cy[a]
      local la, lb, lc = sqrt(ax * ax + ay * ay), sqrt(bx * bx + by * by), sqrt(cx2 * cx2 + cy2 * cy2)
      local kc = max(abs(2 * (ax * by - ay * bx) / max(la * lb * lc, 1e-6)), 1e-5)
      local vr = sqrt(mu * g * cornerUse / kc)
      vr = vr * sqrt(1 - clamp((vr - 25) / 40, 0, 1) * p.highSpeedReserve)
      v[k] = max(v[k], min(vr * 0.95, p.maxSpeed))
    end
  end
  -- Kurventempo ohne Verkehr merken (für die Ausweich-Planung der nächsten Runde)
  pl.vRace = pl.vRace or {}
  for k = 1, n do pl.vRace[k] = v[k] end
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
    local vn = v[k + 1]
    -- in der Kurve braucht der Reifen Grip zum Lenken: weniger bleibt zum Bremsen (Kamm'scher Kreis)
    local latUse = clamp(vn * vn * kappa[k + 1] / aLatMax, 0, 1)
    a = a * sqrt(max(1 - latUse * latUse, 0.2))
    -- bei hohem Tempo bremst ein Auto schwächer (Bremsen werden heiß, weniger Abtrieb als gedacht)
    a = a * (1 - clamp((vn - 25) / 50, 0, 1) * p.highSpeedBrakeReserve)
    v[k] = min(v[k], sqrt(vn * vn + 2 * a * ds))
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
    local cutting = abs(ob.vLat) > 0.8 and (ob.d - (pl.egoLat or 0)) * ob.vLat < 0
    if cutting and not ob.target and ob.s > 0 and ob.s < 40 and not mistake.scared[ob.id] then
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
  local edgeMargin = lerp(p.edgeMarginMax, p.edgeMarginMin, courage) + clamp((ego.speed - 20) * p.edgeMarginSpeed, 0, 0.8)
  if not buildSamples(pl, look, edgeMargin) then return nil end
  local egoLat = lateralAt(pl, 1, ego.pos.x, ego.pos.y)
  measureWidth(pl, courage)
  -- steht er schon auf dem Standstreifen: dort darf die Linie anfangen und läuft sanft zurück
  -- (nur so weit, wie gemessen frei ist; sonst zieht die Linie ihn zurück auf die Fahrbahn)
  local startLat = clamp(egoLat, pl.wideLo[1], pl.wideHi[1])
  for k = 1, pl.n do
    local f = clamp(pl.s[k] / 40, 0, 1)
    if f >= 1 then break end
    if startLat < pl.baseLo[k] then
      pl.baseLo[k] = startLat + (pl.baseLo[k] - startLat) * f
      pl.wideLo[k] = min(pl.wideLo[k], pl.baseLo[k]); pl.lo[k] = pl.baseLo[k]
    elseif startLat > pl.baseHi[k] then
      pl.baseHi[k] = startLat + (pl.baseHi[k] - startLat) * f
      pl.wideHi[k] = max(pl.wideHi[k], pl.baseHi[k]); pl.hi[k] = pl.baseHi[k]
    end
  end
  initOffsets(pl, egoLat)
  planTraffic(pl, courage, nerves, dt, egoLat)
  pl.egoLat = egoLat
  planMistakes(pl, courage, nerves, dt)
  local prefLat, prefPull, prefUntil = planDuel(pl, egoLat, dt)
  smoothLine(pl, egoLat, prefLat, prefPull, prefUntil)
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

  -- Trägt es ihn in der Kurve nach außen (mehr Tempo als Grip)? Dann sofort etwas Tempo raus
  -- und für alle weiteren Kurven merken (wie beim Untersteuern)
  local outSlow = 0
  if v > 15 and bestK > 2 and bestK < pl.n - 2 then
    local ax, ay = pl.px[bestK] - pl.px[bestK - 2], pl.py[bestK] - pl.py[bestK - 2]
    local bx, by = pl.px[bestK + 2] - pl.px[bestK], pl.py[bestK + 2] - pl.py[bestK]
    local cx, cy = bx - ax, by - ay -- zeigt zur Kurven-Innenseite
    local cl = sqrt(cx * cx + cy * cy)
    local mu = obj:getStaticFrictionCoef()
    if cl > 1e-4 and (pl.kappa[bestK] or 0) * v * v > 0.35 * mu * g then
      local outErr = -((ego.pos.x - pl.px[bestK]) * cx + (ego.pos.y - pl.py[bestK]) * cy) / cl
      if outErr > p.driftTol then
        gripEst = max(gripEst - dt * 0.25 * (outErr - p.driftTol), 0.6)
        outSlow = clamp((outErr - p.driftTol) * 0.08, 0, 0.12)
      end
      pl.outErr = outErr
    end
  end

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
  local vT = valueAt(pl, pl.v, min(sV, pl.s[pl.n])) * (1 - outSlow)
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

  -- Warum bremst er? (für die Abstimmung im Spiel, steht im beamng.log)
  if p.logBrakes and brake > 0.25 and simTime - brakeLogTime > 1 then
    brakeLogTime = simTime
    local why = 'Linie'
    if (pl.ttc or math.huge) < emergency then why = 'Notbremse'
    elseif mistake.kind == 'scare' then why = 'Schreck'
    elseif duel.brakeCheck > 0 then why = 'Bremstest' end
    local c = pl.followCaps and pl.followCaps[1]
    local capTxt = 'kein Verkehr'
    if c then
      local ob = c.ob or {}
      capTxt = string.format('Auto %s%s in %.0f m, quer %.1f, %.0f km/h, Limit %.0f km/h ab %.0f m',
        tostring(ob.id), ob.target and ' (Spieler)' or '', c.gap < math.huge and c.gap or (ob.gapLong or -1), ob.d or 0,
        (ob.vAlong or 0) * 3.6, c.v * 3.6, c.s)
    end
    local ch = pl.choice
    local chTxt = 'Ideallinie'
    if ch and #pl.obstacles > 0 then
      chTxt = ch.kind == 'free' and 'Ideallinie' or string.format('nach quer %.1f in %.1f s', ch.dT, ch.T)
      chTxt = chTxt .. (ch.acc > 0.01 and ', Gas' or (ch.acc > -0.01 and ', Tempo halten' or string.format(', verzögern %.1f', -ch.acc)))
    end
    log('I', 'hashiriyaDriver', string.format('Bremse %.2f (%s) bei %.0f km/h, Ziel %.0f km/h, TTC %.1f, quer %.1f, Spur %.1f..%.1f (frei %.1f..%.1f), %d Autos, %d Wege frei, Wahl: %s, Grip %.2f, Bremskraft %.1f, außen %.1f m | %s',
      brake, why, v * 3.6, vT * 3.6, pl.ttc or -1, pl.egoLat or 0, pl.baseLo[1] or 0, pl.baseHi[1] or 0, pl.wideLo[5] or 0, pl.wideHi[5] or 0,
      #pl.obstacles, #(pl.groups or {}), chTxt, gripEst, brakeCap, pl.outErr or 0, capTxt))
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
  -- festgefahren: Gas gibt er, kommt aber nicht vom Fleck, oder er steht vor einem Auto und kein Weg ist frei
  local blocked = plan and (plan.ttc or math.huge) < 0.6 and plan.groups and (plan.groups.n or 0) == 0
  if (lastThrottle > 0.4 or blocked) and ego.speed < 1.2 then
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
  -- Untersteuern erkennen: viel Lenkung, aber die Drehung bleibt deutlich unter dem Soll
  -- -> er schafft weniger Grip als gedacht, Kurventempo runter (langsam wieder rauf)
  local mu = obj:getStaticFrictionCoef()
  if v > 12 and abs(lastSteer) > 0.08 then
    local want = v * math.tan(lastSteer * steerAngleEst) / wheelBase
    local aLat = abs(yawRate * v)
    if abs(yawRate) < abs(want) * 0.75 and aLat > 0.45 * mu * g then
      gripEst = max(gripEst + (clamp(aLat / (mu * g * 0.93), 0.6, 1) - gripEst) * min(1, dt * 2), 0.6)
    end
  end
  gripEst = min(gripEst + dt * 0.004, 1)
  -- Bremsleistung messen: bei (fast) voller Bremse die echte Verzögerung
  if prevSpeed and lastBrake >= 0.85 and v > 12 then
    brakeTime = brakeTime + dt
    local dec = (prevSpeed - v) / dt
    if brakeTime > 0.3 and dec > 1 then
      local k = dec < brakeCap and min(1, dt * 1.5) or min(1, dt * 0.2)
      brakeCap = clamp(brakeCap + (dec - brakeCap) * k, 4, mu * g * 1.3)
    end
  else
    brakeTime = 0
  end
  prevSpeed = v
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
        planAge = 0
      else
        -- Fehler: kurz mit der letzten Planung weiterfahren statt blind geradeaus
        if simTime - errLogTime > 2 then errLogTime = simTime; log('E', 'hashiriyaDriver', 'Planung: ' .. tostring(res)) end
        planAge = planAge + p.replan
        if planAge > 1 then plan = nil end
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
  table.clear(latTrack)
  lastChoice.kind, lastChoice.dT, lastChoice.acc, lastChoice.t0, lastChoice.T = 'free', 0, 0, 0, 1
  planAge, errLogTime = 0, -10
  brakeCap, brakeTime, prevSpeed = obj:getStaticFrictionCoef() * g, 0, nil
  primeSeen = true -- bis zum Start fuhr er schon selbst im Verkehr: die Autos um ihn kennt er
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
