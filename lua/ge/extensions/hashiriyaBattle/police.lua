-- Hashiriya Battle: Blitzer, Laserkontrollen und Polizei-Fahndung (tagsüber)
--
-- Gemessen wird nur tagsüber (world.json nightFrom/nightTo).
--
-- Blitzer = die festen Radarfallen der Map (BeamNG speedTraps, auf der C1 45 Stück, Hook onSpeedTrapTriggered;
--   BeamNG löst ab Limit + 10 % aus). Bußgeld je km/h zu schnell. Die Blitzer werden pro Spieltag gezählt:
--   1. und 2. Mal nur Geld, ab dem 3. Mal (speedcam.dispatchFrom) kommt zusätzlich die Polizei.
-- Laserkontrolle = Orte vom Typ 'police' (Dev-Menü > Orte, "Polizei / Messstelle") plus policeSpots aus der
--   Kartendatei. Nur ab und zu besetzt: pro Spieltag werden ein paar Messstellen ausgewürfelt (Anzahl nach Rang,
--   laser.perDayByRank, am Anfang 1-2), jede für eine Schicht von ein paar Stunden (laser.shiftHours) zwischen laser.hours. Ist sie besetzt, steht dort ein
--   Streifenwagen; wer im Messbereich zu schnell ist, wird sofort verfolgt.
--   (Eine Messstelle kann im Dev-Menü auch ein eigener Blitzer sein: kind = 'speedcam', löst beim Vorbeifahren aus.)
-- Minimap und Radar zeigen eine besetzte Kontrolle erst, wenn man sie an dem Tag schon gesehen hat.
-- Entkommen gibt etwas Ruf (escapeRep, etwas unter einem normalen Sieg, höchstens escapeRepMaxPerDay-mal am Tag).
--
-- Fahndung (Sterne wie bei GTA, aber "indirekt": man sieht die Stufe, nicht die Punkte):
--   1 Stern  = Streifenwagen fährt mit Rotlicht hinterher und fordert zum Anhalten auf. Anhalten = Strafzettel.
--   2 Sterne = Polizei ist gereizt: überholt und bremst vor dem Spieler aus. Gibt es, wenn man weiterfährt,
--              Unfälle mit dem Verkehr baut, die Polizei rammt, noch mal geblitzt wird, oder wenn man am selben
--              Spieltag schon einen Strafzettel bekommen hat (startLevelAfterTicket).
--   3 Sterne = wer immer noch nicht anhält, wird gerammt. Anhalten = Festnahme (hohe Strafe, Auto wird abgeschleppt).
--   Entkommen: kein Streifenwagen sieht einen mehr (Entfernung/Sicht) für evadeSeconds -> Polizei gibt auf.
--
-- Die Streifenwagen sind eigene Fahrzeuge (nicht Teil des BeamNG-Verkehrs, dessen Polizei bleibt aus), gesteuert
-- über die BeamNG-KI: follow (hinterher), manual-Pfad mit Ausweichen (überholen), chase (vorne ausbremsen bzw. rammen).
-- Spielstand: save.police = { day, camHits, tickets, fines, arrests, escapes, pursuits }.
-- Einstellungen: data/police.json. HUD: HashiriyaStatus (st.police), Blitz: Hook HashiriyaFlash { kind = 'speedcam' }.
local M = {}

local logTag = 'hashiriya.police'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/police.json'

local function core() return extensions.hashiriyaBattle_core end
local function home() return extensions.hashiriyaBattle_home end
local function rivals() return extensions.hashiriyaBattle_rivals end
local function battle() return extensions.hashiriyaBattle_battle end

-- Einstellungen -------------------------------------------------------------------

local defaults = {
  enabled = true,
  defaultLimitKmh = 60, toleranceKmh = 10, camWidth = 14, camHeight = 6, camCooldownSeconds = 30,
  laserRange = 110, laserSpawnRange = 600, laserDespawnRange = 800, defaultKind = 'laser',
  mapSpeedTraps = true,
  laser = { perDayByRank = { { 0, 1, 2 }, { 3, 2, 3 }, { 7, 3, 4 }, { 11, 4, 5 }, { 15, 5, 7 } }, shiftHours = { 3, 6 }, hours = { 7, 19 }, seeRange = 200 },
  escapeRep = { 40, 55, 65 }, escapeRepMaxPerDay = 3,
  speedcam = { baseYen = 6000, perKmhYen = 400, repeatFactor = { 1, 1.5, 2 }, dispatchFrom = 3 },
  heat = { level2Heat = 100, level3Heat = 260, fleePerSecond = 2, fleeMinKmh = 30, hitTraffic = 30, hitPolice = 60, speeding = 40 },
  startLevelAfterTicket = 2,
  units = { 1, 2, 3 },
  stopKmh = 6, stopRadius = 40, stopSeconds = { 3, 4, 4 }, checkSeconds = 4,
  ticketYen = { 15000, 45000, 150000 }, offenseYen = { hitTraffic = 10000, hitPolice = 25000 }, arrestTow = true,
  sightRange = 350, evadeSeconds = { 20, 30, 40 },
  vehicles = { { model = 'midsize', config = 'hashiriya_police' }, { model = 'sunburst2', config = 'hashiriya_police' } },
  spawnBehind = { 220, 160, 300, 120 }, reinforceSeconds = 15, wreckDamage = 30000, lostRange = 700, leaveSeconds = 60,
  overtakeExtraKmh = 30, blockAggression = 0.6, ramAggression = 0.9, calmKmh = 20,
}

local cfgCache = nil
function M.cfg()
  if cfgCache then return cfgCache end
  local d = jsonReadFile(dataPath)
  if type(d) ~= 'table' then d = {} end
  local out = {}
  for k, v in pairs(defaults) do
    if type(v) == 'table' and v[1] == nil and type(d[k]) == 'table' then
      -- Unter-Tabelle (speedcam, heat, offenseYen, laser): fehlende Werte aus den Standards
      local sub = {}
      for k2, v2 in pairs(v) do sub[k2] = d[k][k2] ~= nil and d[k][k2] or v2 end
      out[k] = sub
    elseif d[k] ~= nil then
      out[k] = d[k]
    else
      out[k] = v
    end
  end
  cfgCache = out
  return out
end

-- Wert aus einer Liste je Stufe/Anzahl (über das Ende hinaus bleibt der letzte Wert)
local function pick(list, i)
  if type(list) ~= 'table' then return tonumber(list) or 0 end
  if #list == 0 then return 0 end
  return tonumber(list[math.max(1, math.min(i, #list))]) or 0
end

local function round100(yen) return math.floor((yen or 0) / 100 + 0.5) * 100 end

local function yen(n)
  local c = core()
  return c and c.economy and c.economy().formatYen(n) or tostring(n)
end

local function v3(t) return vec3(t[1], t[2], t[3]) end

-- Statistik (save.stats, progress.lua): speedcamHits, policeChases, policeTickets, policeArrests, policeEscapes
local function stat(key) pcall(function() extensions.hashiriyaBattle_progress.bump(core().save, key) end) end

-- Zustand -----------------------------------------------------------------------------

local pursuit = nil       -- laufende Fahndung (siehe startPursuit)
local units = {}          -- [vehId] = Streifenwagen { id, role = 'pursuit'|'laser'|'leave', mode, ... }
local laserCars = {}      -- [placeKey] = vehId des Streifenwagens an einer Laserkontrolle
local camState = {}       -- [placeKey] = { along = letzter Abstand längs, cooldown = s, inside = bool }
local nearPlaces = {}     -- Messstellen in der Nähe (alle Sekunde neu)
local nearTimer = 0
local tickTimer = 0
local collTimer = 0
local recentHits = {}     -- [vehId] = s bis derselbe Zusammenstoß wieder zählt
local frozen = false      -- Spielerauto während der Kontrolle gesperrt
local lastFine = nil      -- { text, t } letzte Strafe fürs HUD
local clock = 0
local placesSrc, placesList = nil, {}
local planCache = {}      -- Dienstplan der Laserkontrollen: [day] = { count, rank, shifts = { [placeKey] = { start, stop } } }

local function msg(text, secs) local c = core() if c then c.msg(text, secs or 5) end end
local function t(key, ...) local c = core() return c and c.t(key, ...) or key end

local function vehCmd(veh, cmd) if veh then pcall(function() veh:queueLuaCommand(cmd) end) end end

local function playerVeh() local c = core() return c and c.getPlayerVehicle() or nil end

-- Das Objekt, das der Spieler steuert: Auto oder zu Fuß das Einrad (Ziel für die Polizei-KI)
local function rawPlayer()
  local ok, v = pcall(function() return getPlayerVehicle and getPlayerVehicle(0) or be:getPlayerVehicle(0) end)
  return ok and v or nil
end

-- Position des Spielers: Auto oder zu Fuß
local function playerPos()
  local v = rawPlayer()
  if v then return v:getPosition(), v end
  return nil, nil
end

-- Messstellen -------------------------------------------------------------------------

-- Liste aus core.spots('police'): Kartendatei (policeSpots) + Dev-Orte. Einstellungen je Ort in p.police.
local function places()
  local c = core()
  local src = c and c.spots and c.spots('police') or {}
  if src == placesSrc then return placesList end
  placesSrc = src
  placesList = {}
  planCache = {} -- Messstellen geändert: Dienstplan neu
  local cf = M.cfg()
  for i, e in ipairs(src) do
    if type(e.pos) == 'table' then
      local pc = type(e.police) == 'table' and e.police or {}
      local kind = pc.kind or e.kind or cf.defaultKind
      if kind ~= 'laser' then kind = 'speedcam' end
      local dir = type(e.dir) == 'table' and v3(e.dir) or vec3(0, 1, 0)
      dir.z = 0
      if dir:length() < 0.1 then dir = vec3(0, 1, 0) end
      dir = dir:normalized()
      local key = tostring(e.id or e.name or i) .. '@' .. string.format('%.0f_%.0f', e.pos[1], e.pos[2])
      table.insert(placesList, {
        key = key, name = e.name or ('#' .. i), pos = v3(e.pos), dir = dir, kind = kind,
        limit = tonumber(pc.limit or e.limit) or cf.defaultLimitKmh,
        both = (pc.both or e.both) and true or false,
        off = pc.off and true or false,
        always = pc.always and true or false, -- Dev: jeden Tag den ganzen Tag besetzt
      })
    end
  end
  return placesList
end
M.places = places

-- Spieltag-Zähler ----------------------------------------------------------------------

local function dayState()
  local c = core()
  local save = c and c.save
  if not save then return nil end
  save.police = type(save.police) == 'table' and save.police or {}
  local p = save.police
  local day = home() and home().getDay() or 1
  if p.day ~= day then
    p.day = day
    p.camHits = 0
    p.tickets = 0
    p.seen = {}      -- heute schon gesehene Laserkontrollen (Minimap/Radar)
    p.escapeRep = 0  -- heute schon für Entkommen belohnt
  end
  if type(p.seen) ~= 'table' then p.seen = {} end
  p.camHits = p.camHits or 0
  p.tickets = p.tickets or 0
  return p
end

-- Geld abziehen (nie ins Minus, wie beim Abschleppen nach unsauberem Beenden)
local function charge(amount, kind)
  local c = core()
  local save = c and c.save
  if not save or amount <= 0 then return 0 end
  local paid = math.min(amount, math.max(0, save.money or 0))
  save.money = (save.money or 0) - paid
  local p = dayState()
  if p then p.fines = (p.fines or 0) + paid end
  lastFine = { text = '-' .. yen(paid), t = 5 }
  log('I', logTag, string.format('Strafe %s: %d ¥ (bezahlt %d)', tostring(kind), amount, paid))
  return paid
end

local function aktiv()
  local c = core()
  if not (c and c.active and c.save) then return false end
  if not M.cfg().enabled then return false end
  if c.save.gameOver then return false end
  return true
end

local function isDaytime()
  local h = home()
  return h and not h.isNight() or false
end

-- Streifenwagen ------------------------------------------------------------------------

local function pickVehicle()
  local list = M.cfg().vehicles or {}
  if #list == 0 then return nil end
  return list[math.random(1, #list)]
end

local function spawnPoliceCar(pos, dir)
  local v = pickVehicle()
  if not v then return nil end
  local cfgPath = tostring(v.config or '')
  if not cfgPath:find('%.pc$') then cfgPath = 'vehicles/' .. v.model .. '/' .. cfgPath .. '.pc' end
  local plate = nil
  pcall(function() plate = extensions.hashiriyaBattle_plates.random() end)
  local opts = { config = cfgPath, pos = pos, rot = quatFromDir(dir, vec3(0, 0, 1)), autoEnterVehicle = false,
    licenseText = plate, removeTraffic = false }
  local ok, veh = pcall(core_vehicles.spawnNewVehicle, v.model, opts)
  if not ok or not veh then
    -- Ersatz: Standard-Config des Modells (falls die eigene Config fehlt)
    opts.config = nil
    ok, veh = pcall(core_vehicles.spawnNewVehicle, v.model, opts)
  end
  if not ok or not veh then
    log('E', logTag, 'Streifenwagen konnte nicht gespawnt werden: ' .. tostring(v.model) .. ' ' .. tostring(veh))
    return nil
  end
  if plate then pcall(core_vehicles.setPlateText, plate, veh:getID()) end
  return veh
end

local function newUnit(veh, role)
  local u = { id = veh:getID(), role = role, mode = nil, born = clock, modeT = 0, retarget = 0 }
  units[u.id] = u
  return u
end

local function deleteUnit(id)
  local u = units[id]
  units[id] = nil
  for k, lid in pairs(laserCars) do if lid == id then laserCars[k] = nil end end
  local veh = be:getObjectByID(id)
  if veh then pcall(function() veh:delete() end) end
  return u
end

local function unitCount(role)
  local n = 0
  for _, u in pairs(units) do if not role or u.role == role then n = n + 1 end end
  return n
end

local function lightbar(veh, v) vehCmd(veh, 'if electrics.set_lightbar_signal then electrics.set_lightbar_signal(' .. v .. ') end') end

-- Ziel-Knoten ein Stück vor dem Spieler auf seiner Fahrbahn (fürs Überholen per Pfad)
local function nodeAhead(ppos, pdir, dist)
  local rv = rivals()
  if not (rv and rv.findRoadSpawn) then return nil end
  local okP, pos = pcall(rv.findRoadSpawn, ppos, pdir, dist)
  if not okP or not pos then return nil end
  local okN, n1, n2 = pcall(map.findClosestRoad, pos)
  if not okN or not n1 then return nil end
  local nodes = map.getMap().nodes
  if not (nodes[n1] and nodes[n2]) then return n1 end
  return (nodes[n2].pos - nodes[n1].pos):dot(pdir) >= 0 and n2 or n1
end

-- KI-Modus eines Streifenwagens setzen (Befehle nur beim Wechsel; Überholen frischt Ziel und Tempo auf)
local function setMode(u, veh, mode, player, pSpeed)
  local pid = player and player:getID() or 0
  local cf = M.cfg()
  if mode == 'overtake' then
    local want = math.max(14, pSpeed + cf.overtakeExtraKmh / 3.6)
    u.retarget = u.retarget - 0.25
    if u.mode ~= 'overtake' or u.retarget <= 0 then
      local node = nodeAhead(player:getPosition(), player:getDirectionVector(), 450)
      if not node then
        mode = 'follow' -- kein Pfad: wenigstens dicht dranbleiben
      else
        u.retarget = 6
        vehCmd(veh, string.format("ai.setAggressionMode('off') ai.driveUsingPath({wpTargetList = {%q}, avoidCars = 'on', driveInLane = 'off', routeSpeed = %f, routeSpeedMode = 'set', aggression = 0.8})", node, want))
        u.mode = 'overtake'
        return
      end
    else
      vehCmd(veh, string.format("ai.setSpeedMode('set') ai.setSpeed(%f)", want))
      return
    end
  end
  if u.mode == mode then return end
  u.mode = mode
  u.modeT = 0
  if mode == 'follow' then
    vehCmd(veh, string.format("controller.setFreeze(0) ai.setMode('follow') ai.setTargetObjectID(%d) ai.setAvoidCars('on') ai.driveInLane('off') ai.setSpeedMode('off') ai.setAggressionMode('rubberBand')", pid))
  elseif mode == 'calm' then
    vehCmd(veh, string.format("controller.setFreeze(0) ai.setMode('follow') ai.setTargetObjectID(%d) ai.setAvoidCars('on') ai.driveInLane('off') ai.setSpeedMode('off') ai.setAggressionMode('off') ai.setAggression(0.4)", pid))
  elseif mode == 'block' then
    vehCmd(veh, string.format("controller.setFreeze(0) ai.setMode('chase') ai.setTargetObjectID(%d) ai.driveInLane('off') ai.setSpeedMode('off') ai.setAggressionMode('off') ai.setAggression(%f)", pid, cf.blockAggression))
  elseif mode == 'ram' then
    vehCmd(veh, string.format("controller.setFreeze(0) ai.setMode('chase') ai.setTargetObjectID(%d) ai.driveInLane('off') ai.setSpeedMode('off') ai.setAggressionMode('off') ai.setAggression(%f)", pid, cf.ramAggression))
  elseif mode == 'leave' then
    vehCmd(veh, "controller.setFreeze(0) ai.setMode('traffic') ai.setAvoidCars('on') ai.driveInLane('on') ai.setSpeedMode('limit') ai.setSpeed(16.7) ai.setAggressionMode('off') ai.setAggression(0.3)")
    lightbar(veh, 0)
  elseif mode == 'stop' then
    vehCmd(veh, "ai.setMode('stop')")
  elseif mode == 'parked' then
    vehCmd(veh, "ai.setMode('disabled') controller.setFreeze(1)")
    lightbar(veh, 0)
  end
end

-- Sieht ein Streifenwagen den Spieler? (Entfernung + freie Sicht)
local function canSee(veh, ppos)
  local p = veh:getPosition()
  local d = (ppos - p):length()
  if d > M.cfg().sightRange then return false, d end
  if d < 25 then return true, d end
  local from = p + vec3(0, 0, 1.3)
  local to = ppos + vec3(0, 0, 1.0)
  local dir = to - from
  local len = dir:length()
  local ok, hit = pcall(castRayStatic, from, dir / len, len)
  if ok and type(hit) == 'number' and hit < len - 2 then return false, d end
  return true, d
end

-- Laserkontrollen: Dienstplan -----------------------------------------------------------
-- Pro Spieltag und Messstelle fest ausgewürfelt (Spielstand-Seed + Tag + Messstelle): gleiche Antwort,
-- egal wann man nachschaut oder neu lädt.

local function hashStr(str)
  local h = 5381
  for i = 1, #str do h = (h * 33 + str:byte(i)) % 2147483647 end
  return h
end

local function rand01(str)
  local x = hashStr(str)
  for _ = 1, 3 do x = (x * 1103515245 + 12345) % 2147483648 end
  return x / 2147483648
end


-- Wie viele Kontrollen heute? Hängt vom Rang ab: es spricht sich herum, dass nachts auf dem Expressway
-- Rennen gefahren werden (laser.perDayByRank = Liste { abRang, min, max }, Rang 0 = Anfänger).
local function perDay(rank)
  local list = M.cfg().laser.perDayByRank or { { 0, 1, 2 } }
  local best = list[1]
  for _, e in ipairs(list) do if rank >= (tonumber(e[1]) or 0) then best = e end end
  -- Hardcore: mehr mobile Kontrollen (hardcore.json laserExtra)
  local extra = math.floor(extensions.hashiriyaBattle_hardcore.num('laserExtra', 0))
  return (tonumber(best[2]) or 1) + extra, (tonumber(best[3]) or tonumber(best[2]) or 1) + extra
end

-- Dienstplan des Tages: welche Laserkontrollen besetzt sind und von wann bis wann
function M.dayPlan()
  local c = core()
  local day = home() and home().getDay() or 1
  local hcKey = extensions.hashiriyaBattle_hardcore.on() and 'hc' or 'n'
  if planCache[day] and planCache[day].hcKey == hcKey then return planCache[day] end
  local seed = tostring(c and c.save and c.save.dealerSeed or 1)
  local rank = 0
  pcall(function() rank = extensions.hashiriyaBattle_progress.rankIndex(c.save) end)
  local lo, hi = perDay(rank)
  local list = {}
  for _, pl in ipairs(places()) do
    if pl.kind == 'laser' and not pl.off then table.insert(list, { pl = pl, r = rand01(seed .. '|' .. day .. '|' .. pl.key .. '|pick') }) end
  end
  table.sort(list, function(x, y) return x.r < y.r end)
  local count = lo + math.floor(rand01(seed .. '|' .. day .. '|count') * (hi - lo + 1))
  count = math.max(0, math.min(count, hi, #list))
  local lc = M.cfg().laser
  local sh = lc.shiftHours or { 2, 5 }
  local hrs = lc.hours or { 7, 19 }
  local from, to = hrs[1] or 7, hrs[2] or 19
  local plan = { count = count, rank = rank, shifts = {}, hcKey = hcKey }
  for i = 1, count do
    local key = list[i].pl.key
    local id = key .. '#' .. day
    local len = (sh[1] or 2) + rand01(seed .. '|' .. id .. '|len') * math.max(0, (sh[2] or sh[1] or 2) - (sh[1] or 2))
    local start = from + rand01(seed .. '|' .. id .. '|start') * math.max(0, to - from - len)
    plan.shifts[key] = { start = start, stop = math.min(to, start + len) }
  end
  planCache = { [day] = plan }
  log('I', logTag, string.format('Laserkontrollen Tag %d: %d besetzt (Rang %d, %d Messstellen)', day, count, rank, #list))
  return plan
end

function M.shift(pl)
  if pl.always then return { start = 0, stop = 24 } end
  return M.dayPlan().shifts[pl.key]
end

local function mannedNow(pl)
  if pl.off or not isDaytime() then return false end
  local s = M.shift(pl)
  if not s then return false end
  local h = home() and home().hour() or 12
  return h >= s.start and h < s.stop
end
M.mannedNow = mannedNow

-- Laserkontrollen: Streifenwagen an der Messstelle erscheinen lassen / entfernen ---------

local function updateLaserCars(ppos)
  local cf = M.cfg()
  local day = isDaytime()
  for _, pl in ipairs(places()) do
    if pl.kind == 'laser' then
      local id = laserCars[pl.key]
      local d = (pl.pos - ppos):length()
      if id and not units[id] then laserCars[pl.key] = nil; id = nil end
      local manned = day and mannedNow(pl)
      if id then
        local u = units[id]
        -- Schichtende: erst wegräumen, wenn man nicht hinschaut (oder weit weg ist)
        local veh = be:getObjectByID(id)
        local gone = not veh or d > cf.laserDespawnRange or (not manned and (d > 300 or not canSee(veh, ppos)))
        if u.role == 'laser' and gone then deleteUnit(id) end
      elseif manned and d < cf.laserSpawnRange and d > 150 then
        -- erst erscheinen lassen, wenn man noch nicht direkt davor ist (kein Auftauchen vor der Nase)
        local veh = spawnPoliceCar(pl.pos + vec3(0, 0, 0.3), pl.dir)
        if veh then
          local u = newUnit(veh, 'laser')
          u.place = pl.key
          laserCars[pl.key] = u.id
          setMode(u, veh, 'parked')
          log('I', logTag, 'Laserkontrolle besetzt: ' .. pl.name)
        end
      end
    end
  end
end

-- Gesehen? Besetzte Kontrolle in Sichtweite = ab jetzt (heute) auf Minimap und Radar
local function updateSeen(ppos)
  local p = dayState()
  if not p then return end
  local range = M.cfg().laser.seeRange or 200
  for key, id in pairs(laserCars) do
    if not p.seen[key] then
      local veh = be:getObjectByID(id)
      if veh then
        local ok, d = canSee(veh, ppos)
        if ok and d < range then
          p.seen[key] = true
          log('I', logTag, 'Laserkontrolle gesehen: ' .. tostring(key))
        end
      end
    end
  end
end

-- Fahndung --------------------------------------------------------------------------------

local function levelForHeat(h)
  local hc = M.cfg().heat
  if h >= hc.level3Heat then return 3 end
  if h >= hc.level2Heat then return 2 end
  return 1
end

local function heatForLevel(level)
  local hc = M.cfg().heat
  if level >= 3 then return hc.level3Heat end
  if level == 2 then return hc.level2Heat end
  return 0
end

-- Streifenwagen hinter dem Spieler auftauchen lassen (außer Sicht, auf seiner Fahrbahn)
local function spawnBehindPlayer()
  local player = playerVeh()
  if not player then return nil end
  local rv = rivals()
  if not (rv and rv.findRoadSpawn) then return nil end
  local ppos, pdir = player:getPosition(), player:getDirectionVector()
  for _, dist in ipairs(M.cfg().spawnBehind or { 220 }) do
    local ok, pos, dir = pcall(rv.findRoadSpawn, ppos, pdir, -math.abs(dist))
    if ok and pos and (not rv.spawnFree or rv.spawnFree(pos, 8)) then
      local veh = spawnPoliceCar(pos, dir)
      if veh then return veh end
    end
  end
  return nil
end

local function addHeat(amount, kind)
  if not pursuit or pursuit.phase ~= 'active' then return end
  pursuit.heat = pursuit.heat + amount
  if kind then pursuit.offenses[kind] = (pursuit.offenses[kind] or 0) + 1 end
  local lvl = math.max(pursuit.level, levelForHeat(pursuit.heat))
  if lvl > pursuit.level then
    pursuit.level = lvl
    pursuit.reinforce = 0
    msg(t('police.level' .. lvl), 5)
    pcall(function() core().sound('challenge') end)
    log('I', logTag, string.format('Fahndung: %d Sterne (Druck %.0f)', lvl, pursuit.heat))
  end
end

-- reason: speedcam | laser | dev; unitId = Streifenwagen, der schon da ist (Laserkontrolle)
function M.startPursuit(level, reason, unitId)
  if not aktiv() then return end
  local p = dayState()
  if pursuit and pursuit.phase == 'active' then
    if level > pursuit.level then pursuit.heat = math.max(pursuit.heat, heatForLevel(level)); addHeat(0) end
    if unitId and units[unitId] then units[unitId].role = 'pursuit' end
    return
  end
  if pursuit then return end -- Kontrolle läuft gerade
  local cf = M.cfg()
  if p and p.tickets > 0 then level = math.max(level, cf.startLevelAfterTicket or 1) end
  level = math.max(1, math.min(3, level))
  pursuit = { level = level, heat = heatForLevel(level), reason = reason, phase = 'active', stopT = 0, unseenT = 0,
    seen = false, reinforce = unitId and cf.reinforceSeconds or 0, offenses = {}, started = clock, approach = true }
  if p then p.pursuits = (p.pursuits or 0) + 1 end
  if unitId and units[unitId] then
    units[unitId].role = 'pursuit'
    local veh = be:getObjectByID(unitId)
    lightbar(veh, 2)
  end
  stat('policeChases')
  msg(t(reason == 'laser' and 'police.startLaser' or 'police.start'), 6)
  pcall(function() core().sound('challenge') end)
  log('I', logTag, string.format('Fahndung gestartet (%s), %d Sterne', tostring(reason), level))
end

local function unfreezePlayer()
  if not frozen then return end
  frozen = false
  local v = playerVeh()
  vehCmd(v, 'controller.setFreeze(0)')
end

-- Fahndung beenden; result = ticket | arrest | escape | abort
local function endPursuit(result)
  if not pursuit then return end
  local lvl = pursuit.level
  pursuit = nil
  unfreezePlayer()
  for id, u in pairs(units) do
    if u.role == 'pursuit' then
      u.role = 'leave'
      u.leaveT = 0
      local veh = be:getObjectByID(id)
      if veh then setMode(u, veh, 'leave') end
    end
  end
  local p = dayState()
  if result == 'escape' and p then
    p.escapes = (p.escapes or 0) + 1
    stat('policeEscapes')
    -- Ruf fürs Entkommen: etwas unter einem normalen Sieg, nur ein paar Mal am Tag (kein Grinden)
    local cf = M.cfg()
    local rep = 0
    if (p.escapeRep or 0) < (tonumber(cf.escapeRepMaxPerDay) or 0) then
      rep = math.floor(pick(cf.escapeRep, lvl))
    end
    local save = core().save
    if rep > 0 and save then
      p.escapeRep = (p.escapeRep or 0) + 1
      save.rep = (save.rep or 0) + rep
      msg(t('police.escapedRep', rep), 6)
    else
      msg(t('police.escaped'), 6)
    end
    pcall(function() core().sound('win') end)
  end
  log('I', logTag, 'Fahndung beendet: ' .. tostring(result) .. ' (' .. lvl .. ' Sterne)')
  pcall(function() core().writeSave() end)
end

-- Kontrolle abgeschlossen: Strafzettel bzw. Festnahme
local function finishCheck()
  local cf = M.cfg()
  local lvl = pursuit.level
  local fine = pick(cf.ticketYen, lvl)
  local off = pursuit.offenses
  fine = fine + (off.hitTraffic or 0) * (cf.offenseYen.hitTraffic or 0) + (off.hitPolice or 0) * (cf.offenseYen.hitPolice or 0)
  fine = round100(extensions.hashiriyaBattle_hardcore.price(fine)) -- Hardcore: höhere Strafen
  local paid = charge(fine, lvl >= 3 and 'arrest' or 'ticket')
  local p = dayState()
  if p then
    p.tickets = p.tickets + 1
    if lvl >= 3 then p.arrests = (p.arrests or 0) + 1 end
  end
  stat(lvl >= 3 and 'policeArrests' or 'policeTickets')
  local key = lvl >= 3 and 'police.arrest' or 'police.ticket'
  msg(t(key, yen(fine)) .. (paid < fine and (' ' .. t('police.cantPay', yen(paid))) or ''), 7)
  pcall(function() core().sound('lose') end)
  endPursuit(lvl >= 3 and 'arrest' or 'ticket')
  if lvl >= 3 and cf.arrestTow then
    -- abgeschleppt zur Garage (normale Gebühr), wie aus dem Menü
    local okT = pcall(function() extensions.hashiriyaBattle_parking.towToGarage() end)
    if not okT then log('W', logTag, 'Abschleppen nach Festnahme fehlgeschlagen') end
  end
end

local function updatePursuit(dt)
  local cf = M.cfg()
  local ppos, player = playerPos() -- player = Auto oder Einrad (zu Fuß)
  if not ppos then return end
  local car = playerVeh()           -- nur das Auto (zum Sperren während der Kontrolle)
  local pSpeed = player:getVelocity():length()
  local pdir = player:getDirectionVector()

  -- Kontrolle läuft: stehen bleiben, dann Strafe
  if pursuit.phase == 'check' then
    pursuit.checkT = pursuit.checkT + dt
    for id, u in pairs(units) do
      local veh = be:getObjectByID(id)
      if veh and u.role == 'pursuit' then setMode(u, veh, 'calm', player, pSpeed) end
    end
    if pursuit.checkT >= cf.checkSeconds then finishCheck() end
    return
  end

  -- Streifenwagen prüfen: weg, Wrack, zu weit weg
  local seenAny, nearest = false, math.huge
  for id, u in pairs(units) do
    local veh = be:getObjectByID(id)
    if not veh then
      units[id] = nil
    elseif u.role == 'pursuit' then
      local obj = map.objects and map.objects[id]
      if obj and (obj.damage or 0) > cf.wreckDamage then
        u.role = 'wreck'
        u.leaveT = 0
        setMode(u, veh, 'stop')
        lightbar(veh, 1)
        log('I', logTag, 'Streifenwagen kaputt')
      else
        local seen, d = canSee(veh, ppos)
        if seen then seenAny = true end
        if d < nearest then nearest = d end
        if d > cf.lostRange and not seen then deleteUnit(id) end
      end
    end
  end
  pursuit.seen = seenAny
  pursuit.nearest = nearest
  local active = unitCount('pursuit')

  -- Anhalten: langsam und ein Streifenwagen nah dran
  if pSpeed * 3.6 < cf.stopKmh and nearest < cf.stopRadius then
    pursuit.stopT = pursuit.stopT + dt
    if pursuit.stopT >= pick(cf.stopSeconds, pursuit.level) then
      pursuit.phase = 'check'
      pursuit.checkT = 0
      if car then frozen = true; vehCmd(car, 'controller.setFreeze(1)') end
      msg(t('police.check'), cf.checkSeconds + 1)
      return
    end
  else
    pursuit.stopT = math.max(0, pursuit.stopT - dt * 2)
  end

  -- Fahndungsdruck: weiterfahren, obwohl die Polizei einen sieht
  if seenAny then
    pursuit.approach = false
    pursuit.unseenT = 0
    if pSpeed * 3.6 > cf.heat.fleeMinKmh and nearest < 120 then addHeat(cf.heat.fleePerSecond * dt) end
  elseif not pursuit.approach then
    pursuit.unseenT = pursuit.unseenT + dt
    if pursuit.unseenT >= pick(cf.evadeSeconds, pursuit.level) then endPursuit('escape') return end
  end

  -- Verstärkung (nur solange man gesehen wird bzw. die erste Einheit noch anrückt)
  pursuit.reinforce = pursuit.reinforce - dt
  local want = pick(cf.units, pursuit.level)
  if active < want and pursuit.reinforce <= 0 and (seenAny or (pursuit.approach and active == 0)) then
    pursuit.reinforce = active == 0 and 3 or cf.reinforceSeconds
    local veh = spawnBehindPlayer()
    if veh then
      local u = newUnit(veh, 'pursuit')
      lightbar(veh, 2)
      log('I', logTag, string.format('Streifenwagen %d/%d unterwegs', active + 1, want))
      active = active + 1
      u.mode = nil
    end
  end
  -- Anrücken klappt nicht (kein Spawnpunkt): nach einer Weile aufgeben
  if pursuit.approach and active == 0 and clock - pursuit.started > 40 then endPursuit('abort') return end

  -- Fahrverhalten je Stufe
  for id, u in pairs(units) do
    local veh = be:getObjectByID(id)
    if veh and u.role == 'pursuit' then
      u.modeT = (u.modeT or 0) + dt
      local rel = veh:getPosition() - ppos
      local along = rel:dot(pdir)
      local dist = rel:length()
      local mode
      if not car then
        mode = 'calm' -- zu Fuß: ruhig hinfahren
      elseif pSpeed * 3.6 < cf.calmKmh and dist < 80 then
        mode = 'calm'
      elseif pursuit.level >= 3 then
        mode = 'ram'
      elseif pursuit.level == 2 then
        if along > 8 or (u.mode == 'block' and along > -4) then mode = 'block'
        elseif dist < 70 then mode = 'overtake'
        else mode = 'follow' end
      else
        mode = 'follow'
      end
      setMode(u, veh, mode, player, pSpeed)
    end
  end
end

-- Streifenwagen nach der Fahndung: wegfahren und verschwinden; Wracks bleiben, bis man weg ist
local function updateLeaving(dt, ppos)
  local cf = M.cfg()
  for id, u in pairs(units) do
    if u.role == 'leave' or u.role == 'wreck' then
      local veh = be:getObjectByID(id)
      if not veh then
        units[id] = nil
      else
        u.leaveT = (u.leaveT or 0) + dt
        local seen, d = true, 0
        if ppos then seen, d = canSee(veh, ppos) end
        if (u.leaveT > 5 and not seen and d > 120) or u.leaveT > cf.leaveSeconds or d > cf.lostRange then deleteUnit(id) end
      end
    end
  end
end

-- Blitzer und Laser --------------------------------------------------------------------

local function flash()
  pcall(function() guihooks.trigger('HashiriyaFlash', { kind = 'speedcam' }) end)
  pcall(function() core().sound('speedcam') end)
end

local function onSpeedcam(pl, kmh)
  local cf = M.cfg()
  local p = dayState()
  if not p then return end
  p.camHits = p.camHits + 1
  stat('speedcamHits')
  local n = p.camHits
  local over = math.max(0, math.floor(kmh - pl.limit + 0.5))
  local fine = round100(extensions.hashiriyaBattle_hardcore.price((cf.speedcam.baseYen + over * cf.speedcam.perKmhYen) * pick(cf.speedcam.repeatFactor, n)))
  flash()
  local paid = charge(fine, 'speedcam')
  local dispatch = n >= (cf.speedcam.dispatchFrom or 3)
  local text = t('police.speedcam', math.floor(kmh + 0.5), pl.limit, yen(fine), n)
  if paid < fine then text = text .. ' ' .. t('police.cantPay', yen(paid)) end
  if pursuit then
    addHeat(cf.heat.speeding, 'speeding')
  elseif dispatch then
    text = text .. ' ' .. t('police.dispatch')
  elseif n + 1 >= (cf.speedcam.dispatchFrom or 3) then
    text = text .. ' ' .. t('police.warnNext')
  end
  msg(text, 7)
  log('I', logTag, string.format('Geblitzt: %s, %.0f km/h bei %d, %d. Mal heute, %d ¥', pl.name, kmh, pl.limit, n, fine))
  if dispatch and not pursuit then M.startPursuit(1, 'speedcam') end
  pcall(function() core().writeSave() end)
end

local function onLaser(pl, kmh)
  local cf = M.cfg()
  flash()
  log('I', logTag, string.format('Laser: %s, %.0f km/h bei %d', pl.name, kmh, pl.limit))
  if pursuit then
    addHeat(cf.heat.speeding, 'speeding')
    return
  end
  msg(t('police.laser', math.floor(kmh + 0.5), pl.limit), 6)
  M.startPursuit(1, 'laser', laserCars[pl.key])
end

-- Jeden Frame für Messstellen in der Nähe (kein Durchrutschen bei hohem Tempo)
local function checkCams(dt, player)
  local cf = M.cfg()
  local ppos = player:getPosition()
  local vel = player:getVelocity()
  local kmh = vel:length() * 3.6
  for _, pl in ipairs(nearPlaces) do
    local st = camState[pl.key]
    if not st then st = { cooldown = 0 }; camState[pl.key] = st end
    local rel = ppos - pl.pos
    if pl.kind == 'speedcam' then
      local along = rel:dot(pl.dir)
      local side = (rel - pl.dir * along)
      side.z = 0
      local lateral = side:length()
      local prev = st.along
      st.along = along
      if prev and math.abs(rel.z) < cf.camHeight and lateral < cf.camWidth and st.cooldown <= 0 then
        local crossed = (prev < 0 and along >= 0 and vel:dot(pl.dir) > 0) or (pl.both and prev > 0 and along <= 0 and vel:dot(pl.dir) < 0)
        if crossed and kmh > pl.limit + cf.toleranceKmh then
          st.cooldown = cf.camCooldownSeconds
          onSpeedcam(pl, kmh)
        end
      end
    else
      local d = rel:length()
      local inside = d < cf.laserRange and math.abs(rel.z) < cf.camHeight
      -- Laser misst Fahrzeuge, die in Fahrtrichtung der Kontrolle unterwegs sind (oder beide Richtungen)
      local dirOk = pl.both or vel:dot(pl.dir) > 0
      local manned = laserCars[pl.key] ~= nil and units[laserCars[pl.key]] ~= nil and units[laserCars[pl.key]].role == 'laser'
      if inside and dirOk and manned and st.cooldown <= 0 and kmh > pl.limit + cf.toleranceKmh then
        st.cooldown = cf.camCooldownSeconds
        onLaser(pl, kmh)
      end
    end
  end
end

-- Feste Radarfallen der Map (BeamNG gameplay/speedTraps.lua) = die Blitzer ---------------
-- Feuert für jedes Fahrzeug, nur in Fahrtrichtung und nur über Limit + 10 %. speedLimit in m/s.
function M.onSpeedTrapTriggered(data, vehSpeed)
  if type(data) ~= 'table' or not aktiv() or not M.cfg().mapSpeedTraps then return end
  local car = playerVeh()
  if not car or (data.subjectID and data.subjectID ~= car:getID()) then return end
  if not isDaytime() then return end
  if battle() and battle().isBusy() then return end
  if pursuit and pursuit.phase == 'check' then return end
  local kmh = (tonumber(vehSpeed) or car:getVelocity():length()) * 3.6
  local limit = math.floor((tonumber(data.speedLimit) or 0) * 3.6 + 0.5)
  onSpeedcam({ name = tostring(data.triggerName or data.triggerID or 'Radarfalle'), limit = limit, key = 'trap' }, kmh)
end

-- Zusammenstöße während der Fahndung (die Polizei sieht zu) --------------------------------

local function checkCollisions(dt, player)
  for id, s in pairs(recentHits) do
    recentHits[id] = s - dt
    if recentHits[id] <= 0 then recentHits[id] = nil end
  end
  if not pursuit or pursuit.phase ~= 'active' or not pursuit.seen then return end
  local obj = map.objects and map.objects[player:getID()]
  local coll = obj and obj.objectCollisions
  if type(coll) ~= 'table' then return end
  local cf = M.cfg()
  local traffic = nil
  pcall(function() traffic = gameplay_traffic.getTrafficData() end)
  for oid, v in pairs(coll) do
    if v == 1 and not recentHits[oid] then
      recentHits[oid] = 4
      if units[oid] then
        addHeat(cf.heat.hitPolice, 'hitPolice')
        msg(t('police.hitPolice'), 3)
      elseif traffic and traffic[oid] then
        addHeat(cf.heat.hitTraffic, 'hitTraffic')
        msg(t('police.hitTraffic'), 3)
      end
    end
  end
end

-- Minimap und Radar ----------------------------------------------------------------------
-- Gezeigt werden: Streifenwagen einer laufenden Fahndung (die sieht man ja) und besetzte Laserkontrollen,
-- die man heute schon gesehen hat (auch wenn der Streifenwagen gerade nicht gespawnt ist).

local function markers()
  local out = {}
  if not aktiv() then return out end
  local p = dayState()
  for id, u in pairs(units) do
    if u.role == 'pursuit' then
      local veh = be:getObjectByID(id)
      if veh then table.insert(out, { pos = veh:getPosition(), dir = veh:getDirectionVector(), chase = true }) end
    end
  end
  if p then
    for _, pl in ipairs(places()) do
      if pl.kind == 'laser' and p.seen[pl.key] and mannedNow(pl) then
        local id = laserCars[pl.key]
        local u = id and units[id]
        if not u or u.role == 'laser' then table.insert(out, { pos = pl.pos, dir = pl.dir, laser = true }) end
      end
    end
  end
  return out
end

-- Punkte fürs Radar oben rechts (HashiriyaStatus), gleiches Format wie rivals.radarInfo
function M.radarItems(range)
  local player = playerVeh()
  if not player then return nil end
  local fwd = player:getDirectionVector(); fwd.z = 0
  if fwd:length() < 0.01 then return nil end
  fwd = fwd:normalized()
  local right = vec3(fwd.y, -fwd.x, 0)
  local list = {}
  for _, m in ipairs(markers()) do
    local d = m.pos - player:getPosition()
    local x, y = d:dot(right), d:dot(fwd)
    local dist = math.sqrt(x * x + y * y)
    if m.chase or dist < range * 2 then
      local scale = math.min(1, range / math.max(dist, 1))
      table.insert(list, { kind = 'police', engaged = m.chase or nil, x = x / range * scale, y = y / range * scale, edge = dist > range,
        heading = math.deg(math.atan2(m.dir:dot(right), m.dir:dot(fwd))),
        dist = dist < 1000 and string.format('%d m', math.floor(dist)) or string.format('%.1f km', dist / 1000), d = dist })
    end
  end
  return #list > 0 and list or nil
end

local mmPos, mmFwd = vec3(), vec3()
local function onDrawOnMinimap(td)
  if not td or not aktiv() then return end
  local list = markers()
  if #list == 0 then return end
  local utils, minimap = ui_apps_minimap_utils, ui_apps_minimap_minimap
  if not utils or not minimap or not utils.getWorldToMapTransform then return end
  local scale = minimap.getScale and minimap.getScale()
  if not scale then return end
  local style = utils.getCurrentStyleColors and utils.getCurrentStyleColors() or utils.colors
  local bg = style and (style.navBg or style.navBgBlack)
  local dpi = (utils.dpi or 1) * (globalDpi or 1)
  local xx, xy, yx, yy, xo, yo = utils.getWorldToMapTransform()
  local blink = math.floor(os.clock() * 3) % 2 == 0
  for _, m in ipairs(list) do
    mmPos:set(m.pos.x, m.pos.y, m.pos.z)
    mmFwd:set(m.dir.x, m.dir.y, 0)
    if mmFwd:length() > 0.001 then
      mmFwd:normalize()
      -- Fahndung: blinkt rot (in Japan ist das Rotlicht der Polizei immer rot, JDMArsch 05.11.2026);
      -- Laserkontrolle: ruhiges Weißgrau wie die weiß-schwarzen Streifenwagen
      local col
      if m.chase then col = blink and color(255, 59, 48, 255) or color(90, 12, 10, 255)
      else col = color(201, 201, 209, 255) end
      td:vehicleMarker(mmPos.x, mmPos.y, mmFwd.x, mmFwd.y, col, bg, m.laser and 0.85 or 1.0, false, scale, dpi, xx, xy, yx, yy, xo, yo, 96)
    end
  end
end

-- Öffentlich ---------------------------------------------------------------------------

function M.isActive() return pursuit ~= nil end
function M.isChecking() return pursuit ~= nil and pursuit.phase == 'check' end
function M.level() return pursuit and pursuit.level or 0 end

-- Alles weg (Modus beendet, Level verlassen, Spielstand gewechselt)
function M.reset()
  if frozen then unfreezePlayer() end
  pursuit = nil
  for id in pairs(units) do deleteUnit(id) end
  units, laserCars, camState, nearPlaces, recentHits = {}, {}, {}, {}, {}
  placesSrc, placesList, cfgCache, lastFine = nil, {}, nil, nil
  planCache = {}
end

-- HUD (HashiriyaStatus): Sterne, Lage, Fortschritt Anhalten/Entkommen, Blitzer heute
function M.getHudState()
  if not aktiv() then return nil end
  local cf = M.cfg()
  local p = dayState()
  local out = nil
  if pursuit then
    local status, pct = 'chase', nil
    if pursuit.phase == 'check' then
      status, pct = 'check', math.floor(math.min(1, pursuit.checkT / cf.checkSeconds) * 100)
    elseif pursuit.stopT > 0.05 then
      status, pct = 'stopping', math.floor(math.min(1, pursuit.stopT / pick(cf.stopSeconds, pursuit.level)) * 100)
    elseif pursuit.approach then
      status = 'approach'
    elseif not pursuit.seen then
      status, pct = 'evading', math.floor(math.min(1, pursuit.unseenT / pick(cf.evadeSeconds, pursuit.level)) * 100)
    end
    out = { level = pursuit.level, status = status, pct = pct,
      label = t('police.hud.level' .. pursuit.level), statusText = t('police.hud.' .. status) }
  end
  local show = (p and p.camHits > 0 and isDaytime()) or out
  if not show and not lastFine then return nil end
  out = out or {}
  if p and p.camHits > 0 then
    out.cams = p.camHits
    out.camsMax = cf.speedcam.dispatchFrom or 3
    out.camsText = t('police.hud.cams', p.camHits)
  end
  if lastFine then out.fine = lastFine.text end
  return out
end

-- Dev-Menü: Tests ohne gesetzte Messstellen
function M.devSpeedcam(kmh)
  local cf = M.cfg()
  onSpeedcam({ name = 'Dev-Test', limit = cf.defaultLimitKmh, key = 'dev' }, tonumber(kmh) or (cf.defaultLimitKmh + 30))
end
function M.devLaser()
  local cf = M.cfg()
  local before = pursuit
  onLaser({ name = 'Dev-Laser', limit = cf.defaultLimitKmh, key = 'dev' }, cf.defaultLimitKmh + 30)
  if not before and pursuit then pursuit.reinforce = 0 end
end
function M.devStart(level) M.startPursuit(tonumber(level) or 1, 'dev') end
function M.devStop() endPursuit('abort') end
function M.devResetDay()
  local p = dayState()
  if p then p.camHits = 0; p.tickets = 0 end
end
function M.devInfo()
  local p = dayState() or {}
  local n, laser = 0, 0
  for _, pl in ipairs(places()) do n = n + 1; if pl.kind == 'laser' then laser = laser + 1 end end
  local plan = M.dayPlan()
  local manned, nowOn = {}, 0
  for _, pl in ipairs(places()) do
    local sh = plan.shifts[pl.key] or (pl.always and { start = 0, stop = 24 })
    if sh then
      local on = mannedNow(pl)
      if on then nowOn = nowOn + 1 end
      table.insert(manned, { name = pl.name, text = string.format('%02d:%02d-%02d:%02d', math.floor(sh.start), math.floor(sh.start % 1 * 60), math.floor(sh.stop), math.floor(sh.stop % 1 * 60)), on = on or nil,
        seen = (dayState() or { seen = {} }).seen[pl.key] or nil })
    end
  end
  return { manned = manned, mannedNow = nowOn, rank = plan.rank, places = n, laser = laser, camHits = p.camHits or 0, tickets = p.tickets or 0, level = M.level(),
    heat = pursuit and math.floor(pursuit.heat) or 0, units = unitCount('pursuit'), day = isDaytime() }
end

-- Hooks --------------------------------------------------------------------------------

local function onUpdate(dtReal, dtSim)
  clock = clock + (tonumber(dtSim) or dtReal)
  if lastFine then
    lastFine.t = lastFine.t - dtReal
    if lastFine.t <= 0 then lastFine = nil end
  end
  if not aktiv() then
    if pursuit or next(units) then M.reset() end
    return
  end
  if home() and home().isResting() then return end
  -- Spielzeit (Pause hält alles an, auch das Entkommen)
  local dt = tonumber(dtSim) or dtReal
  if dt <= 0 then return end
  local player = playerVeh()
  local ppos = playerPos()

  -- Messstellen in der Nähe (jede Sekunde), Laser-Streifenwagen
  nearTimer = nearTimer - dtReal
  if nearTimer <= 0 and ppos then
    nearTimer = 1
    nearPlaces = {}
    local busy = battle() and battle().isBusy()
    if isDaytime() and not busy then
      for _, pl in ipairs(places()) do
        if not pl.off and (pl.pos - ppos):length() < 400 then table.insert(nearPlaces, pl) end
      end
    end
    for k in pairs(camState) do
      local still = false
      for _, pl in ipairs(nearPlaces) do if pl.key == k then still = true break end end
      if not still and (camState[k].cooldown or 0) <= 0 then camState[k] = nil end
    end
    updateLaserCars(ppos)
    updateSeen(ppos)
  end

  -- Sperrzeiten der Messstellen laufen immer ab (auch wenn man gerade weit weg ist)
  for _, st in pairs(camState) do if st.cooldown > 0 then st.cooldown = st.cooldown - dt end end
  if player and #nearPlaces > 0 and not (pursuit and pursuit.phase == 'check') then checkCams(dt, player) end

  if player then
    collTimer = collTimer - dt
    if collTimer <= 0 then
      collTimer = 0.1
      checkCollisions(0.1, player)
    end
  end

  tickTimer = tickTimer - dt
  if tickTimer > 0 then return end
  local step = 0.25 - tickTimer
  tickTimer = 0.25
  if pursuit then updatePursuit(step) end
  updateLeaving(step, ppos)
end

local function onClientEndMission() M.reset() end
local function onExtensionUnloaded() M.reset() end

-- Spielerauto gewechselt/neu gespawnt während der Kontrolle: Sperre aufheben
local function onVehicleSwitched()
  if frozen and not M.isChecking() then unfreezePlayer() end
end

M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission
M.onExtensionUnloaded = onExtensionUnloaded
M.onVehicleSwitched = onVehicleSwitched
M.onDrawOnMinimap = onDrawOnMinimap

return M
