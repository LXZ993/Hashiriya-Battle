-- Hashiriya Battle: Kern (Spielstand, Start, Menüs)
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local dataDir = '/lua/ge/extensions/hashiriyaBattle/data/'
local saveDir = 'settings/hashiriya_battle/'
local savePath = saveDir .. 'save.json'
local capturePath = saveDir .. 'captured_positions.json'

local subExtensions = { 'hashiriyaBattle_logger', 'hashiriyaBattle_plates', 'hashiriyaBattle_economy', 'hashiriyaBattle_rivals', 'hashiriyaBattle_driver', 'hashiriyaBattle_battle', 'hashiriyaBattle_parking', 'hashiriyaBattle_shop', 'hashiriyaBattle_setup', 'hashiriyaBattle_career', 'hashiriyaBattle_home', 'hashiriyaBattle_fuel', 'hashiriyaBattle_dealer', 'hashiriyaBattle_progress', 'hashiriyaBattle_style', 'hashiriyaBattle_condition' }

M.active = false -- läuft der Modus gerade?
M.save = nil
M.carsData = nil
M.mapData = nil
M.levelName = nil

local showMenu = true
local showDealer = false   -- Autohändler (aus dem Menü links)
local showStats = false    -- Statistik (aus dem Menü links)
local showLexicon = false  -- Rivalen-Lexikon (aus dem Menü links, überall)
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
function M.getPlayerVehicle()
  local veh = getPlayerVehicle and getPlayerVehicle(0) or be:getPlayerVehicle(0)
  if veh and veh:getJBeamFilename() == 'unicycle' then return nil end
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
  jsonWriteFile(savePath, M.save, true)
  M.hasSave = true
  log('I', logTag, 'Spielstand gespeichert')
end

local function readSave()
  local data = jsonReadFile(savePath)
  if data and data.version then return data end
  return nil
end
M.peekSave = readSave

-- Daten laden ---------------------------------------------------------------

local function loadData()
  M.carsData = jsonReadFile(dataDir .. 'cars.json') or { starterCars = {} }
  M.buildData = jsonReadFile(dataDir .. 'build.json') or {}
  M.levelName = getLevelName()
  M.hasSave = readSave() ~= nil
  M.mapData = M.levelName and jsonReadFile(dataDir .. 'maps/' .. M.levelName .. '.json') or nil
  log('I', logTag, 'Level: ' .. tostring(M.levelName) .. ', Map-Daten: ' .. tostring(M.mapData ~= nil))
end

-- Auto des Spielers ---------------------------------------------------------

-- Motor aus nach dem Spawnen (wie beim Autokauf in der BeamNG-Karriere).
-- Gilt für das nächste Auto, das innerhalb kurzer Zeit spawnt (auch replaceVehicle).
local engineOffTimer = 0
function M.engineOffAfterSpawn()
  engineOffTimer = 3
  extensions.hashiriyaBattle_fuel.keepAfterRespawn()
  extensions.hashiriyaBattle_condition.keepAfterRespawn()
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

local function trafficGroup()
  local path = M.carsData and M.carsData.trafficGroup
  if not path or path == '' then return nil end
  local g = jsonReadFile(path)
  local list = g and g.data
  if type(list) ~= 'table' or not list[1] then return nil end
  -- nur Autos, deren Modell es gibt (Agent-Mod deaktiviert -> Vanilla-Verkehr)
  local okM, m = pcall(core_vehicles.getModel, list[1].model)
  if not okM or not m or not m.model then return nil end
  return list
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
    M.trafficTotal, M.trafficActive = n, nil
    return
  end
  local amount = M.carsData and tonumber(M.carsData.trafficAmount) or -1
  local parked = M.carsData and tonumber(M.carsData.parkedAmount) or -1
  local tOpts, pOpts = { police = false }, {}
  local group = trafficGroup()
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
  if group then
    local ms = rawget(_G, 'core_multiSpawn') or extensions.core_multiSpawn
    local okF, fitted = pcall(function() return ms and ms.fitGroup and ms.fitGroup(group, n) end)
    tOpts.vehGroup = okF and fitted or group
    pOpts.vehGroup = group
  end
  local ok, err = pcall(tr.setupTrafficHelper, n, tOpts, parked, pOpts)
  if ok then
    trafficRetry, trafficTries = nil, 0
    log('I', logTag, 'Verkehr gestartet' .. (group and ' (Agent Traffic JP)' or ''))
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
  local target = math.max(1, math.floor(M.trafficTotal * pct / 100 + 0.5))
  if target == M.trafficActive then return end
  local tr = rawget(_G, 'gameplay_traffic')
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
  M.save = newSave()
  M.save.playerName = data.playerName
  M.save.experience = data.experience
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
  extensions.hashiriyaBattle_condition.initUsedCar(data.car, data.condition, veh)
  -- Aus dem Showroom in die Garagenbucht
  if veh and extensions.hashiriyaBattle_parking.hasShowroom() then
    local pos, rot = extensions.hashiriyaBattle_parking.spawnTransform(extensions.hashiriyaBattle_parking.find('garage'))
    if pos then
      local ok = pcall(function() spawn.safeTeleport(veh, pos, rot) end)
      if not ok then veh:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w) end
    end
  end
  extensions.hashiriyaBattle_home.applyClock(extensions.hashiriyaBattle_home.world().startHour)
  M.writeSave()
  M.active = true
  showCarSelect = false
  showMenu = false
  msg(M.t('msg.welcomeDriver', data.playerName or ''), 8)
end

-- Weiterspielen: Auto in die Garagenbucht stellen, Spieler zu Fuß daneben.
function M.continueCareer()
  M.save = readSave()
  if not M.save then
    msg(M.t('msg.noSave'))
    return
  end
  extensions.hashiriyaBattle_parking.loadSettings(M.save)
  extensions.hashiriyaBattle_shop.loadSettings(M.save)
  extensions.hashiriyaBattle_condition.syncStarterWear(M.save)
  local car = M.save.cars[M.save.activeCar or 1]
  if not car then return end
  local opts = { config = plateConfig(car), licenseText = car.plate, autoEnterVehicle = false }
  local pos, rot = extensions.hashiriyaBattle_parking.spawnTransform(extensions.hashiriyaBattle_parking.find('garage'))
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
  M.goOnFoot(carVeh)
  M.startTraffic()
end

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
  if M.active then M.writeSave() end
  M.active = false
  extensions.hashiriyaBattle_battle.reset()
  extensions.hashiriyaBattle_rivals.despawnAll()
end

-- Parkplätze (vom Parking-Modul aufgerufen) --------------------------------

function M.onParkingArrived(area)
  extensions.hashiriyaBattle_style.onParkingArrived(area)
  showMenu = true
  menuAutoOpened = true
  msg(M.t('msg.enterPa', M.t('pa.' .. area.type)), 4)
  if area.type == 'garage' then M.writeSave() end
  -- Shop zu Fuß: gleich das Teile-Terminal
  if area.type == 'shop' and extensions.hashiriyaBattle_parking.isFootShop() then extensions.hashiriyaBattle_shop.openTerminal('shop') end
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
  if won then
    -- rivals.json settings.rewardScale: Preisgeld aller Rivalen auf einmal anpassen (1 = volle rewardUsd)
    local rs = extensions.hashiriyaBattle_rivals.getData()
    local scale = tonumber(rs and rs.settings and rs.settings.rewardScale) or 1
    local reward
    local exact = tonumber(rival.rewardYen)
    if exact and exact > 0 then
      -- rewardYen: genauer Yen-Betrag (z. B. 777777), ohne Umrechnung, Rundung, rewardScale und Serien-Bonus
      reward = math.floor(exact)
    else
      reward = math.floor(M.economy().usdToPrice(rival.rewardUsd or 1000) * scale * moneyF / 100 + 0.5) * 100
    end
    M.save.money = M.save.money + reward
    M.save.defeated[rival.id] = true
    M.save.wins = M.save.wins + 1
    msg(M.t('msg.win', rival.name, M.economy().formatYen(reward)), 6)
    if streak >= 2 then msg(M.t('msg.streak', streak, math.floor((moneyF - 1) * 100 + 0.5)), 4) end
    extensions.hashiriyaBattle_progress.leaderHint(rival)
  else
    M.save.losses = M.save.losses + 1
    msg(M.t('msg.lose', rival.name), 6)
  end
  M.writeSave()
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

-- Titelbild-Kamera: aktuelle Kamera (z. B. Freecam) und Uhrzeit merken, Taste Shift+Pos1.
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

function M.captureTitleCamera()
  if M.isRelease() then return end
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

local devRivals = nil -- Dev-Tool: Liste aller Rivalen für die Eingabe im Menü

function M.resetDevRivals() devRivals = nil end

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
    st.radar = extensions.hashiriyaBattle_rivals.radarInfo(600)
    st.battle = extensions.hashiriyaBattle_battle.getHudState()
    st.style = extensions.hashiriyaBattle_style.getHudState()
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
      st.nap = { can = nap.can, reason = nap.reason and M.t('msg.nap.' .. nap.reason) or nil }
    end
    st.day = extensions.hashiriyaBattle_home.dayText()
    st.clock = extensions.hashiriyaBattle_home.clockInfo()
    st.watch = extensions.hashiriyaBattle_home.watchHud()
    st.progress = extensions.hashiriyaBattle_progress.getUiState()
    st.night = extensions.hashiriyaBattle_home.isNight()
    local left = extensions.hashiriyaBattle_rivals.battlesLeftTonight()
    if st.night and left then st.battlesLeft = left end
    if showLexicon then
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
      st.platePrice = eco.formatYen(platePriceYen)
      local cost = parking.repairCost()
      st.repairCost = cost > 0 and eco.formatYen(cost) or nil
      st.canAffordRepair = cost <= M.save.money
      if area.type == 'home' then
        st.home = extensions.hashiriyaBattle_home.getUiState(homeTab)
      end
      if area.type == 'gas' then st.gas = extensions.hashiriyaBattle_fuel.getUiState() end
      if area.type == 'garage' then st.garageCars = extensions.hashiriyaBattle_dealer.ownedCars() end
      if area.type == 'garage' then
        st.garageTab = garageTab
        if garageTab == 'setup' then st.setup = extensions.hashiriyaBattle_setup.getUiState() end
      end
    end
  end
  st.terminal = M.active and M.save and extensions.hashiriyaBattle_shop.terminalState() or nil
  st.release = M.isRelease()
  if st.menuVisible and M.active and not st.release then
    devRivals = devRivals or {}
    if #devRivals == 0 then
      local data = extensions.hashiriyaBattle_rivals.getData() or {}
      local teamName = {}
      for _, t in ipairs(data.teams or {}) do teamName[t.id] = t.name end
      for _, r in ipairs(data.rivals or {}) do
        local tag = r.boss and M.t('home.bosses') or r.wanderer and M.t('home.wanderer') or teamName[r.team] or ''
        if r.leader then tag = tag .. ' (Leader)' end
        table.insert(devRivals, { id = r.id, name = r.name, tag = tag })
      end
    end
    st.devRivals = devRivals
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
local backActions = { back = true, hide = true, previewCancel = true, setupDiscard = true }

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
  cheatRepair = true, cheatFuel = true, devSpawnRival = true, devBeatRival = true, devClearRivals = true,
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
    extensions.hashiriyaBattle_parking.leaveFootShop()
  elseif action == 'dealer' then
    showDealer = true
    showMenu = true
    M.sound('dealer')
  elseif action == 'dealerBack' then
    showDealer = false
  elseif action == 'stats' then
    showStats = true
    showDealer = false
    showMenu = true
  elseif action == 'statsBack' then
    showStats = false
  elseif action == 'lexicon' then
    showLexicon = true
    showStats = false
    showDealer = false
    showMenu = true
  elseif action == 'lexiconBack' then
    showLexicon = false
  elseif action == 'watch' then
    extensions.hashiriyaBattle_home.toggleWatch(tostring(arg))
  elseif action == 'dealerBuy' then
    extensions.hashiriyaBattle_dealer.buy(tonumber(arg))
  elseif action == 'switchCar' then
    extensions.hashiriyaBattle_dealer.switchCar(tonumber(arg))
  elseif action == 'nap' then
    extensions.hashiriyaBattle_home.nap()
  elseif action == 'sleep' then
    extensions.hashiriyaBattle_home.sleep()
  elseif action == 'homeTab' then
    homeTab = arg
  elseif action == 'fuelHold' then
    extensions.hashiriyaBattle_fuel.setHolding(arg == '1')
  elseif action == 'callRival' then
    extensions.hashiriyaBattle_rivals.spawnNext(true)
  elseif action == 'capture' then
    capturePosition()
  elseif action == 'save' then
    M.writeSave()
    msg(M.t('msg.saved'))
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
    end
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
      veh:queueLuaCommand('obj:requestReset(RESET_PHYSICS)')
    end
  elseif action == 'cheatFuel' then
    extensions.hashiriyaBattle_fuel.devFill()
  elseif action == 'builder' then
    -- Entwickler-Werkzeug: Crews, Wanderer und Bosse bearbeiten (UI-App HashiriyaBuilder)
    if extensions.hashiriyaBattle_builder then extensions.hashiriyaBattle_builder.open()
    else M.msg('Builder fehlt (builder.lua nicht im Mod)', 4) end
  elseif action == 'devClearRivals' then
    extensions.hashiriyaBattle_rivals.despawnAll()
  elseif action == 'toggleMarkers' then
    extensions.hashiriyaBattle_parking.setMarkersEnabled(not extensions.hashiriyaBattle_parking.markersEnabled())
  elseif action == 'photoMode' then
    extensions.hashiriyaBattle_parking.setPhotoMode(arg == 'true')
  elseif action == 'setLanguage' then
    M.setLanguage(arg)
  elseif action == 'stop' then
    M.stopGame()
  elseif action == 'report' then
    -- Fehlerbericht für den Entwickler (alle Infos in einer Datei)
    local path = extensions.hashiriyaBattle_logger.writeReport(arg)
    msg(path and M.t('msg.reportSaved', 'BeamNG-Userordner/' .. path) or M.t('msg.reportFailed'), 10)
  end
  M.sendUiState()
end

function M.toggleMenu()
  showMenu = not showMenu
  if not showMenu then extensions.hashiriyaBattle_shop.releaseFocus() end
  M.sendUiState()
end

-- Hooks -----------------------------------------------------------------------

local function onExtensionLoaded()
  -- Builder (Entwickler-Werkzeug) nur laden, wenn die Datei da ist (fehlt im Release-Zip)
  if FS:fileExists('/lua/ge/extensions/hashiriyaBattle/builder.lua') then
    local has = false
    for _, n in ipairs(subExtensions) do if n == 'hashiriyaBattle_builder' then has = true end end
    if not has then table.insert(subExtensions, 'hashiriyaBattle_builder') end
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

-- Release-Build (data/build.json): Zurücksetzen, Konsole, Editor, Zeitlupe usw. während der Karriere sperren.
-- Gleicher Weg wie die BeamNG-Karriere (core_input_actionFilter).
local restrictionsOn = false
local function updateRestrictions()
  local want = M.active and M.buildData and M.buildData.release == true or false
  if want == restrictionsOn then return end
  local af = rawget(_G, 'core_input_actionFilter') or (extensions and extensions.core_input_actionFilter)
  if not af or not af.setGroup or not af.addAction then
    if want then log('W', logTag, 'core_input_actionFilter fehlt, Sperren nicht aktiv') end
    restrictionsOn = want
    return
  end
  local ok, err = pcall(function()
    if want then af.setGroup('hashiriyaBlocked', M.buildData.blockedActions or {}) end
    af.addAction(0, 'hashiriyaBlocked', want)
  end)
  restrictionsOn = want
  log(ok and 'I' or 'W', logTag, 'Release-Sperren ' .. (want and 'an' or 'aus') .. (ok and '' or (': ' .. tostring(err))))
  -- Node Grabber: feste, realistische Stärke
  if want and M.buildData.nodeGrabberStrength then
    pcall(function() be.nodeGrabber:setStrength(M.buildData.nodeGrabberStrength) end)
  end
  -- Schnellreise über die große Karte (freeroam_bigMapMode.teleportToPoi) sperren, solange die Karriere läuft
  local bm = rawget(_G, 'freeroam_bigMapMode')
  if bm and bm.teleportToPoi and M.buildData.blockBigMapTeleport ~= false then
    if want and not M.origTeleportToPoi then
      M.origTeleportToPoi = bm.teleportToPoi
      bm.teleportToPoi = function() msg(M.t('msg.noQuickTravel'), 3) end
    elseif not want and M.origTeleportToPoi then
      bm.teleportToPoi = M.origTeleportToPoi
      M.origTeleportToPoi = nil
    end
  end
end

local function onUpdate(dtReal)
  updateRestrictions()
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
M.onVehicleSpawned = onVehicleSpawned

return M
