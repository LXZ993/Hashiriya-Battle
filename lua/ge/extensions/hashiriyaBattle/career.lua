-- Hashiriya Battle: Karrierestart (Titelbildschirm, Neues Spiel, Weiterspielen)
-- Ablauf "Neues Spiel": Fahrer (Name, Kennzeichen) -> Auto und Lack (Showroom in der Garagenbucht) -> Bestätigen.
-- Danach steht das Auto in der Garagenbucht und der Spieler beginnt zu Fuß daneben.
-- Gestartet wird über den Eintrag im BeamNG-Hauptmenü (lädt das Level ohne Standardauto) oder im Spiel
-- über das Hashiriya-Menü.
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
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

-- Seed-System: aus Fahrername und Kennzeichen wird ein fester Zufallswert. Er wählt starterOffer Autos
-- (verschiedene Modelle) aus dem Pool starterCars und würfelt ihren Gebrauchtzustand (conditionRange).
-- Gleicher Name und gleiches Kennzeichen = gleiches Angebot.
local function seedFrom(text)
  local h = 7
  for i = 1, #text do h = (h * 31 + text:byte(i)) % 2147483646 end
  return h + 1
end

local function seededRandom(seed)
  local x = seed
  return function()
    x = (x * 16807) % 2147483647 -- Park-Miller, bleibt in LuaJIT exakt
    return (x - 1) / 2147483646
  end
end

local starterPriceYen -- weiter unten

-- Startautos, die man sich vom Startgeld leisten kann (sonst würde man mit 0 Yen oder im Minus starten)
local function pool()
  local d = core().carsData
  local out = {}
  local money = core().startMoney()
  for _, e in ipairs(d and d.starterCars or {}) do
    if starterPriceYen(e) <= money then table.insert(out, e) end
  end
  return out
end

local function rollCondition(rand, entry)
  local d = core().carsData or {}
  local r = {}
  for k, v in pairs(d.conditionRange or {}) do r[k] = v end
  for k, v in pairs(entry.conditionRange or {}) do r[k] = v end
  local function pick(key, default)
    local range = r[key]
    if not range then return default end
    return range[1] + rand() * (range[2] - range[1])
  end
  return {
    odometerKm = math.floor(pick('odometerKm', 150000) / 1000 + 0.5) * 1000,
    integrity = math.floor(pick('integrity', 0.85) * 100 + 0.5) / 100,
    visual = math.floor(pick('visual', 0.7) * 100 + 0.5) / 100,
    fuel = math.floor(pick('fuel', 0.4) * 100 + 0.5) / 100,
  }
end

local function buildOffer(name, plate)
  local d = core().carsData or {}
  local list = {}
  for _, e in ipairs(pool()) do table.insert(list, e) end
  local rand = seededRandom(seedFrom(string.lower(name or '') .. '|' .. string.upper(plate or '')))
  for i = #list, 2, -1 do
    local j = math.floor(rand() * i) + 1
    list[i], list[j] = list[j], list[i]
  end
  local offer, models = {}, {}
  for _, e in ipairs(list) do
    if #offer >= (d.starterOffer or 3) then break end
    if not models[e.model] then
      models[e.model] = true
      local car = {}
      for k, v in pairs(e) do car[k] = v end
      car.condition = rollCondition(rand, e)
      table.insert(offer, car)
    end
  end
  -- günstigstes zuerst
  table.sort(offer, function(a, b) return (a.priceUsd or 30000) < (b.priceUsd or 30000) end)
  return offer
end

local function starters()
  return flow and flow.offer or pool()
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

-- Tasten-Check -------------------------------------------------------------------
-- Ohne diese Tasten ist das Spiel nicht spielbar: Lichthupe (Herausfordern), Warnblinker (Annehmen),
-- Blinker links/rechts (Ablehnen) und unser Menü (Pos1).
local keyActions = {
  { id = 'highbeam', action = 'highbeam' },
  { id = 'hazard', action = 'toggle_hazard_signal' },
  { id = 'left', action = 'toggle_left_signal' },
  { id = 'right', action = 'toggle_right_signal' },
  { id = 'menu', action = 'hashiriyaToggleMenu' },
}

-- Lesbare Tastennamen: "comma" -> ",", "modifier2 btn_lt" -> "Mod2 + LT"
local keyNames = { comma = ',', period = '.', slash = '/', backslash = '\\', semicolon = ';', apostrophe = "'",
  minus = '-', equals = '=', lbracket = '[', rbracket = ']', space = 'Space', home = 'Pos1', ['end'] = 'Ende',
  pageup = 'Bild auf', pagedown = 'Bild ab', insert = 'Einfg', delete = 'Entf', backspace = 'Rücktaste',
  ['return'] = 'Enter', enter = 'Enter', tab = 'Tab', escape = 'Esc', lshift = 'Shift', rshift = 'Shift',
  lcontrol = 'Strg', rcontrol = 'Strg', lalt = 'Alt', ralt = 'Alt Gr', up = '↑', down = '↓', left = '←', right = '→',
  button0 = 'Linke Maustaste', button1 = 'Rechte Maustaste', button2 = 'Mittlere Maustaste' }
local keyNamesEn = { home = 'Home', ['end'] = 'End', pageup = 'Page Up', pagedown = 'Page Down', insert = 'Insert',
  delete = 'Del', backspace = 'Backspace', lcontrol = 'Ctrl', rcontrol = 'Ctrl', ralt = 'Alt Gr',
  button0 = 'Left mouse', button1 = 'Right mouse', button2 = 'Middle mouse' }

local function prettyControl(control)
  local en = core().lang == 'en'
  local parts = {}
  for token in tostring(control):lower():gmatch('%S+') do
    local name = (en and keyNamesEn[token]) or keyNames[token]
    if not name then
      local mod = token:match('^modifier(%d+)$')
      if mod then name = 'Mod' .. mod
      else
        name = token:gsub('^btn_', ''):gsub('^numpad', 'Num ')
        name = string.upper(name)
      end
    end
    table.insert(parts, name)
  end
  return table.concat(parts, ' + ')
end

local function deviceLabel(devname)
  local d = tostring(devname or '')
  if d:find('^keyboard') or d:find('^mouse') then return '' end
  return 'Pad '
end

local function keyStatus()
  local bound = {}
  local b = rawget(_G, 'core_input_bindings')
  for _, device in ipairs(b and b.bindings or {}) do
    local contents = device.contents or {}
    for _, binding in ipairs(contents.bindings or {}) do
      if not binding.unused and binding.action and binding.control and binding.control ~= '' then
        bound[binding.action] = bound[binding.action] or {}
        if #bound[binding.action] < 2 then
          table.insert(bound[binding.action], deviceLabel(device.devname) .. prettyControl(binding.control))
        end
      end
    end
  end
  local list, missing = {}, 0
  for _, k in ipairs(keyActions) do
    local keys = bound[k.action]
    if not keys then missing = missing + 1 end
    table.insert(list, { id = k.id, keys = keys and table.concat(keys, ' / ') or nil })
  end
  return list, missing
end

-- BeamNG-Steuerung öffnen (wie der Knopf im Spiel): mit Aktion direkt den Belegen-Dialog dafür
local function openControls(id)
  local router = extensions.ui_router or rawget(_G, 'ui_router')
  if not router or not router.navigate then return end
  local action
  for _, k in ipairs(keyActions) do if k.id == id then action = k.action end end
  if action then
    if pcall(router.navigate, 'menu.options.controls.bindings.edit', { action = action }) then return end
  end
  pcall(router.navigate, 'menu.options.controls.bindings', nil, nil)
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
-- Die freie Kamera ist erst ein paar Frames nach setFreeCamera aktiv (vorher ignoriert setPosRot den Aufruf),
-- darum wird die Ansicht kurz in jedem Frame neu gesetzt.
local camHold = nil
local function holdCamera(pos, rot)
  camHold = { pos = pos, rot = rot, t = 2 }
  pcall(function() if commands and commands.setFreeCamera then commands.setFreeCamera() end end)
end

local function applyHeldCamera(dtReal)
  if not camHold then return end
  camHold.t = camHold.t - (dtReal or 0)
  local p, r = camHold.pos, camHold.rot
  pcall(function()
    if commands and commands.isFreeCamera and not commands.isFreeCamera(0) and commands.setFreeCamera then commands.setFreeCamera() end
    core_camera.setPosRot(0, p[1], p[2], p[3], r[1], r[2], r[3], r[4])
  end)
  if camHold.t <= 0 then camHold = nil end
end

local function garageCamera()
  local cam = core().getTitleCamera and core().getTitleCamera()
  if cam and cam.pos and cam.rot then
    holdCamera(cam.pos, cam.rot)
    -- Uhrzeit, die beim Speichern der Titelkamera war (nur für den Titelbildschirm; ein Spielstand stellt seine eigene Zeit)
    if cam.hour then pcall(extensions.hashiriyaBattle_home.applyClock, cam.hour) end
    return
  end
  local area = parking().find('garage')
  if not area or not area.pos then return end
  local target = vec3(area.pos[1], area.pos[2], area.pos[3]) + vec3(0, 0, 0.6)
  local dir = area.dir and vec3(area.dir[1], area.dir[2], 0) or vec3(0, 1, 0)
  if dir:length() < 1e-3 then dir = vec3(0, 1, 0) end
  dir = dir:normalized()
  local side = dir:cross(vec3(0, 0, 1))
  local camPos = target + dir * 5.5 + side * 3 + vec3(0, 0, 1.2)
  local rot = quatFromDir((target - camPos):normalized(), vec3(0, 0, 1))
  holdCamera({ camPos.x, camPos.y, camPos.z }, { rot.x, rot.y, rot.z, rot.w })
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
  -- Kennzeichen-Design (Plates Pack) gleich in die Config, damit Showroom-Auto und Startauto es haben
  local cfg = extensions.hashiriyaBattle_plates.applyToConfig(starter.config, flow and flow.plateDesign)
  local opts = { config = cfg, pos = pos, rot = rot, paint = paint, paint2 = paint, paint3 = paint }
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
function starterPriceYen(starter)
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
  local cond = starter.condition
  if cond then
    add('spec.odometer', cond.odometerKm and (tostring(cond.odometerKm):reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')) .. ' km')
    add('spec.condition', cond.integrity and string.format('%d %%', math.floor(cond.integrity * 100 + 0.5)))
    add('spec.fuel', cond.fuel and string.format('%d %%', math.floor(math.max(cond.fuel, (core().carsData or {}).conditionMinFuel or 0.25) * 100 + 0.5)))
  end
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

-- Kennzeichen: zufällig im Format des Plates Packs (z. B. 330/12-34)
local function randomPlate()
  local text = extensions.hashiriyaBattle_plates.random()
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
  local plates = extensions.hashiriyaBattle_plates
  local plate = plates.normalize(flow.plate) or plates.random()
  cfg = plates.applyToConfig(cfg, flow.plateDesign)
  c.newCareer({
    playerName = flow.name,
    experience = flow.experience,
    carPrice = starterPriceYen(starter),
    condition = starter.condition,
    car = { model = starter.model, config = cfg, name = starter.name, plate = plate, plateDesign = flow.plateDesign or plates.defaultDesign, seeded = true,
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
      else flow.step = 'keys' end
    end
    return
  end
  if step == 'keys' then
    if cmd == 'back' then flow.step = 'experience'
    elseif cmd == 'openControls' then openControls(val ~= '' and val or nil)
    elseif cmd == 'next' then
      if flow.experience == 'newbie' and #tutorialPages() > 0 then
        flow.step, flow.page = 'tutorial', 1
      else
        flow.step = 'driver'
      end
    end
    return
  end
  if step == 'credits' then
    if cmd == 'back' then flow = { step = 'title' } end
    return
  end
  if cmd == 'back' then
    if step == 'experience' then flow = { step = 'title' }
    elseif step == 'driver' then flow.step = (flow.experience == 'newbie' and #tutorialPages() > 0) and 'tutorial' or 'keys'
    elseif step == 'car' then flow.step = 'driver'
    elseif step == 'confirm' then flow.step = 'car' end
  elseif step == 'title' then
    if cmd == 'newGame' then
      flow = { step = 'experience', name = '', plate = '', plateDesign = extensions.hashiriyaBattle_plates.defaultDesign }
    elseif cmd == 'continue' then
      M.close()
      core().continueCareer()
    elseif cmd == 'credits' then
      flow = { step = 'credits' }
    elseif cmd == 'quit' then
      -- zurück ins BeamNG-Hauptmenü
      M.close()
      local back = rawget(_G, 'returnToMainMenu') or rawget(_G, 'endActiveGameMode')
      if back then pcall(back) else core().setMenuVisible(true) end
    end
  elseif step == 'experience' then
    if cmd == 'experience' and (val == 'newbie' or val == 'pro') then
      flow.experience = val
      flow.step = 'keys'
    end
  elseif step == 'driver' then
    local plates = extensions.hashiriyaBattle_plates
    if cmd == 'randomPlate' then
      randomPlate()
    elseif cmd == 'plateRegion' or cmd == 'plateType' then
      local region, kind = plates.splitDesign(flow.plateDesign)
      if cmd == 'plateRegion' then region = val else kind = val end
      local d = plates.design(region, kind)
      if plates.validDesign(d) then flow.plateDesign = d end
    elseif cmd == 'driver' then
      local name, plate = val:match('^(.-)\031(.*)$')
      name = (name or val):gsub('[%c]', ''):sub(1, 16)
      if name == '' then return end
      flow.name = name
      local typed = (plate or ''):gsub('[%c]', '')
      if typed == '' then
        flow.plate = plates.random()
      else
        local norm = plates.normalize(typed)
        if not norm then
          core().msg(core().t('msg.plateInvalid'), 6)
          return
        end
        flow.plate = norm
      end
      flow.platePick = flow.plate
      flow.step = 'car'
      local seedPlate = flow.plate
      local key = flow.name .. '|' .. tostring(seedPlate)
      if flow.offerKey ~= key then
        flow.offerKey = key
        flow.offer = buildOffer(flow.name, seedPlate)
        flow.carId, flow.paintId = nil, nil
      end
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

-- Credits für den Titelbildschirm aus data/credits.json: Abschnitte mit Name und Aufgabe
local creditsPath = '/lua/ge/extensions/hashiriyaBattle/data/credits.json'
local function creditsList()
  local d = jsonReadFile(creditsPath) or {}
  local pr = extensions.hashiriyaBattle_progress
  local c = core()
  local out = {}
  for _, sec in ipairs(d.sections or {}) do
    local entries = {}
    for _, e in ipairs(sec.entries or {}) do
      if e.name and e.name ~= '' then table.insert(entries, { name = e.name, what = pr.loc(e.what) or '' }) end
    end
    if #entries > 0 then table.insert(out, { title = pr.loc(sec.title), entries = entries }) end
  end
  -- Community: jeder angenommene Wanderer (vom Formular), mit Wanderer-Name
  local community = {}
  for _, e in ipairs(d.community or {}) do
    if e.name and e.name ~= '' then
      local role = c.t('credits.role.' .. tostring(e.role or 'Other'))
      table.insert(community, { name = e.name, what = role .. (e.wanderer and (' · ' .. c.t('credits.wanderer', e.wanderer)) or '') })
    end
  end
  if #community > 0 then table.insert(out, { title = c.t('credits.community'), entries = community }) end
  return out, pr.loc(d.thanks)
end

function M.getUiState()
  if not flow then return nil end
  local c = core()
  local eco = c.economy()
  local st = { step = flow.step, name = flow.name, plate = flow.plate, platePick = flow.platePick, busy = spawnTimer > 0,
    experience = flow.experience, fromHome = flow.fromHome }
  st.steps = flow.experience == 'newbie' and { 'experience', 'keys', 'tutorial', 'driver', 'car', 'confirm' } or { 'experience', 'keys', 'driver', 'car', 'confirm' }
  if flow.step == 'keys' then st.keys, st.keysMissing = keyStatus() end
  if flow.step == 'tutorial' then
    local pages = tutorialPages()
    local i = math.min(math.max(flow.page or 1, 1), math.max(#pages, 1))
    local p = pages[i] or {}
    local pr = extensions.hashiriyaBattle_progress
    local img = p.image
    if img and not (FS and FS:fileExists(img)) then img = nil end
    st.tutorial = { page = i, count = #pages, title = pr.loc(p.title), text = pr.loc(p.text), image = img, last = i >= #pages }
  end
  if flow.step == 'credits' then st.credits, st.creditsThanks = creditsList() end
  flow.platePick = nil
  if flow.step == 'title' then
    local save = c.peekSave()
    if save then
      local car = save.cars and save.cars[save.activeCar or 1]
      st.save = { name = save.playerName or '—', car = car and car.name or '', money = eco.formatYen(save.money or 0) }
    end
  end
  if flow.step == 'driver' then
    local plates = extensions.hashiriyaBattle_plates
    st.plateHint = '330 1234'
    st.plateOptions = plates.uiOptions(c.t)
    st.plateRegion, st.plateType = plates.splitDesign(flow.plateDesign)
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
      name = flow.name, plate = ((flow.plate ~= '' and flow.plate) or '—') .. (function()
        local region, kind = extensions.hashiriyaBattle_plates.splitDesign(flow.plateDesign)
        return ' · ' .. c.t('plate.region.' .. region) .. ', ' .. c.t('plate.type.' .. kind)
      end)(),
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
  applyHeldCamera(dtReal)
  if fallbackTimer > 0 then
    fallbackTimer = fallbackTimer - dtReal
    if fallbackTimer <= 0 then showTitleAfterLoad() end
  end
end

M.onUpdate = onUpdate

return M
