-- Hashiriya Battle: Builder (Entwickler-Werkzeug) für Crews, Wanderer und Bosse.
-- Die Oberfläche ist die UI-App HashiriyaBuilder (ui/modules/apps/HashiriyaBuilder). Sie bekommt rivals.json als Text,
-- bearbeitet ihn im Browser-Teil (Reihenfolge der Felder bleibt so erhalten) und schickt ihn in Stücken zurück.
-- Gespeichert wird direkt in den Mod-Ordner (mods/unpacked/Hashiriya-Battle/...), vorher eine Sicherung nach
-- settings/hashiriya_battle/builder_backups/ (die letzten 20 bleiben).
-- Im Release (data/build.json release = true) ist der Builder aus; das Release-Zip soll diese Datei nicht enthalten.
local M = {}

local logTag = 'hashiriya'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local dataRel = 'lua/ge/extensions/hashiriyaBattle/data/rivals.json'
local modRootGuesses = { '/mods/unpacked/Hashiriya-Battle/', '/mods/unpacked/hashiriya-battle/', '/mods/unpacked/hashiriya_battle/' }
local backupDir = '/settings/hashiriya_battle/builder_backups/'
local maxBackups = 20
local incoming = nil

local function core() return extensions.hashiriyaBattle_core end
local function send(data) guihooks.trigger('HashiriyaBuilder', data) end
local function reply(ok, text) send({ status = { ok = ok, text = text, time = os.date('%H:%M:%S') } }) end

function M.isAllowed()
  local c = core()
  if c and c.isRelease then return not c.isRelease() end
  return not (c and c.buildData and c.buildData.release == true)
end

-- Mod-Ordner im Userordner finden (nur ein entpackter Mod lässt sich beschreiben)
function M.modRoot()
  for _, r in ipairs(modRootGuesses) do
    if FS:fileExists(r .. dataRel) then return r end
  end
  local mm = rawget(_G, 'core_modmanager')
  if mm and mm.getModList then
    local ok, list = pcall(mm.getModList)
    if ok and type(list) == 'table' then
      for _, m in pairs(list) do
        local p = type(m) == 'table' and m.unpackedPath
        if type(p) == 'string' and p ~= '' then
          local root = '/' .. p:gsub('\\', '/'):gsub('^/', ''):gsub('/*$', '') .. '/'
          if FS:fileExists(root .. dataRel) then return root end
        end
      end
    end
  end
  return nil
end

-- Alle Autos mit Configs (auch Mod-Autos und eigene Configs)
local function configList()
  local out = {}
  local keys = core().getModelKeys and core().getModelKeys() or {}
  for _, key in ipairs(keys) do
    local ok, info = pcall(core_vehicles.getModel, key)
    if ok and info and info.model then
      local kind = info.model.Type
      if kind == 'Car' or kind == 'Truck' then
        local brand = info.model.Brand or ''
        local m = { id = key, name = (brand ~= '' and (brand .. ' ') or '') .. tostring(info.model.Name or key), configs = {} }
        for cfgKey, cfg in pairs(info.configs or {}) do
          table.insert(m.configs, {
            key = cfgKey,
            name = tostring(cfg.Configuration or cfg.Name or cfgKey),
            source = cfg.Source,
            value = tonumber(cfg.Value),
            power = tonumber(cfg.Power),
          })
        end
        table.sort(m.configs, function(a, b) return a.name < b.name end)
        table.insert(out, m)
      end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- Vorhandene Porträts: id -> Pfad (gleiche Reihenfolge wie battle.lua: png, jpg, svg)
local function portraitList()
  local found = {}
  for _, f in ipairs(FS:findFiles('/art/portraits/', '*.*', 0, false, false) or {}) do
    local id, ext = f:match('([^/]+)%.(%a+)$')
    if id then
      ext = ext:lower()
      local rank = ({ png = 1, jpg = 2, svg = 3 })[ext]
      if rank and (not found[id] or found[id].rank > rank) then found[id] = { rank = rank, path = f } end
    end
  end
  local out = {}
  for id, v in pairs(found) do out[id] = v.path end
  return out
end

local function plateOptions()
  local p = extensions.hashiriyaBattle_plates
  local byRegion = {}
  for _, r in ipairs(p.regions) do byRegion[r] = p.typesFor(r) end
  return { regions = p.regions, byRegion = byRegion }
end

local function playerInfo()
  local veh = core().getPlayerVehicle and core().getPlayerVehicle()
  if not veh then return nil end
  return { model = veh:getJBeamFilename() }
end

function M.open()
  if not M.isAllowed() then
    core().msg('Builder ist im Release-Build aus (data/build.json release = false setzen).', 6)
    return
  end
  local root = M.modRoot()
  local text = readFile((root or '/') .. dataRel)
  if not text then
    core().msg('Builder: rivals.json nicht lesbar', 6)
    return
  end
  send({
    open = true,
    text = text,
    root = root,
    configs = configList(),
    portraits = portraitList(),
    plates = plateOptions(),
    player = playerInfo(),
    active = core().active and true or false,
  })
  log('I', logTag, 'Builder geöffnet' .. (root and (' (' .. root .. ')') or ' (Mod-Ordner nicht gefunden, Speichern gesperrt)'))
end

function M.close() send({ open = false }) end

-- Text in Stücken vom Browser-Teil empfangen (große Texte passen nicht in einen Aufruf)
function M.chunkBegin() incoming = {} end
function M.chunk(s) if incoming then table.insert(incoming, s) end end
function M.chunkEnd(what, arg)
  local text = table.concat(incoming or {})
  incoming = nil
  if what == 'save' then M.save(text)
  elseif what == 'spawn' then M.spawn(text)
  elseif what == 'silhouette' then M.writeSilhouetteData(text)
  else log('W', logTag, 'Builder: unbekannter Auftrag ' .. tostring(what)) end
end

local function pruneBackups()
  local files = FS:findFiles(backupDir, 'rivals_*.json', 0, false, false) or {}
  table.sort(files)
  for i = 1, #files - maxBackups do FS:removeFile(files[i]) end
end

function M.save(text)
  if not M.isAllowed() then return end
  local ok, data = pcall(jsonDecode, text, 'builder')
  if not ok or type(data) ~= 'table' or type(data.rivals) ~= 'table' or type(data.teams) ~= 'table' then
    reply(false, 'Nicht gespeichert: Daten ungültig')
    log('E', logTag, 'Builder: ungültiges JSON, nichts gespeichert')
    return
  end
  local root = M.modRoot()
  if not root then
    reply(false, 'Nicht gespeichert: Mod-Ordner mods/unpacked/Hashiriya-Battle nicht gefunden')
    return
  end
  local path = root .. dataRel
  local old = readFile(path)
  local backup = nil
  if old then
    if not FS:directoryExists(backupDir) then FS:directoryCreate(backupDir, true) end
    backup = backupDir .. 'rivals_' .. os.date('%Y%m%d_%H%M%S') .. '.json'
    writeFile(backup, old)
    pcall(pruneBackups)
  end
  writeFile(path, text)
  if readFile(path) ~= text then
    reply(false, 'Speichern fehlgeschlagen: ' .. path)
    log('E', logTag, 'Builder: Schreiben fehlgeschlagen ' .. path)
    return
  end
  extensions.hashiriyaBattle_rivals.loadData()
  if core().resetDevRivals then core().resetDevRivals() end
  reply(true, 'Gespeichert (' .. #data.rivals .. ' Rivalen, ' .. #data.teams .. ' Crews)')
  log('I', logTag, 'Builder: rivals.json gespeichert, Sicherung ' .. tostring(backup))
end

-- Silhouetten-Tool (Userordner hashiriya_tools/silhouette) bekommt nach jedem Speichern die aktuelle Gegnerliste,
-- damit neue Rivalen dort sofort auftauchen. Nur wenn der Ordner existiert.
local silhouetteDir = '/hashiriya_tools/silhouette/'
function M.writeSilhouetteData(text)
  if not M.isAllowed() then return end
  if not FS:directoryExists(silhouetteDir) then return end
  if type(text) ~= 'string' or not text:find('window.HB_RIVALS', 1, true) then return end
  writeFile(silhouetteDir .. 'rivals_data.js', text)
  log('I', logTag, 'Builder: Silhouetten-Tool aktualisiert (' .. silhouetteDir .. 'rivals_data.js)')
end

-- Probe-Spawn mit den Werten aus dem Formular (auch ungespeichert)
function M.spawn(text)
  if not M.isAllowed() then return end
  local ok, r = pcall(jsonDecode, text, 'builder')
  if not ok or type(r) ~= 'table' or not r.model then
    reply(false, 'Test-Spawn: Daten ungültig')
    return
  end
  if not core().active then
    reply(false, 'Test-Spawn geht nur in einer laufenden Karriere')
    return
  end
  extensions.hashiriyaBattle_rivals.spawnNext(true, r)
  reply(true, 'Test-Spawn: ' .. tostring(r.name or r.id))
end

-- Aktuelles Auto des Spielers als Config in den Mod-Ordner speichern: vehicles/<model>/hashiriya_<name>.pc
function M.saveCarConfig(name)
  if not M.isAllowed() then return end
  local veh = core().getPlayerVehicle and core().getPlayerVehicle()
  local cfg = extensions.hashiriyaBattle_shop.currentConfig()
  if not veh or not cfg then
    reply(false, 'Kein Auto oder Teileliste nicht lesbar')
    return
  end
  local root = M.modRoot()
  if not root then
    reply(false, 'Mod-Ordner nicht gefunden')
    return
  end
  local model = veh:getJBeamFilename()
  local safe = tostring(name or ''):lower():gsub('[^a-z0-9_]', '_'):gsub('_+', '_'):gsub('^_', ''):gsub('_$', '')
  if safe == '' then safe = 'config' end
  local key = safe:match('^hashiriya_') and safe or ('hashiriya_' .. safe)
  local rel = 'vehicles/' .. model .. '/' .. key .. '.pc'
  local dir = root .. 'vehicles/' .. model .. '/'
  if not FS:directoryExists(dir) then FS:directoryCreate(dir, true) end
  local pc = { format = 2, model = model, mainPartName = model, Configuration = key, parts = cfg.parts, vars = cfg.vars, paints = cfg.paints }
  jsonWriteFile(root .. rel, pc, true)
  if not FS:fileExists(root .. rel) then
    reply(false, 'Config nicht geschrieben: ' .. rel)
    return
  end
  send({ carConfig = { model = model, config = rel, key = key } })
  reply(true, 'Config gespeichert: ' .. rel)
  log('I', logTag, 'Builder: Config gespeichert ' .. root .. rel)
end

return M
