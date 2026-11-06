-- Hashiriya Battle: Kern (Spielstand, Start, Menüs)
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local dataDir = '/lua/ge/extensions/hashiriyaBattle/data/'
local saveDir = 'settings/hashiriya_battle/'
-- Bis zu drei Spielstände (Plätze): Platz 1 = save.json (alte Spielstände bleiben so erhalten),
-- Platz 2 = save_2.json, Platz 3 = save_3.json. Welcher Platz gerade läuft, steht in slots.json.
M.maxSlots = 3
local slotsPath = saveDir .. 'slots.json'
local currentSlot = nil
local function slotFile(n) return saveDir .. (n == 1 and 'save.json' or ('save_' .. n .. '.json')) end
local function readSlotState()
  if currentSlot then return currentSlot end
  local d = jsonReadFile(slotsPath)
  local n = type(d) == 'table' and tonumber(d.active) or 1
  currentSlot = (n and n >= 1 and n <= M.maxSlots) and math.floor(n) or 1
  return currentSlot
end
local function savePath() return slotFile(readSlotState()) end
local capturePath = saveDir .. 'captured_positions.json'

local subExtensions = { 'hashiriyaBattle_logger', 'hashiriyaBattle_plates', 'hashiriyaBattle_economy', 'hashiriyaBattle_rivals', 'hashiriyaBattle_driver', 'hashiriyaBattle_battle', 'hashiriyaBattle_parking', 'hashiriyaBattle_shop', 'hashiriyaBattle_setup', 'hashiriyaBattle_career', 'hashiriyaBattle_home', 'hashiriyaBattle_fuel', 'hashiriyaBattle_dealer', 'hashiriyaBattle_progress', 'hashiriyaBattle_style', 'hashiriyaBattle_condition', 'hashiriyaBattle_damage', 'hashiriyaBattle_release', 'hashiriyaBattle_talk', 'hashiriyaBattle_pinkslip', 'hashiriyaBattle_music', 'hashiriyaBattle_story', 'hashiriyaBattle_jobs', 'hashiriyaBattle_savepoint', 'hashiriyaBattle_unstuck', 'hashiriyaBattle_logos', 'hashiriyaBattle_maintenance', 'hashiriyaBattle_crew', 'hashiriyaBattle_board', 'hashiriyaBattle_aura', 'hashiriyaBattle_stickers', 'hashiriyaBattle_police', 'hashiriyaBattle_travel', 'hashiriyaBattle_hardcore' }

M.active = false -- läuft der Modus gerade?
M.save = nil
M.carsData = nil
M.mapData = nil
M.levelName = nil

local showMenu = true
local showDealer = false   -- Autohändler (aus dem Menü links)
local showStats = false    -- Statistik (aus dem Menü links)
local showLexicon = false  -- Rivalen-Lexikon (aus dem Menü links, überall)
local showLogos = false    -- Logo-Sammlung (aus dem Menü links, überall)
local showJobs = false     -- Jobbrett (Nebenjobs und Tipps, Alpha 0.7; Garage und Zuhause)
local showBoard = false    -- Schwarzes Brett am PA-Aushang (board.lua; im Garagen-PC ist es ein Reiter im Terminal)
local homeTab = 'main'     -- Zuhause: main | lexicon
local showCarSelect = false
local platePriceYen = 15000 -- Kennzeichen ummelden
local garageTab = 'service' -- Garage-Reiter: service, parts, setup
local menuAutoOpened = false -- Menü wurde vom Parkplatz geöffnet und schließt sich beim Wegfahren

-- Hilfsfunktionen -----------------------------------------------------------

-- Sounds ---------------------------------------------------------------------
-- Vorerst BeamNG-eigene Sounds (data/sounds.json): Name -> FMOD-Event.

local soundData = nil
local lastMsgKey = nil -- zuletzt übersetzte Meldung (msg.*), für den Sound zur Meldung

function M.sound(name)
  soundData = soundData or jsonReadFile(dataDir .. 'sounds.json') or { events = {}, messages = {} }
  local ev = soundData.events[name] or (tostring(name):match('^event:') and name)
  if ev then pcall(function() Engine.Audio.playOnce('AudioGui', ev) end) end
end

local function msg(text, ttl)
  local key = lastMsgKey
  lastMsgKey = nil
  if key then
    soundData = soundData or jsonReadFile(dataDir .. 'sounds.json') or { events = {}, messages = {} }
    if soundData.messages[key] then M.sound(soundData.messages[key]) end
  end
  if ui_message then
    ui_message(text, ttl or 4, 'hashiriya', 'flag')
  else
    guihooks.trigger('Message', { ttl = ttl or 4, msg = text, category = 'hashiriya', icon = 'flag' })
  end
end
M.msg = msg

-- Sprache -------------------------------------------------------------------
-- Texte liegen in data/lang/<sprache>.json; fehlende Schlüssel kommen aus en.json.
-- Die Sprache kommt aus der BeamNG-Einstellung bzw. von der UI (setLanguage).

M.lang = nil
M.strings = {}

local function loadLanguage(code)
  local short = tostring(code or ''):sub(1, 2):lower()
  local strings = {}
  for k, v in pairs(jsonReadFile(dataDir .. 'lang/en.json') or {}) do strings[k] = v end
  local own = short ~= '' and jsonReadFile(dataDir .. 'lang/' .. short .. '.json') or nil
  if own then
    for k, v in pairs(own) do strings[k] = v end
  end
  M.lang = own and short or 'en'
  M.strings = strings
  log('I', logTag, 'Sprache: ' .. M.lang)
end

local function detectLanguage()
  local ok, v = pcall(function() return settings.getValue('userLanguage') end)
  if ok and type(v) == 'string' and v ~= '' then return v end
  return 'en'
end

-- Übersetzter Text, optional mit string.format-Parametern.
function M.t(key, ...)
  if type(key) == 'string' and key:sub(1, 4) == 'msg.' then lastMsgKey = key end
  local s = M.strings[key] or key
  if select('#', ...) > 0 then return string.format(s, ...) end
  return s
end

-- Wird von den UI-Apps mit der aktuellen Spielsprache aufgerufen (z. B. "de-DE").
function M.setLanguage(code)
  local short = tostring(code or ''):sub(1, 2):lower()
  if short ~= '' and short ~= M.lang then loadLanguage(short) end
end

local function getLevelName()
  if getCurrentLevelIdentifier then return getCurrentLevelIdentifier() end
  local mission = getMissionFilename and getMissionFilename() or ''
  return mission:match('levels/([^/]+)/')
end

-- Das Auto, in dem der Spieler sitzt. Zu Fuß (Einrad von BeamNG) gibt es keins.
-- Aufkleber-Reiter in der Garage offen? (stickers.lua beendet den Sticker-Modus, sobald nicht mehr)
function M.stickerTabOpen()
  local area = M.active and extensions.hashiriyaBattle_parking.isArrived() and extensions.hashiriyaBattle_parking.getCurrent() or nil
  return garageTab == 'stickers' and area ~= nil and area.type == 'garage' or false
end

function M.getPlayerVehicle()
  local veh = getPlayerVehicle and getPlayerVehicle(0) or be:getPlayerVehicle(0)
  if veh and veh:getJBeamFilename() == 'unicycle' then return nil end
  -- Firmentaxi der Taxischicht (jobs.lua) ist nicht "dein Auto": kein Tank, Schaden, Zustand, Shop, Battle dafür
  local jv = extensions.hashiriyaBattle_jobs and extensions.hashiriyaBattle_jobs.jobVehId
  if veh and jv and veh:getID() == jv then return nil end
  return veh
end

local function walk()
  return extensions.gameplay_walk or (extensions.load('gameplay_walk') and extensions.gameplay_walk)
end

function M.isWalking()
  local w = walk()
  local ok, res = pcall(function() return w and w.isWalking() end)
  return ok and res or false
end

-- Aktuelle Position der Spielfigur. getPosition() liefert beim Einrad die Spawn-Stelle; die Walk-Erweiterung
-- selbst liest getPositionXYZ(). Liegt die Kamera (Ego-Sicht) weit weg, zählt die Kamera, auf den Boden gesetzt.
local function walkerPosition(veh)
  local pos
  local ok, x, y, z = pcall(function() return veh:getPositionXYZ() end)
  if ok and x then pos = vec3(x, y, z) else pos = veh:getPosition() end
  local okC, cam = pcall(core_camera.getPosition)
  if okC and cam and (vec3(cam) - pos):length() > 5 then
    local ground = cam.z - 1.7
    local okH, h = pcall(function() return be:getSurfaceHeightBelow(vec3(cam.x, cam.y, cam.z + 0.5)) end)
    if okH and h and h > -1e6 and cam.z - h < 4 then ground = h end
    pos = vec3(cam.x, cam.y, ground)
  end
  return pos
end
M.walkerPosition = walkerPosition

-- Position des Spielers zu Fuß (nil, wenn er im Auto sitzt)
function M.getWalkerPos()
  local veh = getPlayerVehicle and getPlayerVehicle(0) or be:getPlayerVehicle(0)
  if veh and veh:getJBeamFilename() == 'unicycle' then return walkerPosition(veh) end
  return nil
end

-- Spieler steigt aus und steht zu Fuß am Startpunkt neben der Garage; das Auto bleibt in der Bucht.
function M.goOnFoot(carVeh, pos, rot)
  if not pos then pos, rot = extensions.hashiriyaBattle_parking.footSpawnTransform() end
  local w = walk()
  if not w or not pos then return end
  if carVeh then M.carVehId = carVeh:getID() end
  local ok, err = pcall(w.setWalkingMode, true, pos, rot, true)
  if not ok then log('W', logTag, 'Zu Fuß starten fehlgeschlagen: ' .. tostring(err)) end
end

-- Zu Fuß am Shop-Eingang: fürs Menü ins Auto in der Bucht setzen (Teile-Vorschau braucht das Auto).
function M.enterCarForShop(carVeh)
  local w = walk()
  local ok = w and w.getInVehicle and pcall(w.getInVehicle, carVeh)
  if not ok then pcall(function() be:enterVehicle(0, carVeh) end) end
  M.freezeCar(carVeh, true)
end

-- Auto im Shop festhalten: man sitzt nur fürs Menü darin und soll nicht wegfahren können
function M.freezeCar(veh, on)
  if not veh then return end
  veh:queueLuaCommand(string.format('if controller and controller.setFreeze then controller.setFreeze(%d) end', on and 1 or 0))
end

function M.economy() return extensions.hashiriyaBattle_economy end

-- Spielstand ----------------------------------------------------------------

function M.startMoney()
  return M.carsData and M.carsData.startMoneyYen or 4500000
end

local function newSave()
  return {
    version = 1,
    money = M.startMoney(),
    cars = {},
    activeCar = nil,
    defeated = {},
    defeatedNight = {},
    rep = 0,
    stats = {},
    wins = 0,
    losses = 0,
    day = 1,
    dealerSeed = math.random(1, 1000000),
  }
end

function M.writeSave()
  if not M.save then return end
  local hour = extensions.hashiriyaBattle_home and extensions.hashiriyaBattle_home.hour()
  if hour then M.save.hour = hour end
  M.save.savedAt = os.time()
  jsonWriteFile(savePath(), M.save, true)
  M.hasSave = true
  log('I', logTag, 'Spielstand gespeichert')
end

local function readSlot(n)
  if not FS:fileExists(slotFile(n)) then return nil end
  local data = jsonReadFile(slotFile(n))
  if type(data) == 'table' and data.version then return data end
  return nil
end
local function readSave() return readSlot(readSlotState()) end

-- Spielstand-Plätze ------------------------------------------------------------

function M.currentSlot() return readSlotState() end
function M.savePath() return savePath() end
M.readSlot = readSlot

local function anySave()
  for n = 1, M.maxSlots do if readSlot(n) then return true end end
  return false
end

-- Zuletzt gespielter Platz: der aktive, falls belegt, sonst der mit dem jüngsten Speicherzeitpunkt
function M.lastSlot()
  local cur = readSlotState()
  if readSlot(cur) then return cur end
  local best, bestAt = nil, -1
  for n = 1, M.maxSlots do
    local d = readSlot(n)
    if d and (tonumber(d.savedAt) or 0) > bestAt then best, bestAt = n, tonumber(d.savedAt) or 0 end
  end
  return best
end

-- Spielstand ohne Platzwahl (Titel "Weiterspielen")
function M.peekSave()
  local n = M.lastSlot()
  return n and readSlot(n) or nil, n
end

-- Platz wechseln. Läuft gerade ein anderer Spielstand, wird er vorher sauber gespeichert und beendet.
function M.setSlot(n)
  n = tonumber(n)
  if not n or n < 1 or n > M.maxSlots then return false end
  n = math.floor(n)
  if n ~= readSlotState() and M.active and M.save then
    local ok, err = pcall(M.stopGame)
    if not ok then log('W', logTag, 'Spielstand wechseln: ' .. tostring(err)) end
  end
  currentSlot = n
  jsonWriteFile(slotsPath, { active = n }, true)
  log('I', logTag, 'Spielstand-Platz ' .. n)
  return true
end

-- Schadensdateien (damage/<uid>.json) der Autos eines Spielstands entfernen
local function clearSlotDamage(data)
  for _, car in ipairs(type(data) == 'table' and data.cars or {}) do
    if car.uid then
      local f = 'settings/hashiriya_battle/damage/' .. tostring(car.uid) .. '.json'
      if FS:fileExists(f) then pcall(function() FS:removeFile(f) end) end
    end
  end
end

-- Platz löschen. Der Spielstand, der gerade läuft, lässt sich nicht löschen.
function M.deleteSlot(n)
  n = tonumber(n)
  if not n or n < 1 or n > M.maxSlots then return false end
  if M.active and M.save and n == readSlotState() then return false end
  local data = readSlot(n)
  if not data and not FS:fileExists(slotFile(n)) then return false end
  clearSlotDamage(data)
  pcall(function() FS:removeFile(slotFile(n)) end)
  M.hasSave = anySave()
  log('I', logTag, 'Spielstand-Platz ' .. n .. ' gelöscht')
  return true
end

-- Übersicht für den Titelbildschirm
function M.slotList()
  local eco = M.economy()
  local pr = extensions.hashiriyaBattle_progress
  local out = {}
  for n = 1, M.maxSlots do
    local d = readSlot(n)
    local e = { slot = n, empty = d == nil, running = M.active and M.save ~= nil and n == readSlotState() }
    if d then
      local car = d.cars and d.cars[d.activeCar or 1]
      e.name = d.playerName or '—'
      e.car = car and car.name or ''
      e.money = eco.formatYen(d.money or 0)
      e.day = d.day or 1
      e.cars = #(d.cars or {})
      e.gameOver = d.gameOver and true or nil
      e.hardcore = d.hardcore and true or nil
      local okR, rank = pcall(function() return pr.rankName(d) end)
      e.rank = okR and rank or nil
      e.savedAt = d.savedAt and os.date('%d.%m.%Y %H:%M', d.savedAt) or nil
    end
    table.insert(out, e)
  end
  return out
end

-- Daten laden ---------------------------------------------------------------

local function loadData()
  M.carsData = jsonReadFile(dataDir .. 'cars.json') or { starterCars = {} }
  M.buildData = jsonReadFile(dataDir .. 'build.json') or {}
  M.levelName = getLevelName()
  M.hasSave = anySave()
  M.mapData = M.levelName and jsonReadFile(dataDir .. 'maps/' .. M.levelName .. '.json') or nil
  spotCache = {}
  log('I', logTag, 'Level: ' .. tostring(M.levelName) .. ', Map-Daten: ' .. tostring(M.mapData ~= nil))
end

-- Eigene Punkte: Kartendatei (maps/<level>.json) plus im Dev-Menü gemerkte Orte (dev_places.json) ------
-- kind 'stand' = Stehplätze der PA-Fahrer (standSpots / Dev-Typ npc), 'photo' = Foto-Spots (photoSpots / Dev-Typ photo)
-- kind 'paexit' = Ausfahrt-Routen aus PAs (paExitRoutes / Dev-Typ paexit, mit points = Liste von Punkten)
-- kind 'board' = Aushänge des Schwarzen Bretts (boardSpots / Dev-Typ board), 'taxi' = Fahrgast-Punkte der Taxischicht
-- (taxiSpots / Dev-Typ taxi), 'taxidepot' = Taxi-Depot, dort steht das Firmentaxi (taxiDepots / Dev-Typ taxidepot)
-- kind 'police' = Messstellen für Blitzer und Laserkontrollen (policeSpots / Dev-Typ police, Einstellungen in police = { kind, limit, both, off })
local spotKinds = { stand = { list = 'standSpots', dev = 'npc' }, photo = { list = 'photoSpots', dev = 'photo' },
  paexit = { list = 'paExitRoutes', dev = 'paexit' }, board = { list = 'boardSpots', dev = 'board' },
  taxi = { list = 'taxiSpots', dev = 'taxi' }, taxidepot = { list = 'taxiDepots', dev = 'taxidepot' },
  police = { list = 'policeSpots', dev = 'police' } }
local spotCache = {}
function M.resetSpotCache() spotCache = {} end
function M.spots(kind)
  local k = spotKinds[kind]
  if not k then return {} end
  if spotCache[kind] then return spotCache[kind] end
  local out = {}
  for _, e in ipairs((M.mapData or {})[k.list] or {}) do
    if type(e.pos) == 'table' then table.insert(out, e) end
  end
  local dev = jsonReadFile(saveDir .. 'dev_places.json')
  local L = type(dev) == 'table' and dev.levels and dev.levels[M.levelName or ''] or nil
  for _, p in ipairs(L and L.places or {}) do
    if p.type == k.dev and type(p.pos) == 'table' then
      -- schon in die Kartendatei übernommen? Dann nicht doppelt
      local dup = false
      for _, e in ipairs(out) do
        if not e.dev and math.abs(e.pos[1] - p.pos[1]) < 0.5 and math.abs(e.pos[2] - p.pos[2]) < 0.5 then dup = true break end
      end
      if not dup then table.insert(out, { id = p.id, name = p.name, pos = p.pos, dir = p.dir, points = p.points, police = p.police, dev = true }) end
    end
  end
  spotCache[kind] = out
  return out
end

-- Auto des Spielers ---------------------------------------------------------

-- Motor aus nach dem Spawnen (wie beim Autokauf in der BeamNG-Karriere).
-- Gilt für das nächste Auto, das innerhalb kurzer Zeit spawnt (auch replaceVehicle).
local engineOffTimer = 0
function M.engineOffAfterSpawn()
  engineOffTimer = 3
  extensions.hashiriyaBattle_fuel.keepAfterRespawn()
  extensions.hashiriyaBattle_condition.keepAfterRespawn()
  extensions.hashiriyaBattle_damage.restoreAfterSpawn()
end

local function onVehicleSpawned(vehId)
  if engineOffTimer <= 0 then return end
  local veh = be:getObjectByID(vehId)
  if not veh or veh:getJBeamFilename() == 'unicycle' then return end
  engineOffTimer = 0
  pcall(function() core_vehicleBridge.executeAction(veh, 'setIgnitionLevel', 0) end)
end

-- Verkehr: Freeroam startet ihn in 0.40 nur über den Freeroam-Startbildschirm, darum selbst einschalten.
-- Fahrende und geparkte Autos nehmen die japanische Gruppe der Agent-Traffic-Mod, falls installiert
-- (cars.json: trafficGroup), sonst den normalen BeamNG-Verkehr.
local trafficStarted = false

-- Alle Einträge der Agent-Gruppe (cars.json trafficGroup) plus trafficExtraConfigs (Configs, die Agent nicht in der
-- Gruppe hat). Gewicht = Population der Config (info_*.json), geparkt populationParked, falls angegeben.
local function trafficPool(parked)
  local cd = M.carsData or {}
  local path = cd.trafficGroup
  if not path or path == '' then return nil end
  local g = jsonReadFile(path)
  local list = g and g.data
  if type(list) ~= 'table' or not list[1] then return nil end
  local entries = {}
  for _, e in ipairs(list) do table.insert(entries, e) end
  for _, e in ipairs(cd.trafficExtraConfigs or {}) do table.insert(entries, e) end
  local skip = {}
  for _, c in ipairs(cd.trafficSkipConfigs or {}) do skip[c] = true end
  local pool, models, seen = {}, {}, {}
  for _, e in ipairs(entries) do
    if e.model and e.config and not skip[e.config] and not seen[e.model .. '/' .. e.config] then
      seen[e.model .. '/' .. e.config] = true
      if models[e.model] == nil then
        local okM, m = pcall(core_vehicles.getModel, e.model)
        models[e.model] = (okM and m and type(m.configs) == 'table') and m.configs or false
      end
      local info = models[e.model] and models[e.model][e.config]
      if info then -- nur Configs, die es gibt (Agent-Mod deaktiviert -> Vanilla-Verkehr)
        local w = tonumber(e.population) or tonumber(info.Population) or 1000
        if parked and e.populationParked then w = tonumber(e.populationParked) or w end
        if info.isLarge == true or info.isLarge == 'true' then w = 0 end -- Busse/Lkw wie bei Agent nicht im Verkehr
        if w > 0 then table.insert(pool, { model = e.model, config = e.config, paintName = e.paintName or 'random', w = w }) end
      end
    end
  end
  if not pool[1] then return nil end
  return pool
end

-- Liste mit genau amount Autos ziehen: nach Population gewichtet, aber jede schon gezogene Config wird seltener
-- (wie Agents Traffic Tool), damit möglichst viele verschiedene Autos unterwegs sind.
local function buildTrafficList(pool, amount)
  local repeatFactor = tonumber((M.carsData or {}).trafficRepeatPenalty) or 4
  local used, out = {}, {}
  for _ = 1, amount do
    local total = 0
    for _, e in ipairs(pool) do total = total + e.w / (1 + (used[e] or 0) * repeatFactor) end
    local r, pick = math.random() * total, pool[#pool]
    for _, e in ipairs(pool) do
      r = r - e.w / (1 + (used[e] or 0) * repeatFactor)
      if r <= 0 then pick = e; break end
    end
    used[pick] = (used[pick] or 0) + 1
    table.insert(out, { model = pick.model, config = pick.config, paintName = pick.paintName })
  end
  -- mischen, damit die seltenen Autos nicht alle am Ende spawnen
  for i = #out, 2, -1 do
    local j = math.random(1, i)
    out[i], out[j] = out[j], out[i]
  end
  local kinds = 0
  for _ in pairs(used) do kinds = kinds + 1 end
  return out, kinds
end

-- Lack-Bibliothek von BeamNG laden: sie entsteht erst beim ersten Fahrzeug-Spawn. Im Titelbildschirm direkt nach
-- dem Spielstart gibt es noch keins, dann bricht der Verkehr mit "paintsByIdCache (a nil value)" ab.
local function warmPaintLibrary()
  local vp = rawget(_G, 'core_vehiclePaints') or extensions.core_vehiclePaints
  if vp and vp.validatePcPaints then pcall(vp.validatePcPaints, { paints = {} }, 'pessima') end
end

local trafficRetry = nil -- Sekunden bis zum nächsten Versuch, falls der Start fehlschlug
local trafficTries = 0

function M.startTraffic()
  if trafficStarted or (M.carsData and M.carsData.careerTraffic == false) then return end
  local tr = rawget(_G, 'gameplay_traffic') or extensions.gameplay_traffic
  if not tr or not tr.setupTrafficHelper then return end
  warmPaintLibrary()
  local okL, list = pcall(function() return tr.getTrafficList and tr.getTrafficList() end)
  trafficStarted = true
  if okL and type(list) == 'table' and next(list) then -- läuft schon
    local n = 0
    for _ in pairs(list) do n = n + 1 end
    M.trafficTotal, M.trafficActive, M.trafficSpawned = n, nil, n
    return
  end
  local amount = M.carsData and tonumber(M.carsData.trafficAmount) or -1
  local parked = M.carsData and tonumber(M.carsData.parkedAmount) or -1
  local tOpts, pOpts = { police = false }, {}
  local pool = trafficPool(false)
  local n = amount
  if n < 0 then
    local okA, ideal = pcall(tr.getIdealSpawnAmount, nil, true)
    n = okA and tonumber(ideal) or 10
  end
  -- Verkehr im BeamNG-Hauptmenü ausgeschaltet (Menge 0): der Spielmodus braucht ihn trotzdem
  local minAmount = M.carsData and tonumber(M.carsData.trafficMinAmount) or 12
  if n < minAmount then
    if n <= 0 then log('I', logTag, 'Verkehr war in den BeamNG-Einstellungen aus, wird für Hashiriya Battle eingeschaltet') end
    n = minAmount
  end
  M.trafficTotal = n -- volle Menge (tagsüber); nachts fahren davon weniger (trafficByHour in world.json)
  M.trafficActive = nil
  -- Pool: zusätzlich versteckte Autos, die BeamNG nach und nach gegen die fahrenden tauscht (mehr Abwechslung).
  -- Aktiv sind trotzdem nur n (updateTrafficDensity setzt die Menge).
  local spawnN = n
  if pool then
    spawnN = n + math.max(0, tonumber(M.carsData.trafficPoolExtra) or 0)
    local list, kinds = buildTrafficList(pool, spawnN)
    tOpts.vehGroup = list
    tOpts.activeAmount = n -- setupTraffic: nur n sichtbar, der Rest wartet versteckt im Pool
    local pp = trafficPool(true) or pool
    local pn = parked
    if pn < 0 then pn = tonumber(M.carsData.parkedListSize) or 60 end
    local plist, pkinds = buildTrafficList(pp, math.max(pn, 1))
    pOpts.vehGroup = plist
    log('I', logTag, string.format('Agent Traffic JP: %d Configs verfügbar, fahrend %d Autos (%d aktiv) aus %d Configs, geparkt %d verschiedene', #pool, spawnN, n, kinds, pkinds))
  end
  local ok, err = pcall(tr.setupTrafficHelper, spawnN, tOpts, parked, pOpts)
  M.trafficSpawned = spawnN
  if ok then
    trafficRetry, trafficTries = nil, 0
    log('I', logTag, 'Verkehr gestartet' .. (pool and ' (Agent Traffic JP)' or ''))
  else
    log('W', logTag, 'Verkehr starten fehlgeschlagen: ' .. tostring(err))
    -- gleich noch mal versuchen (höchstens 5-mal), sonst bleibt der Titelbildschirm leer
    trafficTries = trafficTries + 1
    if trafficTries <= 5 then
      trafficStarted = false
      trafficRetry = 2
    end
  end
end

-- Wartenden Neuversuch abarbeiten (aus onUpdate)
local function updateTrafficRetry(dtReal)
  if not trafficRetry then return end
  trafficRetry = trafficRetry - dtReal
  if trafficRetry > 0 then return end
  trafficRetry = nil
  local ok, err = pcall(M.startTraffic)
  if not ok then log('W', logTag, 'Verkehr Neuversuch: ' .. tostring(err)) end
end

-- Verkehr nach Uhrzeit: aktive Menge = volle Menge × trafficByHour[Stunde] %
local trafficTimer = 0
local trafficWarned = false
local function updateTrafficDensity(dt)
  trafficTimer = trafficTimer - dt
  if trafficTimer > 0 or not M.trafficTotal then return end
  trafficTimer = 10
  local home = extensions.hashiriyaBattle_home
  local byHour = home.world().trafficByHour
  local h = home.hour()
  if type(byHour) ~= 'table' or not h then return end
  local pct = tonumber(byHour[math.floor(h) % 24 + 1]) or 100
  -- Hardcore: mehr Verkehr (hardcore.json trafficFactor), höchstens so viele wie gespawnt
  pct = pct * extensions.hashiriyaBattle_hardcore.num('trafficFactor')
  local target = math.max(1, math.floor(M.trafficTotal * pct / 100 + 0.5))
  if M.trafficSpawned then target = math.min(target, M.trafficSpawned) end
  local tr = rawget(_G, 'gameplay_traffic')
  if target == M.trafficActive then
    -- Pool-Autos kommen erst nach dem ersten Setzen dazu: sind mehr aktiv als gewollt, nochmal setzen
    local okN, active = pcall(function() return tr and tr.getNumOfTraffic and tr.getNumOfTraffic(true) end)
    if not okN or not tonumber(active) or tonumber(active) <= target then return end
  end
  if not tr or not tr.setActiveAmount then
    if not trafficWarned then trafficWarned = true; log('W', logTag, 'gameplay_traffic.setActiveAmount fehlt, Verkehr bleibt konstant') end
    return
  end
  local ok, err = pcall(tr.setActiveAmount, target)
  if ok then
    M.trafficActive = target
    log('I', logTag, string.format('Verkehr: %d von %d aktiv (%d %%, %02d Uhr)', target, M.trafficTotal, pct, math.floor(h)))
  else
    log('W', logTag, 'Verkehr anpassen fehlgeschlagen: ' .. tostring(err))
  end
end

-- Config des Spielerautos mit Kennzeichen-Design (Plates Pack); alte Spielstände bekommen das Standard-Design
local function plateConfig(car)
  local plates = extensions.hashiriyaBattle_plates
  if not car.config or car.config == '' then return nil end
  car.plateDesign = plates.validDesign(car.plateDesign) and car.plateDesign or plates.defaultDesign
  if not plates.normalize(car.plate) then car.plate = plates.random() end -- alte Spielstände: BeamNG-Kennzeichen ersetzen
  local cfg = plates.applyToConfig(car.config, car.plateDesign)
  if type(cfg) == 'table' then car.config = cfg end
  return cfg
end
M.plateConfig = plateConfig

local function spawnPlayerCar(car)
  M.engineOffAfterSpawn()
  local opts = { config = plateConfig(car), licenseText = car.plate }
  -- Start in der Garage, falls die Map eine hat
  local pos, rot = extensions.hashiriyaBattle_parking.spawnTransform(extensions.hashiriyaBattle_parking.find('garage'))
  if pos then opts.pos, opts.rot = pos, rot end
  local current = M.getPlayerVehicle()
  if current then
    core_vehicles.replaceVehicle(car.model, opts)
    -- replaceVehicle übernimmt das alte Kennzeichen, daher das eigene danach setzen
    if car.plate then pcall(core_vehicles.setPlateText, car.plate, current:getID()) end
  else
    opts.autoEnterVehicle = true
    core_vehicles.spawnNewVehicle(car.model, opts)
  end
end

-- Aktives Auto des Spielstands in die Garagenbucht stellen (Autowechsel in der Garage)
function M.spawnActiveCar()
  local car = M.save and M.save.cars[M.save.activeCar or 1]
  if car then spawnPlayerCar(car) end
end

local function chooseStarterCar(car)
  M.save = newSave()
  extensions.hashiriyaBattle_parking.loadSettings(M.save)
  extensions.hashiriyaBattle_shop.loadSettings(M.save)
  local entry = { model = car.model, config = car.config, name = car.name }
  table.insert(M.save.cars, entry)
  M.save.activeCar = 1
  extensions.hashiriyaBattle_condition.initUsedCar(entry, car.condition, nil)
  M.writeSave()
  spawnPlayerCar(car)
  M.startTraffic()
  M.active = true
  showCarSelect = false
  msg(M.t('msg.welcome'), 6)
end

-- Neues Spiel aus dem Karriere-Assistenten (career.lua): Auto steht im Showroom oder schon in der Garagenbucht.
function M.newCareer(data)
  if data.slot then M.setSlot(data.slot) end
  clearSlotDamage(readSave()) -- überschriebener Spielstand: alte Schäden weg
  M.save = newSave()
  pcall(function() extensions.hashiriyaBattle_story.reset() end)
  M.save.playerName = data.playerName
  M.save.experience = data.experience
  -- Hardcore-Modus (hardcore.lua): steht ab jetzt fest im Spielstand
  if data.hardcore then M.save.hardcore = true end
  local hc = extensions.hashiriyaBattle_hardcore
  pcall(hc.onSaveLoaded)
  -- Startkapital minus Kaufpreis des Starterautos
  if data.carPrice and data.carPrice > 0 then
    M.save.money = math.max(0, M.save.money - data.carPrice)
    extensions.hashiriyaBattle_progress.bump(M.save, 'carsBought')
  end
  extensions.hashiriyaBattle_parking.loadSettings(M.save)
  extensions.hashiriyaBattle_shop.loadSettings(M.save)
  table.insert(M.save.cars, data.car)
  M.save.activeCar = 1
  -- Starterautos sind gebraucht (cars.json: condition)
  local veh = M.getPlayerVehicle()
  local cond = data.condition
  if M.save.hardcore and type(cond) == 'table' then
    -- Hardcore: Startauto mit fast leerem Tank (hardcore.json startFuel)
    local copy = {}
    for k, v in pairs(cond) do copy[k] = v end
    cond = copy
    cond.fuel = tonumber(hc.cfg().startFuel) or cond.fuel
  end
  extensions.hashiriyaBattle_condition.initUsedCar(data.car, cond, veh)
  -- Aus dem Showroom in die Garagenbucht
  if veh and extensions.hashiriyaBattle_parking.hasShowroom() then
    local pos, rot = extensions.hashiriyaBattle_parking.spawnTransform(extensions.hashiriyaBattle_parking.find('garage'))
    if pos then
      local ok = pcall(function() spawn.safeTeleport(veh, pos, rot) end)
      if not ok then veh:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w) end
    end
  end
  extensions.hashiriyaBattle_home.applyClock(extensions.hashiriyaBattle_home.world().startHour)
  pcall(function() extensions.hashiriyaBattle_savepoint.markSoon('garage') end)
  M.writeSave()
  M.active = true
  showCarSelect = false
  showMenu = false
  msg(M.t('msg.welcomeDriver', data.playerName or ''), 8)
end

-- Weiterspielen: Auto in die Garagenbucht stellen, Spieler zu Fuß daneben.
function M.continueCareer(slot)
  if slot then M.setSlot(slot)
  elseif not readSave() and M.lastSlot() then M.setSlot(M.lastSlot()) end
  M.save = readSave()
  if not M.save then
    msg(M.t('msg.noSave'))
    return
  end
  extensions.hashiriyaBattle_parking.loadSettings(M.save)
  extensions.hashiriyaBattle_shop.loadSettings(M.save)
  extensions.hashiriyaBattle_condition.syncStarterWear(M.save)
  pcall(function() extensions.hashiriyaBattle_story.reset() end)
  -- Hardcore (hardcore.lua): Kaltstart vor dem Spawn setzen, offenes Battle (Ironman) = Niederlage
  pcall(extensions.hashiriyaBattle_hardcore.onSaveLoaded)
  pcall(extensions.hashiriyaBattle_hardcore.checkForfeit)
  local car = M.save.cars[M.save.activeCar or 1]
  if not car then
    -- Alpha 0.8: Spielstand ohne Auto (Pink Slip verloren): zu Fuß an der Garage, Händler oder Game Over
    M.active = true
    showMenu = false
    extensions.hashiriyaBattle_home.applyClock(M.save.hour or extensions.hashiriyaBattle_home.world().startHour)
    M.goOnFoot(nil)
    extensions.hashiriyaBattle_dealer.checkNoCar()
    return
  end
  -- Speichern am Standort (savepoint.lua): zu Hause/Garage -> Garagenbucht, geparkt -> genau dort,
  -- nicht ordentlich geparkt -> abgeschleppt oder Zwischenstand (world.json saving.unsavedExit)
  local sp = extensions.hashiriyaBattle_savepoint
  local okP, plan = pcall(sp.planLoad, M.save)
  if not okP or type(plan) ~= 'table' then
    log('W', logTag, 'Speicherort nicht lesbar, Start in der Garage: ' .. tostring(plan))
    plan = { mode = 'garage' }
  end
  local atSpot = plan.mode == 'spot'
  local inCar = atSpot and not plan.onFoot
  local opts = { config = plateConfig(car), licenseText = car.plate, autoEnterVehicle = inCar }
  local pos, rot
  if atSpot then pos, rot = plan.pos, plan.rot
  else pos, rot = extensions.hashiriyaBattle_parking.spawnTransform(extensions.hashiriyaBattle_parking.find('garage')) end
  if pos then opts.pos, opts.rot = pos, rot end
  local current = M.getPlayerVehicle()
  local carVeh
  M.engineOffAfterSpawn()
  if current then
    core_vehicles.replaceVehicle(car.model, opts)
    if car.plate then pcall(core_vehicles.setPlateText, car.plate, current:getID()) end
    carVeh = current
  else
    carVeh = core_vehicles.spawnNewVehicle(car.model, opts)
  end
  M.active = true
  showMenu = false
  -- Uhr dort weiterlaufen lassen, wo gespeichert wurde
  extensions.hashiriyaBattle_home.applyClock(M.save.hour or extensions.hashiriyaBattle_home.world().startHour)
  msg(M.t('msg.welcomeBack', M.save.playerName or ''), 6)
  if inCar then
    if carVeh then
      M.carVehId = carVeh:getID()
      if M.isWalking() then
        local w = walk()
        if not (w and w.getInVehicle and pcall(w.getInVehicle, carVeh)) then pcall(function() be:enterVehicle(0, carVeh) end) end
      end
    end
  elseif atSpot then
    local fp, fr = plan.footPos, plan.footRot
    if not fp and pos then
      -- zu Fuß, aber ohne gemerkte Stelle: neben dem Auto
      local side = (rot * vec3(1, 0, 0)); side.z = 0
      fp, fr = pos + side:normalized() * 3, rot
    end
    M.goOnFoot(carVeh, fp, fr)
  else
    M.goOnFoot(carVeh)
  end
  pcall(sp.afterLoad, plan)
  M.startTraffic()
end

function M.isDealerOpen() return showDealer end

function M.setMenuVisible(on)
  showMenu = on and true or false
  if not showMenu then menuAutoOpened = false end
end

local function continueGame()
  M.save = readSave()
  if not M.save then
    msg(M.t('msg.noSave'))
    return
  end
  extensions.hashiriyaBattle_parking.loadSettings(M.save)
  extensions.hashiriyaBattle_shop.loadSettings(M.save)
  local car = M.save.cars[M.save.activeCar or 1]
  if car then spawnPlayerCar(car) end
  M.active = true
end

function M.stopGame()
  pcall(function() extensions.hashiriyaBattle_story.reset() end)
  pcall(function() extensions.hashiriyaBattle_jobs.reset() end)
  pcall(function() extensions.hashiriyaBattle_talk.despawnAll() end)
  pcall(function() extensions.hashiriyaBattle_talk.clearPending() end)
  if M.active then
    pcall(function() extensions.hashiriyaBattle_savepoint.beforeStop() end)
    M.writeSave()
  end
  M.active = false
  extensions.hashiriyaBattle_battle.reset()
  extensions.hashiriyaBattle_rivals.despawnAll()
  pcall(extensions.hashiriyaBattle_hardcore.onStop)
end

-- Parkplätze (vom Parking-Modul aufgerufen) --------------------------------

function M.onParkingArrived(area)
  extensions.hashiriyaBattle_style.onParkingArrived(area)
  showMenu = true
  menuAutoOpened = true
  msg(M.t('msg.enterPa', M.t('pa.' .. area.type)), 4)
  if area.type == 'garage' then
    pcall(function() extensions.hashiriyaBattle_savepoint.mark('garage') end) -- Auto steht in der Garage: Laden startet hier
    M.writeSave()
  end
  -- Shop zu Fuß: gleich das Teile-Terminal
  -- Drive-in-Shop ohne Eingang zu Fuß (z. B. Heiwajima PA): Terminal öffnet sich im Auto
  if area.type == 'shop' and (extensions.hashiriyaBattle_parking.isFootShop() or not area.footEntry) then extensions.hashiriyaBattle_shop.openTerminal('shop') end
  -- Story (Alpha 0.6): Szenen in der Garage, zuhause, ...
  pcall(function() extensions.hashiriyaBattle_story.onEvent(area.type, { area = area.type }) end)
  M.sendUiState()
end

function M.onParkingLeft(area)
  homeTab = 'main'
  -- Probeweise eingebaute Teile zurücknehmen, offene Setup-Änderungen verwerfen, Teile-Kamera lösen
  extensions.hashiriyaBattle_shop.cancelPreview()
  extensions.hashiriyaBattle_shop.closeTerminal()
  extensions.hashiriyaBattle_shop.releaseFocus()
  extensions.hashiriyaBattle_setup.onParkingLeft()
  garageTab = 'service'
  if menuAutoOpened then showMenu = false end
  menuAutoOpened = false
  M.sendUiState()
end

-- Belohnungen (vom Battle-Modul aufgerufen) --------------------------------

function M.onBattleResult(rival, won, result)
  if not M.save then return end
  local style = extensions.hashiriyaBattle_style
  local streak, moneyF, repF = 0, 1, 1
  if won then
    streak = style.onBattleWon()
    moneyF, repF = style.streakFactors(streak)
  end
  result = result or {}
  result.repFactor = repF
  log('I', logTag, string.format('Battle-Ergebnis: %s gegen %s (%s), Serie %d, Details %s', won and 'Sieg' or 'Niederlage',
    tostring(rival and rival.id), tostring(rival and rival.config), streak, (pcall(jsonEncode, result) and jsonEncode(result)) or '?'))
  extensions.hashiriyaBattle_progress.onBattle(rival, won, result)
  if not won then style.resetStreak('loss') end
  -- Pink Slip: Auto statt Preisgeld (rivals.json settings.pinkSlip.money = true: beides). Dein Auto zurückholen gibt es bei jedem Sieg.
  local okP, pink = pcall(function() return extensions.hashiriyaBattle_pinkslip.onResult(rival, won) end)
  if not okP then log('E', logTag, 'Pink Slip: ' .. tostring(pink)); pink = false end
  local pinkNoMoney = pink and won and not extensions.hashiriyaBattle_pinkslip.settings().money
  if won and pinkNoMoney then
    M.save.defeated[rival.id] = true
    M.save.wins = M.save.wins + 1
    extensions.hashiriyaBattle_progress.leaderHint(rival)
  elseif won then
    -- rivals.json settings.rewardScale: Preisgeld aller Rivalen auf einmal anpassen (1 = volle rewardUsd)
    local rs = extensions.hashiriyaBattle_rivals.getData()
    local scale = tonumber(rs and rs.settings and rs.settings.rewardScale) or 1
    local reward
    local exact = tonumber(rival.rewardYen)
    if exact and exact > 0 then
      -- rewardYen: genauer Yen-Betrag (z. B. 777777), ohne Umrechnung, Rundung, rewardScale und Serien-Bonus
      reward = math.floor(exact)
    else
      -- Hardcore: weniger Preisgeld (hardcore.json rewardFactor)
      local hcF = extensions.hashiriyaBattle_hardcore.num('rewardFactor')
      reward = math.floor(M.economy().usdToPrice(rival.rewardUsd or 1000) * scale * moneyF * hcF / 100 + 0.5) * 100
    end
    M.save.money = M.save.money + reward
    M.save.defeated[rival.id] = true
    M.save.wins = M.save.wins + 1
    msg(M.t('msg.win', rival.name, M.economy().formatYen(reward)), 6)
    if streak >= 2 then msg(M.t('msg.streak', streak, math.floor((moneyF - 1) * 100 + 0.5)), 4) end
    extensions.hashiriyaBattle_progress.leaderHint(rival)
  else
    M.save.losses = M.save.losses + 1
    M.save.lastLossDay = M.save.day or 1 -- Bedingung minDaysNoLoss
    msg(M.t('msg.lose', rival.name), 6)
  end
  pcall(extensions.hashiriyaBattle_hardcore.battleEnded) -- Ironman: Battle ist sauber zu Ende
  M.writeSave()
  -- Logo-Sammlung: Crew-Logo (Leader besiegt), Wanderer-Siegel oder Boss-Emblem neu freigeschaltet
  if won then
    local okL, newLogo = pcall(function() return extensions.hashiriyaBattle_logos.newlyUnlocked(rival) end)
    -- Trophäe (Plakette / Pokal) für Leader und Bosse, mit Tag, Auto und Zeit; die Meldung nennt dann auch das Logo
    local okT, trophy = pcall(function() return extensions.hashiriyaBattle_logos.recordTrophy(rival, result) end)
    if not okT then log('E', logTag, 'Trophäe: ' .. tostring(trophy)); trophy = nil end
    if trophy then msg(M.t('msg.trophyWon', trophy), 7)
    elseif okL and newLogo then msg(M.t('msg.logoUnlocked', newLogo), 7) end
    -- Aura des geschlagenen Gegners (aura.lua): Crew-, Leader-, Wanderer- oder Boss-Aura
    local okA, newAura = pcall(function() return extensions.hashiriyaBattle_aura.newlyUnlocked(rival) end)
    if okA and newAura then msg(M.t('msg.auraUnlocked', newAura), 7)
    elseif not okA then log('E', logTag, 'Aura: ' .. tostring(newAura)) end
    -- Rivalen-Autos: Leader, Boss oder Wanderer geschlagen -> sein Auto steht beim Händler
    pcall(function() extensions.hashiriyaBattle_dealer.onRivalBeaten(rival) end)
  end
  -- Spitznamen: neu verdiente melden (alle Zähler sind jetzt aktuell)
  pcall(function() extensions.hashiriyaBattle_progress.afterBattle() end)
  -- Story (Alpha 0.6): Szenen nach einem Battle
  pcall(function() extensions.hashiriyaBattle_story.onEvent(won and 'win' or 'lose', { rival = rival }) end)
end

-- Positionen sammeln (für Parkplätze und Spawnpunkte) -----------------------

local function capturePosition()
  local veh = M.getPlayerVehicle()
  local onFoot = false
  if not veh and M.isWalking() then
    -- zu Fuß: Position der Spielfigur, Blickrichtung der Kamera
    veh = getPlayerVehicle and getPlayerVehicle(0) or be:getPlayerVehicle(0)
    onFoot = true
  end
  if not veh then return end
  local p, d = veh:getPosition(), veh:getDirectionVector()
  if onFoot then p = walkerPosition(veh) end
  if p:length() < 0.5 then
    -- genau im Ursprung: keine echte Position (Figur gerade nicht gespawnt). Die C1-Garage liegt selbst nahe am Ursprung.
    msg(M.t('msg.posInvalid'))
    return
  end
  if onFoot then
    local okD, camDir = pcall(core_camera.getForward)
    if okD and camDir then d = vec3(camDir.x, camDir.y, 0):normalized() end
  end
  -- Mitte des Autos (Bounding Box), nicht der Referenzpunkt: daraus wird die Mitte der Parkbucht
  local okC, center = pcall(function() return (not onFoot) and veh:getSpawnWorldOOBB():getCenter() or nil end)
  local list = jsonReadFile(capturePath) or {}
  table.insert(list, {
    level = M.levelName,
    pos = { p.x, p.y, p.z },
    dir = { d.x, d.y, d.z },
    center = okC and center and { center.x, center.y, center.z } or nil,
    onFoot = onFoot or nil,
  })
  jsonWriteFile(capturePath, list, true)
  msg(M.t('msg.posSaved', #list) .. string.format(' (%.0f / %.0f)', p.x, p.y))
end

-- Titelbild-Kamera: aktuelle Kamera (z. B. Freecam) und Uhrzeit merken, Taste Shift+Pos1 (zweimal drücken).
-- Gespeichert in settings/hashiriya_battle/title_camera.json (je Level); der Titelbildschirm nutzt sie,
-- sonst mapData.titleCamera, sonst die Ansicht auf die Garagenbucht.
local titleCamPath = saveDir .. 'title_camera.json'

function M.getTitleCamera()
  local all = jsonReadFile(titleCamPath) or {}
  local cam = M.levelName and all[M.levelName]
  if cam and cam.pos and cam.rot then return cam end
  local md = M.mapData
  return md and md.titleCamera or nil
end

-- Sicherheitsabfrage: die Taste muss innerhalb von titleCamConfirmSec zweimal gedrückt werden,
-- sonst wird nichts überschrieben (versehentliches Drücken). Der Dev-Menü-Knopf speichert direkt.
local titleCamConfirmSec = 3
local titleCamArmedAt = nil

function M.captureTitleCamera(confirmed)
  if M.isRelease() then return end
  if not confirmed then
    local now = os.clock()
    if not titleCamArmedAt or now - titleCamArmedAt > titleCamConfirmSec then
      titleCamArmedAt = now
      msg(M.t('msg.titleCamConfirm', titleCamConfirmSec), titleCamConfirmSec)
      return
    end
  end
  titleCamArmedAt = nil
  local okP, p = pcall(core_camera.getPosition)
  local okQ, q = pcall(core_camera.getQuat)
  if not (okP and p and okQ and q) then
    okP, p = pcall(getCameraPosition)
    okQ, q = pcall(getCameraQuat)
  end
  if not (okP and p and okQ and q) or not M.levelName then
    msg(M.t('msg.posInvalid'))
    return
  end
  local all = jsonReadFile(titleCamPath) or {}
  all[M.levelName] = { pos = { p.x, p.y, p.z }, rot = { q.x, q.y, q.z, q.w }, hour = extensions.hashiriyaBattle_home.hour() }
  jsonWriteFile(titleCamPath, all, true)
  log('I', logTag, 'Titelbild-Kamera gespeichert: ' .. dumps(all[M.levelName]))
  msg(M.t('msg.titleCamSaved'), 4)
end

-- Config-Export ------------------------------------------------------------------
-- Schreibt alle Configs der Marken Hirochi und Ibishu (inkl. Mod-Configs) nach
-- settings/hashiriya_battle/config_dump.json. Daraus entsteht die Auswahlliste für Rivalen und Startautos.

local dumpPath = saveDir .. 'config_dump.json'
local dumpBrands = { Hirochi = true, Ibishu = true }

local function getModelKeys()
  local keys = {}
  local ok, names = pcall(function() return core_vehicles.getModelNames() end)
  if ok and type(names) == 'table' and #names > 0 then return names end
  ok, names = pcall(function() return core_vehicles.getModelList(true) end)
  if ok and type(names) == 'table' then
    for k, v in pairs(names.models or names) do
      table.insert(keys, type(k) == 'string' and k or (type(v) == 'table' and (v.key or v.model)) or tostring(v))
    end
    if #keys > 0 then return keys end
  end
  for _, dir in ipairs(FS:findFiles('/vehicles/', '*', 0, false, true) or {}) do
    table.insert(keys, dir:match('([^/]+)/*$'))
  end
  return keys
end

local function scalars(t)
  local out = {}
  for k, v in pairs(t or {}) do
    local tv = type(v)
    if tv == 'string' or tv == 'number' or tv == 'boolean' then out[k] = v end
  end
  return out
end

M.getModelKeys = getModelKeys

function M.dumpConfigs()
  local result, count = {}, 0
  for _, key in ipairs(getModelKeys()) do
    local ok, info = pcall(core_vehicles.getModel, key)
    if ok and info and info.model and dumpBrands[info.model.Brand] then
      local entry = { model = key, info = scalars(info.model), configs = {} }
      for cfgKey, cfg in pairs(info.configs or {}) do
        local c = scalars(cfg)
        c.key = cfgKey
        table.insert(entry.configs, c)
        count = count + 1
      end
      table.insert(result, entry)
    end
  end
  jsonWriteFile(dumpPath, { gameVersion = beamng_versiond or '', models = result }, true)
  log('I', logTag, 'Config-Export: ' .. count .. ' Configs in ' .. #result .. ' Modellen')
  msg(M.t('msg.configDump', count))
  return count
end

-- UI (BeamNG UI-Apps unter ui/modules/apps/Hashiriya*) ------------------------
-- Die Apps bekommen den Zustand über den Hook 'HashiriyaState' und melden Klicks über uiAction().

M.layoutName = 'hashiriyaBattle' -- settings/ui_apps/originalLayouts/default/hashiriyaBattle.uilayout.json
local uiTimer = 0
local uiInterval = 0.1

local function setLayout(name)
  local gs = rawget(_G, 'core_gamestate')
  if gs and gs.setGameState then pcall(gs.setGameState, 'freeroam', name, 'freeroam') end
end

-- Teile-Terminal (Shop, Garagen-PC) läuft im eigenen Layout: nur die Terminal-App, kein HUD
function M.setTerminalLayout(on)
  setLayout(on and 'hashiriyaShop' or M.layoutName) -- settings/ui_apps/originalLayouts/default/hashiriyaShop.uilayout.json
end

-- Dev-Menü (devtools.lua): Rivalenliste nach Builder-Speichern neu aufbauen
function M.resetDevRivals()
  if extensions.hashiriyaBattle_devtools then extensions.hashiriyaBattle_devtools.resetCache() end
end

local function buildUiState()
  local eco = M.economy()
  local st = {
    level = M.levelName,
    active = M.active,
    menuVisible = (showMenu or extensions.hashiriyaBattle_parking.isFootShop()) and not extensions.hashiriyaBattle_career.isOpen(),
    footShop = extensions.hashiriyaBattle_parking.isFootShop(),
    screen = M.active and 'status' or (showCarSelect and 'carSelect' or 'start'),
    flow = extensions.hashiriyaBattle_career.getUiState(),
    area = nil,
    hasSave = M.hasSave,
    cars = {},
    lang = M.lang,
    markers = extensions.hashiriyaBattle_parking.markersEnabled(),
    t = M.strings,
  }
  if showCarSelect and M.carsData then
    for _, car in ipairs(M.carsData.starterCars or {}) do
      table.insert(st.cars, { id = car.id, name = car.name, price = eco.formatYen(eco.usdToPrice(car.priceUsd or 0)) })
    end
  end
  if M.active and M.save then
    st.money = eco.formatYen(M.save.money)
    st.wins = M.save.wins
    st.losses = M.save.losses
    local rival = extensions.hashiriyaBattle_rivals.getActiveRival()
    st.rival = rival and rival.data.name or nil
    st.rivalKind = rival and extensions.hashiriyaBattle_rivals.markerKind(rival.data) or nil
    -- Hardcore: Rivalen nicht im Radar (hardcore.json hideRivalMarks)
    if not extensions.hashiriyaBattle_hardcore.rule('hideRivalMarks') then st.radar = extensions.hashiriyaBattle_rivals.radarInfo(600) end
    -- Polizei: Streifenwagen der Fahndung und gesehene Laserkontrollen auch im Radar
    local okP, polRadar = pcall(function() return extensions.hashiriyaBattle_police.radarItems(600) end)
    if okP and polRadar then
      st.radar = st.radar or { list = {} }
      for _, it in ipairs(polRadar) do table.insert(st.radar.list, it) end
    end
    st.battle = extensions.hashiriyaBattle_battle.getHudState()
    local talkHud = extensions.hashiriyaBattle_talk.getHudState()
    if talkHud then st.talk, st.talkPrompt = talkHud.talk, talkHud.prompt end
    -- Schwarzes Brett: Hinweis "[T] Lesen" am PA-Aushang, wenn gerade kein Fahrer zum Reden da ist
    if not st.talk and not st.talkPrompt then
      local okB, bp = pcall(function() return extensions.hashiriyaBattle_board.prompt() end)
      if okB and bp then st.talkPrompt = bp end
    end
    -- Story (Alpha 0.6): Kapitelkarte und Szenen haben Vorrang vor PA-Gesprächen
    local okS, storyHud = pcall(function() return extensions.hashiriyaBattle_story.getHudState() end)
    if okS and storyHud then
      st.storyCard = storyHud.card
      if storyHud.talk then st.talk, st.talkPrompt = storyHud.talk, nil end
      if storyHud.card then st.talk, st.talkPrompt = nil, nil end
    end
    local okG, goal = pcall(function() return extensions.hashiriyaBattle_story.goal() end)
    if okG then st.storyGoal = goal end
    st.style = extensions.hashiriyaBattle_style.getHudState()
    st.unlock = extensions.hashiriyaBattle_shop.unlockHud()
    local parking = extensions.hashiriyaBattle_parking
    local nav = parking.getNavInfo()
    if nav then
      nav.name = M.t('pa.' .. nav.type)
      nav.distText = nav.dist < 1000 and string.format('%d m', nav.dist) or string.format('%.1f km', nav.dist / 1000)
      st.nav = nav
    end
    local tow = parking.towInfo()
    if tow and tow.reason ~= 'atGarage' then
      st.tow = { cost = eco.formatYen(tow.cost), can = tow.reason == nil, reason = tow.reason and M.t('msg.tow.' .. tow.reason) or nil }
    end
    local nap = extensions.hashiriyaBattle_home.napInfo()
    if nap and nap.reason ~= 'notHere' then
      local reason = nil
      if nap.untilText then reason = M.t('msg.nap.' .. nap.reason, nap.untilText)
      elseif nap.reason then reason = M.t('msg.nap.' .. nap.reason) end
      st.nap = { can = nap.can, reason = reason }
    end
    -- Reisen: nach dem Abfahren an einer Ausfahrt, oder in der Garage (Start-PA)
    local okTr, tr = pcall(function() return extensions.hashiriyaBattle_travel.getUiState() end)
    st.travel = okTr and tr or nil
    st.day = extensions.hashiriyaBattle_home.dayText()
    st.clock = extensions.hashiriyaBattle_home.clockInfo()
    st.watch = extensions.hashiriyaBattle_home.watchHud()
    st.progress = extensions.hashiriyaBattle_progress.getUiState()
    st.night = extensions.hashiriyaBattle_home.isNight()
    local left = extensions.hashiriyaBattle_rivals.battlesLeftTonight()
    if st.night and left then st.battlesLeft = left end
    st.job = extensions.hashiriyaBattle_jobs.getHudState()
    local okPo, po = pcall(function() return extensions.hashiriyaBattle_police.getHudState() end)
    st.police = okPo and po or nil
    local okU, un = pcall(function() return extensions.hashiriyaBattle_unstuck.getUiState() end)
    st.unstuck = okU and un or nil
    local okSv, sv = pcall(function() return extensions.hashiriyaBattle_savepoint.getUiState() end)
    if okSv then st.saveState = sv end
    local okLg, lg = pcall(function() return extensions.hashiriyaBattle_logos.tileInfo() end)
    st.logoTile = okLg and lg or nil
    st.noCar = M.save.noCar and #M.save.cars == 0 or nil
    if M.save.gameOver then
      -- Alpha 0.8: Karriere vorbei (kein Auto, kein Geld)
      st.screen = 'gameOver'
      st.menuVisible = true
      st.gameOver = { days = M.save.day or 1, wins = M.save.wins or 0, losses = M.save.losses or 0, money = eco.formatYen(M.save.money or 0),
        rank = extensions.hashiriyaBattle_progress.rankName(M.save),
        wipe = extensions.hashiriyaBattle_hardcore.rule('gameOverDeletesSave') or nil }
    elseif showBoard then
      st.screen = 'board'
      st.board = extensions.hashiriyaBattle_board.getUiState()
    elseif showJobs then
      st.screen = 'jobs'
      st.jobs = extensions.hashiriyaBattle_jobs.getUiState()
    elseif showLogos then
      st.screen = 'logos'
      st.logos = extensions.hashiriyaBattle_logos.getUiState()
      local okN, nk = pcall(function() return extensions.hashiriyaBattle_progress.getNickUi() end)
      st.nicks = okN and nk or nil
      local okT, tr = pcall(function() return extensions.hashiriyaBattle_logos.getTrophyUi() end)
      st.trophies = okT and tr or nil
      local okA, au = pcall(function() return extensions.hashiriyaBattle_aura.getUiState() end)
      st.auras = okA and au or nil
    elseif showLexicon then
      st.screen = 'lexicon'
      st.home = extensions.hashiriyaBattle_home.getUiState('lexicon')
    elseif showStats then
      st.screen = 'stats'
      st.stats = extensions.hashiriyaBattle_progress.getStatsUi()
    elseif showDealer then
      st.screen = 'dealer'
      st.dealer = extensions.hashiriyaBattle_dealer.getUiState()
    elseif parking.isArrived() then
      local area = parking.getCurrent()
      st.screen = area.type
      st.area = M.t('pa.' .. area.type)
      local car = M.save.cars[M.save.activeCar or 1]
      st.carName = car and car.name or ''
      st.plate = car and car.plate or ''
      local plates = extensions.hashiriyaBattle_plates
      st.plateOptions = plates.uiOptions(M.t)
      st.plateRegion, st.plateType = plates.splitDesign(car and car.plateDesign)
      st.platePrice = eco.formatYen(extensions.hashiriyaBattle_hardcore.price(platePriceYen))
      local cost = parking.repairCost()
      st.repairCost = cost > 0 and eco.formatYen(cost) or nil
      st.canAffordRepair = cost <= M.save.money
      if area.type == 'home' then
        st.home = extensions.hashiriyaBattle_home.getUiState(homeTab)
      end
      if area.type == 'gas' then st.gas = extensions.hashiriyaBattle_fuel.getUiState() end
      if area.type == 'garage' then st.garageCars = extensions.hashiriyaBattle_dealer.ownedCars() end
      if area.type == 'garage' then
        local okMt, mt = pcall(function() return extensions.hashiriyaBattle_maintenance.getUiState() end)
        st.maintenance = okMt and mt or nil
      end
      if area.type == 'garage' then
        st.garageTab = garageTab
        if garageTab == 'setup' then st.setup = extensions.hashiriyaBattle_setup.getUiState() end
        if garageTab == 'stickers' then
          local okSt, stk = pcall(function() return extensions.hashiriyaBattle_stickers.getUiState() end)
          st.stickers = okSt and stk or nil
        end
      end
    end
  end
  st.terminal = M.active and M.save and extensions.hashiriyaBattle_shop.terminalState() or nil
  -- Garagen-PC: Reiter "Schwarzes Brett" (board.lua)
  if st.terminal and st.terminal.mode == 'garage' then
    local okB, bs = pcall(function() return extensions.hashiriyaBattle_board.getUiState() end)
    if okB then st.terminal.board = bs end
  end
  st.release = M.isRelease()
  st.devMenu = (not st.release) and extensions.hashiriyaBattle_devtools ~= nil or nil
  local mu = extensions.hashiriyaBattle_music
  st.music = mu and mu.nowPlaying() or nil
  st.musicCfg = nil -- Musik-Einstellungen sind jetzt im Pausenmenü (Esc > Mods > Hashiriya Battle)
  if st.music and extensions.hashiriyaBattle_career.keyFor then
    local ok, k = pcall(extensions.hashiriyaBattle_career.keyFor, 'hashiriyaMusicSkip')
    st.music.key = ok and k or nil
  end
  return st
end

function M.sendUiState()
  guihooks.trigger('HashiriyaState', buildUiState())
end

local function arrivedArea()
  local parking = extensions.hashiriyaBattle_parking
  return parking.isArrived() and parking.getCurrent() or nil
end

-- Kennzeichen ummelden (Garage, gegen Gebühr). replaceVehicle behält es bei Teilekäufen; beim Spawn setzt spawnPlayerCar es.
-- Ummelden in der Garage: neuer Text und/oder neues Design (Region, Art). arg = "text|design"
function M.changePlate(arg)
  local plates = extensions.hashiriyaBattle_plates
  local car = M.save and M.save.cars[M.save.activeCar or 1]
  local veh = M.getPlayerVehicle()
  if not car or not veh then return end
  local text, design = tostring(arg or ''):match('^(.-)|(.*)$')
  text, design = text or tostring(arg or ''), design ~= '' and design or nil
  local newText = car.plate
  if text:gsub('%s', '') ~= '' then
    newText = plates.normalize(text)
    if not newText then
      msg(M.t('msg.plateInvalid'), 6)
      return
    end
  end
  if design and not plates.validDesign(design) then design = nil end
  local newDesign = design or car.plateDesign or plates.defaultDesign
  if newText == car.plate and newDesign == car.plateDesign then return end
  local platePriceYen = extensions.hashiriyaBattle_hardcore.price(platePriceYen)
  if M.save.money < platePriceYen then
    msg(M.t('msg.noMoney'))
    return
  end
  M.save.money = M.save.money - platePriceYen
  car.plate = newText
  pcall(core_vehicles.setPlateText, newText, veh:getID())
  if newDesign ~= car.plateDesign then
    car.plateDesign = newDesign
    -- Design ist ein Fahrzeugteil: Config ändern und Auto neu laden (Zustand und Tank bleiben)
    extensions.hashiriyaBattle_shop.setPlateDesign(newDesign)
  end
  M.writeSave()
  log('I', logTag, 'Kennzeichen umgemeldet: ' .. tostring(newText) .. ' ' .. tostring(newDesign))
  msg(M.t('msg.plateChanged', newText, M.economy().formatYen(platePriceYen)))
end

-- Wird von den UI-Apps per bngApi.engineLua aufgerufen.
-- Klick-Sounds der Menüs (Meldungen bringen ihren eigenen Sound mit)
local silentActions = { setLanguage = true, photoMode = true, focusSlot = true, sound = true, fuelHold = true, termHello = true, termCatalog = true, paintLive = true }
local tabActions = { shopTab = true, garageTab = true, setupCat = true, paintSlot = true, termCat = true }
local backActions = { jobsBack = true, boardBack = true, back = true, hide = true, previewCancel = true, setupDiscard = true }

local function actionSound(action, arg)
  if silentActions[action] then return end
  if action == 'flow' then
    local cmd = tostring(arg or ''):match('^([^|]*)')
    M.sound(cmd == 'back' and 'back' or 'click')
  elseif tabActions[action] then M.sound('tab')
  elseif backActions[action] then M.sound('back')
  elseif action == 'customPaint' then M.sound('slider')
  else M.sound('click') end
end

-- Häufige Aktionen nicht ins Log (sonst wird es unlesbar)
local quietActions = { sound = true, slider = true, focusSlot = true, fuelHold = true, setupAdjust = true, paintSlot = true, setLanguage = true, photoMode = true, paintLive = true }


-- Release-Build (data/build.json release = true): Dev- und Cheat-Werkzeuge sind aus.
function M.isRelease()
  return M.buildData and M.buildData.release == true or false
end

local devActions = {
  callRival = true, capture = true, dumpParts = true, dumpConfigs = true,
  cheatMoney = true, cheatWins = true, cheatRep = true, cheatHour = true, cheatDay = true,
  cheatRepair = true, cheatFuel = true, devSpawnRival = true, devBeatRival = true, devClearRivals = true, builder = true, devUnlock = true, devTalkRespawn = true,
  devMenu = true, titleCamera = true,
}

function M.uiAction(action, arg)
  if not quietActions[action] then
    log('I', logTag, 'Aktion: ' .. tostring(action) .. (arg ~= nil and (' ' .. tostring(type(arg) == 'table' and jsonEncode(arg) or arg)) or ''))
  end
  if devActions[action] and M.isRelease() then
    log('W', logTag, 'Dev-Aktion im Release ignoriert: ' .. tostring(action))
    return
  end
  -- Während Schlafen/Nickerchen (schwarzer Bildschirm) nichts auslösen
  if extensions.hashiriyaBattle_home.isResting() and not quietActions[action] and action ~= 'report' then return end
  actionSound(action, arg)
  if action == 'sound' then
    M.sound(arg)
  elseif action == 'flow' then
    extensions.hashiriyaBattle_career.action(arg)
  elseif action == 'tutorial' then
    extensions.hashiriyaBattle_career.openTutorial()
  elseif action == 'career' then
    -- Titelbildschirm im laufenden Level öffnen (Hashiriya-Menü -> Karriere)
    extensions.hashiriyaBattle_career.openTitle()
  elseif action == 'newGame' then
    showCarSelect = true
  elseif action == 'back' then
    showCarSelect = false
  elseif action == 'chooseCar' then
    for _, car in ipairs(M.carsData.starterCars or {}) do
      if car.id == arg then chooseStarterCar(car) end
    end
  elseif action == 'continue' then
    M.continueCareer()
  elseif action == 'hide' then
    extensions.hashiriyaBattle_shop.releaseFocus()
    showMenu = false
    menuAutoOpened = false
    showDealer = false
    showStats = false
    showLexicon = false
    showLogos = false
    showJobs = false
    if showBoard then showBoard = false pcall(function() extensions.hashiriyaBattle_board.close() end) end
    extensions.hashiriyaBattle_parking.leaveFootShop()
  elseif action == 'dealer' then
    showDealer = true
    showLogos = false
    showMenu = true
    M.sound('dealer')
  elseif action == 'dealerBack' then
    showDealer = false
  elseif action == 'stats' then
    showStats = true
    showLogos = false
    showDealer = false
    showMenu = true
  elseif action == 'statsBack' then
    showStats = false
  elseif action == 'lexicon' then
    showLexicon = true
    showLogos = false
    showStats = false
    showDealer = false
    showMenu = true
  elseif action == 'lexiconBack' then
    showLexicon = false
  elseif action == 'logos' then
    showLogos = true
    showLexicon = false
    showStats = false
    showDealer = false
    showJobs = false
    showMenu = true
  elseif action == 'logosBack' then
    showLogos = false
  elseif action == 'logoPick' then
    extensions.hashiriyaBattle_logos.choose(arg and tostring(arg) or nil)
  elseif action == 'auraPick' then
    extensions.hashiriyaBattle_aura.choose(arg and tostring(arg) or nil)
  elseif action == 'auraMode' then
    extensions.hashiriyaBattle_aura.setMode(arg and tostring(arg) or nil)
  elseif action == 'auraLevel' then
    extensions.hashiriyaBattle_aura.setLevel(tonumber(arg))
  elseif action == 'nickPick' then
    extensions.hashiriyaBattle_progress.chooseNick(arg and tostring(arg) or nil)
  elseif action == 'musicSkip' then
    if extensions.hashiriyaBattle_music then extensions.hashiriyaBattle_music.skip() end
  elseif action == 'musicSource' then
    local id, dir = tostring(arg or ''):match('^([%w_]+)|(-?%d+)$')
    if id and extensions.hashiriyaBattle_music then extensions.hashiriyaBattle_music.cycleSource(id, tonumber(dir)) end
  elseif action == 'musicRescan' then
    if extensions.hashiriyaBattle_music then extensions.hashiriyaBattle_music.rescan() end
  elseif action == 'musicFolder' then
    if extensions.hashiriyaBattle_music then extensions.hashiriyaBattle_music.openFolder() end
  elseif action == 'jobs' then
    showJobs = true
    showLogos = false
    showStats = false
    showDealer = false
    showLexicon = false
    showMenu = true
  elseif action == 'jobsBack' then
    showJobs = false
  elseif action == 'board' then
    -- Schwarzes Brett am PA-Aushang (Taste T, board.interact)
    showBoard = true
    showJobs = false
    showLogos = false
    showStats = false
    showDealer = false
    showLexicon = false
    showMenu = true
  elseif action == 'boardBack' then
    if showBoard then
      showBoard = false
      showMenu = false
      pcall(function() extensions.hashiriyaBattle_board.close() end)
    end
  elseif action == 'boardRead' then
    -- Garagen-PC: Reiter verlassen = alles gelesen
    extensions.hashiriyaBattle_board.markRead()
  elseif action == 'jobAccept' then
    extensions.hashiriyaBattle_jobs.accept(tostring(arg))
    showJobs = false
  elseif action == 'jobCancel' then
    extensions.hashiriyaBattle_jobs.cancel()
  elseif action == 'buyTip' then
    extensions.hashiriyaBattle_jobs.buyTip(tostring(arg))
  elseif action == 'storyNext' then
    extensions.hashiriyaBattle_story.interact()
  elseif action == 'watch' then
    extensions.hashiriyaBattle_home.toggleWatch(tostring(arg))
  elseif action == 'dealerBuy' then
    extensions.hashiriyaBattle_dealer.buy(tonumber(arg))
  elseif action == 'rivalCarBuy' then
    extensions.hashiriyaBattle_dealer.buyRivalCar(tostring(arg))
  elseif action == 'service' then
    -- Wartung (Öl, Kühlwasser, Reifen oder alles), nur in der Garage
    local area = arrivedArea()
    if area and area.type == 'garage' then extensions.hashiriyaBattle_maintenance.service(tostring(arg or 'all')) end
  elseif action == 'switchCar' then
    extensions.hashiriyaBattle_dealer.switchCar(tonumber(arg))
  elseif action == 'nap' then
    extensions.hashiriyaBattle_home.nap()
  elseif action == 'travel' then
    extensions.hashiriyaBattle_travel.go(tostring(arg))
  elseif action == 'sleep' then
    extensions.hashiriyaBattle_home.sleep()
  elseif action == 'homeTab' then
    homeTab = arg
  elseif action == 'fuelHold' then
    extensions.hashiriyaBattle_fuel.setHolding(arg == '1')
  elseif action == 'callRival' then
    extensions.hashiriyaBattle_rivals.spawnNext(true)
  elseif action == 'capture' then
    -- Dev-Menü > Orte (mit Name und Typ); ohne devtools.lua wie früher in captured_positions.json
    if extensions.hashiriyaBattle_devtools then extensions.hashiriyaBattle_devtools.capture(arg)
    else capturePosition() end
  elseif action == 'devMenu' then
    M.toggleDevMenu()
  elseif action == 'titleCamera' then
    M.captureTitleCamera(true)
  elseif action == 'unstuck' then
    M.unstuck()
  elseif action == 'save' then
    extensions.hashiriyaBattle_savepoint.manualSave()
  elseif action == 'savePopupClose' then
    extensions.hashiriyaBattle_savepoint.closePopup()
  elseif action == 'paintSlot' then
    extensions.hashiriyaBattle_shop.setPaintSlot(arg)
  elseif action == 'setPlate' then
    local area = arrivedArea()
    if area and area.type == 'garage' then M.changePlate(tostring(arg or '')) end
  elseif action == 'tow' then
    extensions.hashiriyaBattle_parking.towToGarage()
  elseif action == 'repair' then
    extensions.hashiriyaBattle_parking.repair()
  elseif action == 'dumpParts' then
    extensions.hashiriyaBattle_parking.dumpParts(true)
  elseif action == 'dumpConfigs' then
    M.dumpConfigs()
  elseif action == 'buyPart' then
    -- Shop: fremde Teile erst als Vorschau; Garage: nur Serie/Besitz umrüsten.
    -- Leerer Teilename = Slot leer lassen ("Nicht verbaut").
    local slot, part = tostring(arg or ''):match('^([^|]+)|(.*)$')
    local area = arrivedArea()
    if slot and area and area.type == 'shop' then extensions.hashiriyaBattle_shop.select(slot, part) end
    if slot and area and area.type == 'garage' then extensions.hashiriyaBattle_shop.buy(slot, part, true) end
  elseif action == 'sellPart' then
    -- Alpha 0.8: Teil aus dem Lager verkaufen (Garagen-PC)
    local slot, part = tostring(arg or ''):match('^([^|]+)|(.*)$')
    local area = arrivedArea()
    if slot and area and area.type == 'garage' then extensions.hashiriyaBattle_shop.sellPart(slot, part) end
  elseif action == 'sellCar' then
    local area = arrivedArea()
    if area and area.type == 'garage' then extensions.hashiriyaBattle_dealer.sellCar(tonumber(arg)) end
  elseif action == 'gameOverNew' then
    -- Hardcore: Spielstand nach dem Game-Over-Bildschirm löschen
    local wiped = extensions.hashiriyaBattle_hardcore.wipeAfterGameOver()
    if not wiped then extensions.hashiriyaBattle_dealer.clearGameOver() end
    extensions.hashiriyaBattle_career.openTitle()
    if wiped then msg(M.t('hardcore.wiped'), 8) end
  elseif action == 'buyPaint' then
    local area = arrivedArea()
    if area and area.type == 'shop' then extensions.hashiriyaBattle_shop.selectPaint(tostring(arg)) end
  elseif action == 'paintLive' then
    local area = arrivedArea()
    if area and area.type == 'shop' then extensions.hashiriyaBattle_shop.previewPaintLive(tostring(arg)) end
  elseif action == 'customPaint' then
    local area = arrivedArea()
    if area and area.type == 'shop' then extensions.hashiriyaBattle_shop.selectCustomPaint(tostring(arg)) end
  elseif action == 'focusSlot' then
    if arrivedArea() then extensions.hashiriyaBattle_shop.focusSlot(tostring(arg or '')) end
  elseif action == 'previewBuy' then
    extensions.hashiriyaBattle_shop.confirmPreview()
  elseif action == 'previewCancel' then
    extensions.hashiriyaBattle_shop.cancelPreview()
  elseif action == 'cartRemove' then
    extensions.hashiriyaBattle_shop.removeFromCart(arg)
  elseif action == 'shopTab' then
    extensions.hashiriyaBattle_shop.releaseFocus()
    extensions.hashiriyaBattle_shop.setTab(tostring(arg))
  elseif action == 'garageTab' then
    extensions.hashiriyaBattle_shop.releaseFocus()
    -- Reiter "Teile" ist jetzt der Garagen-PC (Teile-Terminal mit Teilelager)
    local area = arrivedArea()
    if tostring(arg) == 'parts' and area and area.type == 'garage' then
      extensions.hashiriyaBattle_shop.openTerminal('garage')
    else
      garageTab = tostring(arg)
      -- Aufkleber: Sticker-Modus starten (beendet sich selbst, sobald der Reiter zu ist, stickers.onUpdate)
      if garageTab == 'stickers' then extensions.hashiriyaBattle_stickers.start() end
    end
  elseif action == 'stickerSel' then
    extensions.hashiriyaBattle_stickers.select(arg and tostring(arg) or nil)
  elseif action == 'stickerAdj' then
    local what, dir = tostring(arg or ''):match('^(%a+)|(-?%d+)$')
    if what then extensions.hashiriyaBattle_stickers.adjust(what, tonumber(dir)) end
  elseif action == 'stickerView' then
    extensions.hashiriyaBattle_stickers.view(tostring(arg or ''))
  elseif action == 'stickerPlace' then
    extensions.hashiriyaBattle_stickers.place()
  elseif action == 'stickerUndo' then
    extensions.hashiriyaBattle_stickers.removeLast()
  elseif action == 'stickerClear' then
    extensions.hashiriyaBattle_stickers.removeAll()
  elseif action == 'stickerDone' then
    garageTab = 'service'
  elseif action == 'garagePc' then
    local area = arrivedArea()
    if area and area.type == 'garage' then extensions.hashiriyaBattle_shop.openTerminal('garage') end
  elseif action == 'termHello' or action == 'termCatalog' then
    extensions.hashiriyaBattle_shop.sendCatalog()
  elseif action == 'termCat' then
    extensions.hashiriyaBattle_shop.setCategory(arg)
  elseif action == 'termView' then
    extensions.hashiriyaBattle_shop.setView(arg)
  elseif action == 'termXray' then
    extensions.hashiriyaBattle_shop.toggleXray()
  elseif action == 'termRotate' then
    extensions.hashiriyaBattle_shop.rotate(tonumber(arg) or 1)
  elseif action == 'termMount' then
    extensions.hashiriyaBattle_shop.toggleMount()
  elseif action == 'termClose' then
    if extensions.hashiriyaBattle_shop.terminalMode() == 'shop' then
      -- wie "Shop verlassen": aussteigen, am Eingang stehen
      extensions.hashiriyaBattle_shop.closeTerminal()
      extensions.hashiriyaBattle_parking.leaveFootShop()
    else
      extensions.hashiriyaBattle_shop.closeTerminal()
    end
  elseif action == 'setupAdjust' then
    local name, dir = tostring(arg or ''):match('^(.+)|([%-%d]+)$')
    local area = arrivedArea()
    if name and area and area.type == 'garage' then extensions.hashiriyaBattle_setup.adjust(name, tonumber(dir) or 1) end
  elseif action == 'setupCat' then
    extensions.hashiriyaBattle_setup.toggleCategory(tostring(arg))
  elseif action == 'setupApply' then
    local area = arrivedArea()
    if area and area.type == 'garage' then extensions.hashiriyaBattle_setup.apply() end
  elseif action == 'setupDefaults' then
    extensions.hashiriyaBattle_setup.resetDefaults()
  elseif action == 'setupDiscard' then
    extensions.hashiriyaBattle_setup.discard()
  elseif action == 'cheatMoney' then
    -- Nur zum Testen
    if M.save then
      M.save.money = M.save.money + 1000000
      M.writeSave()
    end
  elseif action == 'cheatWins' then
    -- Nur zum Testen: +1 Sieg (schaltet Tuning-Stufen frei)
    if M.save then
      M.save.wins = (M.save.wins or 0) + 1
      M.writeSave()
    end
  elseif action == 'devSpawnRival' then
    -- Nur zum Testen: bestimmten Rivalen spawnen (ID oder Name), ohne Bedingungen
    local r
    if arg == '__random' then
      -- Zufälliger Rivale, der gerade nicht unterwegs ist
      local rv = extensions.hashiriyaBattle_rivals
      local onRoad, list = {}, {}
      for _, e in ipairs(rv.getOnRoad()) do onRoad[e.data.id] = true end
      for _, x in ipairs((rv.getData() or {}).rivals or {}) do if not onRoad[x.id] then table.insert(list, x) end end
      r = list[math.random(1, math.max(#list, 1))]
    else
      r = extensions.hashiriyaBattle_rivals.findRival(arg)
    end
    if r then extensions.hashiriyaBattle_rivals.spawnNext(true, r)
    else M.msg(M.t('msg.devNoRival', tostring(arg or '')), 3) end
  elseif action == 'devBeatRival' then
    -- Nur zum Testen: Rivalen als geschlagen markieren (für Leader, Wanderer-Bedingungen, Bosse)
    local r = extensions.hashiriyaBattle_rivals.findRival(arg)
    if r and M.save then
      M.save.defeated = M.save.defeated or {}
      M.save.defeated[r.id] = true
      if r.final then M.save.finalBeaten = true end
      M.writeSave()
      M.msg(M.t('msg.devBeaten', r.name), 3)
    else M.msg(M.t('msg.devNoRival', tostring(arg or '')), 3) end
  elseif action == 'cheatRep' then
    if M.save then
      M.save.rep = (M.save.rep or 0) + 500
      M.writeSave()
    end
  elseif action == 'devUnlock' then
    -- Entwickler-Werkzeug: Freischalt-Meldung (UI-App HashiriyaUnlock) ansehen, ohne etwas freizuschalten
    extensions.hashiriyaBattle_shop.devShowUnlock(arg)
  elseif action == 'cheatHour' then
    local home = extensions.hashiriyaBattle_home
    local h = home.hour() or 0
    home.applyClock(arg == 'night' and 22 or ((math.floor(h) + 1) % 24))
  elseif action == 'cheatDay' then
    if M.save then
      M.save.day = (M.save.day or 1) + 1
      M.writeSave()
      M.msg(M.t('home.day', M.save.day), 3)
    end
  elseif action == 'cheatRepair' then
    local veh = M.getPlayerVehicle()
    if veh then
      extensions.hashiriyaBattle_fuel.keepAfterRespawn()
      extensions.hashiriyaBattle_damage.clear()
      veh:queueLuaCommand('obj:requestReset(RESET_PHYSICS)')
    end
  elseif action == 'cheatFuel' then
    extensions.hashiriyaBattle_fuel.devFill()
  elseif action == 'builder' then
    -- Entwickler-Werkzeug: Crews, Wanderer und Bosse bearbeiten (UI-App HashiriyaBuilder)
    if extensions.hashiriyaBattle_builder then extensions.hashiriyaBattle_builder.open()
    else M.msg('Builder fehlt (builder.lua nicht im Mod)', 4) end
  elseif action == 'devTalkRespawn' then
    extensions.hashiriyaBattle_talk.respawn()
    msg(M.t('msg.devTalkRespawn'), 3)
  elseif action == 'devClearRivals' then
    extensions.hashiriyaBattle_rivals.despawnAll()
  elseif action == 'toggleMarkers' then
    extensions.hashiriyaBattle_parking.setMarkersEnabled(not extensions.hashiriyaBattle_parking.markersEnabled())
  elseif action == 'photoMode' then
    extensions.hashiriyaBattle_parking.setPhotoMode(arg == 'true')
  elseif action == 'setLanguage' then
    M.setLanguage(arg)
  elseif action == 'stop' then
    if not extensions.hashiriyaBattle_hardcore.wipeAfterGameOver() then M.stopGame() end
  elseif action == 'report' then
    -- Fehlerbericht für den Entwickler (alle Infos in einer Datei)
    local path = extensions.hashiriyaBattle_logger.writeReport(arg)
    msg(path and M.t('msg.reportSaved', 'BeamNG-Userordner/' .. path) or M.t('msg.reportFailed'), 10)
  end
  M.sendUiState()
end

-- Dev-Menü (eigenes Fenster, UI-App HashiriyaDev), Taste Shift+Ende. Fehlt im Release.
function M.toggleDevMenu()
  if M.isRelease() then return end
  if extensions.hashiriyaBattle_devtools then extensions.hashiriyaBattle_devtools.toggle()
  else msg('Dev-Menü fehlt (devtools.lua nicht im Mod)', 4) end
end

-- Befreien (Taste Shift+U oder Kachel im Menü): festgehangen an Leitplanke/Objekt, ein Stück zurück. Siehe unstuck.lua.
function M.unstuck()
  if extensions.hashiriyaBattle_unstuck then extensions.hashiriyaBattle_unstuck.unstuck() end
  M.sendUiState()
end

function M.skipMusic()
  if extensions.hashiriyaBattle_music then extensions.hashiriyaBattle_music.skip() end
end

function M.toggleMenu()
  showMenu = not showMenu
  if not showMenu then extensions.hashiriyaBattle_shop.releaseFocus() end
  M.sendUiState()
end

-- Hooks -----------------------------------------------------------------------

local function onExtensionLoaded()
  -- Builder, Dev-Menü und Gegner-Garage (Entwickler-Werkzeuge) nur laden, wenn die Datei da ist (fehlen im Release-Zip)
  for file, ext in pairs({ ['builder.lua'] = 'hashiriyaBattle_builder', ['devtools.lua'] = 'hashiriyaBattle_devtools', ['garagetool.lua'] = 'hashiriyaBattle_garagetool' }) do
    if FS:fileExists('/lua/ge/extensions/hashiriyaBattle/' .. file) then
      local has = false
      for _, n in ipairs(subExtensions) do if n == ext then has = true end end
      if not has then table.insert(subExtensions, ext) end
    end
  end
  for _, name in ipairs(subExtensions) do
    extensions.load(name)
    setExtensionUnloadMode(name, 'manual')
    if name == 'hashiriyaBattle_logger' then extensions.hashiriyaBattle_logger.start() end
  end
  -- Fehler in Hooks und UI-Aktionen landen mit Traceback und Spielzustand in hashiriya.log
  local logger = extensions.hashiriyaBattle_logger
  logger.protect('hashiriyaBattle_core')
  for _, name in ipairs(subExtensions) do
    if name ~= 'hashiriyaBattle_logger' then logger.protect(name) end
  end
  loadLanguage(detectLanguage())
  loadData()
  log('I', logTag, 'Hashiriya Battle geladen')
end

-- Missionen der Map ausblenden (Map-Datei bleibt unverändert): maps/<level>.json "disabledMissionTypes".
-- Nutzt dieselben Overrides wie die BeamNG-Karriere (gameplay_missions_unlocks), danach werden die POIs neu aufgebaut.
local hiddenMissions = {}
local function applyMissionFilter()
  local types = {}
  for _, t in ipairs(M.mapData and M.mapData.disabledMissionTypes or {}) do types[t] = true end
  local mm = rawget(_G, 'gameplay_missions_missions') or extensions.gameplay_missions_missions
  local un = rawget(_G, 'gameplay_missions_unlocks') or extensions.gameplay_missions_unlocks
  if not next(types) or not mm or not un or not un.overrideVisible then return end
  local ok, err = pcall(function()
    local found, hidden = {}, {}
    for _, m in ipairs(mm.getMissionsOfLevel(M.levelName) or {}) do
      local mt = tostring(m.missionType)
      found[mt] = (found[mt] or 0) + 1
      if types[mt] then
        un.overrideVisible(m, false)
        un.overrideStartable(m, false)
        hiddenMissions[m.id] = m
        hidden[mt] = (hidden[mt] or 0) + 1
      end
    end
    local list = {}
    for mt, n in pairs(found) do table.insert(list, mt .. '=' .. n .. (hidden[mt] and ' (aus)' or '')) end
    table.sort(list)
    log('I', logTag, 'Missionen auf ' .. tostring(M.levelName) .. ': ' .. (#list > 0 and table.concat(list, ', ') or 'keine'))
  end)
  if not ok then log('W', logTag, 'Missionen ausblenden fehlgeschlagen: ' .. tostring(err)) end
  local rp = rawget(_G, 'gameplay_rawPois') or extensions.gameplay_rawPois
  if rp and rp.clear then pcall(rp.clear) end
end

local function clearMissionFilter()
  local un = rawget(_G, 'gameplay_missions_unlocks') or extensions.gameplay_missions_unlocks
  if un and un.overrideVisible then
    for _, m in pairs(hiddenMissions) do
      pcall(un.overrideVisible, m, nil)
      pcall(un.overrideStartable, m, nil)
    end
  end
  hiddenMissions = {}
end

-- Lohn für Tagesjobs (BeamNG-Missionen wie Garage2Garage): world.json "jobRewards" je Missionstyp, in Yen.
-- passed = Mission geschafft, completed = alle Sterne. Dieselbe Mission am selben Spieltag nochmal: mal repeatFactor.
local function onMissionAttemptAggregated(attempt, mission)
  if not M.active or not M.save or not attempt or not mission then return end
  local w = jsonReadFile(dataDir .. 'world.json') or {}
  local cfg = (w.jobRewards or {})[tostring(mission.missionType)]
  if type(cfg) ~= 'table' then return end
  local base = attempt.type == 'completed' and cfg.completed or (attempt.type == 'passed' and cfg.passed or nil)
  if not base then
    log('I', logTag, 'Job nicht geschafft: ' .. tostring(mission.id) .. ' (' .. tostring(attempt.type) .. ')')
    return
  end
  M.save.jobsToday = M.save.jobsToday or {}
  local day = M.save.day or 1
  if M.save.jobsToday.day ~= day then M.save.jobsToday = { day = day, done = {} } end
  local runs = M.save.jobsToday.done[mission.id] or 0
  local reward = math.floor(base * ((cfg.repeatFactor or 0.5) ^ runs) / 100 + 0.5) * 100
  M.save.jobsToday.done[mission.id] = runs + 1
  M.save.money = (M.save.money or 0) + reward
  M.save.jobs = (M.save.jobs or 0) + 1
  log('I', logTag, string.format('Job-Lohn: %s %s, %d. Mal heute, +%d Yen', tostring(mission.id), attempt.type, runs + 1, reward))
  msg(M.t('msg.jobPaid', M.economy().formatYen(reward)), 6)
  M.writeSave()
end
M.onMissionAttemptAggregated = onMissionAttemptAggregated

local function onClientPostStartMission()
  loadData()
  applyMissionFilter()
  trafficStarted = false
  trafficRetry, trafficTries = nil, 0
  M.active = false
  showMenu = true
  showCarSelect = false
  setLayout(M.layoutName)
  if not jsonReadFile(dumpPath) then pcall(M.dumpConfigs) end
  if extensions.hashiriyaBattle_career.isPending() then
    extensions.hashiriyaBattle_career.onLevelReady()
  else
    msg(M.t('msg.ready'), 8)
  end
end

local function onClientEndMission()
  M.stopGame()
  clearMissionFilter()
end

-- Release-Build (data/build.json "release": true): Sperren wie in der BeamNG-Karriere, siehe release.lua.
-- Missionen, die die Map ausblenden soll, bleiben ausgeblendet (andere Extensions setzen die Overrides manchmal zurück).
local missionCheckTimer = 5
local function checkMissionFilter(dtReal)
  missionCheckTimer = missionCheckTimer - dtReal
  if missionCheckTimer > 0 then return end
  missionCheckTimer = 5
  local un = rawget(_G, 'gameplay_missions_unlocks')
  if not un or not un.isMissionVisible then return end
  for _, m in pairs(hiddenMissions) do
    local ok, visible = pcall(un.isMissionVisible, m)
    if ok and visible then
      log('I', logTag, 'Ausgeblendete Missionen waren wieder sichtbar, Filter neu gesetzt')
      applyMissionFilter()
      return
    end
  end
end

-- POIs der großen Karte: ausgeblendete Missionstypen auch dann weglassen, wenn eine Mission sie trotzdem meldet.
-- Im Release außerdem keine Schnellreise: Quicktravel-Punkte (spawnPoint) fliegen raus, und allen anderen POIs
-- fehlt die Schnellreise-Funktion, dann zeigt die Karte keinen "Quick Travel"-Knopf (wie in der BeamNG-Karriere).
local function onGetRawPoiListForLevel(levelIdentifier, elements)
  if not M.active or type(elements) ~= 'table' then return end
  local release = M.isRelease() and (M.buildData or {}).blockBigMapTeleport ~= false
  for i = #elements, 1, -1 do
    local e = elements[i]
    if type(e) == 'table' and type(e.data) == 'table' then
      if (e.data.type == 'mission' and hiddenMissions[e.data.missionId]) or (release and e.data.type == 'spawnPoint') then
        table.remove(elements, i)
      elseif release and type(e.markerInfo) == 'table' and type(e.markerInfo.bigmapMarker) == 'table' then
        e.markerInfo.bigmapMarker.quickTravelPosRotFunction = nil
      end
    end
  end
  -- Haupt-PAs mit Vorschaubild (travel.lua); Schnellreise dorthin nur in der Dev-Version
  local okT, errT = pcall(function() extensions.hashiriyaBattle_travel.addPois(elements) end)
  if not okT then log('W', logTag, 'Haupt-PAs auf der Karte: ' .. tostring(errT)) end
end

local function onUpdate(dtReal)
  extensions.hashiriyaBattle_release.update(dtReal, M.active and M.isRelease(), M.buildData)
  if M.active then checkMissionFilter(dtReal) end
  if engineOffTimer > 0 then engineOffTimer = engineOffTimer - dtReal end
  if not M.levelName then return end
  updateTrafficRetry(dtReal)
  if M.active and trafficStarted then updateTrafficDensity(dtReal) end
  uiTimer = uiTimer - dtReal
  if uiTimer <= 0 then
    -- beim Tanken öfter aktualisieren, damit Liter und Preis flüssig mitlaufen
    uiTimer = extensions.hashiriyaBattle_fuel.isHolding() and 0.1 or uiInterval
    M.sendUiState()
  end
end

M.onExtensionLoaded = onExtensionLoaded
M.onClientPostStartMission = onClientPostStartMission
M.onClientEndMission = onClientEndMission
M.onUpdate = onUpdate
M.onGetRawPoiListForLevel = onGetRawPoiListForLevel
M.onVehicleSpawned = onVehicleSpawned

return M
