-- Hashiriya Battle: Nebenjobs am Tag und bezahlte Tipps (Alpha 0.7).
-- Am Jobbrett (Garage oder Zuhause, nur tagsüber) gibt es jeden Tag ein paar Aufträge:
--   courier = Kurierfahrt zu einem Ziel mit Zeitlimit, Schaden am Auto kürzt den Lohn
--   express = wie Kurier, aber knapper und besser bezahlt
--   fragile = zerbrechliche Ladung: mehr Geld, Schaden kostet dreifach, zu viel Schaden = Auftrag geplatzt
--   photo   = Fotojob: zu Fuß an einer PA sein, solange das Zeitfenster offen ist
--   taxi    = Taxischicht: mit dem Firmentaxi (Pessima) mehrere Fahrgäste abholen und hinbringen, dann zurück zum Depot.
--             Taxameter + Trinkgeld; Tempolimit, ruckartiges Fahren, Schaden und Verspätung kosten Trinkgeld.
--             Das eigene Auto bleibt stehen. Das Taxi zählt für Tank, Schaden, Zustand, Shop usw. NICHT als dein Auto
--             (core.getPlayerVehicle gibt dafür nil zurück, siehe M.jobVehId).
--   route   = Lieferrunde: mehrere Stopps nacheinander mit dem eigenen Auto, eine Gesamtzeit; Lohn pro Stopp
-- Dazu Tipps: Hinweise zu Wanderern und Bossen kaufen (wie aus den PA-Gesprächen, landen im Rivalen-Lexikon).
-- Ziele: Parkplätze und PAs der Kartendatei, dazu "jobSpots" (Liste { name, pos }) in maps/<level>.json.
-- Einstellungen und Ladungen: data/jobs.json. Spielstand: save.jobs = { day, offers, done, earned, count }.
local M = {}

local logTag = 'hashiriya.jobs'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local jobsPath = '/lua/ge/extensions/hashiriyaBattle/data/jobs.json'

local function core() return extensions.hashiriyaBattle_core end
local function home() return extensions.hashiriyaBattle_home end
local function progress() return extensions.hashiriyaBattle_progress end
local function parking() return extensions.hashiriyaBattle_parking end

local data = nil
local active = nil   -- laufender Auftrag { offer, left, startDamage, early, stage = 'pickup'|'deliver' }
                     -- Taxi: stage = 'pickup'|'ride'|'depot', fare = Nummer, taxiId, ownId, depot, earned ...
                     -- Lieferrunde: stage = 'route', stop = Nummer
M.jobVehId = nil     -- Firmentaxi während der Schicht (core.getPlayerVehicle ignoriert es)
local pendingDelete = nil -- { id, t } Taxi nach dem Umsteigen löschen
local timer = 0
local updateMarkers -- weiter unten (Markierungen und Navi-Route)

local defaults = {
  enabled = true, offersPerDay = 4, maxPerDay = 4, minDistance = 800, arriveRadius = 25, arriveKmh = 8,
  rankBonus = 0.08, photoRadius = 60, photoWindowHours = 2, failMoney = 0,
  pickup = true, pickupMaxDistance = 2500, photoSpotRadius = 7, photoStopKmh = 2, markers = true, navRoute = true,
  tipPriceWanderer = 250000, tipPriceBoss = 750000, tipRankFactor = 0.1,
}
local typeDefaults = {
  courier = { payBase = 8000, payPerKm = 2500, secondsPerKm = 75, minSeconds = 150, damageFactor = 1, weight = 3 },
  express = { payBase = 12000, payPerKm = 3800, secondsPerKm = 52, minSeconds = 110, damageFactor = 1, weight = 2 },
  fragile = { payBase = 15000, payPerKm = 3200, secondsPerKm = 95, minSeconds = 180, damageFactor = 3, failDamageYen = 40000, weight = 2 },
  photo = { payBase = 22000, weight = 1 },
  taxi = { fares = 3, flagFall = 3000, payPerKm = 3600, tipMax = 4000, secondsPerKm = 80, minSeconds = 120, speedLimitKmh = 80,
    speedPenaltySeconds = 25, joltG = 0.55, joltPenalty = 0.15, damagePenalty = 0.5, latePayFactor = 0.6, failDamageYen = 30000,
    yenPerDamage = 2, repairShare = 1, weight = 2 },
  route = { minStops = 3, maxStops = 4, payPerStop = 7000, payPerKm = 2000, secondsPerKm = 70, stopSeconds = 25, minSeconds = 200,
    damageFactor = 1, partialFactor = 0.6, weight = 2 },
}

local speakerNames = {} -- Auftraggeber: Namen der Sprecher aus chat.json

function M.loadData()
  local chat = jsonReadFile('/lua/ge/extensions/hashiriyaBattle/data/chat.json') or {}
  speakerNames = {}
  for _, sp in ipairs(chat.speakers or {}) do speakerNames[sp.id] = sp.name end
  data = jsonReadFile(jobsPath) or {}
  data.settings = data.settings or {}
  data.types = data.types or {}
  data.cargo = data.cargo or {}
end

local function cfg()
  if not data then M.loadData() end
  local s = data.settings
  return setmetatable({}, { __index = function(_, k) if s[k] ~= nil then return s[k] end return defaults[k] end })
end

local function typeCfg(kind)
  if not data then M.loadData() end
  local t = data.types[kind] or {}
  local d = typeDefaults[kind] or {}
  return setmetatable({}, { __index = function(_, k) if t[k] ~= nil then return t[k] end return d[k] end })
end

local function loc(v) return progress().loc(v) end
local function toVec(t) return vec3(t[1], t[2], t[3]) end

local function hashStr(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

local function seeded(seed)
  local x = seed % 2147483647
  if x <= 0 then x = x + 2147483646 end
  return function(a, b)
    x = (x * 16807) % 2147483647
    local f = (x - 1) / 2147483646
    if not a then return f end
    return a + math.floor(f * (b - a + 1))
  end
end

-- Ziele der Karte ---------------------------------------------------------------------

local function spots()
  local c = core()
  local md = c.mapData or {}
  local out = {}
  for _, a in ipairs(md.parkingAreas or {}) do
    if type(a.pos) == 'table' and a.type ~= 'home' and a.type ~= 'garage' and not a.footOnly then
      table.insert(out, { name = c.t('pa.' .. a.type), pos = a.pos, kind = a.type })
    end
  end
  for _, n in ipairs(md.napSpots or {}) do
    if type(n.pos) == 'table' then table.insert(out, { name = n.name, pos = n.pos, kind = 'pa' }) end
  end
  for _, j in ipairs(md.jobSpots or {}) do
    if type(j.pos) == 'table' then table.insert(out, { name = loc(j.name) ~= '' and loc(j.name) or 'Ziel', pos = j.pos, kind = 'job' }) end
  end
  return out
end

-- Fahrgast-Punkte für die Taxischicht: eigene Punkte (Dev-Typ "taxi" / taxiSpots), dazu alle normalen Ziele
local function taxiSpots()
  local out = {}
  for _, e in ipairs(core().spots('taxi')) do
    table.insert(out, { name = loc(e.name) ~= '' and loc(e.name) or core().t('jobs.taxiStand'), pos = e.pos, kind = 'taxi' })
  end
  for _, s in ipairs(spots()) do table.insert(out, s) end
  return out
end

local function playerPos()
  local c = core()
  local veh = c.getPlayerVehicle()
  if veh then return veh:getPosition() end
  return c.getWalkerPos()
end

-- Spielstand --------------------------------------------------------------------------

local function state(save)
  save = save or core().save
  save.jobs = save.jobs or {}
  local j = save.jobs
  j.done = j.done or {}
  j.count = j.count or 0
  j.earned = j.earned or 0
  return j
end

local function rankFactor(save)
  return 1 + (progress().rankIndex(save) or 0) * cfg().rankBonus
end

local function round100(v) return math.floor(v / 100 + 0.5) * 100 end

local function fmtTime(s)
  s = math.max(0, math.floor(s))
  return string.format('%d:%02d', math.floor(s / 60), s % 60)
end

-- Aufträge des Tages (fest pro Tag und Spielstand, damit Neuladen nichts ändert)
local function buildOffers(save)
  local j = state(save)
  local day = save.day or 1
  if j.day == day and j.offers then return j.offers end
  j.day, j.offers, j.done = day, {}, {}
  local rand = seeded(hashStr(tostring(save.dealerSeed or 1) .. ':jobs:' .. day))
  local from = parking().find('garage')
  local origin = from and toVec(from.pos) or playerPos()
  local list = spots()
  if not origin or #list == 0 then return j.offers end
  local far = {}
  for _, s in ipairs(list) do
    local d = (toVec(s.pos) - origin):length()
    if d >= cfg().minDistance then table.insert(far, { spot = s, dist = d }) end
  end
  local paSpots = {}
  -- Foto-Spots (Dev-Menü / photoSpots): dort wird das Auto abgestellt. Ohne eigene Spots: die PAs.
  for _, e in ipairs(core().spots('photo')) do
    table.insert(paSpots, { name = loc(e.name) ~= '' and loc(e.name) or 'Foto-Spot', pos = e.pos, dir = e.dir, photoSpot = true })
  end
  if #paSpots == 0 then
    for _, s in ipairs(list) do if s.kind == 'pa' then table.insert(paSpots, s) end end
  end
  local kinds = {}
  for _, k in ipairs({ 'courier', 'express', 'fragile', 'photo', 'taxi', 'route' }) do
    for _ = 1, math.max(0, tonumber(typeCfg(k).weight) or 0) do table.insert(kinds, k) end
  end
  local h = home().hour() or 8
  for i = 1, cfg().offersPerDay do
    local kind = kinds[rand(1, math.max(#kinds, 1))]
    if kind == 'photo' and #paSpots == 0 then kind = 'courier' end
    if kind ~= 'photo' and #far == 0 then kind = 'photo' end
    if kind == 'taxi' and #(typeCfg('taxi').cars or {}) == 0 then kind = 'courier' end
    local t = typeCfg(kind)
    local o = { id = 'j' .. day .. '_' .. i, kind = kind }
    if (kind == 'taxi' and not M.buildTaxi(o, t, rand, save)) or (kind == 'route' and not M.buildRoute(o, t, rand, save, origin, list)) then
      kind, o.kind, t = 'courier', 'courier', typeCfg('courier')
    end
    if kind == 'taxi' or kind == 'route' then
      -- schon fertig gebaut
    elseif kind == 'photo' then
      local s = paSpots[rand(1, #paSpots)]
      local w = cfg().photoWindowHours
      -- Fenster tagsüber, frühestens eine Stunde nach jetzt
      local start = math.min(18 - w, math.max(math.floor(h) + 1, 7 + rand(0, 8)))
      o.target = { name = s.name, pos = s.pos, dir = s.dir, photoSpot = s.photoSpot or nil }
      o.window = { start, start + w }
      o.pay = round100(t.payBase * rankFactor(save) * (0.85 + rand() * 0.3))
      local subj = data.photoSubjects or {}
      o.cargo = #subj > 0 and subj[rand(1, #subj)] or nil
    else
      local f = far[rand(1, #far)]
      local km = f.dist / 1000
      o.target = { name = f.spot.name, pos = f.spot.pos }
      -- Ware erst abholen (Abholpunkt näher an der Garage), dann zum Ziel
      if cfg().pickup then
        local cands = {}
        local tpos = toVec(f.spot.pos)
        for _, s2 in ipairs(list) do
          local sp = toVec(s2.pos)
          if s2 ~= f.spot and (sp - origin):length() <= cfg().pickupMaxDistance and (sp - tpos):length() >= cfg().minDistance then
            table.insert(cands, s2)
          end
        end
        if #cands > 0 then
          local pk = cands[rand(1, #cands)]
          o.pickup = { name = pk.name, pos = pk.pos }
          km = (toVec(pk.pos) - tpos):length() / 1000
        end
      end
      o.km = math.floor(km * 10 + 0.5) / 10
      o.seconds = math.max(t.minSeconds, math.floor(km * t.secondsPerKm / 5 + 0.5) * 5)
      o.pay = round100((t.payBase + t.payPerKm * km) * rankFactor(save) * (0.9 + rand() * 0.2))
      local pool = data.cargo[kind] or data.cargo.courier or {}
      o.cargo = #pool > 0 and pool[rand(1, #pool)] or nil
    end
    o.speaker = t.speaker or (kind == 'photo' and 'photo' or (kind == 'fragile' and 'trucker' or 'courier'))
    if kind == 'taxi' then o.speaker = t.speaker end
    table.insert(j.offers, o)
  end
  return j.offers
end

-- Taxischicht und Lieferrunde: Angebote bauen ---------------------------------------------

-- Taxi: Firma + Auto aus jobs.json (types.taxi.cars), dazu die Fahrten (Abholpunkt -> Ziel)
function M.buildTaxi(o, t, rand, save)
  local cars = t.cars or {}
  if #cars == 0 then return false end
  local list = taxiSpots()
  if #list < 2 then return false end
  local car = cars[rand(1, #cars)]
  o.company = car.company
  o.car = { model = car.model, config = car.config, plate = car.plate }
  o.fares = {}
  local total, km = 0, 0
  local last, usedFrom = nil, {}
  for f = 1, math.max(1, tonumber(t.fares) or 3) do
    local from = nil
    for _ = 1, 12 do
      local c = list[rand(1, #list)]
      if c ~= last and not usedFrom[c] then from = c break end
    end
    if from then usedFrom[from] = true end
    from = from or list[1]
    local cands = {}
    for _, s in ipairs(list) do
      if s ~= from and (toVec(s.pos) - toVec(from.pos)):length() >= cfg().minDistance then table.insert(cands, s) end
    end
    if #cands == 0 then return false end
    local to = cands[rand(1, #cands)]
    local d = (toVec(to.pos) - toVec(from.pos)):length() / 1000
    local fare = {
      from = { name = from.name, pos = from.pos }, to = { name = to.name, pos = to.pos },
      km = math.floor(d * 10 + 0.5) / 10,
      seconds = math.max(t.minSeconds, math.floor(d * t.secondsPerKm / 5 + 0.5) * 5),
      pay = round100((t.flagFall + t.payPerKm * d) * rankFactor(save) * (0.9 + rand() * 0.2)),
    }
    local pl = data.passengers or {}
    if #pl > 0 then fare.passenger = rand(1, #pl) end
    table.insert(o.fares, fare)
    total, km = total + fare.pay, km + d
    last = to
  end
  o.pay = total
  o.km = math.floor(km * 10 + 0.5) / 10
  o.target = { name = loc(o.company) ~= '' and loc(o.company) or core().t('jobs.type.taxi') }
  o.cargo = { title = core().t('jobs.taxiTitle', tostring(#o.fares)), text = car.text }
  return true
end

-- Lieferrunde: Stopps nacheinander, jeder ein Stück vom vorigen entfernt
function M.buildRoute(o, t, rand, save, origin, list)
  if not origin or #list < 3 then return false end
  local n = rand(math.max(2, t.minStops), math.max(t.minStops, t.maxStops))
  local stops, used = {}, {}
  local prev = origin
  local km = 0
  for _ = 1, n do
    local cands = {}
    for _, s in ipairs(list) do
      if not used[s] and (toVec(s.pos) - prev):length() >= cfg().minDistance * 0.6 then table.insert(cands, s) end
    end
    if #cands == 0 then break end
    local s = cands[rand(1, #cands)]
    used[s] = true
    km = km + (toVec(s.pos) - prev):length() / 1000
    prev = toVec(s.pos)
    table.insert(stops, { name = s.name, pos = s.pos })
  end
  if #stops < 2 then return false end
  o.stops = stops
  o.km = math.floor(km * 10 + 0.5) / 10
  o.seconds = math.max(t.minSeconds, math.floor((km * t.secondsPerKm + #stops * t.stopSeconds) / 5 + 0.5) * 5)
  o.pay = round100((t.payPerStop * #stops + t.payPerKm * km) * rankFactor(save) * (0.9 + rand() * 0.2))
  o.target = stops[#stops]
  local pool = data.cargo.route or {}
  o.cargo = #pool > 0 and pool[rand(1, #pool)] or nil
  return true
end

-- Aufträge von heute (für das Schwarze Brett: Anzeigen der Taxifirma usw.)
function M.todaysOffers(save)
  save = save or core().save
  if not save or not cfg().enabled then return {} end
  if not data then M.loadData() end
  return buildOffers(save)
end

-- Taxi: Auto holen, einsteigen, zurückgeben -------------------------------------------------

local function taxiVeh()
  return M.jobVehId and be:getObjectByID(M.jobVehId) or nil
end

local function rawPlayerVeh()
  return getPlayerVehicle and getPlayerVehicle(0) or be:getPlayerVehicle(0)
end

local function vehDamageYen(veh, t)
  local o = veh and map.objects[veh:getID()]
  return (o and o.damage or 0) * (t.yenPerDamage or 2)
end

local function taxiRepairs(tx, t)
  return round100(vehDamageYen(tx, t) * (t.repairShare or 1))
end

-- Depot: nächster eigener Depot-Punkt (Dev-Typ "taxidepot"), sonst direkt neben dem Spieler
local function depotTransform()
  local c = core()
  local own = c.getPlayerVehicle()
  local base, dir
  if own then base, dir = own:getPosition(), own:getDirectionVector()
  else
    base = c.getWalkerPos()
    local okD, f = pcall(core_camera.getForward)
    dir = okD and f and vec3(f.x, f.y, 0) or vec3(0, 1, 0)
  end
  if not base then return nil end
  local best, bestD = nil, 1e9
  for _, e in ipairs(c.spots('taxidepot')) do
    local d = (toVec(e.pos) - base):length()
    if d < bestD then best, bestD = e, d end
  end
  if best and bestD < 3000 then
    local d = best.dir and toVec(best.dir) or dir
    return toVec(best.pos) + vec3(0, 0, 0.3), quatFromDir(vec3(d.x, d.y, 0):normalized(), vec3(0, 0, 1)), loc(best.name)
  end
  dir = vec3(dir.x, dir.y, 0)
  if dir:length() < 0.1 then dir = vec3(0, 1, 0) end
  dir = dir:normalized()
  local right = dir:cross(vec3(0, 0, 1)):normalized()
  return base + right * 4.5 + vec3(0, 0, 0.3), quatFromDir(dir, vec3(0, 0, 1)), nil
end

local function startTaxi(o)
  local c = core()
  local pos, rot, depotName = depotTransform()
  if not pos then return false end
  local own = c.getPlayerVehicle()
  local ownId = own and own:getID() or c.carVehId
  if ownId then c.carVehId = ownId end
  local walking = c.getWalkerPos() ~= nil
  local opts = { config = o.car.config, pos = pos, rot = rot, autoEnterVehicle = false }
  if o.car.plate then opts.licenseText = o.car.plate end
  local ok, veh = pcall(core_vehicles.spawnNewVehicle, o.car.model, opts)
  if not ok or not veh then log('E', logTag, 'Taxi spawnen fehlgeschlagen: ' .. tostring(veh)) return false end
  M.jobVehId = veh:getID()
  pcall(function() spawn.safeTeleport(veh, pos, rot) end)
  local entered = false
  if walking then
    local w = extensions.gameplay_walk
    entered = w and w.getInVehicle and pcall(w.getInVehicle, veh) or false
  end
  if not entered then pcall(function() be:enterVehicle(0, veh) end) end
  local tp = veh:getPosition()
  active.taxiId, active.ownId = M.jobVehId, ownId
  active.depot = { name = depotName or (loc(o.company) ~= '' and loc(o.company) or c.t('jobs.type.taxi')), pos = { tp.x, tp.y, tp.z } }
  active.fare, active.stage, active.earned, active.repairs = 1, 'pickup', 0, 0
  log('I', logTag, 'Taxischicht: Taxi ' .. tostring(M.jobVehId) .. ' (' .. tostring(o.car.config) .. '), eigenes Auto ' .. tostring(ownId))
  return true
end

-- Taxi abgeben: zurück ins eigene Auto (oder zu Fuß daneben), Taxi danach löschen
local function returnTaxi()
  local c = core()
  local tx = taxiVeh()
  local cur = rawPlayerVeh()
  local own = active and active.ownId and be:getObjectByID(active.ownId)
  if tx and cur and cur:getID() == tx:getID() then
    if own and own:getJBeamFilename() ~= 'unicycle' then
      pcall(function() be:enterVehicle(0, own) end)
    else
      local p, d = tx:getPosition(), tx:getDirectionVector()
      local side = d:cross(vec3(0, 0, 1)):normalized()
      c.goOnFoot(nil, p + side * 2.5, quatFromDir(vec3(d.x, d.y, 0):normalized(), vec3(0, 0, 1)))
    end
  end
  if tx then pendingDelete = { id = tx:getID(), t = 0.6 } end
  M.jobVehId = nil
end

-- Annehmen, abbrechen, abschließen ------------------------------------------------------

local function damageYen()
  local ok, v = pcall(function() return parking().repairCost() end)
  return ok and v or 0
end

function M.isActive() return active ~= nil end

-- Aktuelles Ziel des laufenden Auftrags und ein Schlüssel dafür (für Markierung und Navi)
local function currentGoal()
  if not active then return nil end
  local o = active.offer
  if o.kind == 'taxi' then
    local f = o.fares[active.fare or 1]
    if active.stage == 'depot' or not f then return active.depot, 'depot' end
    return (active.stage == 'pickup' and f.from or f.to), active.stage .. (active.fare or 1)
  elseif o.kind == 'route' then
    return o.stops[active.stop or 1], 'stop' .. tostring(active.stop or 1)
  end
  return (active.stage == 'pickup' and o.pickup) or o.target, active.stage
end

function M.canWork()
  local c = core()
  local save = c.save
  if not save or not cfg().enabled then return false, nil end
  if home().isNight() then return false, 'jobs.notNight' end
  if active then return false, 'jobs.busy' end
  if state(save).count >= cfg().maxPerDay and state(save).countDay == save.day then return false, 'jobs.dayFull' end
  return true
end

function M.accept(id)
  local c = core()
  local save = c.save
  if not save then return end
  local ok, reason = M.canWork()
  if not ok then if reason then c.msg(c.t(reason), 4) end return end
  local j = state(save)
  for _, o in ipairs(buildOffers(save)) do
    if o.id == id and not j.done[o.id] then
      if o.kind == 'photo' and (home().hour() or 0) >= o.window[2] then c.msg(c.t('jobs.photoMissed'), 4) return end
      active = { offer = o, left = o.seconds, startDamage = damageYen(), stage = o.pickup and 'pickup' or 'deliver' }
      if o.kind == 'taxi' then
        if not startTaxi(o) then active = nil M.jobVehId = nil c.msg(c.t('jobs.taxiNoCar'), 5) return end
      elseif o.kind == 'route' then
        active.stage, active.stop = 'route', 1
      end
      j.done[o.id] = 'active'
      c.sound('challenge')
      local what = loc(o.cargo and o.cargo.title or '') ~= '' and loc(o.cargo.title) or c.t('jobs.type.' .. o.kind)
      if o.kind == 'taxi' then c.msg(c.t('jobs.taxiStart', loc(o.company), o.fares[1].from.name), 7)
      elseif o.kind == 'route' then c.msg(c.t('jobs.routeStart', tostring(#o.stops), o.stops[1].name, fmtTime(o.seconds)), 7)
      elseif o.pickup then c.msg(c.t('jobs.acceptedPickup', what, o.pickup.name), 6)
      else c.msg(c.t('jobs.accepted', what, o.target.name), 6) end
      updateMarkers()
      log('I', logTag, 'Auftrag angenommen: ' .. o.id .. ' ' .. o.kind .. ' -> ' .. tostring(o.target.name))
      c.writeSave()
      return
    end
  end
end

local function finish(success, pay, reasonKey)
  local c = core()
  local save = c.save
  local o = active.offer
  local j = state(save)
  if o.kind == 'taxi' then returnTaxi() end
  active = nil
  j.done[o.id] = success and 'ok' or 'fail'
  if j.countDay ~= save.day then j.countDay, j.count = save.day, 0 end
  j.count = j.count + 1
  if success then
    save.money = save.money + pay
    j.earned = j.earned + pay
    progress().bump(save, 'jobsDone')
    c.msg(c.t(reasonKey or 'jobs.done', c.economy().formatYen(pay)), 7)
    c.sound('levelUp')
  else
    progress().bump(save, 'jobsFailed')
    c.msg(c.t(reasonKey or 'jobs.failed'), 7)
  end
  log('I', logTag, 'Auftrag ' .. o.id .. (success and (' erledigt, ' .. tostring(pay) .. ' Yen') or (' geplatzt: ' .. tostring(reasonKey))))
  c.writeSave()
  pcall(function() extensions.hashiriyaBattle_story.onEvent('job', { job = o.kind, success = success }) end)
end

function M.cancel()
  if not active then return end
  -- Taxischicht: bis jetzt Verdientes gibt es trotzdem (abzüglich Werkstatt)
  if active.offer.kind == 'taxi' and (active.earned or 0) > 0 then
    local tx = taxiVeh()
    local net = math.max(0, active.earned - (tx and taxiRepairs(tx, typeCfg('taxi')) or 0))
    finish(true, net, 'jobs.taxiCancelPaid')
    return
  end
  finish(false, 0, 'jobs.cancelled')
end

-- Tipps ---------------------------------------------------------------------------------

-- Tipps nur zu Gegnern, die man vom Fortschritt her schon fordern könnte (Rang, Teams, Kapitel ...).
-- Uhrzeit, Auto und Teile zählen nicht: genau das verrät ja der Tipp.
local progressKeys = { minRank = true, minWins = true, minDay = true, speedTraps = true, beatenTeam = true,
  beatenTeams = true, beatenRivals = true, requires = true, storyChapter = true }
local function reachable(r, save)
  local cond = {}
  for k, v in pairs(r.conditions or {}) do if progressKeys[k] then cond[k] = v end end
  local rv = extensions.hashiriyaBattle_rivals
  local ok, met = pcall(rv.conditionsMet, cond, save)
  return ok and met
end

-- Preis steigt mit dem Rang (tipRankFactor pro Rangstufe)
local function tipPrice(r, save)
  local base = r.boss and cfg().tipPriceBoss or cfg().tipPriceWanderer
  local rank = 0
  pcall(function() rank = progress().rankIndex(save) end)
  return math.floor(base * (1 + (cfg().tipRankFactor or 0) * rank) / 1000 + 0.5) * 1000
end

local function tipList(save)
  local rv = extensions.hashiriyaBattle_rivals
  local out = {}
  for _, r in ipairs((rv.getData() or {}).rivals or {}) do
    if (r.wanderer or r.boss) and r.hint and not (save.defeated or {})[r.id] and reachable(r, save) then
      local known = save.knownHints and save.knownHints[r.id]
      table.insert(out, { id = r.id, boss = r.boss or false, known = known or false,
        price = tipPrice(r, save), name = r.name, hint = loc(r.hint), text = known and loc(r.hint) or nil })
    end
  end
  table.sort(out, function(a, b) if a.known ~= b.known then return not a.known end if a.boss ~= b.boss then return not a.boss end return a.id < b.id end)
  return out
end

function M.buyTip(id)
  local c = core()
  local save = c.save
  if not save then return end
  for _, t in ipairs(tipList(save)) do
    if t.id == id and not t.known then
      if save.money < t.price then c.msg(c.t('msg.noMoney'), 3) return end
      save.money = save.money - t.price
      home().learnHint(id)
      progress().bump(save, 'tipsBought')
      local st = extensions.hashiriyaBattle_story
      if st and st.phoneMessage then
        st.phoneMessage('tip_' .. id, 'genzo', { c.t('jobs.tipPhone1', t.name or ''), t.hint or '' })
      end
      c.msg(c.t('msg.talkHint'), 5)
      c.writeSave()
      return
    end
  end
end

-- UI ------------------------------------------------------------------------------------

function M.getUiState()
  local c = core()
  local save = c.save
  if not save then return nil end
  if not data then M.loadData() end
  local eco = c.economy()
  local ok, reason = M.canWork()
  local st = { can = ok, reason = reason and c.t(reason) or nil, offers = {}, tips = {}, earned = eco.formatYen(state(save).earned) }
  local j = state(save)
  if not home().isNight() then
    for _, o in ipairs(buildOffers(save)) do
      local e = {
        id = o.id, kind = o.kind, kindText = c.t('jobs.type.' .. o.kind), pay = eco.formatYen(o.pay), target = o.target.name,
        title = o.cargo and loc(o.cargo.title) or c.t('jobs.type.' .. o.kind), text = o.cargo and loc(o.cargo.text) or nil,
        state = j.done[o.id], client = nil,
      }
      if o.kind == 'photo' and not e.state and (home().hour() or 0) >= o.window[2] then e.state = 'missed' end
      if o.kind == 'taxi' then
        e.info = c.t('jobs.taxiInfo', tostring(#o.fares), tostring(o.km), tostring(typeCfg('taxi').speedLimitKmh))
        e.toText = c.t('jobs.taxiFor')
        e.pay = c.t('jobs.taxiPay', eco.formatYen(o.pay))
      elseif o.kind == 'route' then
        e.info = c.t('jobs.routeInfo', tostring(#o.stops), fmtTime(o.seconds), tostring(o.km))
        e.toText = c.t('jobs.routeLast')
      elseif o.kind == 'photo' then
        e.info = c.t(o.target.photoSpot and 'jobs.windowSpot' or 'jobs.window', string.format('%02d:00', o.window[1]), string.format('%02d:00', o.window[2]))
      elseif o.pickup then e.info = c.t('jobs.limitPickup', o.pickup.name, fmtTime(o.seconds), tostring(o.km))
      else e.info = c.t('jobs.limit', fmtTime(o.seconds), tostring(o.km)) end
      e.client = speakerNames[o.speaker] and loc(speakerNames[o.speaker]) or nil
      table.insert(st.offers, e)
    end
  end
  for _, t in ipairs(tipList(save)) do
    table.insert(st.tips, { id = t.id, label = c.t(t.boss and 'jobs.tipBoss' or 'jobs.tipWanderer'), price = eco.formatYen(t.price),
      known = t.known, text = t.text, afford = save.money >= t.price })
  end
  if active then st.active = M.getHudState() end
  return st
end

-- HUD-Zeile (Status-App) während eines Auftrags
function M.getHudState()
  if not active then return nil end
  local c = core()
  local o = active.offer
  local tx = o.kind == 'taxi' and taxiVeh() or nil
  local pos = tx and tx:getPosition() or playerPos()
  local goal = currentGoal()
  if not goal then return nil end
  local hud = { kind = o.kind, title = c.t('jobs.type.' .. o.kind), target = goal.name }
  if active.stage == 'pickup' and o.pickup then hud.title = c.t('jobs.pickupHud') hud.pickup = true end
  if o.kind == 'taxi' then
    if active.stage == 'pickup' then hud.title = c.t('jobs.taxiHudPickup', tostring(active.fare), tostring(#o.fares))
    elseif active.stage == 'ride' then hud.title = c.t('jobs.taxiHudRide', tostring(active.fare), tostring(#o.fares))
    else hud.title = c.t('jobs.taxiHudDepot') end
  elseif o.kind == 'route' then
    hud.title = c.t('jobs.routeHud', tostring(active.stop), tostring(#o.stops))
  end
  if pos then
    local to = toVec(goal.pos) - pos
    local d = to:length()
    hud.distText = d < 1000 and string.format('%d m', math.floor(d)) or string.format('%.1f km', d / 1000)
    local veh = tx or c.getPlayerVehicle()
    if veh then
      local fwd = veh:getDirectionVector()
      hud.angle = math.floor(math.deg(math.atan2(fwd.x * to.y - fwd.y * to.x, fwd.x * to.x + fwd.y * to.y)) * -1 + 0.5)
    end
  end
  if o.kind == 'taxi' then
    local t = typeCfg('taxi')
    if active.stage == 'ride' then
      hud.timeText = active.late and c.t('jobs.taxiLateHud') or fmtTime(active.left)
      hud.warn = active.late or active.left < 20 or active.speedingNow or nil
      if active.speedingNow then hud.timeText = c.t('jobs.taxiSlowDown', tostring(t.speedLimitKmh)) end
    else
      hud.timeText = c.economy().formatYen(active.earned or 0)
    end
    local dmg = tx and math.max(0, vehDamageYen(tx, t) - (active.startDamageTaxi or 0)) or 0
    if dmg > 0 then hud.damage = c.economy().formatYen(dmg) end
  elseif o.kind == 'route' then
    hud.timeText = fmtTime(active.left)
    hud.warn = active.left < 30 or nil
    local dmg = math.max(0, damageYen() - active.startDamage)
    if dmg > 0 then hud.damage = c.economy().formatYen(dmg * (typeCfg('route').damageFactor or 1)) end
  elseif o.kind == 'photo' then
    hud.timeText = string.format('%02d-%02d h', o.window[1], o.window[2])
    hud.early = active.early or nil
  elseif active.stage == 'pickup' then
    hud.timeText = fmtTime(active.left)
  else
    hud.timeText = fmtTime(active.left)
    hud.warn = active.left < 30 or nil
    local dmg = math.max(0, damageYen() - active.startDamage)
    if dmg > 0 then hud.damage = c.economy().formatYen(dmg * (typeCfg(o.kind).damageFactor or 1)) end
  end
  return hud
end

-- Laufend -------------------------------------------------------------------------------

-- Markierungen in der Welt (wie die Parkplätze) und Navi-Route zum aktuellen Ziel
local shownGoal = nil
local function clearRoute()
  pcall(function() if core_groundMarkers then core_groundMarkers.setPath(nil) end end)
end

local function setRoute(pos)
  if not cfg().navRoute then return end
  local ok = pcall(function() core_groundMarkers.setPath(toVec(pos)) end)
  if not ok then log('W', logTag, 'Navi-Route zum Auftrag konnte nicht gesetzt werden') end
end

updateMarkers = function()
  local goal, kind, gk = nil, 'job', nil
  if active then
    local o = active.offer
    goal, gk = currentGoal()
    if o.kind == 'photo' then kind = 'photo' end
  end
  local key = goal and (tostring(active.offer.id) .. ':' .. tostring(gk)) or nil
  if key == shownGoal then return end
  shownGoal = key
  local pk = parking()
  if pk and pk.setExtraMarkers then
    pcall(pk.setExtraMarkers, (goal and cfg().markers) and { { id = 'job', type = kind, pos = goal.pos, dir = goal.dir } } or {})
  end
  clearRoute()
  if goal then setRoute(goal.pos) end
end
M.updateMarkers = updateMarkers

local function stoppedNear(veh, pos, radius, kmh)
  if not veh then return false end
  local d = (veh:getPosition() - toVec(pos)):length()
  return d < radius and veh:getVelocity():length() * 3.6 < kmh
end

local function photoTaken(c, o)
  c.sound('photo')
  pcall(function() guihooks.trigger('HashiriyaFlash', { kind = 'photo' }) end)
  finish(true, o.pay, 'jobs.photoDone')
end

-- Taxischicht laufend ------------------------------------------------------------------------

local function nextFare(c, o)
  active.fare = active.fare + 1
  active.late, active.speedingNow = nil, nil
  if active.fare > #o.fares then
    active.stage = 'depot'
    c.msg(c.t('jobs.taxiBackToDepot', active.depot.name), 6)
  else
    active.stage = 'pickup'
    c.msg(c.t('jobs.taxiNext', o.fares[active.fare].from.name), 6)
  end
  updateMarkers()
end

local function passengerLine(f, good)
  local pl = data.passengers or {}
  local p = f.passenger and pl[f.passenger]
  if good == nil then return p and loc(p.text) or '' end
  local bye = (data.passengerBye or {})[good and 'good' or 'bad'] or {}
  if #bye == 0 then return '' end
  return loc(bye[((f.passenger or 1) - 1) % #bye + 1])
end

local function settleFare(c, o, t, tx)
  local f = o.fares[active.fare]
  local dmg = math.max(0, vehDamageYen(tx, t) - (active.startDamageTaxi or 0))
  local factor = 1 - (active.jolts or 0) * t.joltPenalty - (active.speeding or 0) / math.max(1, t.speedPenaltySeconds) - (dmg > 0 and t.damagePenalty or 0)
  factor = math.max(0, math.min(1, factor))
  local base = f.pay
  if active.late then base, factor = round100(base * t.latePayFactor), 0 end
  local tip = round100(t.tipMax * factor)
  local stars = active.late and 1 or math.max(1, math.min(5, math.floor(1 + 4 * factor + 0.5)))
  active.earned = (active.earned or 0) + base + tip
  active.stars = (active.stars or 0) + stars
  local eco = c.economy()
  c.msg(c.t('jobs.taxiFare', string.rep('★', stars) .. string.rep('☆', 5 - stars), eco.formatYen(base), eco.formatYen(tip)), 7)
  local line = passengerLine(f, stars >= 4)
  if line ~= '' then c.msg('"' .. line .. '"', 5) end
  c.sound(stars >= 4 and 'money' or 'info')
  progress().bump(c.save, 'taxiFares')
  log('I', logTag, string.format('Taxi-Fahrt %d: %d Sterne, Fahrpreis %d, Trinkgeld %d (Ruckler %d, zu schnell %.0f s, Schaden %d)',
    active.fare, stars, base, tip, active.jolts or 0, active.speeding or 0, dmg))
  nextFare(c, o)
end

local function taxiUpdate(c, o, t, dtReal, dtSim)
  local tx = taxiVeh()
  if not tx then finish(false, 0, 'jobs.taxiLost') updateMarkers() return end
  local dt = dtSim or dtReal or 0
  local cur = rawPlayerVeh()
  local inTaxi = cur and cur:getID() == tx:getID()
  -- Fahrgast an Bord: Zeit, Tempo, Ruckeln (jeden Frame)
  if active.stage == 'ride' then
    if not home().isResting() then active.left = active.left - dt end
    if active.left <= 0 and not active.late then active.late = true c.msg(c.t('jobs.taxiLate'), 5) end
    local v = tx:getVelocity()
    local flat = vec3(v.x, v.y, 0)
    active.speedingNow = inTaxi and v:length() * 3.6 > t.speedLimitKmh + 2 or nil
    if active.speedingNow then active.speeding = (active.speeding or 0) + dt end
    active.sampleT = (active.sampleT or 0) + dt
    if active.sampleT >= 0.2 then
      active.joltCd = math.max(0, (active.joltCd or 0) - active.sampleT)
      if active.lastVel and inTaxi then
        local acc = (flat - active.lastVel):length() / active.sampleT
        if acc > t.joltG * 9.81 and active.joltCd <= 0 then
          active.jolts = (active.jolts or 0) + 1
          active.joltCd = 1.5
          if active.jolts == 1 or active.jolts % 3 == 0 then c.msg(c.t('jobs.taxiJolt'), 3) end
        end
      end
      active.lastVel, active.sampleT = flat, 0
    end
  end
  timer = timer - (dtReal or 0)
  if timer > 0 then return end
  timer = 0.5
  updateMarkers()
  if not inTaxi then return end
  local goal = currentGoal()
  if active.stage == 'ride' then
    local dmg = math.max(0, vehDamageYen(tx, t) - (active.startDamageTaxi or 0))
    if dmg >= t.failDamageYen then
      c.msg(c.t('jobs.taxiPassengerOut'), 6)
      progress().bump(c.save, 'taxiFaresLost')
      nextFare(c, o)
      return
    end
  end
  if goal and stoppedNear(tx, goal.pos, cfg().arriveRadius, cfg().arriveKmh) then
    if active.stage == 'pickup' then
      local f = o.fares[active.fare]
      active.stage, active.left, active.late = 'ride', f.seconds, nil
      active.speeding, active.jolts, active.lastVel, active.sampleT = 0, 0, nil, 0
      active.startDamageTaxi = vehDamageYen(tx, t)
      c.sound('jobPickup')
      local line = passengerLine(f)
      c.msg(c.t('jobs.taxiBoard', f.to.name, fmtTime(f.seconds), tostring(t.speedLimitKmh)), 7)
      if line ~= '' then c.msg('"' .. line .. '"', 6) end
      updateMarkers()
    elseif active.stage == 'ride' then
      settleFare(c, o, t, tx)
    elseif active.stage == 'depot' then
      local repairs = taxiRepairs(tx, t)
      local net = math.max(0, (active.earned or 0) - repairs)
      if repairs > 0 then c.msg(c.t('jobs.taxiRepairs', c.economy().formatYen(math.min(repairs, active.earned or 0))), 6) end
      if net > 0 then finish(true, net, 'jobs.taxiDone') else finish(false, 0, 'jobs.taxiNothing') end
    end
  end
end

-- Lieferrunde laufend ------------------------------------------------------------------------

local function routeUpdate(c, o, t, dtReal, dtSim)
  if not home().isResting() then active.left = active.left - (dtSim or dtReal or 0) end
  if active.left <= 0 then
    local delivered = (active.stop or 1) - 1
    local dmg = math.max(0, damageYen() - active.startDamage) * (t.damageFactor or 1)
    if delivered > 0 then
      local pay = math.max(0, round100(t.payPerStop * delivered * rankFactor(c.save) * (t.partialFactor or 0.6) - dmg))
      finish(true, pay, 'jobs.routePartial')
    else
      finish(false, 0, 'jobs.late')
    end
    updateMarkers()
    return
  end
  timer = timer - (dtReal or 0)
  if timer > 0 then return end
  timer = 0.5
  updateMarkers()
  local veh = c.getPlayerVehicle()
  if not veh then return end
  local stop = o.stops[active.stop]
  if stop and stoppedNear(veh, stop.pos, cfg().arriveRadius, cfg().arriveKmh) then
    if active.stop >= #o.stops then
      local dmg = math.max(0, damageYen() - active.startDamage) * (t.damageFactor or 1)
      finish(true, math.max(0, round100(o.pay - dmg)), dmg > 0 and 'jobs.doneDamage' or 'jobs.routeDone')
      updateMarkers()
    else
      active.stop = active.stop + 1
      c.sound('jobPickup')
      c.msg(c.t('jobs.routeStop', tostring(active.stop - 1), tostring(#o.stops), o.stops[active.stop].name), 5)
      updateMarkers()
    end
  end
end

local function onUpdate(dtReal, dtSim)
  if pendingDelete then
    pendingDelete.t = pendingDelete.t - (dtReal or 0)
    if pendingDelete.t <= 0 then
      local v = be:getObjectByID(pendingDelete.id)
      local cur = rawPlayerVeh()
      if v and not (cur and cur:getID() == pendingDelete.id) then pcall(function() v:delete() end) pendingDelete = nil
      elseif not v then pendingDelete = nil
      else pendingDelete.t = 0.5 end
    end
  end
  local c = core()
  if not c or not c.active or not c.save then
    if active or shownGoal then
      if active and active.offer.kind == 'taxi' then returnTaxi() end
      active = nil updateMarkers()
    end
    return
  end
  if not active then
    if shownGoal then updateMarkers() end
    return
  end
  local o = active.offer
  local t = typeCfg(o.kind)
  if o.kind == 'taxi' then
    local ok, err = pcall(taxiUpdate, c, o, t, dtReal, dtSim)
    if not ok then log('E', logTag, 'Taxischicht: ' .. tostring(err)) end
    if not active then updateMarkers() end
    return
  elseif o.kind == 'route' then
    local ok, err = pcall(routeUpdate, c, o, t, dtReal, dtSim)
    if not ok then log('E', logTag, 'Lieferrunde: ' .. tostring(err)) end
    if not active then updateMarkers() end
    return
  end
  if o.kind ~= 'photo' and active.stage == 'deliver' then
    if not extensions.hashiriyaBattle_home.isResting() then active.left = active.left - (dtSim or dtReal or 0) end
    if active.left <= 0 then finish(false, 0, 'jobs.late') updateMarkers() return end
  end
  timer = timer - (dtReal or 0)
  if timer > 0 then return end
  timer = 0.5
  local ok, err = pcall(function()
    updateMarkers()
    local veh = c.getPlayerVehicle()
    if o.kind == 'photo' then
      local h = home().hour() or 0
      if h >= o.window[2] then finish(false, 0, 'jobs.photoMissed') return end
      local there
      if o.target.photoSpot then
        -- eigener Foto-Spot: Auto genau dort abstellen (Fahrer darf drin bleiben oder aussteigen)
        there = stoppedNear(veh, o.target.pos, cfg().photoSpotRadius, cfg().photoStopKmh)
        if not there and not veh then
          local okL, last = pcall(function() return c.carVehId and be:getObjectByID(c.carVehId) end)
          there = okL and last and stoppedNear(last, o.target.pos, cfg().photoSpotRadius, cfg().photoStopKmh) or false
        end
      else
        local w = c.getWalkerPos()
        there = (w and (w - toVec(o.target.pos)):length() < cfg().photoRadius) or stoppedNear(veh, o.target.pos, cfg().photoRadius, cfg().photoStopKmh)
      end
      if there then
        if h >= o.window[1] then photoTaken(c, o)
        elseif not active.early then active.early = true c.msg(c.t('jobs.photoEarly', string.format('%02d:00', o.window[1])), 5) end
      end
      return
    end
    if not veh then return end
    if active.stage == 'pickup' then
      if stoppedNear(veh, o.pickup.pos, cfg().arriveRadius, cfg().arriveKmh) then
        active.stage = 'deliver'
        active.left = o.seconds
        active.startDamage = damageYen()
        c.sound('jobPickup')
        c.msg(c.t('jobs.pickedUp', o.target.name, fmtTime(o.seconds)), 6)
        log('I', logTag, 'Ware abgeholt: ' .. o.id)
        updateMarkers()
      end
      return
    end
    local dmg = math.max(0, damageYen() - active.startDamage) * (t.damageFactor or 1)
    if t.failDamageYen and dmg >= t.failDamageYen then finish(false, 0, 'jobs.broken') return end
    if stoppedNear(veh, o.target.pos, cfg().arriveRadius, cfg().arriveKmh) then
      local pay = math.max(0, round100(o.pay - dmg))
      finish(true, pay, dmg > 0 and 'jobs.doneDamage' or 'jobs.done')
    end
  end)
  if not ok then log('E', logTag, 'Auftrag: ' .. tostring(err)) end
  if not active then updateMarkers() end
end

function M.reset()
  if active and active.offer.kind == 'taxi' then returnTaxi() end
  active = nil updateMarkers()
end

M.onUpdate = onUpdate
M.onClientEndMission = function()
  if M.jobVehId then local v = be:getObjectByID(M.jobVehId) if v then pcall(function() v:delete() end) end end
  M.jobVehId, pendingDelete = nil, nil
  active = nil shownGoal = nil clearRoute()
end

return M
