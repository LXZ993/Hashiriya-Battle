-- Hashiriya Battle: PA-Gespräche (Alpha 0.4).
-- An den Parkplätzen der Kartendatei (napSpots, z. B. Shibaura PA) stehen Fahrer neben ihren geparkten Autos.
-- Nachts mehr, tagsüber wenige. Zu Fuß hingehen, Taste "Reden" (Standard T): Sprechblase mit Name und Porträt.
-- Was sie sagen, hängt vom Fortschritt ab: Crew-Gerüchte ab dem passenden Rang, Leader-Gerüchte wenn die Crew fast
-- geschlagen ist, Hinweise auf Wanderer und Bosse (schaltet den Hinweis im Lexikon frei), wartende Rivalen, Smalltalk.
-- Dazu Wissen (kind fact, Alpha 0.4.1): echte Fakten über Japan, Tokio, den Shutoko und die Szene, oft als kleine
-- Geschichte über mehrere Sätze. Gefiltert nach Karte (map) und PA (place), jede Figur hat ihre eigenen Themen.
-- Alpha 0.5: Nachts stehen auch Rivalen und Wanderer neben ihrem eigenen Auto. Ansprechen = Spruch, dann Battle
-- verabreden (Taste Reden) oder Pink Slip (Taste "Reden: Pink Slip", Standard G). Er fährt vor und wartet auf dem C1.
-- Alpha 0.5.x: Er steigt sichtbar in sein Auto, startet den Motor, fährt langsam aus der PA und ist auf der Straße
-- ein normaler Rivale (Radar, Lichthupe). Klappt das nicht (kein Weg, hängt fest), wartet er wie früher vor dir.
-- Texte und Einstellungen: data/chat.json (speakers, talk, pa). Figuren = BeamNG-Fußgänger (Einrad mit Figur),
-- Porträts: art/portraits/npc/<sprecher>_<n>.svg.
local M = {}

local logTag = 'hashiriya.talk'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local chatPath = '/lua/ge/extensions/hashiriyaBattle/data/chat.json'
local up = vec3(0, 0, 1)

local function core() return extensions.hashiriyaBattle_core end
local function home() return extensions.hashiriyaBattle_home end
local function rivals() return extensions.hashiriyaBattle_rivals end
local function progress() return extensions.hashiriyaBattle_progress end

local chat = nil        -- chat.json
local speakerById = {}
local crowds = {}       -- [paIndex] = { key, npcs = { {speaker, variant, carId, figId, pos, dir, lines, talked} } }
local nearest = nil     -- Fahrer, mit dem man gerade reden kann
local convo = nil       -- laufendes Gespräch { npc, lines, index }
local checkTimer = 0
local lookTimer = 0
local pendingFace = {}  -- [figId] = { dir, tries }: Blickrichtung nach dem Spawnen setzen
local pending = nil     -- an der PA verabredetes Battle { rival, pink, paPos, night, tries, phase, carId, figId, entry }
-- phase: 'board' (geht zum Auto, steigt ein) -> 'start' (Motor an) -> 'leave' (fährt aus der PA)
--        -> 'road' (normaler Rivale auf der Straße) ; 'stuck' (wartet, bis du weg bist) ; 'wait' (alte Art: taucht vor dir auf)
local acceptBattle      -- weiter unten

-- Einstellungen ---------------------------------------------------------------------

local defaults = {
  nightCount = { 3, 6 }, dayCount = { 1, 2 }, spawnDistance = 230, despawnDistance = 330, spotRadius = 70,
  talkDistance = 2.8, lookDistance = 9, importantChance = 0.4, secondLineChance = 0.35, rankSlack = 1,
  heardWeight = 0.15, portraitVariants = 3, excludeConfigs = { 'police', 'race' },
  loreChance = 0.6, ownTopicWeight = 3, otherTopicWeight = 0.5, placeWeight = 3, moreChance = 0.5,
  rivalNight = { 0, 2 }, rivalDay = { 0, 0 }, rivalWaitDistance = 250, rivalWaitSpeed = 30,
  rivalWeightNew = 3, rivalWeightBeaten = 1, rivalWeightHolder = 6,
  rivalLeave = true, rivalBoardSeconds = 2.5, rivalLeaveKmh = 20, rivalLeaveTimeout = 90,
  rivalWaitCruiseKmh = 70, rivalCatchUpDistance = 250,
}

local function cfg()
  local p = chat and chat.pa or {}
  return setmetatable({}, { __index = function(_, k) if p[k] ~= nil then return p[k] end return defaults[k] end })
end

function M.loadData()
  chat = jsonReadFile(chatPath) or { speakers = {}, talk = {} }
  speakerById = {}
  for _, s in ipairs(chat.speakers or {}) do speakerById[s.id] = s end
end

local function loc(v) return progress().loc(v) end

-- Zufall mit festem Startwert: dieselbe PA zeigt in derselben Nacht dieselben Leute
local function seeded(seed)
  local x = math.floor(seed) % 2147483646 + 1
  return function()
    x = (x * 16807) % 2147483647
    return (x - 1) / 2147483646
  end
end

local function hashStr(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

local function pickWeighted(list, weightOf, rand)
  local total = 0
  for _, e in ipairs(list) do total = total + math.max(weightOf(e), 0) end
  if total <= 0 then return nil end
  local r = (rand or math.random)() * total
  for _, e in ipairs(list) do
    r = r - math.max(weightOf(e), 0)
    if r <= 0 then return e end
  end
  return list[#list]
end

-- PAs der Karte ---------------------------------------------------------------------

local function paList()
  local md = core().mapData
  return md and md.talkSpots or md and md.napSpots or {}
end

local function toVec(t) return vec3(t[1], t[2], t[3]) end

-- Zeitraum: Nacht n oder Tag n. Wechselt er, stellen sich andere Leute hin (aber nie vor deinen Augen).
local function periodKey()
  local h = home()
  if h.isNight() then return 'n' .. tostring(h.nightId()) end
  return 'd' .. tostring(h.getDay and h.getDay() or (core().save and core().save.day) or 1)
end

-- Freie Parkbuchten an der PA (aus den Parkplätzen der Map, wie beim BeamNG-Parkverkehr)
local function freeSpots(center, radius)
  local park = extensions.gameplay_parking
  if not park then
    extensions.load('gameplay_parking')
    park = extensions.gameplay_parking
  end
  if not park then return {} end
  if not extensions.gameplay_city then extensions.load('gameplay_city') end
  pcall(park.getParkingSpots) -- lädt die Sites der Map, falls noch nicht geschehen
  local ok, list = pcall(park.findParkingSpots, center, 0, radius)
  if not ok or type(list) ~= 'table' then return {} end
  local vehPos = {}
  for _, v in ipairs(getAllVehicles and getAllVehicles() or {}) do
    local okP, p = pcall(function() return v:getPosition() end)
    if okP and p then table.insert(vehPos, vec3(p)) end
  end
  local out = {}
  for _, e in ipairs(list) do
    local ps = e.ps
    if ps and ps.pos and not ps.vehicle then
      local free = true
      -- auch Fahrzeuge, die nur in die Bucht ragen (Parkverkehr, größere Autos nebenan)
      local okA, any = pcall(function() return ps:hasAnyVehicles() end)
      if okA and any then free = false end
      for _, p in ipairs(vehPos) do
        if (p - ps.pos):length() < 4 then free = false; break end
      end
      if free then table.insert(out, ps) end
    end
  end
  return out
end

-- Config fürs geparkte Auto: zufällig aus den Configs des Modells, ohne Polizei, Rennwagen usw.
local function pickConfig(model, match, rand)
  local ok, m = pcall(function() return core_vehicles.getModel(model) end)
  if not ok or not m or type(m.configs) ~= 'table' then return nil end
  local keys = {}
  for key in pairs(m.configs) do
    local k = tostring(key):lower()
    local good = true
    if match and match ~= '' then
      good = k:find(match:lower(), 1, true) ~= nil
    else
      for _, bad in ipairs(cfg().excludeConfigs or {}) do
        if k:find(tostring(bad):lower(), 1, true) then good = false; break end
      end
    end
    if good then table.insert(keys, key) end
  end
  if #keys == 0 then return nil end
  table.sort(keys)
  return keys[math.floor(rand() * #keys) + 1]
end

local function paintFromColor(c)
  c = type(c) == 'table' and c or { 0.6, 0.6, 0.6 }
  local ok, p = pcall(createVehiclePaint, { x = c[1] or 0.6, y = c[2] or 0.6, z = c[3] or 0.6, w = 1 })
  return ok and p or nil
end

local occupantFaces = nil
local function randomFace(rand)
  if occupantFaces == nil then
    local ok, mod = pcall(require, 'jbeam/sections/occupantFaces')
    occupantFaces = ok and mod or false
  end
  if not occupantFaces then return nil end
  local ok, opts = pcall(occupantFaces.getFaceOptions)
  if not ok or type(opts) ~= 'table' or #opts == 0 then return nil end
  return opts[math.floor(rand() * #opts) + 1].value
end

-- Blickrichtung der Figur: Die Figur dreht sich zur "Kamera" ihres Steuer-Controllers (playerController).
local function setFacing(figId, dir)
  local fig = be:getObjectByID(figId)
  if not fig or not dir then return false end
  local d = vec3(dir.x, dir.y, 0)
  if d:length() < 0.01 then return false end
  d = d:normalized()
  local q = quatFromDir(d, up)
  fig:queueLuaCommand(string.format(
    'if controller and controller.mainController and controller.mainController.setCameraControlData then controller.mainController.setCameraControlData({cameraRotation = quat(%f, %f, %f, %f)}) end',
    q.x, q.y, q.z, q.w))
  return true
end

-- Buchten, in denen unsere Autos stehen: für den BeamNG-Parkverkehr als belegt markiert (ps.vehicle),
-- damit er dort kein Auto hineinsetzt
local ourSpots = {}

local function deleteObj(id)
  local ps = id and ourSpots[id]
  if ps then
    if ps.vehicle == id then ps.vehicle = nil end
    ourSpots[id] = nil
  end
  local o = id and be:getObjectByID(id)
  if o then pcall(function() o:delete() end) end
end

local function despawnCrowd(i)
  local cr = crowds[i]
  if not cr then return end
  for _, n in ipairs(cr.npcs) do
    if convo and convo.npc == n then convo = nil end
    deleteObj(n.figId)
    deleteObj(n.carId)
    if n.rival then rivals().setReserved(n.rival.id, false) end
  end
  crowds[i] = nil
  nearest = nil
  log('I', logTag, 'PA-Fahrer entfernt (' .. tostring(cr.name) .. ')')
end

function M.despawnAll()
  for i in pairs(crowds) do despawnCrowd(i) end
  crowds, nearest, convo = {}, nil, nil
end

-- Spiel beendet / Spielstand gewechselt: Verabredung verfällt
local function dropPending()
  if not pending then return end
  -- Auto noch nicht als Rivale auf der Straße: mit wegräumen
  if pending.phase ~= 'road' then
    deleteObj(pending.figId)
    deleteObj(pending.carId)
  end
  rivals().setReserved(pending.rival.id, false)
  pending = nil
end

function M.clearPending() dropPending() end

-- Figur neben der Fahrertür (rechts, japanische Autos) oder frei auf dem Platz
-- Farbe der 3D-Figur = Oberteil-Farbe ihres Porträts (art/portraits/colors.json aus dem Porträt-Tool),
-- damit Bob und Porträt zusammenpassen. Ohne Eintrag: Farbe des Sprechers bzw. des Rivalen-Autos.
local portraitColors = nil
local function portraitColor(n)
  if portraitColors == nil then portraitColors = jsonReadFile('/art/portraits/colors.json') or false end
  if not portraitColors then return nil end
  local key
  if n.rival then
    if type(n.rival.portrait) == 'string' and n.rival.portrait ~= '' then return nil end -- eigenes Bild
    key = n.rival.baseId or n.rival.id
    if FS:fileExists('/art/portraits/' .. key .. '.png') or FS:fileExists('/art/portraits/' .. key .. '.jpg') then return nil end
  else
    key = tostring(n.speaker) .. '_' .. tostring(n.variant or 1)
  end
  local c = portraitColors[key]
  return type(c) == 'table' and c or nil
end

local function spawnFigure(n, pos, dir, rand)
  local s = speakerById[n.speaker] or {}
  local config = { model = 'unicycle', format = 2, parts = { unicycle_meshes = 'unicycle_character' } }
  local face = randomFace(rand)
  if face then config.parts.skin_character_face = face end
  local okH, h = pcall(function() return be:getSurfaceHeightBelow(pos + vec3(0, 0, 2)) end)
  if okH and h and h > -1e6 and math.abs(h - pos.z) < 3 then pos = vec3(pos.x, pos.y, h) end
  local opts = { config = config, pos = pos + vec3(0, 0, 0.1), rot = quatFromDir(dir, up), autoEnterVehicle = false,
    removeTraffic = false, canSpawnAnotherVehicleCheck = false, paint = paintFromColor(portraitColor(n) or n.color or s.color) }
  local ok, fig = pcall(core_vehicles.spawnNewVehicle, 'unicycle', opts)
  if not ok or not fig then
    log('W', logTag, 'Figur nicht gespawnt: ' .. tostring(fig))
    return nil
  end
  fig.playerUsable = false
  pendingFace[fig:getID()] = { dir = dir, tries = 6 }
  return fig:getID(), pos
end

-- Kennzeichen-Design (Plates Pack) für Autos ohne eigenes: zufällige Region, Taxis grün (gewerblich)
local function randomDesign(model, config, rand)
  local P = extensions.hashiriyaBattle_plates
  local regions = {}
  for _, r in ipairs(P.regions) do if not P.onlySpecial[r] then table.insert(regions, r) end end
  local region = regions[math.floor(rand() * #regions) + 1] or 'shinagawa'
  local name = (tostring(model) .. ' ' .. (type(config) == 'string' and config or '')):lower()
  local kind = (name:find('taxi', 1, true) or name:find('van', 1, true) or name:find('delivery', 1, true)) and 'commercial' or 'standard'
  return P.design(region, kind)
end

local function withPlateDesign(model, config, design, rand)
  local P = extensions.hashiriyaBattle_plates
  if type(config) == 'table' then
    for k, v in pairs(config.parts or {}) do
      if type(k) == 'string' and k:match(P.slot .. '$') and type(v) == 'string' and v:find('^am5jp_') then return config end
    end
  end
  design = design or randomDesign(model, config, rand)
  local src = config
  if type(config) == 'string' and not config:find('/', 1, true) then src = 'vehicles/' .. model .. '/' .. config .. '.pc' end
  if src == nil then return config end
  local ok, out = pcall(P.applyToConfig, src, design)
  if ok and type(out) == 'table' then
    -- Werkslack aus der info_*.json, wenn die .pc keinen hat (sonst käme das Auto in Standardfarbe)
    if not out.paints and type(src) == 'string' then
      local okP, paints = pcall(rivals().infoPaints, src)
      if okP and paints then out.paints = paints end
    end
    return out
  end
  return config
end

-- Autos eines PA-Fahrers, die es gerade gibt: Einträge mit config nur, wenn Modell und Config installiert sind
-- (z. B. Agent Traffic JP). fallback = true sind Ersatzautos, die nur kommen, wenn keins der anderen da ist.
local carCache = {}
local function speakerCars(s)
  if carCache[s.id] then return carCache[s.id] end
  local main, spare = {}, {}
  for _, car in ipairs(s.cars or {}) do
    local okM, m = pcall(function() return core_vehicles.getModel(car.model) end)
    local ok = okM and m and m.model ~= nil
    if ok and car.config then ok = type(m.configs) == 'table' and m.configs[car.config] ~= nil end
    if ok then table.insert(car.fallback and spare or main, car) end
  end
  carCache[s.id] = #main > 0 and main or spare
  return carCache[s.id]
end

-- Ausfahrt-Routen (Dev-Menü > Orte > PA-Ausfahrt aufnehmen, bzw. paExitRoutes in der Kartendatei), die an dieser PA beginnen
local function exitRoutesFor(center)
  local out = {}
  local reach = (cfg().spotRadius or 70) + 40
  for _, e in ipairs(core().spots('paexit')) do
    if type(e.points) == 'table' and #e.points >= 2 then
      local pts = {}
      for _, q in ipairs(e.points) do table.insert(pts, toVec(q)) end
      if (pts[1] - center):length() <= reach then table.insert(out, { name = e.name, points = pts }) end
    end
  end
  return out
end

-- nächster Routenpunkt zu pos (über alle Routen): Punkt, Index, Route
local function nearestRoutePoint(routes, pos)
  local best, bi, br = math.huge, nil, nil
  for _, r in ipairs(routes) do
    for i, q in ipairs(r.points) do
      local d = (q - pos):length()
      if d < best then best, bi, br = d, i, r end
    end
  end
  return br and br.points[bi] or nil, bi, br, best
end

-- forwardTo = Punkt, zu dem die Nase zeigen soll (Gasse): Rivalen stehen rückwärts eingeparkt (in Japan üblich)
local function spawnCar(model, config, ps, rand, paints, plate, design, forwardTo)
  config = withPlateDesign(model, config, design, rand)
  if not paints and type(config) == 'table' and type(config.paints) == 'table' and config.paints[1] then paints = config.paints end
  local opts = { pos = ps.pos, rot = ps.rot, autoEnterVehicle = false, removeTraffic = false,
    canSpawnAnotherVehicleCheck = false, licenseText = plate or extensions.hashiriyaBattle_plates.random(rand) }
  if config then opts.config = config end
  if paints then opts.paint, opts.paint2, opts.paint3 = paints[1], paints[2], paints[3] end
  local ok, veh = pcall(core_vehicles.spawnNewVehicle, model, opts)
  if not ok or not veh then
    log('W', logTag, 'PA-Auto nicht gespawnt: ' .. tostring(model) .. ' ' .. tostring(config) .. ' ' .. tostring(veh))
    return nil
  end
  local id = veh:getID()
  ps.vehicle = id -- Bucht für den Parkverkehr belegen
  ourSpots[id] = ps
  if plate then pcall(core_vehicles.setPlateText, plate, id) end
  veh.playerUsable = false -- nicht einsteigbar
  -- sauber in die Bucht stellen (wie der BeamNG-Parkverkehr), Motor aus, Bremse fest
  local backwards = rand() < 0.3
  if forwardTo then
    local fwd = ps.rot * vec3(0, 1, 0)
    backwards = vec3(fwd.x, fwd.y, 0):dot(vec3(forwardTo.x - ps.pos.x, forwardTo.y - ps.pos.y, 0)) < 0
  end
  pcall(function()
    ps:moveResetVehicleTo(id, false, backwards, nil, nil, true, false, nil, { skipVehicleIntersectionCheck = true })
  end)
  pcall(function() veh:queueLuaCommand('electrics.setIgnitionLevel(0)') end)
  core().freezeCar(veh, true)
  return id
end

-- Figur neben ihr Auto stellen: meist an die Fahrerseite (Rechtslenker), Blick vom Auto weg
-- Eigene Stehplätze (Dev-Menü Typ "PA-Fahrer-Stehplatz" bzw. standSpots in der Kartendatei), je PA
local standsFor = {}
local function buildStands(pa, center, radius)
  local list = {}
  for _, e in ipairs(core().spots('stand')) do
    local p = toVec(e.pos)
    if (p - center):length() <= radius + 20 then
      local d = type(e.dir) == 'table' and toVec(e.dir) or nil
      if d then d = vec3(d.x, d.y, 0) if d:length() > 0.01 then d = d:normalized() else d = nil end end
      table.insert(list, { pos = p, dir = d })
    end
  end
  standsFor[pa.name or ''] = list
  return list
end

-- freier Stehplatz: am nächsten zu pos (höchstens maxDist m weg), nil wenn keiner
local function takeStand(place, pos, maxDist)
  local best, bestD = nil, maxDist or math.huge
  for _, st in ipairs(standsFor[place or ''] or {}) do
    if not st.used then
      local d = pos and (st.pos - pos):length() or 0
      if d <= bestD then best, bestD = st, d end
    end
  end
  if best then best.used = true end
  return best
end

local function placeOnStand(n, st, rand, lookAt)
  local dir = st.dir
  if not dir and lookAt then dir = vec3(lookAt.x - st.pos.x, lookAt.y - st.pos.y, 0) end
  if not dir or dir:length() < 0.01 then dir = vec3(1, 0, 0) end
  dir = dir:normalized()
  n.figId, n.pos = spawnFigure(n, st.pos, dir, rand)
  n.dir = dir
end

local function placeBeside(n, ps, rand)
  local veh = be:getObjectByID(n.carId)
  -- gibt es gemerkte Stehplätze an dieser PA: den nächsten freien beim Auto nehmen
  local carPos = veh and vec3(veh:getPosition()) or ps.pos
  local st = takeStand(n.place, carPos, cfg().standMaxDistance or 15)
  if st then placeOnStand(n, st, rand, carPos) return end
  local fwd = veh and veh:getDirectionVector() or (ps.rot * vec3(0, 1, 0))
  fwd = vec3(fwd.x, fwd.y, 0):normalized()
  local right = fwd:cross(up):normalized()
  local okB, ext = pcall(function() return veh.initialNodePosBB:getExtents() end)
  local half = (okB and ext and ext.x or 1.8) / 2
  local side = rand() < 0.75 and 1 or -1
  local base = veh and veh:getPosition() or ps.pos
  local okC, ctr = pcall(function() return veh:getSpawnWorldOOBB():getCenter() end)
  if okC and ctr then base = vec3(ctr) end
  local pos = base + right * side * (half + 0.9) + fwd * (rand() * 1.2 - 0.3)
  -- schaut zur Seite vom Auto weg, leicht nach vorne (als würde er warten)
  local dir = (right * side + fwd * (rand() - 0.5)):normalized()
  n.figId, n.pos = spawnFigure(n, pos, dir, rand)
  n.dir = dir
end

-- Rivalen, die an dieser PA stehen könnten: wer heute auf der Straße auftauchen dürfte (ohne Bosse).
-- Wer dein Auto hat, steht am liebsten hier und zeigt es herum.
local function paRivalPool(save)
  local c = cfg()
  local pool = {}
  for _, r in ipairs((rivals().getData() or {}).rivals or {}) do
    if not r.boss and not (pending and pending.rival.id == r.id) and rivals().isEligible(r, save) then
      local w = save.defeated[r.id] and (c.rivalWeightBeaten or 1) or (c.rivalWeightNew or 3)
      if save.pinkHeld and save.pinkHeld[r.id] then w = c.rivalWeightHolder or 6 end
      table.insert(pool, { r = r, w = w })
    end
  end
  return pool
end

local function spawnRivalNpc(r, ps, rand, pa)
  local model, config, paints, plate = rivals().carFor(r)
  local n = { rival = r, speaker = 'rival', variant = 1, heard = {}, place = pa.name,
    color = type(r.paint) == 'table' and r.paint.color or nil }
  -- Nase zur Gasse: nächster Punkt der Ausfahrt-Route, sonst Richtung PA-Mitte
  local center = toVec(pa.pos)
  local q = nearestRoutePoint(exitRoutesFor(center), ps.pos)
  n.carId = spawnCar(model, config, ps, rand, paints, plate, r.plate and r.plate.design, q or center)
  if not n.carId then return nil end
  placeBeside(n, ps, rand)
  if not n.figId then
    deleteObj(n.carId)
    return nil
  end
  rivals().setReserved(r.id, true)
  return n
end

local function spawnCrowd(i, pa)
  local key = periodKey()
  local save = core().save
  local rand = seeded(hashStr(tostring(save and save.dealerSeed or 1) .. '|' .. key .. '|' .. tostring(pa.name or i)))
  local c = cfg()
  local night = home().isNight()
  local range = night and c.nightCount or c.dayCount
  local count = math.floor(range[1] + rand() * (range[2] - range[1] + 1))
  local center = toVec(pa.pos)
  -- spotRadius der PA (Kartendatei) für lange PAs mit eigenen Buchten (z. B. Oi PA), sonst wie bisher
  local spotR = tonumber(pa.spotRadius) or math.min(pa.radius or c.spotRadius, c.spotRadius)
  local spots = freeSpots(center, spotR)
  buildStands(pa, center, spotR)
  -- Buchten mischen (fest pro Nacht)
  for k = #spots, 2, -1 do
    local j = math.floor(rand() * k) + 1
    spots[k], spots[j] = spots[j], spots[k]
  end
  local cr = { key = key, name = pa.name, npcs = {} }
  crowds[i] = cr
  local used = {}
  local spotIdx = 1
  -- Rivalen und Wanderer zuerst (sie brauchen eine Bucht für ihr Auto)
  local rr = night and c.rivalNight or c.rivalDay
  local rcount = rr and math.floor(rr[1] + rand() * (rr[2] - rr[1] + 1)) or 0
  if rcount > 0 and save then
    local okPool, pool = pcall(paRivalPool, save)
    if not okPool then log('E', logTag, 'Rivalen für die PA: ' .. tostring(pool)); pool = {} end
    for _ = 1, rcount do
      local e = spots[spotIdx] and pickWeighted(pool, function(x) return x.w end, rand)
      if not e then break end
      e.w = 0
      local okR, n = pcall(spawnRivalNpc, e.r, spots[spotIdx], rand, pa)
      if not okR then log('E', logTag, 'Rivale an der PA nicht aufgestellt: ' .. tostring(n)); n = nil end
      if n then
        spotIdx = spotIdx + 1
        table.insert(cr.npcs, n)
        log('I', logTag, 'Rivale an ' .. tostring(pa.name) .. ': ' .. tostring(e.r.id))
      end
      local co, isMain = coroutine.running()
      if co and not isMain then coroutine.yield() end
      if crowds[i] ~= cr then return end
    end
  end
  for _ = 1, count do
    local pool = {}
    for _, s in ipairs(chat.speakers or {}) do
      if not used[s.id] and (night and (s.night or 1) or (s.day or 1)) > 0 then table.insert(pool, s) end
    end
    local s = pickWeighted(pool, function(e) return night and (e.night or 1) or (e.day or 1) end, rand)
    if not s then break end
    used[s.id] = true
    local n = { speaker = s.id, variant = math.floor(rand() * (c.portraitVariants or 3)) + 1, heard = {}, place = pa.name }
    local cars = speakerCars(s)
    if #cars > 0 and spots[spotIdx] then
      local ps = spots[spotIdx]
      spotIdx = spotIdx + 1
      local car = cars[math.floor(rand() * #cars) + 1]
      -- eigene Config (chat.json cars[].config = Name der .pc ohne Endung) geht vor, wenn es sie gibt
      local config = car.config
      config = config or pickConfig(car.model, car.match, rand)
      if not config and car.match then config = pickConfig(car.model, nil, rand) end
      n.carId = spawnCar(car.model, config, ps, rand)
      if n.carId then placeBeside(n, ps, rand) end
    end
    local free = (not n.carId and (#cars == 0 or #spots == 0)) and takeStand(pa.name, nil) or nil
    if free then
      -- ohne Auto: auf einen freien gemerkten Stehplatz
      placeOnStand(n, free, rand, center)
    elseif not n.carId and (#cars == 0 or #spots == 0) then
      -- ohne Auto (z. B. Parkwächter): irgendwo am Rand der PA-Mitte
      local a = rand() * math.pi * 2
      local pos = center + vec3(math.cos(a), math.sin(a), 0) * (4 + rand() * 6)
      local dir = (center - pos):normalized()
      n.figId, n.pos = spawnFigure(n, pos, dir, rand)
      n.dir = dir
    end
    if n.figId then
      table.insert(cr.npcs, n)
    else
      deleteObj(n.carId)
    end
    -- einer pro Takt, damit das Spiel beim Vorbeifahren nicht ruckelt (läuft als Coroutine)
    local co, isMain = coroutine.running()
    if co and not isMain then coroutine.yield() end
    if crowds[i] ~= cr then return end
  end
  if #spots == 0 then log('W', logTag, 'Keine freien Parkbuchten an ' .. tostring(pa.name) .. ' gefunden (Map ohne Parkplatz-Daten?), Fahrer stehen ohne Auto') end
  log('I', logTag, string.format('PA-Fahrer an %s: %d (%s, %d freie Buchten)', tostring(pa.name), #cr.npcs, key, #spots))
end

-- Was gesagt wird --------------------------------------------------------------------

local function talkHeard(save)
  save.talk = save.talk or { heard = {}, count = 0 }
  save.talk.heard = save.talk.heard or {}
  return save.talk
end

local function teamById(id)
  for _, t in ipairs((rivals().getData() or {}).teams or {}) do if t.id == id then return t end end
end
local function rivalById(id)
  for _, r in ipairs((rivals().getData() or {}).rivals or {}) do if r.id == id then return r end end
end

local function teamState(teamId, save)
  local total, beaten, leader = 0, 0, nil
  for _, r in ipairs((rivals().getData() or {}).rivals or {}) do
    if r.team == teamId then
      if r.leader then leader = r
      else
        total = total + 1
        if save.defeated[r.id] then beaten = beaten + 1 end
      end
    end
  end
  return total, beaten, leader
end

-- Rivale für die Vorlage "{name} sucht dich": wer heute fahren kann; Revanchen und Leute, die dich geschlagen haben, zuerst
local function waitingRival(save, rand)
  local list = {}
  for _, r in ipairs((rivals().getData() or {}).rivals or {}) do
    if not r.wanderer and not r.boss and rivals().isEligible(r, save) then
      local last = (save.lastBattle or {})[r.id]
      local w = 1
      if last and not last.won then w = 4 elseif save.defeated[r.id] then w = 2 end
      table.insert(list, { r = r, w = w })
    end
  end
  local e = pickWeighted(list, function(x) return x.w end, rand)
  return e and e.r or nil
end

-- Kandidaten mit Gewicht. important = Gerücht/Hinweis, sonst Smalltalk/Tipp.
local function candidates(n, save, important)
  local c = cfg()
  local heard = talkHeard(save).heard
  local rank = progress().rankIndex(save)
  local out = {}
  local function add(t, w, extra)
    if heard[t.id] then w = w * (c.heardWeight or 0) end
    if n.heard[t.id] then w = 0 end
    if w > 0 then table.insert(out, { t = t, w = w, extra = extra }) end
  end
  for _, t in ipairs(chat.talk or {}) do
    local k = t.kind
    if not important and (k == 'small' or k == 'tip') and t.speaker == n.speaker then
      add(t, k == 'tip' and (rank <= 2 and 1.5 or 0.7) or 1)
    elseif important and k == 'crew' then
      local team = teamById(t.about)
      local _, _, leader = teamState(t.about, save)
      if team and rank >= (team.minRank or 0) - (c.rankSlack or 1) and not (leader and save.defeated[leader.id]) then
        add(t, t.speaker == n.speaker and 2 or 1)
      end
    elseif important and k == 'leader' then
      local total, beaten, leader = teamState(t.about, save)
      if leader and not save.defeated[leader.id] and total > 0 and beaten >= math.max(total - 2, 1) then
        add(t, (t.speaker == n.speaker and 2 or 1) * 2)
      end
    elseif important and (k == 'wanderer' or k == 'boss') then
      local r = rivalById(t.about)
      local need = r and r.conditions and r.conditions.minRank or 0
      if r and not save.defeated[r.id] and rank >= need - (c.rankSlack or 1) then
        local known = save.knownHints and save.knownHints[r.id]
        add(t, (t.speaker == n.speaker and 2 or 1) * (known and 0.3 or 1.5) * (k == 'boss' and 0.7 or 1))
      end
    elseif important and k == 'waiting' and t.speaker == n.speaker and home().isNight() then
      add(t, 1.5)
    end
  end
  return out
end

-- Wissen (fact): nur für diese Karte (map) und diese PA (place = Teil des PA-Namens). Eigene Themen der Figur zuerst.
-- fresh = nur, was man noch nie gehört hat (fürs zweite Ansprechen).
local function factCandidates(n, save, fresh)
  local c = cfg()
  local heard = talkHeard(save).heard
  local level = core().levelName
  local place = string.lower(tostring(n.place or ''))
  local out = {}
  for _, t in ipairs(chat.talk or {}) do
    if t.kind == 'fact' and not n.heard[t.id] and (t.map == nil or t.map == level)
       and (t.place == nil or place:find(string.lower(t.place), 1, true) ~= nil)
       and not (fresh and heard[t.id]) then
      local w = t.speaker == n.speaker and (c.ownTopicWeight or 3) or (c.otherTopicWeight or 0.5)
      if t.place then w = w * (c.placeWeight or 3) end
      if heard[t.id] then w = w * (c.heardWeight or 0) end
      if w > 0 then table.insert(out, { t = t, w = w }) end
    end
  end
  return out
end

local function speakerName(n)
  if n.rival then
    local nick = loc(n.rival.nick or '')
    return n.rival.name .. (nick ~= '' and ('  "' .. nick .. '"') or '')
  end
  local s = speakerById[n.speaker]
  return s and loc(s.name) or ''
end

local function portraitOf(n)
  if n.rival then
    if type(n.rival.portrait) == 'string' and n.rival.portrait ~= '' then
      local p = '/' .. n.rival.portrait:gsub('^/', '')
      if FS:fileExists(p) then return p end
    end
    for _, ext in ipairs({ 'png', 'jpg', 'svg' }) do
      local p = '/art/portraits/' .. n.rival.id .. '.' .. ext
      if FS:fileExists(p) then return p end
    end
    return nil
  end
  local path = '/art/portraits/npc/' .. n.speaker .. '_' .. tostring(n.variant) .. '.svg'
  if FS:fileExists(path) then return path end
  path = '/art/portraits/npc/' .. n.speaker .. '_1.svg'
  return FS:fileExists(path) and path or nil
end

-- Zeilen für ein Gespräch zusammenstellen
local function rivalLines(n, save)
  local co = core()
  local r = n.rival
  local lines = {}
  local function say(text, extra)
    local l = { id = 'rival_' .. r.id, kind = 'rival', text = text }
    for k, v in pairs(extra or {}) do l[k] = v end
    table.insert(lines, l)
  end
  if n.talked then
    say(co.t('talk.rivalAgain'), { choice = true, pinkOk = n.pinkOk,
      pinkForced = n.pinkOk and not extensions.hashiriyaBattle_pinkslip.heldBy(r, save) and extensions.hashiriyaBattle_hardcore.rule('pinkSlipForced', save) or nil })
    return lines
  end
  local challenge = type(r.lines) == 'table' and loc(r.lines.challenge) or ''
  say(challenge ~= '' and challenge or co.t('talk.rivalHello'))
  local pk = extensions.hashiriyaBattle_pinkslip
  local held = pk.heldBy(r, save)
  if held then say(co.t('talk.pinkHeld', held.name or held.model)) end
  local pinkOk, why = pk.canOffer(r, save)
  n.pinkOk = pinkOk
  if pinkOk and not held and extensions.hashiriyaBattle_hardcore.rule('pinkSlipForced', save) then
    -- Hardcore: wer um Autos fährt, fährt nur um Autos
    say(co.t('hardcore.pinkForced'), { choice = true, pinkOk = true, pinkForced = true })
  elseif pinkOk then
    say(co.t(held and 'talk.rivalAskPinkBack' or 'talk.rivalAskPink'), { choice = true, pinkOk = true })
  else
    if why then say(co.t(why)) end
    say(co.t(save.defeated[r.id] and 'talk.rivalAskRematch' or 'talk.rivalAsk'), { choice = true })
  end
  return lines
end

local function buildLines(n, save)
  if n.rival then return rivalLines(n, save) end
  local c = cfg()
  local rand = math.random
  local lines = {}
  local function push(entry)
    local t = entry.t
    local text = loc(t.text)
    local about = nil
    if t.kind == 'waiting' then
      local r = waitingRival(save, rand)
      if not r then return false end
      text = text:gsub('{name}', r.name)
    elseif t.kind == 'wanderer' or t.kind == 'boss' then
      about = t.about
    end
    table.insert(lines, { id = t.id, kind = t.kind, text = text, hint = about, topic = t.topic })
    -- mehrteilige Geschichte: jeder weitere Satz ist eine eigene Sprechblase
    for k, more in ipairs(t.lines or {}) do
      table.insert(lines, { id = t.id, kind = t.kind, text = loc(more), topic = t.topic, part = k + 1 })
    end
    n.heard[t.id] = true
    return true
  end
  local function pushKind(kind)
    local list = {}
    for _, t in ipairs(chat.talk or {}) do
      if t.kind == kind and (t.speaker == '' or t.speaker == nil or t.speaker == n.speaker) then table.insert(list, t) end
    end
    local t = list[math.random(math.max(#list, 1))]
    if t then table.insert(lines, { id = t.id, kind = kind, text = loc(t.text) }) end
  end
  if n.talked then
    -- nochmal angesprochen: manchmal kennt er noch etwas, das du noch nie gehört hast
    local fresh = factCandidates(n, save, true)
    if #fresh > 0 and math.random() < (c.moreChance or 0.5) then
      pushKind('more')
      push(pickWeighted(fresh, function(e) return e.w end))
    else
      pushKind('again')
    end
    return lines
  end
  local imp = candidates(n, save, true)
  local small = candidates(n, save, false)
  local facts = factCandidates(n, save, false)
  local wantImportant = #imp > 0 and math.random() < (c.importantChance or 0.6)
  if wantImportant then
    -- manchmal erst ein Satz Smalltalk, dann das Gerücht
    if #small > 0 and math.random() < (c.secondLineChance or 0.35) then
      push(pickWeighted(small, function(e) return e.w end))
    end
    for _ = 1, 3 do
      local e = pickWeighted(imp, function(x) return x.w end)
      if e and push(e) then break end
    end
  end
  if #lines == 0 and #facts > 0 and math.random() < (c.loreChance or 0.5) then
    -- Wissen, manchmal mit einem Satz Smalltalk davor
    if #small > 0 and math.random() < (c.secondLineChance or 0.35) then
      push(pickWeighted(small, function(e) return e.w end))
    end
    push(pickWeighted(facts, function(e) return e.w end))
  end
  if #lines == 0 and #small > 0 then
    push(pickWeighted(small, function(e) return e.w end))
    if #imp > 0 and math.random() < (c.secondLineChance or 0.35) then
      local e = pickWeighted(imp, function(x) return x.w end)
      if e then push(e) end
    end
  end
  if #lines == 0 then
    -- nichts mehr Neues: irgendein Smalltalk dieser Figur, auch schon gehörter
    for _, t in ipairs(chat.talk or {}) do
      if t.kind == 'small' and t.speaker == n.speaker then table.insert(lines, { id = t.id, kind = 'small', text = loc(t.text) }); break end
    end
  end
  return lines
end

-- Gespräch --------------------------------------------------------------------------

local function showLine()
  if not convo then return end
  local line = convo.lines[convo.index]
  if not line then return end
  local save = core().save
  -- gehört: merken, Hinweis im Lexikon freischalten
  if save then
    local th = talkHeard(save)
    if not line.part then
      if line.kind == 'fact' and not th.heard[line.id] then th.facts = (th.facts or 0) + 1 end
      th.heard[line.id] = (th.heard[line.id] or 0) + 1
    end
    if line.hint and not (save.knownHints and save.knownHints[line.hint]) then
      home().learnHint(line.hint)
      th.hints = (th.hints or 0) + 1
      convo.newHint = true
      core().msg(core().t('msg.talkHint'), 5)
      core().sound('talkHint')
    end
  end
end

function M.startTalk(n)
  local save = core().save
  if not save or not n then return end
  local lines = buildLines(n, save)
  if #lines == 0 then return end
  convo = { npc = n, lines = lines, index = 1 }
  local th = talkHeard(save)
  th.count = (th.count or 0) + 1
  core().sound('talk')
  showLine()
  -- Figur schaut dich an
  local wpos = core().getWalkerPos()
  if wpos and n.figId and n.pos then setFacing(n.figId, wpos - n.pos) end
  core().sendUiState()
end

function M.endTalk()
  if not convo then return end
  local n = convo.npc
  n.talked = true
  convo = nil
  core().writeSave()
  core().sendUiState()
end

-- Battle an der PA verabreden: Figur und Auto verschwinden ("fährt schon mal vor"), er wartet auf dem C1
acceptBattle = function(n, pink)
  local c = core()
  local r = n.rival
  if not r then return end
  local copy = {}
  for k, v in pairs(r) do copy[k] = v end
  copy.paChallenge = true
  copy.pinkSlip = pink or nil
  local paPos = n.pos
  for _, cr in pairs(crowds) do
    for k, x in ipairs(cr.npcs) do
      if x == n then
        table.remove(cr.npcs, k)
        local pa = nil
        for _, p in ipairs(paList()) do if p.name == cr.name then pa = p end end
        if pa then paPos = toVec(pa.pos) end
        break
      end
    end
  end
  convo = nil
  nearest = nil
  rivals().setReserved(r.id, true) -- bis er auf der Straße ist
  pending = { rival = copy, pink = pink, paPos = paPos, place = n.place, night = home().nightId(), tries = 0, wait = 0 }
  local car = n.carId and be:getObjectByID(n.carId)
  if cfg().rivalLeave and car and n.figId then
    -- sichtbar einsteigen und losfahren
    pending.phase, pending.carId, pending.figId, pending.timer = 'board', n.carId, n.figId, cfg().rivalBoardSeconds
    pendingFace[n.figId] = nil
    local door = M.doorPoint(car)
    if door and n.pos then setFacing(n.figId, door - n.pos) end
  else
    deleteObj(n.figId)
    deleteObj(n.carId)
    pending.phase = 'wait'
  end
  c.sound('challenge')
  c.msg(c.t(pink and 'msg.paPinkAccepted' or 'msg.paBattleAccepted', r.name), 8)
  log('I', logTag, 'Battle an der PA verabredet: ' .. tostring(r.id) .. (pink and ' (Pink Slip)' or ''))
  c.writeSave()
  c.sendUiState()
end

-- Zweite Taste im Gespräch mit einem Rivalen: Pink Slip annehmen
function M.interactAlt()
  local c = core()
  if not c or not c.active or not convo then return end
  local line = convo.lines[convo.index]
  if line and line.choice and line.pinkOk then acceptBattle(convo.npc, true) end
end

function M.getPending() return pending end

-- Wo steigt er ein? Seite des Autos, auf der die Figur steht (meist rechts, Rechtslenker), auf Höhe der Tür
function M.doorPoint(car, figPos)
  if not car then return nil end
  local okC, ctr = pcall(function() return vec3(car:getSpawnWorldOOBB():getCenter()) end)
  local base = okC and ctr or vec3(car:getPosition())
  local fwd = car:getDirectionVector()
  fwd = vec3(fwd.x, fwd.y, 0)
  if fwd:length() < 0.01 then return base end
  fwd = fwd:normalized()
  local right = fwd:cross(up):normalized()
  local side = 1
  if figPos and (figPos - base):dot(right) < 0 then side = -1 end
  return base + right * side * 0.9 + fwd * 0.2
end

local function vehCmd(veh, cmd) pcall(function() veh:queueLuaCommand(cmd) end) end

-- Motor an, Licht nach Uhrzeit, Bremse los, BeamNG-KI fährt langsam (Verkehrsmodus) aus der PA
local function startEngine(car, r)
  vehCmd(car, 'electrics.setIgnitionLevel(3)')
  local lights = (r.lights == 'off' or not home().isNight()) and 0 or 1
  if r.lights == 'on' then lights = 1 end
  vehCmd(car, string.format('electrics.setLightsState(%d)', lights))
end

-- Fahrweg aus der Bucht: geradeaus raus (Nase zeigt zur Gasse), dann ab dem nächsten Routenpunkt vor ihm
-- die aufgenommene Route bis zum Ende. nil = keine Route an dieser PA.
local function buildExitPath(car, paPos)
  local routes = exitRoutesFor(paPos)
  if #routes == 0 then return nil end
  local okC, ctr = pcall(function() return vec3(car:getSpawnWorldOOBB():getCenter()) end)
  local p0 = okC and ctr or vec3(car:getPosition())
  local fwd = car:getDirectionVector()
  fwd = vec3(fwd.x, fwd.y, 0)
  fwd = fwd:length() > 0.01 and fwd:normalized() or vec3(0, 1, 0)
  local p1 = p0 + fwd * 4
  local _, k, route = nearestRoutePoint(routes, p1)
  if not route then return nil end
  local pts = route.points
  -- erster Routenpunkt, der weit genug weg ist (sonst lenkt er auf der Stelle ein)
  local j = k
  while j < #pts and (pts[j] - p1):length() < 7 do j = j + 1 end
  local path = { p0, p1 }
  for i = j, #pts do table.insert(path, pts[i]) end
  return path, route.name
end

-- Zeitplan für die Script-KI (BeamNG scriptai: Punkt + Zeit): langsam anrollen, dann rivalLeaveKmh
local function timedPath(path)
  local vmax = (cfg().rivalLeaveKmh or 25) / 3.6
  local out, t, s = {}, 0, 0
  for i, p in ipairs(path) do
    if i > 1 then
      local seg = (p - path[i - 1]):length()
      s = s + seg
      local v = math.min(vmax, 1.5 + s * 0.35)
      t = t + seg / v
    end
    table.insert(out, string.format('{x=%.3f,y=%.3f,z=%.3f,t=%.2f}', p.x, p.y, p.z, t + 0.5))
  end
  return '{' .. table.concat(out, ',') .. '}'
end

local function driveOut(car, path)
  vehCmd(car, 'electrics.setIgnitionLevel(2)')
  core().freezeCar(car, false)
  vehCmd(car, 'if input and input.event then input.event("parkingbrake", 0, 1) end')
  -- 'none' = kein Zurücksetzen an den Startpunkt (er steht ja schon dort)
  vehCmd(car, 'ai.startFollowing({path=' .. timedPath(path) .. '}, 0, 1, "none")')
end

-- Bucht freigeben, sobald er losfährt (sonst hält guardSpots sie weiter fest)
local function releaseSpot(id)
  local ps = id and ourSpots[id]
  if ps and ps.vehicle == id then ps.vehicle = nil end
  if id then ourSpots[id] = nil end
end

-- Auf die alte Art weitermachen: Auto weg (falls noch da), er taucht später vor dir auf
local function toWait(reason)
  if reason then log('I', logTag, 'PA-Rivale fährt nicht selbst raus (' .. reason .. '), wartet stattdessen vor dir: ' .. tostring(pending.rival.id)) end
  deleteObj(pending.figId)
  deleteObj(pending.carId)
  pending.figId, pending.carId, pending.entry = nil, nil, nil
  pending.phase, pending.wait, pending.tries = 'wait', 0, 0
  rivals().setReserved(pending.rival.id, true)
end

-- Verabredung einlösen
local function updatePending(dt, c, veh, wpos)
  if not pending then return end
  local h = home()
  local conf = cfg()
  local battleBusy = extensions.hashiriyaBattle_battle.isBusy()
  -- Battle gelaufen (battle.finishBattle löscht paChallenge auf genau dieser Kopie): erledigt
  if not pending.rival.paChallenge then
    if pending.phase ~= 'road' then deleteObj(pending.figId); deleteObj(pending.carId) end
    rivals().setReserved(pending.rival.id, false)
    pending = nil
    return
  end
  if (pending.night ~= h.nightId() or not h.isNight()) and not battleBusy then
    c.msg(c.t('msg.paBattleExpired', pending.rival.name), 5)
    dropPending()
    return
  end
  local ppos = wpos or (veh and veh:getPosition()) or nil
  local phase = pending.phase or 'wait'

  if phase == 'board' or phase == 'start' or phase == 'leave' or phase == 'stuck' then
    local car = pending.carId and be:getObjectByID(pending.carId)
    if not car then toWait('Auto weg') return end
    local carPos = vec3(car:getPosition())
    if phase == 'board' then
      pending.timer = pending.timer - dt
      local fig = pending.figId and be:getObjectByID(pending.figId)
      if fig then setFacing(pending.figId, carPos - vec3(fig:getPosition())) end
      if pending.timer <= 0 then
        -- eingestiegen: Figur weg, Zündung
        deleteObj(pending.figId)
        pending.figId = nil
        startEngine(car, pending.rival)
        pending.phase, pending.timer = 'start', 1.5
      end
    elseif phase == 'start' then
      pending.timer = pending.timer - dt
      if pending.timer <= 0 then
        local path, routeName = buildExitPath(car, pending.paPos)
        if not path then
          -- keine Ausfahrt-Route an dieser PA: Motor läuft, er wartet, bis du weg bist, dann vor dir auf dem C1
          log('W', logTag, 'Keine PA-Ausfahrt-Route bei ' .. tostring(pending.place) .. ' (Dev-Menü > Orte > PA-Ausfahrt aufnehmen)')
          pending.phase = 'stuck'
          return
        end
        releaseSpot(pending.carId)
        driveOut(car, path)
        pending.path = path
        pending.phase, pending.timer, pending.still, pending.startPos = 'leave', conf.rivalLeaveTimeout or 90, 0, carPos
        log('I', logTag, 'PA-Rivale fährt aus der PA: ' .. tostring(pending.rival.id) .. ' (Route ' .. tostring(routeName) .. ', ' .. #path .. ' Punkte)')
      end
    elseif phase == 'leave' then
      pending.timer = pending.timer - dt
      local v = vec3(car:getVelocity()):length()
      if v < 1 then pending.still = pending.still + dt else pending.still = 0 end
      -- am Ende der Route angekommen = auf der Fahrbahn
      local okC, ctr = pcall(function() return vec3(car:getSpawnWorldOOBB():getCenter()) end)
      local last = pending.path[#pending.path]
      local out = ((okC and ctr or carPos) - last):length() < 8
      if out then
        vehCmd(car, 'ai.scriptStop(false, false)')
        local entry = rivals().adoptVehicle(pending.rival, pending.carId)
        if entry then
          pending.phase, pending.entry, pending.catchUp = 'road', entry, nil
          rivals().setReserved(pending.rival.id, false)
          -- ab jetzt BeamNG-Verkehrs-KI auf der Fahrbahn, erstmal gemütlich, damit du hinterherkommst
          rivals().setCruise(car, pending.rival)
          vehCmd(car, string.format('ai.setSpeed(%f)', (conf.rivalWaitCruiseKmh or 70) / 3.6))
          log('I', logTag, 'PA-Rivale ist auf der Straße: ' .. tostring(pending.rival.id))
        else
          toWait('Übergabe an die Straße fehlgeschlagen')
        end
        return
      end
      if pending.still > 12 or pending.timer <= 0 then
        pending.phase = 'stuck'
        vehCmd(car, 'ai.scriptStop(true, true)')
        log('W', logTag, 'PA-Rivale kommt nicht aus der PA (kein Weg?): ' .. tostring(pending.rival.id))
      end
    elseif phase == 'stuck' then
      -- erst verschwinden lassen, wenn du ihn nicht mehr siehst
      if not ppos or (ppos - carPos):length() > 120 then toWait('hing fest') end
    end
    return
  end

  if phase == 'road' then
    local e = pending.entry
    -- Revanchen bekommen fürs Battle eine neue Datenkopie (rivals.challengeData): deren Flag zählt auch
    if e and e.data and not e.data.paChallenge then
      rivals().setReserved(pending.rival.id, false)
      pending = nil
      return
    end
    local car = e and be:getObjectByID(e.vehId)
    local still = false
    for _, x in ipairs(rivals().getOnRoad()) do if x == e then still = true end end
    if not car or not still then
      -- zu weit weg verschwunden o. ä., bevor ihr gefahren seid: wartet dann vor dir
      if battleBusy then return end
      pending.carId = nil
      toWait('auf der Straße verloren')
      return
    end
    -- Du bist nah genug dran: normales Reisetempo
    if not pending.catchUp and veh and not wpos and (vec3(car:getPosition()) - veh:getPosition()):length() < (conf.rivalCatchUpDistance or 250) then
      pending.catchUp = true
      rivals().setCruise(car, e.data)
    end
    return
  end

  -- phase 'wait': Bist du mit dem Auto weit genug von der PA weg und schnell genug, taucht er vor dir auf
  if wpos or not veh or battleBusy then return end
  pending.wait = pending.wait - dt
  if pending.wait > 0 then return end
  local far = (veh:getPosition() - pending.paPos):length() > (conf.rivalWaitDistance or 250)
  local fast = veh:getVelocity():length() * 3.6 > (conf.rivalWaitSpeed or 30)
  if not far or not fast or extensions.hashiriyaBattle_parking.getCurrent() then return end
  rivals().setReserved(pending.rival.id, false)
  local ok, entry = pcall(rivals().spawnNext, true, pending.rival)
  if ok and entry then
    c.msg(c.t(pending.pink and 'msg.paPinkWaiting' or 'msg.paBattleWaiting', pending.rival.name), 8)
    pending.phase, pending.entry, pending.catchUp = 'road', entry, true
    return
  end
  rivals().setReserved(pending.rival.id, true)
  pending.tries = pending.tries + 1
  pending.wait = 2
  if pending.tries >= 15 then
    log('W', logTag, 'Verabredeter Rivale fand keinen Platz auf der Straße: ' .. tostring(pending.rival.id))
    c.msg(c.t('msg.paBattleExpired', pending.rival.name), 5)
    dropPending()
  end
end

-- Taste "Reden": ansprechen, nächster Satz, beenden
function M.interact()
  local c = core()
  if not c or not c.active then return end
  -- Story-Szene oder Kapitelkarte (story.lua) geht vor
  local st = extensions.hashiriyaBattle_story
  if st and st.isShowing() and st.interact() then return end
  if convo then
    local line = convo.lines[convo.index]
    if line and line.choice then
      acceptBattle(convo.npc, line.pinkForced and true or false) -- Hardcore: Pink Slip Pflicht
      return
    end
    convo.index = convo.index + 1
    if convo.index > #convo.lines then M.endTalk() else
      c.sound('talk')
      showLine()
      c.sendUiState()
    end
    return
  end
  if nearest then M.startTalk(nearest) return end
  -- Kein Fahrer in der Nähe: Schwarzes Brett am PA-Aushang lesen (board.lua)
  local bd = extensions.hashiriyaBattle_board
  if bd and bd.interact then pcall(bd.interact) end
end

function M.isTalking() return convo ~= nil end

-- UI-Daten für die Sprechblase (HashiriyaTalk)
function M.getHudState()
  local c = core()
  if convo then
    local line = convo.lines[convo.index]
    if not line then return nil end
    local last = convo.index >= #convo.lines
    local tag = line.hint and 'hint' or (line.kind == 'fact' and 'fact' or 'npc')
    if convo.npc.rival then tag = rivals().markerKind(convo.npc.rival) end
    local nextText = c.t(last and 'talk.end' or 'talk.next')
    local alt = nil
    if line.choice then
      nextText = c.t(line.pinkForced and 'talk.acceptPink' or 'talk.accept')
      if line.pinkOk and not line.pinkForced then alt = { key = M.keyName('hashiriyaTalkAlt'), text = c.t('talk.acceptPink') } end
    end
    return {
      talk = { text = line.text, name = speakerName(convo.npc), portrait = portraitOf(convo.npc), side = 'left', kind = 'pa',
        logo = convo.npc.rival and extensions.hashiriyaBattle_rivals.logoOf and extensions.hashiriyaBattle_rivals.logoOf(convo.npc.rival, true) or nil,
        tag = tag, step = convo.index, steps = #convo.lines,
        topic = line.topic and c.t('talk.topic.' .. line.topic) or nil,
        key = M.keyName(), next = nextText, alt = alt, decline = line.choice and c.t('talk.declineHint') or nil,
        hint = line.hint and c.t('talk.hintLearned') or nil },
    }
  end
  if nearest then
    return { prompt = { name = speakerName(nearest), key = M.keyName(), text = c.t(nearest.rival and 'talk.promptRival' or 'talk.prompt'),
      again = nearest.talked or nil, rival = nearest.rival and rivals().markerKind(nearest.rival) or nil } }
  end
  return nil
end

-- Name der Taste fürs Reden (aus der Tastenbelegung)
local keyCache = {}
function M.keyName(action)
  action = action or 'hashiriyaTalk'
  local kc = keyCache[action]
  if kc and os.clock() - kc.t < 5 then return kc.name end
  local name = action == 'hashiriyaTalk' and 'T' or 'G'
  local ok, found = pcall(function() return extensions.hashiriyaBattle_career.keyFor(action) end)
  if ok and found then name = found end
  keyCache[action] = { name = name, t = os.clock() }
  return name
end

-- Laufend ---------------------------------------------------------------------------

-- Parkverkehr, der trotzdem in einer unserer Buchten landet (z. B. gleichzeitig gespawnt): wegschicken
local spotGuardTimer = 1
local function guardSpots(dtReal)
  spotGuardTimer = spotGuardTimer - dtReal
  if spotGuardTimer > 0 then return end
  spotGuardTimer = 1
  if not next(ourSpots) then return end
  local park = extensions.gameplay_parking
  local parked = {}
  for _, id in ipairs(park and park.getParkedCarsList and park.getParkedCarsList() or {}) do parked[id] = true end
  local player = core().getPlayerVehicle()
  local playerId = player and player:getID()
  for id, ps in pairs(ourSpots) do
    if not be:getObjectByID(id) then
      if ps.vehicle == id then ps.vehicle = nil end
      ourSpots[id] = nil
    else
      if not ps.vehicle then ps.vehicle = id end
      local ok, any, ids = pcall(function() return ps:hasAnyVehicles(id) end)
      if ok and any then
        for _, other in ipairs(ids or {}) do
          local o = be:getObjectByID(other)
          local leaving = pending and pending.carId == other
          if other ~= playerId and not leaving and not ourSpots[other] and o and o:getJBeamFilename() ~= 'unicycle' then
            if parked[other] and park.forceTeleport then
              pcall(park.forceTeleport, other, nil, 80, 400)
              log('I', logTag, 'Parkverkehr aus einer PA-Bucht weggestellt: ' .. tostring(other))
            elseif vec3(o:getVelocity()):length() < 0.5 then
              -- fremdes stehendes Auto (anderer Parkverkehr): ausblenden statt ineinander stecken lassen
              pcall(function() o:setActive(0) end)
              log('I', logTag, 'Stehendes Auto in einer PA-Bucht ausgeblendet: ' .. tostring(other))
            end
          end
        end
      end
    end
  end
end

local function onUpdate(dtReal)
  local c = core()
  if not c or not c.active or not c.save then
    if next(crowds) then M.despawnAll() end
    return
  end
  if not chat then M.loadData() end
  pcall(guardSpots, dtReal)

  -- Blickrichtung nachreichen (Controller ist erst nach dem Spawnen bereit)
  for id, p in pairs(pendingFace) do
    p.wait = (p.wait or 0.6) - dtReal
    if p.wait <= 0 then
      setFacing(id, p.dir)
      p.tries = p.tries - 1
      p.wait = 0.5
      if p.tries <= 0 then pendingFace[id] = nil end
    end
  end

  checkTimer = checkTimer - dtReal
  if checkTimer > 0 then return end
  checkTimer = 0.25
  local conf = cfg()
  local wpos = c.getWalkerPos()
  local veh = c.getPlayerVehicle()
  local ppos = wpos or (veh and veh:getPosition()) or nil
  if not ppos then return end
  local okU, errU = pcall(updatePending, 0.25, c, veh, wpos)
  if not okU then log('E', logTag, 'PA-Verabredung: ' .. tostring(errU)) end
  local busy = extensions.hashiriyaBattle_battle.isBusy()

  -- Leute an den PAs auf- und abbauen
  for i, pa in ipairs(paList()) do
    local d = (ppos - toVec(pa.pos)):length()
    local cr = crowds[i]
    if cr and (d > conf.despawnDistance or (cr.key ~= periodKey() and d > conf.spawnDistance)) then
      despawnCrowd(i)
      cr = nil
    end
    if cr and cr.job then
      local ok, err = coroutine.resume(cr.job)
      if not ok then log('E', logTag, 'PA-Fahrer aufstellen fehlgeschlagen: ' .. tostring(err)) end
      if coroutine.status(cr.job) == 'dead' then cr.job = nil end
    elseif not cr and d < conf.spawnDistance and not busy then
      local job = coroutine.create(spawnCrowd)
      local ok, err = coroutine.resume(job, i, pa)
      if not ok then log('E', logTag, 'PA-Fahrer aufstellen fehlgeschlagen: ' .. tostring(err)) end
      if crowds[i] and coroutine.status(job) ~= 'dead' then crowds[i].job = job end
    end
  end

  -- Wer steht nah genug? Fahrer drehen sich zu dir, wenn du zu Fuß näher kommst.
  nearest = nil
  if wpos then
    local best = conf.talkDistance
    lookTimer = lookTimer - 0.25
    for _, cr in pairs(crowds) do
      for _, n in ipairs(cr.npcs) do
        local fig = n.figId and be:getObjectByID(n.figId)
        if fig then
          local okP, fp = pcall(function() return vec3(fig:getPositionXYZ()) end)
          if okP and fp then n.pos = fp end
          local d = (wpos - n.pos):length()
          if d < best then best, nearest = d, n end
          if lookTimer <= 0 and d < conf.lookDistance then setFacing(n.figId, wpos - n.pos)
          elseif lookTimer <= 0 and n.looking and d >= conf.lookDistance then setFacing(n.figId, n.dir) end
          if lookTimer <= 0 then n.looking = d < conf.lookDistance end
        end
      end
    end
    if lookTimer <= 0 then lookTimer = 0.75 end
  end
  -- Weggehen oder einsteigen beendet das Gespräch
  if convo then
    local n = convo.npc
    if not wpos or not n.pos or (wpos - n.pos):length() > conf.talkDistance + 2.5 then M.endTalk() end
  end
end

local function onClientEndMission() M.despawnAll(); pending = nil; carCache = {} end
local function onExtensionUnloaded() M.despawnAll() end

-- Entwickler: Leute neu aufstellen
function M.respawn()
  M.loadData()
  M.despawnAll()
  checkTimer = 0
end

M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission
M.onExtensionUnloaded = onExtensionUnloaded

return M
