-- Hashiriya Battle: Gegner-Garage (Entwickler-Werkzeug, nicht im Release).
-- In der BeamNG-Garage (Hauptmenü > Mehr > Garage) erscheint zusätzlich das Panel HashiriyaGarage:
-- Gegner aus rivals.json wählen, sein Auto mit seiner Config wird in der Garage geladen, daneben stehen
-- Crew, Beschreibung, Bedingungen und Sprüche. Nach dem Anpassen mit den Garage-Menüs (Teile, Tuning, Lack)
-- speichert "Auf Gegner speichern" die Config zurück:
--   * eigene Mod-Config (vehicles/<model>/hashiriya_*.pc im Mod-Ordner) wird überschrieben (Sicherung vorher),
--   * eine BeamNG- oder fremde Config bleibt unangetastet: es entsteht vehicles/<model>/hashiriya_r_<id>.pc im
--     Mod-Ordner, und rivals.json bekommt beim Gegner den neuen Pfad (und das Modell, falls du das Auto gewechselt hast).
-- Die Original-Garage bleibt unverändert: Wir schalten nur, solange die Garage offen ist, auf unser eigenes
-- UI-Layout "hashiriyaGarage" (Garage-Meldungen + Panel). Datei-Overrides der BeamNG-Garage gibt es nicht.
-- Ein-/Ausschalten: Dev-Menü > Werkzeuge, gemerkt in settings/hashiriya_battle/garagetool.json.
local M = {}

local logTag = 'hashiriya'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local layoutName = 'hashiriyaGarage' -- settings/ui_apps/originalLayouts/default/hashiriyaGarage.uilayout.json
local settingsFile = '/settings/hashiriya_battle/garagetool.json'
local backupDir = '/settings/hashiriya_battle/builder_backups/'
local dataRel = 'lua/ge/extensions/hashiriyaBattle/data/rivals.json'
local maxBackups = 20

local cfg = nil
local loadedId = nil   -- Gegner, dessen Auto gerade in der Garage steht
local loadedMode = nil -- 'game' (wie im Spiel: Kennzeichen-Design, fester Lack) oder 'pure' (nur die .pc)

local function core() return extensions.hashiriyaBattle_core end
local function rivals() return extensions.hashiriyaBattle_rivals end
local function send(data) guihooks.trigger('HashiriyaGarage', data) end
local function status(ok, text) send({ status = { ok = ok, text = text, time = os.date('%H:%M:%S') } }) end

local function settings()
  if not cfg then
    cfg = jsonReadFile(settingsFile) or {}
    if cfg.auto == nil then cfg.auto = true end
  end
  return cfg
end

local function saveSettings()
  local dir = settingsFile:match('^(.*/)')
  if not FS:directoryExists(dir) then FS:directoryCreate(dir, true) end
  jsonWriteFile(settingsFile, settings(), true)
end

function M.isAllowed()
  local c = core()
  if c and c.isRelease then return not c.isRelease() end
  return true
end

local function garageActive()
  local g = rawget(_G, 'gameplay_garageMode') or extensions.gameplay_garageMode
  local ok, on = pcall(function() return g and g.isActive() end)
  return ok and on or false
end
M.garageActive = garageActive

local function modRoot()
  local b = extensions.hashiriyaBattle_builder
  if b and b.modRoot then return b.modRoot() end
  for _, r in ipairs({ '/mods/unpacked/Hashiriya-Battle/', '/mods/unpacked/hashiriya-battle/' }) do
    if FS:fileExists(r .. dataRel) then return r end
  end
end

-- Layout ----------------------------------------------------------------------------------

local function setLayout(name)
  local gs = rawget(_G, 'core_gamestate')
  if gs and gs.setGameState then pcall(gs.setGameState, nil, name) end
end

-- BeamNG setzt beim Betreten der Garage state 'garage' + Layout 'garage' (gameplay_garageMode.activateGarageMode,
-- noch bevor isActive() true ist). Dann auf unser Layout umschalten.
function M.onGameStateUpdate(state)
  if type(state) ~= 'table' or not M.isAllowed() then return end
  if state.state == 'garage' and state.appLayout == 'garage' and settings().auto then
    setLayout(layoutName)
    log('I', logTag, 'Gegner-Garage: Panel eingeblendet (Layout ' .. layoutName .. ')')
  end
end

function M.onEndGarageMode()
  loadedId, loadedMode = nil, nil
end

-- Auto in der Garage gewechselt (auch über die Garage-Menüs): Anzeige "in der Garage" aktualisieren
function M.onVehicleSpawned()
  local gs = rawget(_G, 'core_gamestate')
  if gs and gs.state and gs.state.appLayout == layoutName then M.refresh() end
end

function M.getAuto() return settings().auto and true or false end

function M.setAuto(on)
  settings().auto = on and true or false
  saveSettings()
  local gs = rawget(_G, 'core_gamestate')
  local st = gs and gs.state or {}
  if garageActive() then
    if on and st.appLayout == 'garage' then setLayout(layoutName)
    elseif not on and st.appLayout == layoutName then setLayout('garage') end
  end
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
  for i, r in ipairs(data.rivals or {}) do
    local ci = configInfo(r.model, r.config)
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
    })
  end
  local ranks = {}
  for i, rk in ipairs(data.ranks or {}) do ranks[i] = loc(rk.name) end
  return { teams = teams, rivals = list, ranks = ranks, root = root }
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
    full = true, garage = garageActive(), auto = settings().auto,
    teams = d.teams, rivals = d.rivals, ranks = d.ranks, root = d.root,
    loadedId = loadedId, loadedMode = loadedMode, player = playerInfo(),
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
  if not garageActive() then status(false, 'Nur in der BeamNG-Garage (Hauptmenü > Mehr > Garage)') return end
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
  local ok, err = pcall(core_vehicles.replaceVehicle, r.model, opts)
  if not ok then
    status(false, 'Laden fehlgeschlagen: ' .. tostring(err))
    log('E', logTag, 'Gegner-Garage: ' .. tostring(r.id) .. ' nicht geladen: ' .. tostring(err))
    return
  end
  loadedId, loadedMode = r.id, mode
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
  if not garageActive() then status(false, 'Nur in der BeamNG-Garage') return end
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
  if model == r.model and isOwnConfig(oldPath, root) and not a.ownFile then
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
  if rel ~= oldPath or model ~= r.model then
    local jsonPath = root .. dataRel
    local text = readFile(jsonPath)
    if not text then status(false, 'Config gespeichert, aber rivals.json nicht lesbar: ' .. rel) return end
    local newText, err = text, nil
    if rel ~= oldPath then
      newText, err = replaceField(newText, r.id, 'config', rel)
      if not newText then status(false, 'Config gespeichert, rivals.json nicht geändert: ' .. err) return end
      table.insert(changed, 'config')
    end
    if model ~= r.model then
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

local actions = {
  load = loadRival,
  save = saveRival,
  hide = function() M.setAuto(false) end,
  refresh = function() M.refresh() end,
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
