-- Hashiriya Battle: Kern (Spielstand, Start, Menüs)
local M = {}

local logTag = 'hashiriya'

local dataDir = '/lua/ge/extensions/hashiriyaBattle/data/'
local saveDir = 'settings/hashiriya_battle/'
local savePath = saveDir .. 'save.json'
local capturePath = saveDir .. 'captured_positions.json'

local subExtensions = { 'hashiriyaBattle_economy', 'hashiriyaBattle_rivals', 'hashiriyaBattle_battle', 'hashiriyaBattle_parking', 'hashiriyaBattle_shop', 'hashiriyaBattle_setup' }

M.active = false -- läuft der Modus gerade?
M.save = nil
M.carsData = nil
M.mapData = nil
M.levelName = nil

local showMenu = true
local showCarSelect = false
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

function M.getPlayerVehicle()
  return getPlayerVehicle and getPlayerVehicle(0) or be:getPlayerVehicle(0)
end

function M.economy() return extensions.hashiriyaBattle_economy end

-- Spielstand ----------------------------------------------------------------

local function newSave()
  return {
    version = 1,
    money = M.carsData and M.carsData.startMoneyYen or 300000,
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

-- Daten laden ---------------------------------------------------------------

local function loadData()
  M.carsData = jsonReadFile(dataDir .. 'cars.json') or { starterCars = {} }
  M.levelName = getLevelName()
  M.hasSave = readSave() ~= nil
  M.mapData = M.levelName and jsonReadFile(dataDir .. 'maps/' .. M.levelName .. '.json') or nil
  log('I', logTag, 'Level: ' .. tostring(M.levelName) .. ', Map-Daten: ' .. tostring(M.mapData ~= nil))
end

-- Auto des Spielers ---------------------------------------------------------

local function spawnPlayerCar(car)
  local opts = { config = car.config ~= '' and car.config or nil }
  -- Start in der Garage, falls die Map eine hat
  local pos, rot = extensions.hashiriyaBattle_parking.spawnTransform(extensions.hashiriyaBattle_parking.find('garage'))
  if pos then opts.pos, opts.rot = pos, rot end
  local current = M.getPlayerVehicle()
  if current then
    core_vehicles.replaceVehicle(car.model, opts)
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
  M.active = true
  showCarSelect = false
  msg(M.t('msg.welcome'), 6)
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
  -- Probeweise eingebaute Teile zurücknehmen, offene Setup-Änderungen verwerfen
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
  if not veh then return end
  local p, d = veh:getPosition(), veh:getDirectionVector()
  -- Mitte des Autos (Bounding Box), nicht der Referenzpunkt: daraus wird die Mitte der Parkbucht
  local okC, center = pcall(function() return veh:getSpawnWorldOOBB():getCenter() end)
  local list = jsonReadFile(capturePath) or {}
  table.insert(list, {
    level = M.levelName,
    pos = { p.x, p.y, p.z },
    dir = { d.x, d.y, d.z },
    center = okC and center and { center.x, center.y, center.z } or nil,
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
    menuVisible = showMenu,
    screen = M.active and 'status' or (showCarSelect and 'carSelect' or 'start'),
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
    if parking.isArrived() then
      local area = parking.getCurrent()
      st.screen = area.type
      st.area = M.t('pa.' .. area.type)
      local car = M.save.cars[M.save.activeCar or 1]
      st.carName = car and car.name or ''
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

-- Wird von den UI-Apps per bngApi.engineLua aufgerufen.
function M.uiAction(action, arg)
  if action == 'newGame' then
    showCarSelect = true
  elseif action == 'back' then
    showCarSelect = false
  elseif action == 'chooseCar' then
    for _, car in ipairs(M.carsData.starterCars or {}) do
      if car.id == arg then chooseStarterCar(car) end
    end
  elseif action == 'continue' then
    continueGame()
  elseif action == 'hide' then
    showMenu = false
    menuAutoOpened = false
  elseif action == 'callRival' then
    extensions.hashiriyaBattle_rivals.spawnNext(true)
  elseif action == 'capture' then
    capturePosition()
  elseif action == 'save' then
    M.writeSave()
    msg(M.t('msg.saved'))
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
  elseif action == 'previewBuy' then
    extensions.hashiriyaBattle_shop.confirmPreview()
  elseif action == 'previewCancel' then
    extensions.hashiriyaBattle_shop.cancelPreview()
  elseif action == 'shopTab' then
    extensions.hashiriyaBattle_shop.setTab(tostring(arg))
  elseif action == 'garageTab' then
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
  M.active = false
  showMenu = true
  showCarSelect = false
  setLayout(M.layoutName)
  if not jsonReadFile(dumpPath) then pcall(M.dumpConfigs) end
  msg(M.t('msg.ready'), 8)
end

local function onClientEndMission()
  M.stopGame()
end

local function onUpdate(dtReal)
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

return M
