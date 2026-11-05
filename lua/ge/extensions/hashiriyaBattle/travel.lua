-- Hashiriya Battle: Haupt-PAs und Reisen (05.11.2026)
-- 1. Haupt-PAs (napSpots der Kartendatei mit main = true) erscheinen auf der großen Karte (M), mit Vorschaubild.
--    In der Dev-Version gibt es dort den Knopf "Quick Travel" zum Ankunftspunkt der PA (spawn), im Release nicht.
-- 2. Eigene Parkbuchten der PAs (bays) kommen zu den Parkplätzen der Map dazu (gameplay_parking).
--    Die nutzt der BeamNG-Parkverkehr und die PA-Fahrer/PA-Rivalen (talk.lua sucht dort freie Buchten).
-- 3. Reisen: An einer Ausfahrt (ramps, kind off) langsam abfahren, dann im Menü links "Reisen" wählen.
--    Ziele sind die Garage und schon besuchte Haupt-PAs. Reisen spult die Uhr vor und kostet Sprit.
--    Aus der Garage kann man genauso an einer besuchten PA losfahren (Start-PA).
--    Auffahrten (kind on) sind für den Map-Wechsel nach 1.0 (dort kommt man wieder auf den C1).
-- Einstellungen: data/travel.json. Neue PAs: nur Eintrag in maps/<level>.json, kein Code nötig.
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
local cfgPath = '/lua/ge/extensions/hashiriyaBattle/data/travel.json'
local up = vec3(0, 0, 1)

local function core() return extensions.hashiriyaBattle_core end
local function toVec(t) return vec3(t[1], t[2], t[3]) end

local defaults = {
  onlyVisited = true, detour = 1.4, cityKmh = 35, minMinutes = 10, litersPer100km = 9, minFuelLiters = 1,
  rampRadius = 25, rampMaxKmh = 45, offerSeconds = 60, offerDistance = 400, hintSeconds = 6, blackSeconds = 6,
  bayScale = { 2.6, 5.4, 3 }, mapIcon = nil, cardIcon = 'parking', poiPrefix = 'hashiriya_pa_',
}
local cfgCache = nil
function M.cfg()
  if cfgCache then return cfgCache end
  local d = jsonReadFile(cfgPath) or {}
  for k, v in pairs(defaults) do if d[k] == nil then d[k] = v end end
  cfgCache = d
  return d
end

local function lang()
  local c = core()
  return c and c.lang == 'de' and 'de' or 'en'
end
local function loc(v)
  if type(v) == 'table' then return v[lang()] or v.en or v.de or '' end
  return v or ''
end

-- Haupt-PAs -------------------------------------------------------------------------

function M.mainPas()
  local md = core() and core().mapData or {}
  local out = {}
  for i, n in ipairs(md.napSpots or {}) do
    if type(n.pos) == 'table' and n.main ~= false then
      n.id = n.id or ('pa' .. i)
      table.insert(out, n)
    end
  end
  return out
end

local function paById(id)
  for _, n in ipairs(M.mainPas()) do if n.id == id then return n end end
  return nil
end

-- Ankunftspunkt einer PA: spawn (vom Dev-Ort mit Notiz "Haupt Spawnpunkt"), sonst die Mitte
function M.paTransform(pa)
  local s = pa.spawn or {}
  local pos = toVec(s.pos or pa.pos) + vec3(0, 0, 0.3)
  local dir = s.dir or pa.dir or { 0, 1, 0 }
  return pos, quatFromDir(vec3(dir[1], dir[2], 0):normalized(), up)
end

local function isDev()
  local c = core()
  return c and not (c.isRelease and c.isRelease())
end

-- große Karte: wird aus core.onGetRawPoiListForLevel aufgerufen (nur während der Karriere)
function M.addPois(elements)
  local cfg = M.cfg()
  local dev = isDev()
  for _, pa in ipairs(M.mainPas()) do
    local name = loc(pa.label) ~= '' and loc(pa.label) or pa.name
    local preview = pa.preview or cfg.placeholderPreview
    local bm = { pos = toVec(pa.spawn and pa.spawn.pos or pa.pos), name = name, cardIcon = cfg.cardIcon,
      description = core().t('travel.poiDesc'), thumbnail = preview, previews = preview and { preview } or nil }
    if cfg.mapIcon then bm.icon = cfg.mapIcon end
    if dev then
      bm.quickTravelPosRotFunction = function() return M.paTransform(pa) end
    end
    table.insert(elements, { id = cfg.poiPrefix .. pa.id, data = { type = 'hashiriyaPa', id = cfg.poiPrefix .. pa.id },
      markerInfo = { bigmapMarker = bm } })
  end
end

local function clearPois()
  local rp = rawget(_G, 'gameplay_rawPois') or extensions.gameplay_rawPois
  if rp and rp.clear then pcall(rp.clear) end
end

-- Eigene Parkbuchten in die Parkplätze der Map einfügen ------------------------------

local injectedSites = nil
local function bayName(pa, i) return 'hashiriya_' .. tostring(pa.id) .. '_' .. i end

local function injectBays()
  local pas = M.mainPas()
  local probe = nil -- Name einer unserer Buchten: fehlt sie, wurden die Parkplätze neu geladen
  for _, pa in ipairs(pas) do if type(pa.bays) == 'table' and pa.bays[1] then probe = bayName(pa, 1) break end end
  if not probe then return end
  local park = extensions.gameplay_parking
  if not park then extensions.load('gameplay_parking') park = extensions.gameplay_parking end
  if not park then return end
  if not extensions.gameplay_city then extensions.load('gameplay_city') end
  local okL, list = pcall(park.getParkingSpots)
  local sites = okL and type(list) == 'table' and list.parent or nil
  local fresh = false
  if not sites then
    -- Map ohne Parkplatz-Daten: eigene Sites nur mit unseren Buchten
    local okS, s = pcall(function() return require('/lua/ge/extensions/gameplay/sites/sites')('hashiriya') end)
    if not okS or not s then return end
    sites = s
    fresh = true
  end
  if sites == injectedSites and sites.parkingSpots.byName[probe] ~= nil then return end
  local scl = M.cfg().bayScale
  local n = 0
  for _, pa in ipairs(pas) do
    for i, b in ipairs(pa.bays or {}) do
      if type(b.pos) == 'table' and not sites.parkingSpots.byName[bayName(pa, i)] then
        local ps = sites.parkingSpots:create(bayName(pa, i), nil, true)
        local d = b.dir or { 0, 1, 0 }
        ps:set(toVec(b.pos), quatFromDir(vec3(d[1], d[2], 0):normalized(), up), vec3(scl[1], scl[2], scl[3]))
        n = n + 1
      end
    end
  end
  if n == 0 and sites == injectedSites then return end
  local okF, err = pcall(function() sites:finalizeSites() end)
  if not okF then log('E', logTag, 'PA-Buchten einfügen fehlgeschlagen: ' .. tostring(err)) return end
  if park.setSites then pcall(park.setSites, sites) end
  injectedSites = sites
  log('I', logTag, string.format('PA-Buchten eingefügt: %d (%s)', n, fresh and 'eigene Parkplatz-Daten' or 'zu den Parkplätzen der Map'))
end

-- Reisen ----------------------------------------------------------------------------

local offer = nil      -- { ramp, t } nach dem Abfahren an einer Ausfahrt
local hinted = {}      -- Ausfahrt-Hinweis je Ausfahrt nur alle paar Minuten
local busyTravel = false

local function ramps(kind)
  local out = {}
  for _, r in ipairs((core().mapData or {}).ramps or {}) do
    if type(r.pos) == 'table' and (not kind or r.kind == kind) then table.insert(out, r) end
  end
  return out
end
M.ramps = ramps

local function fuelLiters()
  local save = core().save
  local car = save and save.cars and save.cars[save.activeCar or 1]
  return car and tonumber(car.fuel) or nil
end

local function blocked()
  local c = core()
  if not c.active or not c.save then return 'inactive' end
  if busyTravel or extensions.hashiriyaBattle_home.isResting() then return 'busy' end
  if extensions.hashiriyaBattle_battle.isBusy() then return 'battle' end
  if extensions.hashiriyaBattle_police and extensions.hashiriyaBattle_police.isActive() then return 'police' end
  if extensions.hashiriyaBattle_jobs and extensions.hashiriyaBattle_jobs.isActive() then return 'job' end
  if not c.getPlayerVehicle() then return 'noCar' end
  return nil
end

local function fmtDuration(minutes)
  local h, m = math.floor(minutes / 60), math.floor(minutes % 60 + 0.5)
  if m >= 60 then h, m = h + 1, 0 end
  return string.format('%d:%02d h', h, m)
end

-- Reiseziele von einem Ort aus (fromPos), ohne das Ziel, an dem man gerade ist
function M.destinations(fromPos)
  local c = core()
  local cfg = M.cfg()
  local out = {}
  local visited = c.save and c.save.paVisited or {}
  local list = {}
  local garage = extensions.hashiriyaBattle_parking.find('garage')
  if garage then table.insert(list, { id = 'garage', name = c.t('pa.garage'), pos = toVec(garage.pos), kind = 'garage' }) end
  for _, pa in ipairs(M.mainPas()) do
    local name = loc(pa.label) ~= '' and loc(pa.label) or pa.name
    table.insert(list, { id = pa.id, name = name, pos = toVec(pa.spawn and pa.spawn.pos or pa.pos), kind = 'pa',
      visited = visited[pa.name] ~= nil, radius = pa.radius or 80 })
  end
  local fuel = fuelLiters()
  for _, d in ipairs(list) do
    local dist = (d.pos - fromPos):length()
    local here = dist < (d.kind == 'pa' and d.radius or 60)
    if not here then
      local km = dist * cfg.detour / 1000
      local minutes = math.max(cfg.minMinutes, km / cfg.cityKmh * 60)
      local liters = km * cfg.litersPer100km / 100
      local reason = nil
      if d.kind == 'pa' and cfg.onlyVisited and not d.visited and not isDev() then reason = 'notVisited'
      elseif fuel and fuel - liters < cfg.minFuelLiters then reason = 'fuel' end
      table.insert(out, { id = d.id, name = d.name, kind = d.kind, km = km, minutes = minutes, liters = liters,
        can = reason == nil, reason = reason, visited = d.visited })
    end
  end
  table.sort(out, function(a, b)
    if a.kind ~= b.kind then return a.kind == 'garage' end
    if (a.reason == nil) ~= (b.reason == nil) then return a.reason == nil end
    return a.km < b.km
  end)
  return out
end

local function teleport(veh, pos, rot)
  local ok = pcall(function() spawn.safeTeleport(veh, pos, rot, nil, nil, nil, nil, false) end)
  if not ok then
    ok = pcall(function() veh:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w) end)
  end
  pcall(function() core_camera.resetCamera(0) end)
  return ok
end

-- Woher wird gereist? 'ramp' (nach dem Abfahren an einer Ausfahrt) oder 'garage' (in der Garagenbucht)
local function origin()
  local c = core()
  local parking = extensions.hashiriyaBattle_parking
  if parking.isArrived() then
    local area = parking.getCurrent()
    if area and area.type == 'garage' then return 'garage', toVec(area.pos), c.t('pa.garage') end
    return nil
  end
  if offer then return 'ramp', toVec(offer.ramp.pos), offer.ramp.name end
  return nil
end

function M.go(destId)
  local c = core()
  local why = blocked()
  if why then
    if why ~= 'inactive' and why ~= 'busy' then c.msg(c.t('travel.no.' .. why), 4) end
    return
  end
  local from, fromPos, fromName = origin()
  if not from then c.msg(c.t('travel.no.here'), 4) return end
  local dest = nil
  for _, d in ipairs(M.destinations(fromPos)) do if d.id == destId then dest = d end end
  if not dest then return end
  if not dest.can then c.msg(c.t('travel.no.' .. dest.reason), 4) return end
  local veh = c.getPlayerVehicle()
  local pos, rot
  if dest.kind == 'garage' then
    pos, rot = extensions.hashiriyaBattle_parking.spawnTransform(extensions.hashiriyaBattle_parking.find('garage'))
  else
    pos, rot = M.paTransform(paById(dest.id))
  end
  if not pos then return end
  busyTravel = true
  offer = nil
  log('I', logTag, string.format('Reise von %s (%s) nach %s: %.1f km, %d min, %.1f l', tostring(fromName), from, dest.name,
    dest.km, math.floor(dest.minutes), dest.liters))
  pcall(extensions.hashiriyaBattle_rivals.despawnActive)
  local fuelBefore = fuelLiters()
  local hours = dest.minutes / 60
  local ok = extensions.hashiriyaBattle_home.travelRest(hours, M.cfg().blackSeconds, function()
    -- Bildschirm ist schwarz: Auto versetzen und Sprit abziehen
    local v = c.getPlayerVehicle() or veh
    if v then teleport(v, pos, rot) end
    if fuelBefore then extensions.hashiriyaBattle_fuel.consume(dest.liters) end
    if dest.kind == 'garage' then pcall(function() extensions.hashiriyaBattle_savepoint.markSoon('garage') end) end
  end, function()
    busyTravel = false
    c.writeSave()
    c.msg(c.t('travel.arrived', dest.name, fmtDuration(dest.minutes), string.format('%.1f', dest.liters)), 6)
    pcall(function() extensions.hashiriyaBattle_story.onEvent('travel', { place = dest.name }) end)
  end)
  if not ok then busyTravel = false end
end

-- Menü links: Liste der Reiseziele (Ausfahrt oder Garage), sonst nil
function M.getUiState()
  local c = core()
  if not c.active or not c.save then return nil end
  local from, fromPos, fromName = origin()
  if not from then return nil end
  local why = blocked()
  local list = {}
  for _, d in ipairs(M.destinations(fromPos)) do
    local sub = fmtDuration(d.minutes) .. ' · ' .. string.format('%.1f l', d.liters)
    table.insert(list, { id = d.id, name = d.name, kind = d.kind, sub = sub, can = d.can and why == nil,
      reason = d.reason and c.t('travel.no.' .. d.reason) or nil })
  end
  return { from = from, fromName = fromName, title = from == 'garage' and c.t('travel.fromGarage') or c.t('travel.fromRamp', tostring(fromName)),
    note = c.t('travel.note'),
    list = list, blocked = why and why ~= 'inactive' and c.t('travel.no.' .. why) or nil }
end

-- Laufend: Ausfahrten erkennen ---------------------------------------------------------

local checkTimer, injectTimer = 0, 0
local wasActive = false

local function checkRamps(dt)
  local c = core()
  local cfg = M.cfg()
  if offer then
    offer.t = offer.t - dt
    local veh = c.getPlayerVehicle()
    local far = veh and (vec3(veh:getPosition()) - toVec(offer.ramp.pos)):length() > cfg.offerDistance
    if offer.t <= 0 or far or not veh then offer = nil end
  end
  if blocked() then return end
  local veh = c.getPlayerVehicle()
  local p = vec3(veh:getPosition())
  local kmh = vec3(veh:getVelocity()):length() * 3.6
  if kmh > cfg.rampMaxKmh then return end
  for _, r in ipairs(ramps('off')) do
    local d = (p - toVec(r.pos)):length()
    if d < cfg.rampRadius and (not offer or offer.ramp ~= r) then
      offer = { ramp = r, t = cfg.offerSeconds }
      local now = os.clock()
      if not hinted[r.id or r.name] or now - hinted[r.id or r.name] > 180 then
        hinted[r.id or r.name] = now
        local key = 'Pos1'
        pcall(function() key = extensions.hashiriyaBattle_career.keyFor('hashiriyaToggleMenu') or key end)
        c.msg(c.t('travel.rampHint', r.name, key), cfg.hintSeconds)
      end
      break
    end
  end
end

local function onUpdate(dtReal)
  local c = core()
  if not c or not c.levelName then return end
  local active = c.active and c.save ~= nil
  if active ~= wasActive then
    wasActive = active
    clearPois() -- große Karte neu aufbauen (Haupt-PAs nur während der Karriere)
    if not active then offer = nil end
  end
  injectTimer = injectTimer - (dtReal or 0)
  if injectTimer <= 0 then
    injectTimer = 5
    local ok, err = pcall(injectBays)
    if not ok then log('E', logTag, 'PA-Buchten: ' .. tostring(err)) end
  end
  if not active then return end
  -- Sicherheitsnetz: Ruhephase wurde abgebrochen (Fehler), dann nicht ewig "unterwegs" bleiben
  if busyTravel and not extensions.hashiriyaBattle_home.isResting() then busyTravel = false end
  checkTimer = checkTimer - (dtReal or 0)
  if checkTimer > 0 then return end
  checkTimer = 0.25
  local ok, err = pcall(checkRamps, 0.25)
  if not ok then log('E', logTag, 'Ausfahrten: ' .. tostring(err)) end
end

function M.reload()
  cfgCache = nil
  injectedSites = nil
  clearPois()
end

local function onClientEndMission()
  offer, injectedSites, busyTravel, wasActive = nil, nil, false, false
  hinted = {}
end

M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission

return M
