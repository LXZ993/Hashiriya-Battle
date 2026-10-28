-- Hashiriya Battle: Kern (Spielstand, Start, Menüs)
local M = {}

local logTag = 'hashiriya'

local dataDir = '/lua/ge/extensions/hashiriyaBattle/data/'
local saveDir = 'settings/hashiriya_battle/'
local savePath = saveDir .. 'save.json'
local capturePath = saveDir .. 'captured_positions.json'

local subExtensions = { 'hashiriyaBattle_economy', 'hashiriyaBattle_rivals', 'hashiriyaBattle_battle', 'hashiriyaBattle_parking', 'hashiriyaBattle_shop', 'hashiriyaBattle_setup', 'hashiriyaBattle_career' }

M.active = false -- läuft der Modus gerade?
M.save = nil
M.carsData = nil
M.mapData = nil
M.levelName = nil

local showMenu = true
local showCarSelect = false
local platePriceYen = 15000 -- Kennzeichen ummelden
local garageTab = 'service' -- Garage-Reiter: service, parts, setup
local menuAutoOpened = false -- Menü wurde vom Parkplatz geöffnet und schließt sich beim Wegfahren

-- Hilfsfunktionen -----------------------------------------------------------

local function msg(text, ttl)
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

-- Position des Spielers zu Fuß (nil, wenn er im Auto sitzt)
function M.getWalkerPos()
  local veh = getPlayerVehicle and getPlayerVehicle(0) or be:getPlayerVehicle(0)
  if veh and veh:getJBeamFilename() == 'unicycle' then return veh:getPosition() end
  return nil
end

-- Spieler steigt aus und steht zu Fuß am Startpunkt neben der Garage; das Auto bleibt in der Bucht.
function M.goOnFoot(carVeh)
  local pos, rot = extensions.hashiriyaBattle_parking.footSpawnTransform()
  local w = walk()
  if not w or not pos then return end
  if carVeh then M.carVehId = carVeh:getID() end
  local ok, err = pcall(w.setWalkingMode, true, pos, rot, true)
  if not ok then log('W', logTag, 'Zu Fuß starten fehlgeschlagen: ' .. tostring(err)) end
end

function M.economy() return extensions.hashiriyaBattle_economy end

-- Spielstand ----------------------------------------------------------------

function M.startMoney()
  return M.carsData and M.carsData.startMoneyYen or 5000000
end

local function newSave()
  return {
    version = 1,
    money = M.startMoney(),
    cars = {},
    activeCar = nil,
    defeated = {},
    wins = 0,
    losses = 0,
  }
end

function M.writeSave()
  if not M.save then return end
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
  M.levelName = getLevelName()
  M.hasSave = readSave() ~= nil
  M.mapData = M.levelName and jsonReadFile(dataDir .. 'maps/' .. M.levelName .. '.json') or nil
  log('I', logTag, 'Level: ' .. tostring(M.levelName) .. ', Map-Daten: ' .. tostring(M.mapData ~= nil))
end

-- Auto des Spielers ---------------------------------------------------------

-- Motor aus nach dem Spawnen (wie beim Autokauf in der BeamNG-Karriere).
-- Gilt für das nächste Auto, das innerhalb kurzer Zeit spawnt (auch replaceVehicle).
local engineOffTimer = 0
function M.engineOffAfterSpawn() engineOffTimer = 3 end

local function onVehicleSpawned(vehId)
  if engineOffTimer <= 0 then return end
  local veh = be:getObjectByID(vehId)
  if not veh or veh:getJBeamFilename() == 'unicycle' then return end
  engineOffTimer = 0
  pcall(function() core_vehicleBridge.executeAction(veh, 'setIgnitionLevel', 0) end)
end

-- Verkehr: Freeroam startet ihn in 0.40 nur über den Freeroam-Startbildschirm, darum selbst einschalten.
local trafficStarted = false
function M.startTraffic()
  if trafficStarted or (M.carsData and M.carsData.careerTraffic == false) then return end
  local tr = rawget(_G, 'gameplay_traffic')
  if not tr or not tr.setupTrafficHelper then return end
  local okL, list = pcall(function() return tr.getTrafficList and tr.getTrafficList() end)
  trafficStarted = true
  if okL and type(list) == 'table' and next(list) then return end -- läuft schon
  local amount = M.carsData and tonumber(M.carsData.trafficAmount) or -1
  local ok, err = pcall(tr.setupTrafficHelper, amount, { police = false }, 0, {})
  if ok then log('I', logTag, 'Verkehr gestartet') else log('W', logTag, 'Verkehr starten fehlgeschlagen: ' .. tostring(err)) end
end

local function spawnPlayerCar(car)
  M.engineOffAfterSpawn()
  local opts = { config = car.config ~= '' and car.config or nil, licenseText = car.plate }
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

local function chooseStarterCar(car)
  M.save = newSave()
  extensions.hashiriyaBattle_parking.loadSettings(M.save)
  table.insert(M.save.cars, { model = car.model, config = car.config, name = car.name })
  M.save.activeCar = 1
  M.writeSave()
  spawnPlayerCar(car)
  M.startTraffic()
  M.active = true
  showCarSelect = false
  msg(M.t('msg.welcome'), 6)
end

-- Neues Spiel aus dem Karriere-Assistenten (career.lua): Auto steht schon in der Garagenbucht.
function M.newCareer(data)
  M.save = newSave()
  M.save.playerName = data.playerName
  extensions.hashiriyaBattle_parking.loadSettings(M.save)
  table.insert(M.save.cars, data.car)
  M.save.activeCar = 1
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
  local car = M.save.cars[M.save.activeCar or 1]
  if not car then return end
  local opts = { config = car.config ~= '' and car.config or nil, licenseText = car.plate, autoEnterVehicle = false }
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
  showMenu = true
  menuAutoOpened = true
  msg(M.t('msg.enterPa', M.t('pa.' .. area.type)), 4)
  if area.type == 'garage' then M.writeSave() end
  M.sendUiState()
end

function M.onParkingLeft(area)
  -- Probeweise eingebaute Teile zurücknehmen, offene Setup-Änderungen verwerfen, Teile-Kamera lösen
  extensions.hashiriyaBattle_shop.releaseFocus()
  extensions.hashiriyaBattle_shop.cancelPreview()
  extensions.hashiriyaBattle_setup.onParkingLeft()
  garageTab = 'service'
  if menuAutoOpened then showMenu = false end
  menuAutoOpened = false
  M.sendUiState()
end

-- Belohnungen (vom Battle-Modul aufgerufen) --------------------------------

function M.onBattleResult(rival, won)
  if not M.save then return end
  if won then
    local reward = M.economy().usdToPrice(rival.rewardUsd or 1000)
    M.save.money = M.save.money + reward
    M.save.defeated[rival.id] = true
    M.save.wins = M.save.wins + 1
    msg(M.t('msg.win', rival.name, M.economy().formatYen(reward)), 6)
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
  msg(M.t('msg.posSaved', #list))
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

local function buildUiState()
  local eco = M.economy()
  local st = {
    level = M.levelName,
    active = M.active,
    menuVisible = showMenu and not extensions.hashiriyaBattle_career.isOpen(),
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
    st.battle = extensions.hashiriyaBattle_battle.getHudState()
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
    if parking.isArrived() then
      local area = parking.getCurrent()
      st.screen = area.type
      st.area = M.t('pa.' .. area.type)
      local car = M.save.cars[M.save.activeCar or 1]
      st.carName = car and car.name or ''
      st.plate = car and car.plate or ''
      st.platePrice = eco.formatYen(platePriceYen)
      local cost = parking.repairCost()
      st.repairCost = cost > 0 and eco.formatYen(cost) or nil
      st.canAffordRepair = cost <= M.save.money
      if area.type == 'shop' then st.shop = extensions.hashiriyaBattle_shop.getUiState() end
      if area.type == 'garage' then
        st.garageTab = garageTab
        if garageTab == 'parts' then st.shop = extensions.hashiriyaBattle_shop.getUiState('garage') end
        if garageTab == 'setup' then st.setup = extensions.hashiriyaBattle_setup.getUiState() end
      end
    end
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
function M.changePlate(text)
  local car = M.save and M.save.cars[M.save.activeCar or 1]
  local veh = M.getPlayerVehicle()
  if not car or not veh then return end
  text = text:gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
  if text == '' or #text > 24 or text == car.plate then return end
  if M.save.money < platePriceYen then
    msg(M.t('msg.noMoney'))
    return
  end
  M.save.money = M.save.money - platePriceYen
  car.plate = text
  pcall(core_vehicles.setPlateText, text, veh:getID())
  M.writeSave()
  msg(M.t('msg.plateChanged', text, M.economy().formatYen(platePriceYen)))
end

-- Wird von den UI-Apps per bngApi.engineLua aufgerufen.
function M.uiAction(action, arg)
  if action == 'flow' then
    extensions.hashiriyaBattle_career.action(arg)
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
  elseif action == 'customPaint' then
    local area = arrivedArea()
    if area and area.type == 'shop' then extensions.hashiriyaBattle_shop.selectCustomPaint(tostring(arg)) end
  elseif action == 'focusSlot' then
    if arrivedArea() then extensions.hashiriyaBattle_shop.focusSlot(tostring(arg or '')) end
  elseif action == 'previewBuy' then
    extensions.hashiriyaBattle_shop.confirmPreview()
  elseif action == 'previewCancel' then
    extensions.hashiriyaBattle_shop.cancelPreview()
  elseif action == 'shopTab' then
    extensions.hashiriyaBattle_shop.releaseFocus()
    extensions.hashiriyaBattle_shop.setTab(tostring(arg))
  elseif action == 'garageTab' then
    extensions.hashiriyaBattle_shop.releaseFocus()
    garageTab = tostring(arg)
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
  elseif action == 'toggleMarkers' then
    extensions.hashiriyaBattle_parking.setMarkersEnabled(not extensions.hashiriyaBattle_parking.markersEnabled())
  elseif action == 'photoMode' then
    extensions.hashiriyaBattle_parking.setPhotoMode(arg == 'true')
  elseif action == 'setLanguage' then
    M.setLanguage(arg)
  elseif action == 'stop' then
    M.stopGame()
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
  for _, name in ipairs(subExtensions) do
    extensions.load(name)
    setExtensionUnloadMode(name, 'manual')
  end
  loadLanguage(detectLanguage())
  loadData()
  log('I', logTag, 'Hashiriya Battle geladen')
end

local function onClientPostStartMission()
  loadData()
  trafficStarted = false
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
end

local function onUpdate(dtReal)
  if engineOffTimer > 0 then engineOffTimer = engineOffTimer - dtReal end
  if not M.levelName then return end
  uiTimer = uiTimer - dtReal
  if uiTimer <= 0 then
    uiTimer = uiInterval
    M.sendUiState()
  end
end

M.onExtensionLoaded = onExtensionLoaded
M.onClientPostStartMission = onClientPostStartMission
M.onClientEndMission = onClientEndMission
M.onUpdate = onUpdate
M.onVehicleSpawned = onVehicleSpawned

return M
