-- Hashiriya Battle: Musik.
-- Lua entscheidet, welche Situation gerade ist (Titel, Tag, Nacht, Shop, Battle), und spielt die passende
-- Playlist über BeamNGs eigenes Audio (Kanal AudioMusic, folgt damit den Reglern Gesamt und Musik).
-- HTML5-Audio im UI geht in BeamNG nicht zuverlässig (OGG wird nicht gestreamt, bleibt stumm).
-- Solange Hashiriya läuft, wird die Hauptmenü-Musik von BeamNG angehalten.
-- Einstellungen und Playlists: data/music.json.
-- Eigene Musik: Spieler legen Dateien in <Userfolder>/hashiriya_musik/<situation>/ ab. Pro Situation
-- stellt man im Hashiriya-Menü ein, ob Mod-Musik, eigene Musik, beides oder nichts läuft
-- (gespeichert in settings/hashiriya_battle/music_settings.json).
local M = {}

local logTag = 'hashiriya.music'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/music.json'
local data = nil
local context = nil       -- aktuelle Situation
local checkTimer = 0
local pendingCtx, pendingTime = nil, 0 -- Tag/Nacht erst nach kurzer Bestätigung wechseln

-- Wiedergabe: cur = läuft/blendet ein, old = blendet aus
local cur = nil           -- { id, vol, target, age, loop, file }
local fading = {}         -- Liste ausblendender Quellen
local playlist, plIndex, introPending = {}, 0, nil
local menuPaused = false

local function core() return extensions.hashiriyaBattle_core end

function M.loadData()
  data = jsonReadFile(dataPath) or { enabled = false, contexts = {}, tracks = {} }
  return data
end

local function cfg() return data or M.loadData() end

local function targetVolume() return cfg().volume or 0.8 end

local function fadeTime() return math.max(0.05, cfg().fadeSeconds or 2) end

-- Liegt neben einer Datei eine WAV mit gleichem Namen (z. B. daikoku.wav neben daikoku.ogg),
-- wird die WAV genommen (volle Qualität, ohne OGG-Umwandlung). Sonst die eingetragene Datei.
local function filePath(file)
  local folder = cfg().folder or '/art/sound/hashiriya/music/'
  local base = file:match('^(.*)%.[^.]+$')
  if base and not file:lower():match('%.wav$') then
    local wav = folder .. base .. '.wav'
    if FS:fileExists(wav) then return wav end
  end
  local path = folder .. file
  return FS:fileExists(path) and path or nil
end

local function shuffled(list)
  local out = {}
  for i, v in ipairs(list) do out[i] = v end
  for i = #out, 2, -1 do
    local j = math.random(i)
    out[i], out[j] = out[j], out[i]
  end
  return out
end

-- Situationen ---------------------------------------------------------------------
-- id = interne Situation, folder = Unterordner für eigene Musik, fallback = woher Musik kommt,
-- wenn für diese Situation nichts da ist ('daynight' = Tag oder Nacht je nach Uhrzeit).
local SITUATIONS = {
  { id = 'title',    folder = 'titel' },
  { id = 'day',      folder = 'tag' },
  { id = 'night',    folder = 'nacht' },
  { id = 'pa',       folder = 'parkplatz', fallback = 'daynight' },
  { id = 'garage',   folder = 'garage',    fallback = 'daynight' },
  { id = 'shop',     folder = 'shop' },
  { id = 'battle',   folder = 'battle' },
  { id = 'leader',   folder = 'boss',      fallback = 'battle' },
  { id = 'wanderer', folder = 'wanderer',  fallback = 'battle' },
  { id = 'pinkslip', folder = 'pinkslip',  fallback = 'battle' },
}
local SIT = {}
for i, sdef in ipairs(SITUATIONS) do sdef.order = i; SIT[sdef.id] = sdef end
local MODES = { 'both', 'mod', 'own', 'off' }
local OWN_EXT = { 'ogg', 'wav', 'mp3', 'flac' }

local settingsPath = '/settings/hashiriya_battle/music_settings.json'
local userSettings = nil
local ownCache = {}       -- folder -> Liste der Pfade (bei jedem Situationswechsel neu eingelesen)
local badFiles = {}       -- Dateien, die BeamNG nicht laden konnte

local function settings()
  if not userSettings then
    userSettings = jsonReadFile(settingsPath) or {}
    userSettings.sources = userSettings.sources or {}
  end
  return userSettings
end

local function modeOf(id)
  local m = settings().sources[id]
  if m == 'both' or m == 'mod' or m == 'own' or m == 'off' then return m end
  return (cfg().defaultSource or 'both')
end

local function ownRoot() return cfg().ownFolder or '/hashiriya_musik/' end

local function isNight()
  local home = extensions.hashiriyaBattle_home
  return home and home.isNight() and true or false
end

local function resolveFallback(fb)
  if fb == 'daynight' then return isNight() and 'night' or 'day' end
  return fb
end

local function scanOwn(folder)
  local dir = ownRoot() .. folder .. '/'
  local out = {}
  for _, ext in ipairs(OWN_EXT) do
    local ok, list = pcall(function() return FS:findFiles(dir, '*.' .. ext, 0, true, false) end)
    if ok and type(list) == 'table' then
      for _, f in ipairs(list) do if not badFiles[f] then table.insert(out, f) end end
    end
  end
  table.sort(out)
  ownCache[folder] = out
  return out
end

-- Ordner und Kurzanleitung anlegen, damit Spieler wissen, wohin die Dateien kommen
local readme = [[
Hashiriya Battle - eigene Musik / own music

DE: Lege deine Musik (OGG, WAV, MP3, FLAC) in den passenden Unterordner.
Im Pausenmenü unter Esc > Mods > Hashiriya Battle wählst du für jeden
Song, in welchen Situationen er läuft (Mod-Songs und eigene).
Ein Song startet in der Situation seines Unterordners. Ist eine Situation
leer, läuft die Musik der Situation in Klammern.

EN: Put your music (OGG, WAV, MP3, FLAC) into the matching subfolder.
In the pause menu under Esc > Mods > Hashiriya Battle you choose for
every song in which situations it plays (mod songs and your own).
A song starts in the situation of its subfolder. An empty situation
plays the music of the one in brackets.

titel      Titelbildschirm / title screen
tag        Freie Fahrt am Tag / free roam by day
nacht      Freie Fahrt in der Nacht / free roam at night
parkplatz  Parkplätze (PA) (tag/nacht)
garage     Garage und Zuhause / garage and home (tag/nacht)
shop       Shops, Teile-Terminal, Autohändler / shops and dealer
battle     Battle gegen normale Rivalen / battle vs. normal rivals
boss       Battle gegen Leader und Bosse (battle)
wanderer   Battle gegen Wanderer (battle)
pinkslip   Pink-Slip-Battle (battle)
]]

local foldersMade = false
local function ensureFolders()
  if foldersMade then return end
  foldersMade = true
  local root = ownRoot()
  pcall(function()
    if not FS:directoryExists(root) then FS:directoryCreate(root, true) end
    for _, sdef in ipairs(SITUATIONS) do
      local d = root .. sdef.folder
      if not FS:directoryExists(d) then FS:directoryCreate(d, true) end
    end
    if not FS:fileExists(root .. 'LIESMICH_README.txt') then writeFile(root .. 'LIESMICH_README.txt', readme) end
  end)
end

-- BeamNG-Hauptmenü-Musik anhalten, solange Hashiriya läuft (main.lua: setMainMenuMusicPauseRequest)
local function pauseMenuMusic(on)
  on = on and true or false
  if menuPaused == on then return end
  local fn = rawget(_G, 'setMainMenuMusicPauseRequest')
  if fn then
    pcall(fn, 'hashiriyaBattle', on)
    menuPaused = on
  end
end
M.pauseMenuMusic = pauseMenuMusic

-- Fahrzeug-Geräusche (Verkehr) im Titelbildschirm leiser ----------------------------
-- Nur zur Laufzeit über Engine.Audio.setChannelVolume, die gespeicherten BeamNG-Einstellungen bleiben unberührt.
local duckChannels = { 'AudioChannelPower', 'AudioChannelForcedInduction', 'AudioChannelTransmission',
  'AudioChannelSuspension', 'AudioChannelSurface', 'AudioChannelAero', 'AudioChannelCollision' }
local duck = 1        -- aktueller Faktor (1 = normal)
local duckTarget = 1

-- Grundwert = die Lautstärke aus den BeamNG-Optionen (getChannelVolume(ch, false)).
-- Gesetzt wird nur zur Laufzeit (drittes Argument true), wie BeamNGs eigener Audio-Fade.
-- Ohne true würde BeamNG die Options-Lautstärke selbst überschreiben und das Dämpfen
-- schaukelt sich bis 0 hoch (Fehler aus PR #48).
local function savedChannelVolume(ch)
  local ok, v = pcall(Engine.Audio.getChannelVolume, ch, false)
  v = ok and tonumber(v) or nil
  return v or 1
end

local function applyDuck()
  for _, ch in ipairs(duckChannels) do
    pcall(Engine.Audio.setChannelVolume, ch, savedChannelVolume(ch) * duck, true)
  end
end

local function updateDuck(dt)
  if duck == duckTarget then return end
  local speed = dt / 1.5 -- 1,5 s Übergang
  if duck < duckTarget then duck = math.min(duckTarget, duck + speed) else duck = math.max(duckTarget, duck - speed) end
  applyDuck()
end

-- Audio-Quellen -----------------------------------------------------------------
local function sourceObj(id) return id and scenetree.findObjectById(id) or nil end

local function setVol(s, v)
  local o = sourceObj(s.id)
  if o then pcall(function() o:setVolume(math.max(0, v)) end) end
end

local function destroy(s)
  local o = sourceObj(s.id)
  if not o then return end
  pcall(function() o:stop(-1) end)
  pcall(function() o:delete() end)
end

local function isPlaying(s)
  local o = sourceObj(s.id)
  if not o then return false end
  local ok, res = pcall(function() return o:isPlaying() end)
  if not ok then return true end -- unbekannt: weiterlaufen lassen
  return res and true or false
end

local function startFile(path, loop)
  local ok, id = pcall(Engine.Audio.createSource, 'AudioMusic', path)
  if not ok or not id or id == 0 then
    log('W', logTag, 'Musik konnte nicht geladen werden: ' .. tostring(path))
    return nil
  end
  local s = { id = id, vol = 0, target = targetVolume(), age = 0, loop = loop, file = path }
  setVol(s, 0)
  local o = sourceObj(id)
  if o then pcall(function() o:play(-1) end) end
  log('I', logTag, 'Spielt: ' .. path)
  return s
end

local function fadeOutCurrent()
  if cur then
    table.insert(fading, cur)
    cur = nil
  end
end

-- Bedingungen pro Stück (music.json tracks.<datei>.when) ---------------------------
local function hourIn(h, range)
  local a, b = range[1] or 0, range[2] or 24
  if a <= b then return h >= a and h < b end
  return h >= a or h < b -- über Mitternacht, z. B. [22, 4]
end

local function inList(v, list)
  if type(list) ~= 'table' then return list == v end
  for _, x in ipairs(list) do if x == v then return true end end
  return false
end

-- Art des Gegners im Battle: normal, leader, wanderer, boss
local function rivalKind()
  local r = extensions.hashiriyaBattle_rivals
  local e = r and r.getActiveRival and r.getActiveRival()
  local d = e and e.data
  if not d then return nil end
  if d.boss then return 'boss' end
  if d.wanderer then return 'wanderer' end
  if d.leader then return 'leader' end
  return 'normal'
end

local function trackAllowed(entry)
  if type(entry) == 'table' then
    if entry.own then return true end
    entry = entry.key
  end
  local file = entry
  local t = (cfg().tracks or {})[file]
  local w = t and t.when
  if type(w) ~= 'table' then return true end
  local home = extensions.hashiriyaBattle_home
  if w.hours then
    local h = home and home.hour()
    if h and not hourIn(h, w.hours) then return false end
  end
  if w.rival then
    local k = rivalKind()
    if not k or not inList(k, w.rival) then return false end
  end
  if w.pinkSlip ~= nil then
    local b = extensions.hashiriyaBattle_battle
    local hud = b and b.getHudState and b.getHudState()
    if (hud and hud.pinkSlip and true or false) ~= w.pinkSlip then return false end
  end
  if w.minRank or w.maxRank then
    local pr = extensions.hashiriyaBattle_progress
    local idx = pr and pr.rankIndex() or 0
    if w.minRank and idx < w.minRank then return false end
    if w.maxRank and idx > w.maxRank then return false end
  end
  if w.area then
    local parking = extensions.hashiriyaBattle_parking
    local area = parking and parking.isArrived() and parking.getCurrent()
    if not area or not inList(area.type, w.area) then return false end
  end
  if w.level then
    local lvl = core() and core().levelName
    if not inList(lvl, w.level) then return false end
  end
  return true
end

local function pathOf(file) return file and filePath(file) or nil end

-- startet das Stück; lädt BeamNG es nicht (z. B. ein Format, das nicht geht), wird es gemerkt und übersprungen
local function tryStart(entry, loop)
  local s2 = startFile(entry.path, loop)
  if s2 then s2.entry = entry; return s2 end
  badFiles[entry.path] = true
  return nil
end

local function nextTrack()
  if introPending then
    local e = introPending
    introPending = nil
    if trackAllowed(e) then
      cur = tryStart(e, #playlist == 0)
      if cur then return end
    end
  end
  if #playlist == 0 then return end
  local allowedCount = 0
  for _, e in ipairs(playlist) do if trackAllowed(e) and not badFiles[e.path] then allowedCount = allowedCount + 1 end end
  -- nächstes Stück, dessen Bedingungen gerade passen; passt keins, ganz normal reihum
  for attempt = 1, #playlist do
    local pick = nil
    for k = 1, #playlist do
      local i = (plIndex + k - 1) % #playlist + 1
      local e = playlist[i]
      if not badFiles[e.path] and (allowedCount == 0 or trackAllowed(e)) then pick = i break end
    end
    if not pick then return end
    plIndex = pick
    cur = tryStart(playlist[pick], #playlist == 1 or allowedCount == 1)
    if cur then return end
  end
end

-- Welche Situation gerade ist ---------------------------------------------------
local function nearPa()
  local md = core() and core().mapData
  local list = md and (md.talkSpots or md.napSpots) or {}
  local veh = be and be:getPlayerVehicle(0)
  if not veh or #list == 0 then return false end
  local p = veh:getPosition()
  for _, pa in ipairs(list) do
    if pa.pos then
      local dx, dy, dz = p.x - pa.pos[1], p.y - pa.pos[2], p.z - pa.pos[3]
      local r = pa.radius or 80
      if dx * dx + dy * dy + dz * dz < r * r then return true end
    end
  end
  return false
end

local function wantedContext()
  local c = cfg()
  if c.enabled == false then return 'off' end
  local career = extensions.hashiriyaBattle_career
  if career and career.isOpen() then return 'title' end
  local co = core()
  if not (co and co.active and co.save) then return 'off' end
  local battle = extensions.hashiriyaBattle_battle
  if battle then
    local st = battle.getState()
    if st == 'sync' or st == 'countdown' or st == 'battle' or st == 'result' then
      local hud = battle.getHudState and battle.getHudState()
      if hud and hud.pinkSlip then return 'pinkslip' end
      local k = rivalKind()
      if k == 'boss' or k == 'leader' then return 'leader' end
      if k == 'wanderer' then return 'wanderer' end
      return 'battle'
    end
  end
  local shop = extensions.hashiriyaBattle_shop
  if shop and shop.isTerminalOpen() then return 'shop' end
  if co.isDealerOpen and co.isDealerOpen() then return 'shop' end
  local parking = extensions.hashiriyaBattle_parking
  if parking and parking.isArrived() then
    local area = parking.getCurrent()
    local ctx = area and (c.areaContexts or {})[area.type]
    if ctx then return ctx end
  end
  local okPa, inPa = pcall(nearPa)
  if okPa and inPa then return 'pa' end
  return isNight() and 'night' or 'day'
end

-- Song-Auswahl pro Situation ------------------------------------------------------
-- Bibliothek = alle Mod-Stücke (music.json tracks, Datei vorhanden) + alle eigenen Dateien aus allen
-- Unterordnern. Vorgabe: Mod-Stücke laufen in den Situationen, in deren contexts-Liste sie stehen,
-- eigene Dateien in der Situation ihres Ordners. Im Pausenmenü (Esc > Mods > Hashiriya Battle) kann jeder
-- Spieler pro Song ankreuzen, in welchen Situationen er läuft (settings: assign[songId] = { situationen }).
-- Hat eine Situation keinen Song, kommt die Musik der Ersatz-Situation (pa/garage -> Tag/Nacht, Boss usw. -> battle).
local function modSongId(file) return 'mod:' .. file end
local function ownSongId(path) return 'own:' .. path end

local function library()
  local out, seen = {}, {}
  local contexts = cfg().contexts or {}
  local tracks = cfg().tracks or {}
  local function addMod(f)
    if seen[f] or not f then return end
    seen[f] = true
    local p = filePath(f)
    if not p then return end
    local t = tracks[f] or {}
    local artist = t.artist
    if artist and artist:match('^%[') then artist = nil end
    local d = {}
    for _, sdef in ipairs(SITUATIONS) do
      local def = contexts[sdef.id]
      if def then
        if def.intro == f then d[sdef.id] = true end
        for _, x in ipairs(def.tracks or {}) do if x == f then d[sdef.id] = true end end
      end
    end
    table.insert(out, { id = modSongId(f), key = f, path = p, title = t.title or f:gsub('%.[^.]+$', ''),
      artist = artist, ai = t.ai and true or nil, defaults = d })
  end
  -- Reihenfolge wie in music.json (wichtig für Situationen ohne shuffle, z. B. Titel)
  for _, sdef in ipairs(SITUATIONS) do
    local def = contexts[sdef.id]
    if def then
      addMod(def.intro)
      for _, f in ipairs(def.tracks or {}) do addMod(f) end
    end
  end
  local rest = {}
  for f in pairs(tracks) do if not seen[f] then table.insert(rest, f) end end
  table.sort(rest)
  for _, f in ipairs(rest) do addMod(f) end
  for _, sdef in ipairs(SITUATIONS) do
    for _, p in ipairs(scanOwn(sdef.folder)) do
      if not seen[p] then
        seen[p] = true
        table.insert(out, { id = ownSongId(p), key = p:match('([^/]+)$'), path = p, own = true,
          title = (p:match('([^/]+)$') or p):gsub('%.[^.]+$', ''), folder = sdef.folder, defaults = { [sdef.id] = true } })
      end
    end
  end
  return out
end

local function assignOf(song)
  local a = (settings().assign or {})[song.id]
  if type(a) ~= 'table' then return song.defaults, false end
  local set = {}
  for _, id in ipairs(a) do set[id] = true end
  return set, true
end

-- Songs einer Situation (nach Quelle gefiltert), keiner da -> Ersatz-Situation
local function songsFor(id, depth)
  local mode = modeOf(id)
  local list = {}
  if mode ~= 'off' then
    for _, song in ipairs(library()) do
      local set = assignOf(song)
      local okSrc = (mode == 'both') or (mode == 'own' and song.own) or (mode == 'mod' and not song.own)
      if set[id] and okSrc and not badFiles[song.path] then table.insert(list, song) end
    end
  end
  local sdef = SIT[id]
  if #list == 0 and mode ~= 'off' and sdef and sdef.fallback and (depth or 0) < 3 then
    return songsFor(resolveFallback(sdef.fallback), (depth or 0) + 1)
  end
  return list, id, mode
end

-- Playlist der Situation bauen (Intro vorn, shuffle laut music.json, Titel ohne shuffle)
local function buildPlaylist(ctx)
  local songs, srcId, mode = songsFor(ctx)
  local def = (cfg().contexts or {})[srcId] or {}
  local list, intro = {}, nil
  local nMod, nOwn = 0, 0
  for _, song in ipairs(songs) do
    local e = { path = song.path, key = song.key, own = song.own, id = song.id }
    if not intro and def.intro and song.key == def.intro then intro = e
    else table.insert(list, e) end
    if song.own then nOwn = nOwn + 1 else nMod = nMod + 1 end
  end
  if def.shuffle ~= false or nOwn > 0 then list = shuffled(list) end
  return list, intro, mode, nMod, nOwn, srcId
end

local function switchTo(ctx)
  context = ctx
  fadeOutCurrent()
  playlist, plIndex, introPending = {}, 0, nil
  if ctx ~= 'off' then
    ensureFolders()
    local list, intro, mode, nMod, nOwn, srcId = buildPlaylist(ctx)
    playlist, introPending = list, intro
    nextTrack()
    log('I', logTag, 'Musik: ' .. ctx .. (srcId ~= ctx and (' -> ' .. srcId) or '') .. ' (' .. mode .. ', ' .. nMod .. ' Mod, ' .. nOwn .. ' eigene)')
  else
    log('I', logTag, 'Musik: off')
  end
end

-- nach einer Änderung im Menü: Playlist neu, das laufende Stück läuft weiter, wenn es noch dazugehört
local function refreshPlaylist()
  if not context or context == 'off' then return end
  local list, intro = buildPlaylist(context)
  local curId = cur and cur.entry and cur.entry.id
  local keep = false
  if intro and intro.id == curId then keep = true end
  for i, e in ipairs(list) do if e.id == curId then keep = true; plIndex = i end end
  playlist = list
  introPending = (not keep and intro) or nil
  if not keep then
    if cur then local s = cur; cur = nil; table.insert(fading, s) end
    plIndex = 0
    nextTrack()
  elseif cur and cur.loop and #list + (intro and 1 or 0) > 1 then
    cur.loop = false -- war vorher allein in der Playlist, jetzt gibt es mehr
  end
end

-- Überspringen (Menü-Knopf, Taste): aktuelles Stück schnell ausblenden, nächstes passendes starten
function M.skip()
  if not context or context == 'off' then return end
  introPending = nil
  if cur then
    local s = cur
    cur = nil
    s.fast = true
    table.insert(fading, s)
  end
  nextTrack()
  if cur then cur.vol = cur.target * 0.5; setVol(cur, cur.vol) end
end

-- Für das Menü: Titel und Künstler des laufenden Stücks
function M.nowPlaying()
  if not cur or not context or context == 'off' then return nil end
  local e = cur.entry or { key = cur.file:match('([^/]+)$') }
  if e.own then
    return { title = (e.key or ''):gsub('%.[^.]+$', ''), own = true }
  end
  local t = (cfg().tracks or {})[e.key] or {}
  local artist = t.artist
  if artist and artist:match('^%[') then artist = nil end
  return { title = t.title or e.key, artist = artist }
end

function M.stop()
  if context and context ~= 'off' then switchTo('off') end
end

-- vom alten UI-Player, falls noch eine alte index.js geladen ist
function M.playerReady() end
function M.resend() end

local function updatePlayback(dt)
  local step = targetVolume() * dt / fadeTime()
  -- ausblenden
  for i = #fading, 1, -1 do
    local s = fading[i]
    s.vol = s.vol - (s.fast and step * 4 or step)
    if s.vol <= 0 then
      destroy(s)
      table.remove(fading, i)
    else
      setVol(s, s.vol)
    end
  end
  if not cur then return end
  cur.age = cur.age + dt
  cur.target = targetVolume()
  if cur.vol < cur.target then
    cur.vol = math.min(cur.target, cur.vol + step)
    setVol(cur, cur.vol)
  elseif cur.vol > cur.target then
    cur.vol = cur.target
    setVol(cur, cur.vol)
  end
  -- Stück zu Ende: nächstes (eine einzelne Datei läuft als Schleife neu an)
  if cur.age > 1.5 and not isPlaying(cur) then
    local s = cur
    cur = nil
    destroy(s)
    if s.loop then
      cur = startFile(s.file, true)
      if cur then cur.entry = s.entry; cur.vol = cur.target; setVol(cur, cur.vol) end
    else
      nextTrack()
    end
  end
end

local function onUpdate(dtReal)
  -- Pausenmenü-Eintrag: so lange versuchen, bis BeamNGs Pausenmenü-Modul da ist
  if not pauseRegistered then
    pauseRetry = pauseRetry - dtReal
    if pauseRetry <= 0 then pauseRetry = 3; M.registerPauseButton() end
  end
  updatePlayback(dtReal)
  updateDuck(dtReal)
  checkTimer = checkTimer - dtReal
  if checkTimer > 0 then return end
  checkTimer = 0.25
  local ctx = wantedContext()
  local career = extensions.hashiriyaBattle_career
  pauseMenuMusic(ctx ~= 'off' or (career and career.isPending and career.isPending()))
  if ctx ~= context then
    local slow = (ctx == 'day' or ctx == 'night') and (context == 'day' or context == 'night')
    if slow then
      if pendingCtx ~= ctx then pendingCtx, pendingTime = ctx, 0 end
      pendingTime = pendingTime + 0.25
      if pendingTime < 2 then return end
    end
    pendingCtx = nil
    switchTo(ctx)
    local t = (cfg().trafficVolumeInTitle or 0)
    duckTarget = (ctx == 'title') and math.max(0, math.min(1, t)) or 1
  else
    pendingCtx = nil
  end
end

-- Musik-Einstellungen fürs Menü -------------------------------------------------------
local function osFolder()
  local ok, up = pcall(function() return FS:getUserPath() end)
  local root = ownRoot():gsub('^/', '')
  if ok and type(up) == 'string' and up ~= '' then
    return (up .. root):gsub('/', '\\')
  end
  return root
end

function M.uiSettings()
  local rows = {}
  for _, sdef in ipairs(SITUATIONS) do
    local own = ownCache[sdef.folder] or scanOwn(sdef.folder)
    local def = (cfg().contexts or {})[sdef.id]
    local nMod = 0
    if def then for _, f in ipairs(def.tracks or {}) do if filePath(f) then nMod = nMod + 1 end end
      if def.intro and filePath(def.intro) then nMod = nMod + 1 end end
    table.insert(rows, { id = sdef.id, folder = sdef.folder, mode = modeOf(sdef.id), own = #own, mod = nMod,
      fallback = sdef.fallback })
  end
  return { folder = osFolder(), rows = rows, current = context }
end

local function saveSettings()
  pcall(jsonWriteFile, settingsPath, settings(), true)
end

local function tr(key, fallbackText)
  local c = core()
  local ok, v = pcall(function() return c and c.t and c.t(key) end)
  if ok and type(v) == 'string' and v ~= key then return v end
  return fallbackText or key
end

-- Daten für die Karte im Pausenmenü (ui/ui-vue/mods/hashiriyaBattle/PauseCard.vue)
function M.matrix()
  ensureFolders()
  local sits = {}
  for _, sdef in ipairs(SITUATIONS) do
    local fb = sdef.fallback and (sdef.fallback == 'daynight' and 'daynight' or sdef.fallback) or nil
    table.insert(sits, { id = sdef.id, folder = sdef.folder, mode = modeOf(sdef.id), fallback = fb,
      name = tr('music.sit.' .. sdef.id, sdef.id) })
  end
  local songs = {}
  local playingId = cur and cur.entry and cur.entry.id
  for _, song in ipairs(library()) do
    local set, custom = assignOf(song)
    local on = {}
    for _, sdef in ipairs(SITUATIONS) do if set[sdef.id] then table.insert(on, sdef.id) end end
    table.insert(songs, { id = song.id, title = song.title, artist = song.artist, own = song.own or false,
      ai = song.ai or false, folder = song.folder, on = on, custom = custom, playing = (song.id == playingId),
      bad = badFiles[song.path] and true or false })
  end
  local now = M.nowPlaying()
  local t = {}
  for _, k in ipairs({ 'pause.title', 'pause.sub', 'pause.situation', 'pause.source', 'pause.songs', 'pause.empty',
    'pause.fallbackDayNight', 'pause.fallbackBattle', 'pause.own', 'pause.ai', 'pause.custom', 'pause.now', 'pause.skip',
    'pause.reset', 'pause.resetDone', 'pause.all', 'pause.none', 'pause.alsoIn', 'pause.hint', 'pause.current',
    'music.openFolder', 'music.rescan', 'music.folder', 'music.mode.both', 'music.mode.mod', 'music.mode.own', 'music.mode.off' }) do
    t[k] = tr(k, k)
  end
  return { sits = sits, songs = songs, current = context, folder = osFolder(), now = now, t = t }
end

function M.sendMatrix()
  if guihooks then guihooks.trigger('HashiriyaMusicMatrix', M.matrix()) end
end

-- Song an/aus für eine Situation
function M.setAssign(songId, sitId, on)
  if not SIT[sitId] then return end
  local song = nil
  for _, s2 in ipairs(library()) do if s2.id == songId then song = s2 break end end
  if not song then return end
  local set = assignOf(song)
  local copy = {}
  for k, v in pairs(set) do copy[k] = v end
  copy[sitId] = on and true or nil
  local list = {}
  for _, sdef in ipairs(SITUATIONS) do if copy[sdef.id] then table.insert(list, sdef.id) end end
  settings().assign = settings().assign or {}
  settings().assign[songId] = list
  saveSettings()
  refreshPlaylist()
  M.sendMatrix()
end

-- alle Songs einer Situation an oder aus
function M.setAllFor(sitId, on)
  if not SIT[sitId] then return end
  settings().assign = settings().assign or {}
  for _, song in ipairs(library()) do
    local set = assignOf(song)
    local copy = {}
    for k, v in pairs(set) do copy[k] = v end
    copy[sitId] = on and true or nil
    local list = {}
    for _, sdef in ipairs(SITUATIONS) do if copy[sdef.id] then table.insert(list, sdef.id) end end
    settings().assign[song.id] = list
  end
  saveSettings()
  refreshPlaylist()
  M.sendMatrix()
end

-- zurück auf die Vorgabe der Mod (alle Songs)
function M.resetAssign()
  settings().assign = {}
  saveSettings()
  refreshPlaylist()
  M.sendMatrix()
end

function M.setSource(id, mode)
  if not SIT[id] then return end
  local ok = false
  for _, v in ipairs(MODES) do if v == mode then ok = true end end
  if not ok then return end
  settings().sources[id] = mode
  saveSettings()
  refreshPlaylist()
  M.sendMatrix()
end

function M.cycleSource(id, dir)
  if not SIT[id] then return end
  local m = modeOf(id)
  local idx = 1
  for i, v in ipairs(MODES) do if v == m then idx = i end end
  idx = (idx - 1 + (tonumber(dir) or 1)) % #MODES + 1
  M.setSource(id, MODES[idx])
end

function M.rescan()
  ownCache, badFiles = {}, {}
  ensureFolders()
  for _, sdef in ipairs(SITUATIONS) do scanOwn(sdef.folder) end
  if context and context ~= 'off' then switchTo(context) end
  M.sendMatrix()
end

function M.openFolder()
  ensureFolders()
  pcall(function() Engine.Platform.exploreFolder(ownRoot()) end)
end

function M.skipAndSend()
  M.skip()
  M.sendMatrix()
end

-- Pausenmenü (Esc) > Reiter "Mods" > "Hashiriya Battle" (wie Beam Turismo, BeamNG 0.40 ui_pause_actions)
local pauseRegistered = false
local pauseRetry = 0
function M.registerPauseButton()
  local pa = extensions.ui_pause_actions
  if not pa and extensions.load then
    pcall(extensions.load, 'ui_pause_actions')
    pa = extensions.ui_pause_actions
  end
  if not pa or not pa.registerModButton then return false end
  local ok, res = pcall(pa.registerModButton, {
    id = 'hashiriya-battle', tabId = 'mods', label = 'Hashiriya Battle', icon = 'wrench',
    componentName = '/ui/ui-vue/mods/hashiriyaBattle/PauseCard.vue',
  })
  pauseRegistered = ok and type(res) == 'table' and res.success and true or false
  return pauseRegistered
end

-- Credits: alle Stücke mit Titel, Künstler, Lizenz
function M.creditEntries()
  local out = {}
  local seen = {}
  for _, ctxName in ipairs({ 'title', 'day', 'night', 'shop', 'battle' }) do
    local def = (cfg().contexts or {})[ctxName] or {}
    local files = {}
    if def.intro then table.insert(files, def.intro) end
    for _, f in ipairs(def.tracks or {}) do table.insert(files, f) end
    for _, f in ipairs(files) do
      local t = (cfg().tracks or {})[f]
      if t and not t.hideInCredits and not seen[f] and filePath(f) then
        seen[f] = true
        table.insert(out, { title = t.title, artist = t.artist, license = t.license, context = ctxName, ai = t.ai and true or nil })
      end
    end
  end
  return out
end

local function onClientEndMission()
  for _, s in ipairs(fading) do destroy(s) end
  fading = {}
  if cur then destroy(cur) cur = nil end
  context = nil
  playlist, plIndex, introPending = {}, 0, nil
  pauseMenuMusic(false)
  if duck ~= 1 then duck, duckTarget = 1, 1; applyDuck() end
end

local function onExtensionUnloaded() onClientEndMission() end

local function onExtensionLoaded() M.registerPauseButton() end
local function onWorldReadyState(state) if state == 2 then M.registerPauseButton() end end

M.onExtensionLoaded = onExtensionLoaded
M.onWorldReadyState = onWorldReadyState
M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission
M.onExtensionUnloaded = onExtensionUnloaded

return M
