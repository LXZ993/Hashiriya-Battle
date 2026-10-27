-- Hashiriya Battle: Kern (Spielstand, Start, Menüs)
local M = {}

local im = ui_imgui
local logTag = 'hashiriya'

local dataDir = '/lua/ge/extensions/hashiriyaBattle/data/'
local saveDir = 'settings/hashiriya_battle/'
local savePath = saveDir .. 'save.json'
local capturePath = saveDir .. 'captured_positions.json'

local subExtensions = { 'hashiriyaBattle_economy', 'hashiriyaBattle_rivals', 'hashiriyaBattle_battle' }

M.active = false -- läuft der Modus gerade?
M.save = nil
M.carsData = nil
M.mapData = nil
M.levelName = nil

local showMenu = true
local showCarSelect = false

-- Hilfsfunktionen -----------------------------------------------------------

local function msg(text, ttl)
  ui_message(text, ttl or 4, 'hashiriya', 'flag')
end
M.msg = msg

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
  M.mapData = M.levelName and jsonReadFile(dataDir .. 'maps/' .. M.levelName .. '.json') or nil
  log('I', logTag, 'Level: ' .. tostring(M.levelName) .. ', Map-Daten: ' .. tostring(M.mapData ~= nil))
end

-- Auto des Spielers ---------------------------------------------------------

local function spawnPlayerCar(car)
  local opts = { config = car.config ~= '' and car.config or nil }
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
  table.insert(M.save.cars, { model = car.model, config = car.config, name = car.name })
  M.save.activeCar = 1
  M.writeSave()
  spawnPlayerCar(car)
  M.active = true
  showCarSelect = false
  msg('Willkommen bei Hashiriya Battle! Fahr los und fordere Rivalen per Lichthupe heraus.', 6)
end

local function continueGame()
  M.save = readSave()
  if not M.save then
    msg('Kein Spielstand gefunden.')
    return
  end
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

-- Belohnungen (vom Battle-Modul aufgerufen) --------------------------------

function M.onBattleResult(rival, won)
  if not M.save then return end
  if won then
    local reward = M.economy().usdToPrice(rival.rewardUsd or 1000)
    M.save.money = M.save.money + reward
    M.save.defeated[rival.id] = true
    M.save.wins = M.save.wins + 1
    msg('Sieg gegen ' .. rival.name .. '! +' .. M.economy().formatYen(reward), 6)
  else
    M.save.losses = M.save.losses + 1
    msg('Niederlage gegen ' .. rival.name .. '.', 6)
  end
  M.writeSave()
end

-- Positionen sammeln (für Parkplätze und Spawnpunkte) -----------------------

local function capturePosition()
  local veh = M.getPlayerVehicle()
  if not veh then return end
  local p, d = veh:getPosition(), veh:getDirectionVector()
  local list = jsonReadFile(capturePath) or {}
  table.insert(list, {
    level = M.levelName,
    pos = { p.x, p.y, p.z },
    dir = { d.x, d.y, d.z },
  })
  jsonWriteFile(capturePath, list, true)
  msg('Position gemerkt (' .. #list .. ' insgesamt).')
end

-- Menüs (imgui) -------------------------------------------------------------

local function drawStartMenu()
  im.SetNextWindowPos(im.ImVec2(40, 120), im.Cond_FirstUseEver)
  im.Begin('Hashiriya Battle##menu', nil, im.WindowFlags_AlwaysAutoResize)
  if showCarSelect then
    im.Text('Wähle dein erstes Auto:')
    im.Separator()
    for _, car in ipairs(M.carsData.starterCars or {}) do
      local price = M.economy().formatYen(M.economy().usdToPrice(car.priceUsd or 0))
      if im.Button(car.name .. '  (' .. price .. ')##' .. car.id) then
        chooseStarterCar(car)
      end
    end
    im.Separator()
    if im.Button('Zurück') then showCarSelect = false end
  else
    if im.Button('Neues Spiel') then showCarSelect = true end
    if readSave() then
      im.SameLine()
      if im.Button('Weiter') then continueGame() end
    end
    if im.Button('Ausblenden') then showMenu = false end
  end
  im.End()
end

local function drawStatusWindow()
  im.SetNextWindowPos(im.ImVec2(40, 120), im.Cond_FirstUseEver)
  im.Begin('Hashiriya Battle##status', nil, im.WindowFlags_AlwaysAutoResize)
  im.Text('Geld: ' .. M.economy().formatYen(M.save.money))
  im.Text('Siege: ' .. M.save.wins .. '   Niederlagen: ' .. M.save.losses)
  local rival = extensions.hashiriyaBattle_rivals.getActiveRival()
  im.Text('Rivale in der Nähe: ' .. (rival and rival.data.name or '-'))
  im.Separator()
  if im.Button('Rivale rufen (Test)') then extensions.hashiriyaBattle_rivals.spawnNext(true) end
  if im.Button('Position merken') then capturePosition() end
  if im.Button('Speichern') then M.writeSave(); msg('Gespeichert.') end
  im.SameLine()
  if im.Button('Modus beenden') then M.stopGame() end
  im.SameLine()
  if im.Button('Ausblenden') then showMenu = false end
  im.End()
end

function M.toggleMenu()
  showMenu = not showMenu
end

-- Hooks -----------------------------------------------------------------------

local function onExtensionLoaded()
  for _, name in ipairs(subExtensions) do
    extensions.load(name)
    setExtensionUnloadMode(name, 'manual')
  end
  loadData()
  log('I', logTag, 'Hashiriya Battle geladen')
end

local function onClientPostStartMission()
  loadData()
  M.active = false
  showMenu = true
end

local function onClientEndMission()
  M.stopGame()
end

local function onUpdate()
  if not showMenu or not M.levelName then return end
  if M.active and M.save then
    drawStatusWindow()
  else
    drawStartMenu()
  end
end

M.onExtensionLoaded = onExtensionLoaded
M.onClientPostStartMission = onClientPostStartMission
M.onClientEndMission = onClientEndMission
M.onUpdate = onUpdate

return M
