-- Hashiriya Battle: Karrierestart (Titelbildschirm, Neues Spiel, Weiterspielen)
-- Ablauf "Neues Spiel": Fahrer (Name, Kennzeichen) -> Auto und Lack (Showroom in der Garagenbucht) -> Bestätigen.
-- Danach steht das Auto in der Garagenbucht und der Spieler beginnt zu Fuß daneben.
-- Gestartet wird über den Eintrag im BeamNG-Hauptmenü (lädt das Level ohne Standardauto) oder im Spiel
-- über das Hashiriya-Menü.
local M = {}

local logTag = 'hashiriya'
local titleLayout = 'hashiriyaTitle'

local flow = nil          -- nil = kein Titel/Assistent offen
local spawnTimer = 0      -- kurze Sperre, solange das Showroom-Auto spawnt
local pendingTitle = false -- Level wird gerade für den Titelbildschirm geladen
local fallbackTimer = 0   -- falls onLoadingScreenFadeout nicht kommt: Titel trotzdem öffnen

local function core() return extensions.hashiriyaBattle_core end
local function parking() return extensions.hashiriyaBattle_parking end
local function shop() return extensions.hashiriyaBattle_shop end

local function setLayout(name)
  local gs = rawget(_G, 'core_gamestate')
  if gs and gs.setGameState then pcall(gs.setGameState, 'freeroam', name, 'freeroam') end
end

local function starters()
  local d = core().carsData
  return d and d.starterCars or {}
end

local function starterById(id)
  for _, c in ipairs(starters()) do
    if c.id == id then return c end
  end
end

function M.isOpen() return flow ~= nil end
function M.isPending() return pendingTitle end

-- Titel ------------------------------------------------------------------------

function M.openTitle()
  flow = { step = 'title' }
  core().setMenuVisible(false)
  setLayout(titleLayout)
end

function M.close()
  local fromHome = flow and flow.fromHome
  flow = nil
  setLayout(core().layoutName)
  if fromHome then core().setMenuVisible(true) end
end

-- Tutorial ---------------------------------------------------------------------

local tutorialPath = '/lua/ge/extensions/hashiriyaBattle/data/tutorial.json'
local function tutorialPages()
  local d = jsonReadFile(tutorialPath) or {}
  return d.pages or {}
end

-- Tutorial später erneut ansehen (Zuhause)
function M.openTutorial()
  flow = { step = 'tutorial', page = 1, fromHome = true }
  core().setMenuVisible(false)
  setLayout(titleLayout)
end

local function endTutorial()
  if flow.fromHome then M.close() return end
  flow.step = 'driver'
end

-- Vom BeamNG-Hauptmenü: Level ohne Standardauto laden, dann Titelbildschirm.
function M.startFromMainMenu()
  local level = (core().carsData and core().carsData.careerLevel) or 'c1'
  pendingTitle = true
  local ff = rawget(_G, 'freeroam_freeroam') or (extensions.load('freeroam_freeroam') and freeroam_freeroam)
  local ok = ff and ff.startFreeroamByName and ff.startFreeroamByName(level, nil, nil, false)
  if not ok then
    pendingTitle = false
    log('E', logTag, 'Karriere: Level ' .. tostring(level) .. ' nicht gefunden')
    core().msg(core().t('msg.levelMissing', level), 8)
  end
end

-- Feste Kameraansicht auf die Garagenbucht, solange noch kein Auto dasteht.
-- (Ohne Auto schaltet Freeroam auf die freie Kamera; wir stellen sie nur passend hin.)
local function garageCamera()
  local area = parking().find('garage')
  if not area or not area.pos then return end
  local target = vec3(area.pos[1], area.pos[2], area.pos[3]) + vec3(0, 0, 0.6)
  local dir = area.dir and vec3(area.dir[1], area.dir[2], 0) or vec3(0, 1, 0)
  if dir:length() < 1e-3 then dir = vec3(0, 1, 0) end
  dir = dir:normalized()
  local side = dir:cross(vec3(0, 0, 1))
  local camPos = target + dir * 5.5 + side * 3 + vec3(0, 0, 1.2)
  local rot = quatFromDir((target - camPos):normalized(), vec3(0, 0, 1))
  pcall(function()
    if commands and commands.setFreeCamera then commands.setFreeCamera() end
    core_camera.setPosRot(0, camPos.x, camPos.y, camPos.z, rot.x, rot.y, rot.z, rot.w)
  end)
end

-- Ladebildschirm ist weg: BeamNG-Hauptmenü verlassen und Titel zeigen.
local function showTitleAfterLoad()
  if not pendingTitle then return end
  pendingTitle = false
  fallbackTimer = 0
  local router = extensions.ui_router or (extensions.load('ui_router') and extensions.ui_router)
  if router and router.navigate then pcall(router.navigate, 'play') end
  garageCamera()
  M.openTitle()
  log('I', logTag, 'Karriere: Titelbildschirm geöffnet')
end

-- Nach dem Laden des Levels (von core.onClientPostStartMission)
function M.onLevelReady()
  if pendingTitle then
    garageCamera()
    fallbackTimer = 5
    log('I', logTag, 'Karriere: Level geladen, warte auf Ende des Ladebildschirms')
  end
end

function M.onLoadingScreenFadeout()
  showTitleAfterLoad()
end

-- Showroom: Auto am Präsentationsplatz der Karte (C1: Werkstatt), sonst in der Garagenbucht -------------------------------------------

local function showroomTransform()
  return parking().showroomTransform()
end

local function spawnShowroomCar(starter, paint)
  core().engineOffAfterSpawn()
  local pos, rot = showroomTransform()
  local opts = { config = starter.config, pos = pos, rot = rot, paint = paint, paint2 = paint, paint3 = paint }
  if flow and flow.plate and flow.plate ~= '' then opts.licenseText = flow.plate end
  local veh = getPlayerVehicle and getPlayerVehicle(0) or be:getPlayerVehicle(0)
  spawnTimer = 1.2
  if veh and veh:getJBeamFilename() ~= 'unicycle' then
    core_vehicles.replaceVehicle(starter.model, opts)
    if opts.licenseText then pcall(core_vehicles.setPlateText, opts.licenseText, veh:getID()) end
  else
    opts.autoEnterVehicle = true
    core_vehicles.spawnNewVehicle(starter.model, opts)
  end
  pcall(function() core_camera.setByName(0, 'orbit', true) end)
end

-- Kaufpreis des Starterautos in Yen (wird vom Startkapital abgezogen)
local function starterPriceYen(starter)
  local info = {}
  local key = tostring(starter.config or ''):match('([^/]+)%.pc$')
  local okM, m = pcall(core_vehicles.getModel, starter.model)
  if okM and m and m.configs and key then info = m.configs[key] or {} end
  return core().economy().usdToPrice(starter.priceUsd or info.Value or 0)
end

-- Daten für die Anzeige des Autos aus den Config-Infos von BeamNG
local function carSpecs(starter)
  local c = core()
  local eco = c.economy()
  local specs, info = {}, {}
  local key = tostring(starter.config or ''):match('([^/]+)%.pc$')
  local okM, m = pcall(core_vehicles.getModel, starter.model)
  if okM and m and m.configs and key then info = m.configs[key] or {} end
  local brand = okM and m and m.model and m.model.Brand or ''
  local function add(label, value) if value then table.insert(specs, { label = c.t(label), value = value }) end end
  local power = tonumber(info.Power)
  local torque = tonumber(info.Torque)
  local weight = tonumber(info.Weight)
  add('spec.power', power and string.format('%d PS', math.floor(power + 0.5)))
  add('spec.torque', torque and string.format('%d Nm', math.floor(torque + 0.5)))
  add('spec.weight', weight and string.format('%d kg', math.floor(weight + 0.5)))
  add('spec.drivetrain', info.Drivetrain)
  add('spec.transmission', info.Transmission)
  add('spec.price', eco.formatYen(eco.usdToPrice(starter.priceUsd or info.Value or 0)))
  local name = starter.name or ''
  local modelName = brand ~= '' and name:sub(1, #brand) == brand and name:sub(#brand + 2) or name
  return specs, info.Drivetrain, brand, modelName, eco.formatYen(eco.usdToPrice(starter.priceUsd or info.Value or 0))
end

local function selectCar(id)
  local starter = starterById(id)
  if not starter then return end
  flow.carId = id
  flow.paintId = nil
  spawnShowroomCar(starter, nil)
end

local function selectPaint(id)
  local starter = starterById(flow.carId)
  if not starter then return end
  for _, p in ipairs(shop().factoryPaints(starter.model)) do
    if p.id == id then
      flow.paintId = id
      -- gleiches Auto steht schon da: nur umlackieren, nicht neu laden
      local veh = core().getPlayerVehicle()
      local same = veh and veh:getJBeamFilename() == starter.model
      if not (same and shop().applyPaintsLive({ p.paint, p.paint, p.paint })) then spawnShowroomCar(starter, p.paint) end
      return
    end
  end
end

-- Kennzeichen: Vorschlag von BeamNG (zufällig) übernehmen
local function randomPlate()
  local text = nil
  local okGen, gen = pcall(function()
    local skia = extensions.core_skiaTemplate or (extensions.load('core_skiaTemplate') and extensions.core_skiaTemplate)
    return skia and skia.generateText(nil, nil)
  end)
  if okGen and type(gen) == 'string' and gen ~= '' then text = gen end
  if not text then text = string.format('%d%d-%02d', math.random(1, 9), math.random(0, 9), math.random(0, 99)) end
  flow.plate = text
  flow.platePick = text
end

-- Neues Spiel abschließen: Spielstand anlegen, Spieler zu Fuß neben die Garage.
local function startCareer()
  local c = core()
  local starter = starterById(flow.carId)
  if not starter then return end
  local veh = c.getPlayerVehicle()
  local cfg = shop().currentConfig()
  if not veh or not cfg then
    c.msg(c.t('msg.partFailed'))
    return
  end
  local plate = flow.plate
  if not plate or plate == '' then
    local okP, p = pcall(core_vehicles.getVehicleLicenseText, veh)
    plate = okP and p or nil
  end
  c.newCareer({
    playerName = flow.name,
    experience = flow.experience,
    carPrice = starterPriceYen(starter),
    condition = starter.condition,
    car = { model = starter.model, config = cfg, name = starter.name, plate = plate,
      paintId = flow.paintId, paintIds = { flow.paintId }, ownedPaints = flow.paintId and { [flow.paintId] = true } or nil },
  })
  M.close()
  c.goOnFoot(veh)
  c.startTraffic()
end

-- Eingaben aus der Titel-App: "befehl|wert"
function M.action(arg)
  if not flow then return end
  local cmd, val = tostring(arg or ''):match('^([^|]*)|?(.*)$')
  local step = flow.step
  if step == 'tutorial' then
    if cmd == 'next' then
      flow.page = (flow.page or 1) + 1
      if flow.page > #tutorialPages() then endTutorial() end
    elseif cmd == 'skip' then
      endTutorial()
    elseif cmd == 'back' then
      if (flow.page or 1) > 1 then flow.page = flow.page - 1
      elseif flow.fromHome then M.close()
      else flow.step = 'experience' end
    end
    return
  end
  if cmd == 'back' then
    if step == 'experience' then flow = { step = 'title' }
    elseif step == 'driver' then flow.step = 'experience'
    elseif step == 'car' then flow.step = 'driver'
    elseif step == 'confirm' then flow.step = 'car' end
  elseif step == 'title' then
    if cmd == 'newGame' then
      flow = { step = 'experience', name = '', plate = '' }
    elseif cmd == 'continue' then
      M.close()
      core().continueCareer()
    elseif cmd == 'quit' then
      -- zurück ins BeamNG-Hauptmenü
      M.close()
      local back = rawget(_G, 'returnToMainMenu') or rawget(_G, 'endActiveGameMode')
      if back then pcall(back) else core().setMenuVisible(true) end
    end
  elseif step == 'experience' then
    if cmd == 'experience' and (val == 'newbie' or val == 'pro') then
      flow.experience = val
      if val == 'newbie' and #tutorialPages() > 0 then
        flow.step, flow.page = 'tutorial', 1
      else
        flow.step = 'driver'
      end
    end
  elseif step == 'driver' then
    if cmd == 'randomPlate' then
      randomPlate()
    elseif cmd == 'driver' then
      local name, plate = val:match('^(.-)\031(.*)$')
      name = (name or val):gsub('[%c]', ''):sub(1, 16)
      if name == '' then return end
      flow.name = name
      flow.plate = (plate or ''):gsub('[%c]', ''):sub(1, 12)
      flow.platePick = nil
      flow.step = 'car'
      if not flow.carId and starters()[1] then selectCar(starters()[1].id) end
    end
  elseif step == 'car' then
    if cmd == 'selectCar' then selectCar(val)
    elseif cmd == 'selectPaint' then selectPaint(val)
    elseif cmd == 'next' and flow.carId then flow.step = 'confirm' end
  elseif step == 'confirm' then
    if cmd == 'next' then startCareer() end
  end
end

function M.getUiState()
  if not flow then return nil end
  local c = core()
  local eco = c.economy()
  local st = { step = flow.step, name = flow.name, plate = flow.plate, platePick = flow.platePick, busy = spawnTimer > 0,
    experience = flow.experience, fromHome = flow.fromHome }
  st.steps = flow.experience == 'newbie' and { 'experience', 'tutorial', 'driver', 'car', 'confirm' } or { 'experience', 'driver', 'car', 'confirm' }
  if flow.step == 'tutorial' then
    local pages = tutorialPages()
    local i = math.min(math.max(flow.page or 1, 1), math.max(#pages, 1))
    local p = pages[i] or {}
    local pr = extensions.hashiriyaBattle_progress
    local img = p.image
    if img and not (FS and FS:fileExists(img)) then img = nil end
    st.tutorial = { page = i, count = #pages, title = pr.loc(p.title), text = pr.loc(p.text), image = img, last = i >= #pages }
  end
  flow.platePick = nil
  if flow.step == 'title' then
    local save = c.peekSave()
    if save then
      local car = save.cars and save.cars[save.activeCar or 1]
      st.save = { name = save.playerName or '—', car = car and car.name or '', money = eco.formatYen(save.money or 0) }
    end
  end
  if flow.step == 'driver' then
    local veh = c.getPlayerVehicle()
    local okP, p = pcall(function() return veh and core_vehicles.getVehicleLicenseText(veh) end)
    st.plateHint = okP and p or ''
  end
  if flow.step == 'car' then
    st.cars = {}
    for _, s in ipairs(starters()) do
      local specs, drivetrain, brand, modelName, price = carSpecs(s)
      table.insert(st.cars, { id = s.id, name = s.name, specs = specs, drivetrain = drivetrain, brand = brand, model = modelName,
        price = price, selected = s.id == flow.carId })
    end
  end
  if flow.step == 'car' then
    st.paints = {}
    local starter = starterById(flow.carId)
    for _, p in ipairs(starter and shop().factoryPaints(starter.model) or {}) do
      table.insert(st.paints, { id = p.id, name = p.name, swatch = shop().paintSwatch(p.paint), selected = p.id == flow.paintId })
    end
  end
  if flow.step == 'confirm' then
    local starter = starterById(flow.carId)
    local paintName, swatch = c.t('new.factoryPaint'), 'transparent'
    for _, p in ipairs(starter and shop().factoryPaints(starter.model) or {}) do
      if p.id == flow.paintId then paintName, swatch = p.name, shop().paintSwatch(p.paint) end
    end
    st.summary = {
      name = flow.name, plate = (flow.plate ~= '' and flow.plate) or st.plateHint or '—',
      car = starter and starter.name or '', paint = paintName, swatch = swatch,
      money = eco.formatYen(c.startMoney()),
      carPrice = starter and eco.formatYen(starterPriceYen(starter)) or nil,
      rest = eco.formatYen(c.startMoney() - (starter and starterPriceYen(starter) or 0)),
    }
    if st.summary.plate == '—' then
      local veh = c.getPlayerVehicle()
      local okP, p = pcall(function() return veh and core_vehicles.getVehicleLicenseText(veh) end)
      if okP and p then st.summary.plate = p end
    end
  end
  return st
end

local function onUpdate(dtReal)
  if spawnTimer > 0 then spawnTimer = spawnTimer - dtReal end
  if fallbackTimer > 0 then
    fallbackTimer = fallbackTimer - dtReal
    if fallbackTimer <= 0 then showTitleAfterLoad() end
  end
end

M.onUpdate = onUpdate

return M
