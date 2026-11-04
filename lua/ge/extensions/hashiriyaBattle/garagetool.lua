-- Hashiriya Battle: Gegner-Garage (Entwickler-Werkzeug, nicht im Release).
-- BeamNG-Hauptmenü > More > "Gegner-Garage (Dev)" startet die ganz normale BeamNG-Garage
-- (gameplay_garageMode.start(), genau wie More > Garage: Teile, Tuning, Lack, Decals, Fahrzeuge, Kamera, Licht, Foto ...).
-- Zusätzlich liegt darüber das Panel "Gegner-Garage" (Vue, ui/ui-vue/mods/hashiriyaGarage/GaragePanel.vue).
-- Die Original-Garage wird nicht verändert: keine Datei ersetzt, kein Layout umgeschaltet. Das Panel erscheint nur,
-- wenn die Garage über unseren Eintrag gestartet wurde.
-- Reiter "Gegner": Gegner wählen, sein Auto mit seiner Config laden, daneben Crew, Beschreibung, Bedingungen, Sprüche.
-- "Auf Gegner speichern" schreibt die Config zurück:
--   * eigene Mod-Config (vehicles/<model>/hashiriya_*.pc im Mod-Ordner) wird überschrieben (Sicherung vorher),
--   * eine BeamNG- oder fremde Config bleibt unangetastet: es entsteht vehicles/<model>/hashiriya_r_<id>.pc im
--     Mod-Ordner, und rivals.json bekommt beim Gegner den neuen Pfad (und das Modell, falls du das Auto gewechselt hast).
-- Reiter "Aura": Aura eines Gegners am Auto in der Garage ansehen (aura.lua, Vorschau ohne Karriere).
-- Weitere Test-Reiter kommen in GaragePanel.vue dazu (tabs) und bekommen hier eine Aktion in "actions".
local M = {}

local logTag = 'hashiriya'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local garageLevel = 'garage_v2'  -- Level der BeamNG-Garage
local backupDir = '/settings/hashiriya_battle/builder_backups/'
local dataRel = 'lua/ge/extensions/hashiriyaBattle/data/rivals.json'
local maxBackups = 20

local loadedId = nil   -- Gegner, dessen Auto gerade in der Garage steht
local loadedMode = nil -- 'game' (wie im Spiel: Kennzeichen-Design, fester Lack) oder 'pure' (nur die .pc)
local wanted = false   -- Garage wurde über "Gegner-Garage (Dev)" gestartet
local starting = false -- Garage-Level lädt gerade
local shown = nil      -- zuletzt an die Oberfläche gemeldeter Zustand
local auraPreview = nil -- { id = Gegner-ID, mode = 'ground'|'battle'|'both', sp = 0..1, level = 1..3 }
local expectSpawn = false -- nächstes Spawnen kommt von "Gegner laden"
local pendingPlate = nil   -- Kennzeichen-Text des geladenen Gegners (nach dem Spawnen setzen, wie rivals.lua spawnCar)

local auraCfgForUi -- weiter unten
local setRivalOrStageField -- weiter unten (Stufen in rivals.json)
local auraChanged = {} -- aura.json: Pfad -> Wert, geändert seit dem letzten Speichern/Laden
local function core() return extensions.hashiriyaBattle_core end
local function rivals() return extensions.hashiriyaBattle_rivals end
local function send(data) guihooks.trigger('HashiriyaGarage', data) end
local function status(ok, text) send({ status = { ok = ok, text = text, time = os.date('%H:%M:%S') } }) end

function M.isAllowed()
  local c = core()
  if c and c.isRelease then return not c.isRelease() end
  return true
end

local function levelName()
  local ok, n = pcall(function() return getCurrentLevelIdentifier and getCurrentLevelIdentifier() end)
  return ok and n and tostring(n):lower() or ''
end

local function garageMode()
  local gm = rawget(_G, 'gameplay_garageMode') or extensions.gameplay_garageMode
  if not gm then
    pcall(extensions.load, 'gameplay_garageMode')
    gm = extensions.gameplay_garageMode
  end
  return gm
end

-- Läuft die BeamNG-Garage und wurde sie über unseren Eintrag gestartet?
local function garageActive()
  if not wanted then return false end
  local gm = rawget(_G, 'gameplay_garageMode')
  return gm and gm.isActive and gm.isActive() and levelName() == garageLevel or false
end
M.garageActive = garageActive
M.isActive = garageActive

local function modRoot()
  local b = extensions.hashiriyaBattle_builder
  if b and b.modRoot then return b.modRoot() end
  for _, r in ipairs({ '/mods/unpacked/Hashiriya-Battle/', '/mods/unpacked/hashiriya-battle/' }) do
    if FS:fileExists(r .. dataRel) then return r end
  end
end

-- Zustand an das Panel melden (es zeigt sich nur, wenn active = true)
local function pushState(force)
  local a = garageActive()
  if not force and a == shown then return end
  shown = a
  guihooks.trigger('HashiriyaGarageState', { active = a })
end
function M.getState() return { active = garageActive() } end

local function setAuraPreview(p)
  auraPreview = p
  local au = extensions.hashiriyaBattle_aura
  if au and au.setPreview then au.setPreview(p and M.auraSpec(p) or nil) end
end

local function reset()
  wanted, starting = false, false
  loadedId, loadedMode, pendingPlate = nil, nil, nil
  setAuraPreview(nil)
  pushState()
end

-- Starten / Beenden -------------------------------------------------------------------------

-- Hauptmenü > More > "Gegner-Garage (Dev)": dieselbe Garage wie More > Garage, nur mit Panel
function M.start()
  if not M.isAllowed() then return end
  local c = core()
  if c and c.active then
    if c.msg then c.msg('Gegner-Garage: erst die Karriere beenden', 6) end
    return
  end
  local gm = garageMode()
  if not gm or not gm.start then
    log('E', logTag, 'Gegner-Garage: gameplay_garageMode fehlt')
    return
  end
  wanted = true
  loadedId, loadedMode, pendingPlate = nil, nil, nil
  if gm.isActive and gm.isActive() and levelName() == garageLevel then
    pushState(true)
    M.refresh()
    return
  end
  starting = true
  local ok, err = pcall(gm.start)
  if not ok then
    reset()
    log('E', logTag, 'Gegner-Garage: Start fehlgeschlagen: ' .. tostring(err))
    return
  end
  log('I', logTag, 'Gegner-Garage: starte BeamNG-Garage (' .. garageLevel .. ')')
end

-- Level fertig: nur in der Garage-Halle bleibt die Gegner-Garage an
function M.onClientPostStartMission()
  if not wanted then return end
  starting = false
  if levelName() ~= garageLevel then reset() return end
  log('I', logTag, 'Gegner-Garage: geöffnet')
end

-- Garage verlassen (Hauptmenü, Testfahrt, anderer Modus): Panel aus
function M.onClientEndMission()
  if starting then return end
  if wanted then log('I', logTag, 'Gegner-Garage: beendet') end
  reset()
end

-- Zustand regelmäßig prüfen (Garage kann auch ohne Levelwechsel enden), Panel ein-/ausblenden
local stateTimer = 0
function M.onUpdate(dtReal)
  if not wanted and not shown then return end
  stateTimer = stateTimer + (dtReal or 0)
  if stateTimer < 0.3 then return end
  stateTimer = 0
  pushState()
  if auraPreview and not garageActive() then setAuraPreview(nil) end
end

-- Auto gewechselt (auch über die Garage-Menüs): Anzeige "in der Garage" aktualisieren
local function applyPlate(vid)
  if not pendingPlate then return end
  local veh = vid and be:getObjectByID(vid) or getPlayerVehicle(0)
  if veh then pcall(core_vehicles.setPlateText, pendingPlate, veh:getID()) end
end

function M.onVehicleSpawned(vid)
  if not garageActive() then return end
  if expectSpawn then
    expectSpawn = false
    applyPlate(vid)
  else
    loadedId, loadedMode, pendingPlate = nil, nil, nil
  end
  M.refresh()
end

-- Daten fürs Panel ------------------------------------------------------------------------------

local function loc(v)
  if type(v) == 'table' then return v.de or v.en or '' end
  return v
end

local modelCache = {}
local function modelInfo(model)
  if modelCache[model] == nil then
    local ok, info = pcall(core_vehicles.getModel, model)
    modelCache[model] = (ok and info and info.model) and info or false
  end
  return modelCache[model] or nil
end

local function configKey(path)
  return tostring(path or ''):match('([^/]+)%.pc$')
end

local function configInfo(model, path)
  local info = modelInfo(model)
  local key = configKey(path)
  local c = info and key and info.configs and info.configs[key]
  return {
    name = c and tostring(c.Configuration or c.Name or key) or key,
    exists = path ~= nil and path ~= '' and FS:fileExists('/' .. tostring(path):gsub('^/', '')) or false,
    source = c and c.Source or nil,
    value = c and tonumber(c.Value) or nil,
    power = c and tonumber(c.Power) or nil,
    weight = c and tonumber(c.Weight) or nil,
  }
end

local function modelName(model)
  local info = modelInfo(model)
  if not info then return tostring(model) .. ' (fehlt)' end
  local brand = info.model.Brand or ''
  return (brand ~= '' and (brand .. ' ') or '') .. tostring(info.model.Name or model)
end

local function isOwnConfig(path, root)
  path = tostring(path or ''):gsub('^/', '')
  return root ~= nil and configKey(path) ~= nil and configKey(path):match('^hashiriya_') ~= nil and FS:fileExists(root .. path)
end

local function roleOf(r)
  if r.final then return 'final' end
  if r.boss then return 'boss' end
  if r.wanderer then return 'wanderer' end
  if r.leader then return 'leader' end
  if r.team then return 'crew' end
  return 'other'
end

local function buildData()
  local rv = rivals()
  rv.loadData()
  local data = rv.getData() or {}
  local root = modRoot()
  local teams, teamById = {}, {}
  for _, t in ipairs(data.teams or {}) do
    local tt = { id = t.id, name = t.name, jp = t.jp, color = t.color, minRank = t.minRank, desc = loc(t.desc) }
    table.insert(teams, tt)
    teamById[t.id] = tt
  end
  local byConfig = {}
  for _, r in ipairs(data.rivals or {}) do
    local k = tostring(r.config or '')
    byConfig[k] = byConfig[k] or {}
    table.insert(byConfig[k], r.id)
  end
  local list = {}
  local au = extensions.hashiriyaBattle_aura
  for i, r in ipairs(data.rivals or {}) do
    local ci = configInfo(r.model, r.config)
    local okA, auraColor = pcall(function() return au and au.colorOf and au.colorOf(r) or nil end)
    local shared = {}
    for _, id in ipairs(byConfig[tostring(r.config or '')] or {}) do if id ~= r.id then table.insert(shared, id) end end
    local lines = {}
    for k, v in pairs(r.lines or {}) do lines[k] = loc(v) end
    table.insert(list, {
      idx = i, id = r.id, name = r.name, nick = loc(r.nick), role = roleOf(r),
      team = r.team, teamName = r.team and teamById[r.team] and teamById[r.team].name or nil,
      color = r.team and teamById[r.team] and teamById[r.team].color or nil,
      model = r.model, modelName = modelName(r.model), config = r.config, configName = ci.name, configOk = ci.exists,
      value = ci.value, power = ci.power, weight = ci.weight,
      own = isOwnConfig(r.config, root), shared = shared,
      desc = loc(r.desc), hint = loc(r.hint), conditions = r.conditions, appear = r.appear,
      lines = lines, paint = r.paint, plate = r.plate,
      aggression = r.aggression, cruiseKmh = r.cruiseKmh, maxSp = r.maxSp,
      rewardUsd = r.rewardUsd, rewardYen = r.rewardYen, rep = r.rep,
      placeholder = r._platzhalter,
      auraColor = okA and auraColor or nil, leader = r.leader and true or false,
      auraOn = au and au.hasAura and au.hasAura(r) or false, auraOwn = r.auraOn,
      auraOwnColor = type(r.aura) == 'string' and r.aura or nil,
      auraDefault = au and au.defaultColorOf and au.defaultColorOf(r) or nil,
      auraDefaultOn = au and au.defaultOn and au.defaultOn(r) or false, auraLevel = r.auraLevel,
      stage = r.stage, stageOf = r.stageOf, stageChapter = r.stageChapter, stageOwnConfig = r.stageOwnConfig or false,
      stages = type(r.stages) == 'table' and #r.stages or 0,
    })
  end
  local ranks = {}
  for i, rk in ipairs(data.ranks or {}) do ranks[i] = loc(rk.name) end
  return { teams = teams, rivals = list, ranks = ranks, root = root }
end

-- Werte aus aura.json, die der Aura-Editor zeigt
auraCfgForUi = function()
  local au = extensions.hashiriyaBattle_aura
  local c = au and au.config and au.config() or {}
  return { who = c.who, shell = c.shell, haze = c.haze, ground = c.ground, battle = c.battle, rim = c.rim,
    rivalLevel = c.rivalLevel, leaderRimColor = c.leaderRimColor }
end

local function playerInfo()
  local veh = getPlayerVehicle and getPlayerVehicle(0)
  if not veh then return nil end
  local model = veh:getJBeamFilename()
  return { model = model, modelName = modelName(model) }
end

function M.refresh()
  if not M.isAllowed() then return end
  local d = buildData()
  send({
    full = true, garage = garageActive(),
    teams = d.teams, rivals = d.rivals, ranks = d.ranks, root = d.root,
    loadedId = loadedId, loadedMode = loadedMode, player = playerInfo(),
    aura = auraPreview, auraCfg = auraCfgForUi(),
  })
end

-- Auto des Gegners laden -------------------------------------------------------------------------

local function findRival(id)
  for _, r in ipairs((rivals().getData() or {}).rivals or {}) do
    if r.id == id then return r end
  end
end

local function loadRival(a)
  local r = findRival(a.id)
  if not r then status(false, 'Gegner nicht gefunden: ' .. tostring(a.id)) return end
  if not garageActive() then status(false, 'Nur in der Gegner-Garage (Hauptmenü > More > Gegner-Garage (Dev))') return end
  if not r.config or r.config == '' or not FS:fileExists('/' .. r.config:gsub('^/', '')) then
    status(false, 'Config fehlt: ' .. tostring(r.config))
    return
  end
  local rv = rivals()
  if rv.clearPcCache then rv.clearPcCache() end
  local mode = a.mode == 'pure' and 'pure' or 'game'
  local opts = { config = r.config, licenseText = r.plate and r.plate.text or nil }
  if mode == 'game' and rv.spawnSetup then
    local cfgOut, paints = rv.spawnSetup(r)
    opts.config = cfgOut or r.config
    if paints then opts.paint, opts.paint2, opts.paint3 = paints[1], paints[2], paints[3] end
  end
  local prevId, prevMode, prevPlate = loadedId, loadedMode, pendingPlate
  loadedId, loadedMode, expectSpawn, pendingPlate = r.id, mode, true, opts.licenseText
  local ok, err = pcall(core_vehicles.replaceVehicle, r.model, opts)
  if not ok then
    loadedId, loadedMode, expectSpawn, pendingPlate = prevId, prevMode, false, prevPlate
    status(false, 'Laden fehlgeschlagen: ' .. tostring(err))
    log('E', logTag, 'Gegner-Garage: ' .. tostring(r.id) .. ' nicht geladen: ' .. tostring(err))
    return
  end
  applyPlate()
  M.refresh()
  status(true, r.name .. ' geladen (' .. (mode == 'pure' and 'nur Config' or 'wie im Spiel') .. ')')
  log('I', logTag, 'Gegner-Garage: ' .. r.id .. ' geladen, ' .. tostring(r.config))
end

-- Speichern ---------------------------------------------------------------------------------------

local function pruneBackups(pattern)
  local files = FS:findFiles(backupDir, pattern, 0, false, false) or {}
  table.sort(files)
  for i = 1, #files - maxBackups do FS:removeFile(files[i]) end
end

local function backup(path, name)
  local old = readFile(path)
  if not old then return nil end
  if not FS:directoryExists(backupDir) then FS:directoryCreate(backupDir, true) end
  local b = backupDir .. name
  writeFile(b, old)
  return b
end

-- Lack so lesen, wie BeamNG beim Speichern einer Config (partmgmt captureVehiclePaints)
local function capturePaints(veh)
  local ok, paints = pcall(function()
    local out = {}
    local colorTable = veh:getColorFTable()
    for i = 1, tableSize(colorTable) do
      local metallic = stringToTable(veh:getField('metallicPaintData', i - 1))
      local p = createVehiclePaint({ x = colorTable[i].r, y = colorTable[i].g, z = colorTable[i].b, w = colorTable[i].a }, metallic)
      validateVehiclePaint(p)
      table.insert(out, p)
    end
    return out
  end)
  if ok and type(paints) == 'table' and #paints > 0 then return paints end
  return nil
end

local function currentConfig(veh)
  local okVd, vd = pcall(core_vehicle_manager.getPlayerVehicleData)
  if not okVd or not vd or not vd.config then return nil end
  local c = vd.config
  local parts = c.parts
  if type(parts) ~= 'table' and c.partsTree and core_vehicle_partmgmt and core_vehicle_partmgmt.partsTreeToPartsMap then
    local ok, map = pcall(core_vehicle_partmgmt.partsTreeToPartsMap, c.partsTree)
    if ok then parts = map end
  end
  if type(parts) ~= 'table' then return nil end
  local out = { parts = {}, vars = {} }
  for k, v in pairs(parts) do out.parts[k] = v end
  for k, v in pairs(c.vars or {}) do out.vars[k] = v end
  out.paints = capturePaints(veh) or c.paints
  return out
end

-- Ein Feld eines Gegners in rivals.json als Text ersetzen (Reihenfolge und Formatierung bleiben erhalten)
local function replaceField(text, id, field, value)
  local idPat = '"id"%s*:%s*"' .. id:gsub('%p', '%%%0') .. '"'
  local s, e = text:find(idPat)
  if not s then return nil, 'Gegner ' .. id .. ' nicht in rivals.json gefunden' end
  local nextId = text:find('"id"%s*:%s*"', e + 1) or #text
  local fs, fe, old = text:find('"' .. field .. '"%s*:%s*"([^"]*)"', e + 1)
  if not fs or fs > nextId then return nil, 'Feld ' .. field .. ' bei ' .. id .. ' nicht gefunden' end
  local repl = '"' .. field .. '": "' .. value .. '"'
  return text:sub(1, fs - 1) .. repl .. text:sub(fe + 1), old
end

local function saveRival(a)
  local r = findRival(a.id)
  if not r then status(false, 'Gegner nicht gefunden') return end
  if not garageActive() then status(false, 'Nur in der Gegner-Garage') return end
  local veh = getPlayerVehicle and getPlayerVehicle(0)
  if not veh then status(false, 'Kein Auto in der Garage') return end
  local root = modRoot()
  if not root then status(false, 'Mod-Ordner mods/unpacked/Hashiriya-Battle nicht gefunden') return end
  local model = veh:getJBeamFilename()
  local cfgNow = currentConfig(veh)
  if not cfgNow then status(false, 'Teileliste des Autos nicht lesbar') return end

  -- Ziel: eigene Mod-Config überschreiben (gleiches Modell, nicht mit anderen geteilt oder bewusst geteilt),
  -- sonst eine eigene Datei für diesen Gegner
  local oldPath = tostring(r.config or ''):gsub('^/', '')
  local rel
  -- Stufe ohne eigene Config fährt die der Stufe davor: nie überschreiben, eigene Datei anlegen
  if model == r.model and isOwnConfig(oldPath, root) and not a.ownFile and not (r.stageOf and not r.stageOwnConfig) then
    rel = oldPath
  else
    local safeId = tostring(r.id):lower():gsub('[^a-z0-9_]', '_')
    rel = 'vehicles/' .. model .. '/hashiriya_r_' .. safeId .. '.pc'
  end
  local key = configKey(rel)
  local dir = root .. 'vehicles/' .. model .. '/'
  if not FS:directoryExists(dir) then FS:directoryCreate(dir, true) end
  local stamp = os.date('%Y%m%d_%H%M%S')
  if FS:fileExists(root .. rel) then backup(root .. rel, 'config_' .. key .. '_' .. stamp .. '.pc') end

  local pc = { format = 2, model = model, mainPartName = model, parts = cfgNow.parts, vars = cfgNow.vars, paints = cfgNow.paints }
  jsonWriteFile(root .. rel, pc, true)
  if not FS:fileExists(root .. rel) then status(false, 'Config nicht geschrieben: ' .. rel) return end

  -- info_<key>.json: vorhandene behalten, sonst von der alten Config übernehmen (Wert/Leistung für den Händler)
  local infoRel = 'vehicles/' .. model .. '/info_' .. key .. '.json'
  local info = jsonReadFile(root .. infoRel)
  if type(info) ~= 'table' then
    local oldDir, oldName = oldPath:match('^(.*)/([^/]+)%.pc$')
    info = (oldDir and jsonReadFile('/' .. oldDir .. '/info_' .. oldName .. '.json')) or {}
    if type(info) ~= 'table' then info = {} end
    info.Configuration = 'Hashiriya: ' .. tostring(r.name)
    info.Source = nil
    jsonWriteFile(root .. infoRel, info, true)
  end

  -- rivals.json anpassen, wenn sich Pfad oder Modell ändert
  local changed = {}
  if rel ~= oldPath or model ~= r.model or (r.stageOf and not r.stageOwnConfig) then
    local jsonPath = root .. dataRel
    local text = readFile(jsonPath)
    if not text then status(false, 'Config gespeichert, aber rivals.json nicht lesbar: ' .. rel) return end
    local newText, err = text, nil
    if r.stageOf then
      -- Stufe: Config und Modell in ihren Eintrag unter "stages" schreiben
      newText, err = setRivalOrStageField(newText, r, 'config', '"' .. rel .. '"')
      if newText and model ~= r.model then newText, err = setRivalOrStageField(newText, r, 'model', '"' .. model .. '"') end
      if not newText then status(false, 'Config gespeichert, rivals.json nicht geändert: ' .. tostring(err)) return end
      table.insert(changed, 'stage ' .. tostring(r.stage))
    elseif rel ~= oldPath then
      newText, err = replaceField(newText, r.id, 'config', rel)
      if not newText then status(false, 'Config gespeichert, rivals.json nicht geändert: ' .. err) return end
      table.insert(changed, 'config')
    end
    if model ~= r.model and not r.stageOf then
      newText, err = replaceField(newText, r.id, 'model', model)
      if not newText then status(false, 'Config gespeichert, rivals.json nicht geändert: ' .. err) return end
      table.insert(changed, 'model')
    end
    local okJson = pcall(jsonDecode, newText, 'garagetool')
    if not okJson then status(false, 'rivals.json wäre ungültig, nicht gespeichert') return end
    local b = backup(jsonPath, 'rivals_' .. stamp .. '.json')
    pcall(pruneBackups, 'rivals_*.json')
    writeFile(jsonPath, newText)
    log('I', logTag, 'Gegner-Garage: rivals.json ' .. r.id .. ' ' .. table.concat(changed, '+') .. ' -> ' .. rel .. ' (Sicherung ' .. tostring(b) .. ')')
  end
  pcall(pruneBackups, 'config_*.pc')

  pcall(core_vehicles.clearCache)
  modelCache = {}
  local rv = rivals()
  if rv.clearPcCache then rv.clearPcCache() end
  rv.loadData()
  if core().resetDevRivals then pcall(core().resetDevRivals) end
  loadedId = r.id
  local where = rel == oldPath and 'überschrieben' or 'neu angelegt'
  status(true, 'Gespeichert: ' .. rel .. ' (' .. where .. (#changed > 0 and ', rivals.json angepasst' or '') .. ')')
  log('I', logTag, 'Gegner-Garage: ' .. r.id .. ' gespeichert nach ' .. root .. rel)
  M.refresh()
end

-- Aktionen aus der App -----------------------------------------------------------------------------

-- Aura-Vorschau -------------------------------------------------------------------------------------

-- Spec für aura.setPreview aus Gegner + Modus
function M.auraSpec(p)
  local au = extensions.hashiriyaBattle_aura
  local r = p and findRival(p.id)
  if not au or not r then return nil end
  local color = au.colorOf and au.colorOf(r) or '#ff6600'
  if type(p.color) == 'string' and p.color:match('^#%x%x%x%x%x%x$') then color = p.color end
  local rim = nil
  if r.leader then
    local okC, c = pcall(function() return jsonReadFile('/lua/ge/extensions/hashiriyaBattle/data/aura.json') end)
    rim = okC and c and c.leaderRimColor or '#ffd257'
  end
  local mode = p.mode or 'ground'
  return {
    color = color, rim = rim,
    ground = mode == 'ground' or mode == 'both',
    battle = mode == 'battle' or mode == 'both',
    sp = math.max(0, math.min(1, tonumber(p.sp) or 1)),
    level = math.max(1, math.min(3, math.floor(tonumber(p.level) or tonumber(r.auraLevel) or tonumber((au.config and au.config() or {}).rivalLevel) or 2))),
    boost = math.max(1, math.min(20, tonumber(p.boost) or 1)),
  }
end


local function auraAction(a)
  if not garageActive() then status(false, 'Nur in der Gegner-Garage') return end
  local au = extensions.hashiriyaBattle_aura
  if not au or not au.setPreview then status(false, 'aura.lua fehlt oder ist zu alt') return end
  if not a.id or a.mode == 'off' then
    setAuraPreview(nil)
    status(true, 'Aura aus')
    M.refresh()
    return
  end
  local r = findRival(a.id)
  if not r then status(false, 'Gegner nicht gefunden: ' .. tostring(a.id)) return end
  setAuraPreview({ id = r.id, mode = a.mode or 'ground', sp = a.sp, level = a.level, boost = a.boost, color = a.color })
  local names = { ground = 'Boden-Aura', battle = 'Battle-Aura', both = 'Boden + Battle' }
  status(true, 'Aura von ' .. tostring(r.name) .. ': ' .. (names[a.mode] or tostring(a.mode)))
  M.refresh()
end

local function auraReload()
  local au = extensions.hashiriyaBattle_aura
  if not au or not au.reload then status(false, 'aura.lua fehlt') return end
  au.reload()
  auraChanged = {}
  if auraPreview then setAuraPreview(auraPreview) end
  status(true, 'aura.json neu geladen')
  M.refresh()
end

-- Aura-Editor ---------------------------------------------------------------------------------------

-- Wert aus aura.json live ändern (nur im Speicher, bis "aura.json speichern")
local auraEditable = { who = true, shell = true, haze = true, ground = true, battle = true, rim = true, rivalLevel = true }
local function auraSet(a)
  local au = extensions.hashiriyaBattle_aura
  if not au or not au.setValue then status(false, 'aura.lua fehlt oder ist zu alt') return end
  local path = tostring(a.path or '')
  local top = path:match('^([^%.]+)')
  if not top or not auraEditable[top] then status(false, 'Wert nicht änderbar: ' .. path) return end
  local v = a.value
  if type(v) ~= 'number' and type(v) ~= 'boolean' then status(false, 'Ungültiger Wert für ' .. path) return end
  au.setValue(path, v)
  auraChanged[path] = v
  if auraPreview then setAuraPreview(auraPreview) end
  M.refresh()
end

-- aura.json gezielt im Text ändern: nur die geänderten Werte, Reihenfolge und Format bleiben wie in der Datei

-- Objekt ab Position s ("{"): Position des Werts zu key (direkt in diesem Objekt) und Ende des Objekts
local function jsonFindKey(text, s, key)
  local depth, i, n = 0, s, #text
  while i <= n do
    local c = text:sub(i, i)
    if c == '"' then
      local j = i + 1
      while j <= n do
        local d = text:sub(j, j)
        if d == '\\' then j = j + 2 elseif d == '"' then break else j = j + 1 end
      end
      if depth == 1 and text:sub(i + 1, j - 1) == key then
        local _, ce = text:find('^%s*:%s*', j + 1)
        if ce then return ce + 1 end
      end
      i = j + 1
    else
      if c == '{' or c == '[' then depth = depth + 1
      elseif c == '}' or c == ']' then
        depth = depth - 1
        if depth == 0 then return nil, i end
      end
      i = i + 1
    end
  end
  return nil, n
end

local function jsonNum(v)
  if type(v) == 'boolean' then return tostring(v) end
  local t = string.format('%.4f', v):gsub('0+$', ''):gsub('%.$', '')
  return t
end

local function patchJsonPath(text, path, value)
  local keys = {}
  for k in path:gmatch('[^%.]+') do table.insert(keys, k) end
  local objStart = text:find('{')
  for i, k in ipairs(keys) do
    local vs, objEnd = jsonFindKey(text, objStart, k)
    if not vs then
      if i < #keys then return nil, 'Abschnitt fehlt: ' .. k end
      -- neuer Schlüssel: vor die schließende Klammer, mit gleicher Einrückung wie die anderen
      local before = text:sub(1, objEnd - 1):gsub('%s*$', '')
      local ind = (text:sub(objStart, objEnd):match('\n(%s*)"') or '  ')
      local closeInd = text:sub(1, objEnd - 1):match('\n([ \t]*)$') or ''
      return before .. ',\n' .. ind .. '"' .. k .. '": ' .. jsonNum(value) .. '\n' .. closeInd .. text:sub(objEnd)
    end
    if i == #keys then
      local ve = text:find('[,%}%]\r\n]', vs) or (#text + 1)
      local old = text:sub(vs, ve - 1):gsub('%s+$', '')
      return text:sub(1, vs - 1) .. jsonNum(value) .. text:sub(vs + #old)
    end
    if text:sub(vs, vs) ~= '{' then return nil, k .. ' ist kein Abschnitt' end
    objStart = vs
  end
end
M._patchJsonPath = patchJsonPath -- für Tests

-- Ende (inklusive) des JSON-Werts, der bei vs beginnt
local function jsonValueEnd(text, vs)
  local c = text:sub(vs, vs)
  local n = #text
  if c == '"' then
    local j = vs + 1
    while j <= n do
      local d = text:sub(j, j)
      if d == '\\' then j = j + 2 elseif d == '"' then return j else j = j + 1 end
    end
    return n
  end
  if c == '{' or c == '[' then
    local depth, i = 0, vs
    while i <= n do
      local d = text:sub(i, i)
      if d == '"' then i = jsonValueEnd(text, i)
      elseif d == '{' or d == '[' then depth = depth + 1
      elseif d == '}' or d == ']' then depth = depth - 1; if depth == 0 then return i end end
      i = i + 1
    end
    return n
  end
  local e = text:find('[,%}%]%s]', vs)
  return (e or (n + 1)) - 1
end

-- Schlüssel in dem Objekt ab objStart ("{") setzen, ändern oder (jsonValue == nil) entfernen
local function jsonObjSet(text, objStart, key, jsonValue)
  local vs, objEnd = jsonFindKey(text, objStart, key)
  if vs then
    local ve = jsonValueEnd(text, vs)
    if jsonValue ~= nil then return text:sub(1, vs - 1) .. jsonValue .. text:sub(ve + 1) end
    local ks = nil
    local from = 1
    while true do
      local a = text:find('"' .. key .. '"', from, true)
      if not a or a >= vs then break end
      ks = a
      from = a + 1
    end
    if not ks then return text end
    local _, ce = text:find('^%s*,%s*', ve + 1)
    if ce then return text:sub(1, ks - 1) .. text:sub(ce + 1) end
    local before = text:sub(1, ks - 1):gsub('%s*,%s*$', '')
    return before .. text:sub(ve + 1)
  end
  if jsonValue == nil then return text end
  local inner = text:sub(objStart, objEnd)
  local ind = inner:match('\n(%s*)"') or ''
  local closeInd = text:sub(1, objEnd - 1):match('\n([ \t]*)$') or ''
  local before = text:sub(1, objEnd - 1):gsub('%s*$', '')
  if ind == '' then
    local lineInd = text:sub(1, objStart):match('\n([ \t]*)[^\n]*$') or ''
    ind = lineInd .. '  '
    closeInd = lineInd
  end
  local sep = before:sub(-1) == '{' and '' or ','
  return before .. sep .. '\n' .. ind .. '"' .. key .. '": ' .. jsonValue .. '\n' .. closeInd .. text:sub(objEnd)
end

-- Objekt der Stufe n (2, 3 ...) von Rivale baseId in rivals.json: Startposition von "{"
local function stageObjStart(text, baseId, n)
  local listStart = text:find('"rivals"%s*:%s*%[') or 1
  local idPat = '"id"%s*:%s*"' .. baseId:gsub('%p', '%%%0') .. '"'
  local s0 = text:find(idPat, listStart)
  if not s0 then return nil, 'Gegner ' .. baseId .. ' nicht in rivals.json gefunden' end
  -- umschließendes Objekt suchen (rückwärts bis zur offenen Klammer)
  local depth, i = 0, s0 - 1
  while i > 0 do
    local c = text:sub(i, i)
    if c == '}' or c == ']' then depth = depth + 1
    elseif c == '{' or c == '[' then
      if depth == 0 then break end
      depth = depth - 1
    end
    i = i - 1
  end
  if i <= 0 then return nil, 'Gegner ' .. baseId .. ': Objekt nicht gefunden' end
  local as = jsonFindKey(text, i, 'stages')
  if not as or text:sub(as, as) ~= '[' then return nil, baseId .. ' hat keine "stages"' end
  local k, j, ae = 0, as + 1, jsonValueEnd(text, as)
  while j < ae do
    local c = text:sub(j, j)
    if c == '{' then
      k = k + 1
      if k == n - 1 then return j end
      j = jsonValueEnd(text, j) + 1
    elseif c == '"' or c == '[' then j = jsonValueEnd(text, j) + 1
    else j = j + 1 end
  end
  return nil, baseId .. ': Stufe ' .. n .. ' fehlt in "stages"'
end

-- Feld eines Gegners setzen; bei Stufen landet es in rivals.json im Eintrag der Stufe
setRivalOrStageField = function(text, r, field, jsonValue)
  if not r.stageOf then return M._setRivalField(text, r.id, field, jsonValue) end
  local os_, err = stageObjStart(text, r.stageOf, r.stage)
  if not os_ then return nil, err end
  return jsonObjSet(text, os_, field, jsonValue)
end
M._setRivalOrStageField = setRivalOrStageField -- für Tests

local auraRel = 'lua/ge/extensions/hashiriyaBattle/data/aura.json'
local function auraSaveCfg()
  local root = modRoot()
  if not root then status(false, 'Mod-Ordner mods/unpacked/Hashiriya-Battle nicht gefunden') return end
  if next(auraChanged) == nil then status(true, 'aura.json: nichts geändert') return end
  local text = readFile(root .. auraRel)
  if not text then status(false, 'aura.json nicht lesbar') return end
  local paths = {}
  for p in pairs(auraChanged) do table.insert(paths, p) end
  table.sort(paths)
  for _, p in ipairs(paths) do
    local t, err = patchJsonPath(text, p, auraChanged[p])
    if not t then status(false, 'aura.json: ' .. tostring(err)) return end
    text = t
  end
  local okJson = pcall(jsonDecode, text, 'garagetool')
  if not okJson then status(false, 'aura.json wäre ungültig, nicht gespeichert') return end
  local stamp = os.date('%Y%m%d_%H%M%S')
  local b = backup(root .. auraRel, 'aura_' .. stamp .. '.json')
  pcall(pruneBackups, 'aura_*.json')
  writeFile(root .. auraRel, text)
  auraChanged = {}
  log('I', logTag, 'Gegner-Garage: aura.json gespeichert: ' .. table.concat(paths, ', ') .. ' (Sicherung ' .. tostring(b) .. ')')
  status(true, 'aura.json gespeichert (' .. #paths .. ' Werte, Sicherung in builder_backups)')
end

-- Feld eines Rivalen setzen, ändern oder entfernen (Text, Reihenfolge bleibt). jsonValue = fertiger JSON-Text oder nil = entfernen
local function setRivalField(text, id, field, jsonValue)
  local idPat = '"id"%s*:%s*"' .. id:gsub('%p', '%%%0') .. '"'
  local listStart = text:find('"rivals"%s*:%s*%[') or 1
  local s0, e0 = text:find(idPat, listStart)
  if not s0 then return nil, 'Gegner ' .. id .. ' nicht in rivals.json gefunden' end
  local nextId = text:find('"id"%s*:%s*"', e0 + 1) or #text
  -- vorhandenes Feld (Wert: Text, Zahl, true/false)
  local fs, fe = text:find('%s*"' .. field .. '"%s*:%s*"[^"]*"%s*,?', e0 + 1)
  if not fs or fs > nextId then fs, fe = text:find('%s*"' .. field .. '"%s*:%s*[%w%.%-]+%s*,?', e0 + 1) end
  if fs and fs > nextId then fs, fe = nil, nil end
  if fs then
    local chunk = text:sub(fs, fe)
    local hadComma = chunk:match(',%s*$') ~= nil
    if jsonValue == nil then
      if hadComma then return text:sub(1, fs - 1) .. text:sub(fe + 1) end
      -- letztes Feld: Komma davor mit entfernen
      local before = text:sub(1, fs - 1):gsub(',%s*$', '')
      return before .. text:sub(fe + 1)
    end
    local lead = chunk:match('^(%s*)')
    return text:sub(1, fs - 1) .. lead .. '"' .. field .. '": ' .. jsonValue .. (hadComma and ',' or '') .. text:sub(fe + 1)
  end
  if jsonValue == nil then return text end
  -- neu: direkt hinter "id": "..." einfügen, gleiche Einrückung wie die id-Zeile
  local lineStart = text:sub(1, s0 - 1):match('.*\n()') or 1
  local indent = text:sub(lineStart, s0 - 1):match('^(%s*)') or ''
  return text:sub(1, e0) .. ',\n' .. indent .. '"' .. field .. '": ' .. jsonValue .. text:sub(e0 + 1)
end
M._setRivalField = setRivalField -- für Tests

local function auraSaveRival(a)
  local r = findRival(a.id)
  if not r then status(false, 'Gegner nicht gefunden') return end
  local root = modRoot()
  if not root then status(false, 'Mod-Ordner mods/unpacked/Hashiriya-Battle nicht gefunden') return end
  local jsonPath = root .. dataRel
  local text = readFile(jsonPath)
  if not text then status(false, 'rivals.json nicht lesbar') return end
  local on = a.on
  local onJson = (on == true and 'true') or (on == false and 'false') or nil
  local color = type(a.color) == 'string' and a.color:match('^#%x%x%x%x%x%x$') and a.color:lower() or nil
  local level = tonumber(a.level)
  local levelJson = level and tostring(math.max(1, math.min(3, math.floor(level)))) or nil
  local err
  text, err = setRivalOrStageField(text, r, 'auraOn', onJson)
  if not text then status(false, err) return end
  text, err = setRivalOrStageField(text, r, 'aura', color and ('"' .. color .. '"') or nil)
  if not text then status(false, err) return end
  text, err = setRivalOrStageField(text, r, 'auraLevel', levelJson)
  if not text then status(false, err) return end
  local okJson = pcall(jsonDecode, text, 'garagetool')
  if not okJson then status(false, 'rivals.json wäre ungültig, nicht gespeichert') return end
  local stamp = os.date('%Y%m%d_%H%M%S')
  local b = backup(jsonPath, 'rivals_' .. stamp .. '.json')
  pcall(pruneBackups, 'rivals_*.json')
  writeFile(jsonPath, text)
  rivals().loadData()
  log('I', logTag, string.format('Gegner-Garage: Aura von %s gespeichert (an=%s, Farbe=%s, Stufe=%s, Sicherung %s)',
    r.id, tostring(onJson or 'Standard'), tostring(color or 'Standard'), tostring(levelJson or 'Standard'), tostring(b)))
  if auraPreview then setAuraPreview(auraPreview) end
  status(true, 'Aura von ' .. tostring(r.name) .. ' gespeichert (rivals.json)')
  M.refresh()
end

local actions = {
  load = loadRival,
  save = saveRival,
  aura = auraAction,
  auraReload = auraReload,
  auraSet = auraSet,
  auraSaveCfg = auraSaveCfg,
  auraSaveRival = auraSaveRival,
  refresh = function() M.refresh() end,
  state = function() pushState(true) end,
}

function M.action(name, argText)
  if not M.isAllowed() then return end
  local a = {}
  if type(argText) == 'string' and argText ~= '' then
    local ok, d = pcall(jsonDecode, argText, 'hashiriyaGarage')
    if ok and type(d) == 'table' then a = d end
  end
  local f = actions[name]
  if not f then log('W', logTag, 'Gegner-Garage: unbekannte Aktion ' .. tostring(name)) return end
  local ok, err = pcall(f, a)
  if not ok then
    log('E', logTag, 'Gegner-Garage ' .. tostring(name) .. ': ' .. tostring(err))
    status(false, 'Fehler: ' .. tostring(err))
  end
end

return M
