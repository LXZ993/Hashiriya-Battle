-- Hashiriya Battle: eigenes Log für Fehlersuche bei Testern und Spielern.
-- Datei: <BeamNG-Userordner>/settings/hashiriya_battle/logs/hashiriya.log
-- Größe begrenzt: ab maxKb wird die Datei zu hashiriya.1.log (ältere rücken auf .2, .3 ...),
-- höchstens files Dateien insgesamt. Gleiche Meldungen hintereinander werden zusammengefasst,
-- sehr häufige Meldungen gedrosselt. Fehler in den Hooks der Mod werden mit Traceback und
-- Spielzustand festgehalten. "Fehlerbericht erstellen" im Menü schreibt alles in eine Datei.
local M = {}

local logTag = 'hashiriya'
local beamLog = log

local logDir = 'settings/hashiriya_battle/logs/'
local logPath = logDir .. 'hashiriya.log'
local reportPath = logDir .. 'fehlerbericht.txt'
local dataDir = '/lua/ge/extensions/hashiriyaBattle/data/'

-- Standardwerte, überschreibbar in data/build.json unter "log"
local cfg = {
  level = 'I',          -- D = alles (Debug), I = normal, W = nur Warnungen und Fehler, E = nur Fehler
  maxKb = 512,          -- so groß wird eine Datei höchstens
  files = 4,            -- hashiriya.log + 3 ältere = höchstens ca. 2 MB
  statusMinutes = 5,    -- alle x Minuten (Echtzeit) eine Statuszeile
  perMinute = 30,       -- dieselbe Meldung höchstens so oft pro Minute, danach nur gezählt
  flushSeconds = 2,     -- Puffer so oft in die Datei schreiben (Fehler sofort)
}
local levels = { D = 1, I = 2, W = 3, E = 4 }

local buffer = {}
local size = 0
local last = nil      -- { key, line, count, time } für "wiederholt"
local rate = {}       -- Meldung -> { count, start }
local flushTimer = 0
local statusTimer = 0
local errorsSeen = {} -- Fehlertext -> Anzahl (Traceback nur beim ersten Mal)
local started = false
local useAppend = true

local function now() return os.date('%Y-%m-%d %H:%M:%S') end

local function fileSize(path)
  local ok, res = pcall(function()
    local f = io.open(path, 'r')
    if not f then return 0 end
    local s = f:seek('end') or 0
    f:close()
    return s
  end)
  return ok and res or 0
end

local function removeFile(path)
  pcall(function() if FS:fileExists(path) then FS:removeFile(path) end end)
end

local function renameFile(from, to)
  local ok = pcall(function() FS:renameFile(from, to) end)
  if not ok or not FS:fileExists(to) then ok = pcall(os.rename, from, to) end
  return ok
end

local function rotate()
  removeFile(logDir .. 'hashiriya.' .. (cfg.files - 1) .. '.log')
  for i = cfg.files - 2, 1, -1 do
    local from = logDir .. 'hashiriya.' .. i .. '.log'
    if FS:fileExists(from) then renameFile(from, logDir .. 'hashiriya.' .. (i + 1) .. '.log') end
  end
  if not renameFile(logPath, logDir .. 'hashiriya.1.log') then
    -- Umbenennen geht nicht: Datei leeren, damit sie nicht wächst
    pcall(writeFile, logPath, '')
  end
  size = 0
end

function M.flush()
  if #buffer == 0 then return end
  local text = table.concat(buffer, '\n') .. '\n'
  buffer = {}
  if size + #text > cfg.maxKb * 1024 then rotate() end
  local ok = false
  if useAppend then
    ok = pcall(function()
      local f = io.open(logPath, 'a')
      if not f then error('io.open') end
      f:write(text)
      f:close()
    end)
    if not ok then useAppend = false end
  end
  if not ok then
    -- Ersatzweg: ganze Datei neu schreiben (bleibt durch maxKb begrenzt)
    local old = (pcall(readFile, logPath) and readFile(logPath)) or ''
    pcall(writeFile, logPath, old .. text)
  end
  size = size + #text
end

local function push(line, urgent)
  buffer[#buffer + 1] = line
  if urgent or #buffer > 200 then M.flush() end
end

local function closeRepeat()
  if last and last.count > 1 then
    push(string.format('%s  ... %dx wiederholt', last.lastTime, last.count))
  end
  last = nil
end

-- Hauptfunktion: wie BeamNGs log(level, tag, text), schreibt zusätzlich in hashiriya.log
function M.log(level, tag, text)
  level = level or 'I'
  text = tostring(text)
  if level ~= 'D' then beamLog(level, tag or logTag, text) end
  if (levels[level] or 2) < (levels[cfg.level] or 2) then return end
  local key = level .. '|' .. text
  local t = os.time()
  -- Drosseln: gleiche Meldung zu oft pro Minute
  local r = rate[key]
  if not r or t - r.start > 60 then r = { count = 0, start = t, dropped = 0 } rate[key] = r end
  r.count = r.count + 1
  if r.count > cfg.perMinute then
    r.dropped = r.dropped + 1
    if r.dropped == 1 then push(now() .. ' ' .. level .. ' (gedrosselt, kommt sehr oft) ' .. text) end
    return
  end
  -- Zusammenfassen: gleiche Meldung direkt hintereinander
  if last and last.key == key then
    last.count = last.count + 1
    last.lastTime = now()
    return
  end
  closeRepeat()
  last = { key = key, count = 1, lastTime = now() }
  push(now() .. ' ' .. level .. ' ' .. text, level == 'E')
end

function M.debug(text) M.log('D', logTag, text) end

-- Spielzustand für Fehlermeldungen und Statuszeilen
local function try(f) local ok, v = pcall(f) if ok then return v end end

function M.context()
  local core = rawget(_G, 'hashiriyaBattle_core')
  local parts = {}
  local function add(k, v) if v ~= nil then parts[#parts + 1] = k .. '=' .. tostring(v) end end
  add('level', try(function() return getLevelName() end))
  if core then
    add('aktiv', core.active)
    local s = core.save
    if s then
      add('tag', s.day)
      add('uhr', try(function() return string.format('%.1f', extensions.hashiriyaBattle_home.hour()) end))
      add('yen', s.money)
      add('ruf', s.rep)
      add('siege', s.wins)
      add('auto', try(function() local c = s.cars[s.activeCar or 1] return c and (c.model .. ' ' .. tostring(c.config)) end))
    end
    add('zuFuss', try(function() return core.isWalking() end))
  end
  add('battle', try(function() local h = extensions.hashiriyaBattle_battle.getHudState() return h and h.state end))
  add('rivalen', try(function() return #extensions.hashiriyaBattle_rivals.getOnRoad() end))
  add('veh', try(function()
    local v = getPlayerVehicle(0)
    return v and (v:getJBeamFilename() .. ' ' .. string.format('%.0f km/h', v:getVelocity():length() * 3.6))
  end))
  return table.concat(parts, ', ')
end

-- Fehler abfangen: Funktion läuft in xpcall; ein Fehler wird mit Traceback geloggt statt das Spiel zu stören
function M.wrap(name, f)
  return function(...)
    local res = { xpcall(f, debug.traceback, ...) }
    if res[1] then return unpack(res, 2, table.maxn(res)) end
    local err = tostring(res[2])
    local first = err:match('^[^\n]*') or err
    local n = (errorsSeen[first] or 0) + 1
    errorsSeen[first] = n
    if n == 1 then
      M.log('E', logTag, 'FEHLER in ' .. name .. ': ' .. err .. '\n    Zustand: ' .. M.context())
    else
      M.log('E', logTag, 'FEHLER in ' .. name .. ' (' .. n .. '. Mal): ' .. first)
    end
    return nil
  end
end

-- Alle Hooks (on...) und die UI-Aktion eines Moduls schützen
function M.protect(modName)
  local m = rawget(_G, modName) or (extensions and extensions[modName])
  if type(m) ~= 'table' or m._hbProtected then return end
  for k, f in pairs(m) do
    if type(f) == 'function' and (k:match('^on%u') or k == 'uiAction') then
      m[k] = M.wrap(modName:gsub('^hashiriyaBattle_', '') .. '.' .. k, f)
    end
  end
  m._hbProtected = true
end

-- Sitzungskopf: alles, was man für die Fehlersuche wissen muss
local function modList()
  local names = {}
  pcall(function()
    local list = core_modmanager.getModList()
    for name, mod in pairs(list or {}) do
      if mod.active ~= false then names[#names + 1] = name end
    end
  end)
  table.sort(names)
  return names
end

local function header()
  local build = jsonReadFile(dataDir .. 'build.json') or {}
  local lines = {
    '',
    '==================== Sitzung ' .. now() .. ' ====================',
    'Mod: Hashiriya Battle ' .. tostring(build.modVersion or '?') .. (build.release and ' (Release)' or ' (Entwicklung)'),
    'BeamNG: ' .. tostring(rawget(_G, 'beamng_versiond') or rawget(_G, 'beamng_versionb') or '?')
      .. ', Sprache: ' .. tostring(try(function() return settings.getValue('userLanguage') end) or '?'),
  }
  local mods = modList()
  if #mods > 0 then lines[#lines + 1] = 'Aktive Mods (' .. #mods .. '): ' .. table.concat(mods, ', ') end
  return lines
end

-- Datencheck: kaputte JSON-Dateien und fehlende Autos/Configs gleich beim Start melden
function M.checkData()
  for _, f in ipairs({ 'rivals', 'cars', 'dealer', 'tuning', 'world', 'style', 'sounds', 'tutorial', 'build', 'chat', 'lang/de', 'lang/en' }) do
    local path = dataDir .. f .. '.json'
    if not FS:fileExists(path) then
      M.log('W', logTag, 'Datencheck: Datei fehlt: data/' .. f .. '.json')
    elseif not jsonReadFile(path) then
      M.log('E', logTag, 'Datencheck: data/' .. f .. '.json ist kaputt (JSON-Fehler, Details in beamng.log)')
    end
  end
  local rv = jsonReadFile(dataDir .. 'rivals.json')
  if not rv then return end
  local ids, teams, missingModel, missingCfg, problems = {}, {}, {}, {}, {}
  for _, t in ipairs(rv.teams or {}) do teams[t.id] = true end
  for _, r in ipairs(rv.rivals or {}) do
    if ids[r.id] then problems[#problems + 1] = 'doppelte ID ' .. tostring(r.id) end
    ids[r.id] = true
    if r.team and not teams[r.team] then problems[#problems + 1] = tostring(r.id) .. ': unbekannte Crew ' .. r.team end
    if r.plate and r.plate.text and #r.plate.text ~= 9 then problems[#problems + 1] = tostring(r.id) .. ': Kennzeichen nicht 9 Zeichen' end
    if r.model and not FS:directoryExists('/vehicles/' .. r.model) then
      missingModel[#missingModel + 1] = r.id .. ' (' .. r.model .. ')'
    elseif r.config and r.config:match('%.pc$') and not FS:fileExists('/' .. r.config:gsub('^/', '')) then
      missingCfg[#missingCfg + 1] = r.id .. ' (' .. r.config .. ')'
    end
  end
  local function report(list, what)
    if #list == 0 then return end
    local shown = {}
    for i = 1, math.min(#list, 15) do shown[i] = list[i] end
    M.log('W', logTag, string.format('Datencheck: %d %s: %s%s', #list, what, table.concat(shown, ', '), #list > 15 and ', ...' or ''))
  end
  report(problems, 'Probleme in rivals.json')
  report(missingModel, 'Rivalen mit fehlendem Fahrzeug (Mod fehlt?)')
  report(missingCfg, 'Rivalen mit fehlender Config')
  M.log('I', logTag, string.format('Datencheck: %d Rivalen, %d Crews geprüft', #(rv.rivals or {}), #(rv.teams or {})))
end

function M.start()
  if started then return end
  started = true
  local build = jsonReadFile(dataDir .. 'build.json') or {}
  for k, v in pairs(build.log or {}) do if cfg[k] ~= nil then cfg[k] = v end end
  pcall(function() if not FS:directoryExists(logDir) then FS:directoryCreate(logDir, true) end end)
  size = fileSize(logPath)
  for _, l in ipairs(header()) do push(l) end
  M.flush()
  M.checkData()
end

-- Fehlerbericht: Kopf, Spielzustand, Spielstand und die letzten Log-Zeilen in eine Datei
local function tailLines(path, maxLines)
  local text = (pcall(readFile, path) and readFile(path)) or ''
  local lines = {}
  for l in text:gmatch('[^\n]*') do lines[#lines + 1] = l end
  local from = math.max(1, #lines - maxLines + 1)
  local out = {}
  for i = from, #lines do out[#out + 1] = lines[i] end
  return out
end

function M.writeReport(note)
  closeRepeat()
  M.flush()
  local out = { 'Hashiriya Battle Fehlerbericht vom ' .. now() }
  for _, l in ipairs(header()) do out[#out + 1] = l end
  out[#out + 1] = 'Zustand: ' .. M.context()
  if note and note ~= '' then out[#out + 1] = 'Notiz: ' .. tostring(note) end
  out[#out + 1] = ''
  out[#out + 1] = '---------- Spielstand (save.json) ----------'
  out[#out + 1] = (pcall(readFile, 'settings/hashiriya_battle/save.json') and readFile('settings/hashiriya_battle/save.json')) or '(kein Spielstand)'
  out[#out + 1] = ''
  out[#out + 1] = '---------- Log (ältere Datei, Ende) ----------'
  for _, l in ipairs(tailLines(logDir .. 'hashiriya.1.log', 300)) do out[#out + 1] = l end
  out[#out + 1] = '---------- Log (aktuell) ----------'
  for _, l in ipairs(tailLines(logPath, 1500)) do out[#out + 1] = l end
  local ok = pcall(writeFile, reportPath, table.concat(out, '\n'))
  M.log(ok and 'I' or 'E', logTag, ok and ('Fehlerbericht geschrieben: ' .. reportPath) or 'Fehlerbericht konnte nicht geschrieben werden')
  return ok and reportPath or nil
end

local function onUpdate(dtReal)
  flushTimer = flushTimer + dtReal
  if flushTimer >= cfg.flushSeconds then
    flushTimer = 0
    if last and last.count > 1 then closeRepeat() end
    M.flush()
  end
  statusTimer = statusTimer + dtReal
  if cfg.statusMinutes > 0 and statusTimer >= cfg.statusMinutes * 60 then
    statusTimer = 0
    M.log('I', logTag, 'Status: ' .. M.context())
  end
end

local function onExtensionUnloaded()
  closeRepeat()
  M.log('I', logTag, 'Mod entladen')
  M.flush()
end

M.onUpdate = onUpdate
M.onExtensionUnloaded = onExtensionUnloaded

return M
