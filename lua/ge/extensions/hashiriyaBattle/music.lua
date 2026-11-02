-- Hashiriya Battle: Musik.
-- Lua entscheidet, welche Situation gerade ist (Titel, Tag, Nacht, Shop, Battle), und spielt die passende
-- Playlist über BeamNGs eigenes Audio (Kanal AudioMusic, folgt damit den Reglern Gesamt und Musik).
-- HTML5-Audio im UI geht in BeamNG nicht zuverlässig (OGG wird nicht gestreamt, bleibt stumm).
-- Solange Hashiriya läuft, wird die Hauptmenü-Musik von BeamNG angehalten.
-- Einstellungen und Playlists: data/music.json.
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

local function filePath(file)
  local path = (cfg().folder or '/art/sound/hashiriya/music/') .. file
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

local function nextTrack()
  if introPending then
    local p = introPending
    introPending = nil
    cur = startFile(p, #playlist == 0)
    if cur then return end
  end
  if #playlist == 0 then return end
  plIndex = plIndex % #playlist + 1
  cur = startFile(playlist[plIndex], #playlist == 1)
end

-- Welche Situation gerade ist ---------------------------------------------------
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
    if st == 'sync' or st == 'countdown' or st == 'battle' or st == 'result' then return 'battle' end
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
  local home = extensions.hashiriyaBattle_home
  return (home and home.isNight()) and 'night' or 'day'
end

local function switchTo(ctx)
  context = ctx
  fadeOutCurrent()
  playlist, plIndex, introPending = {}, 0, nil
  local def = (cfg().contexts or {})[ctx]
  if ctx ~= 'off' and def then
    introPending = def.intro and filePath(def.intro) or nil
    local list = def.shuffle and shuffled(def.tracks or {}) or (def.tracks or {})
    for _, f in ipairs(list) do
      local p = filePath(f)
      if p then table.insert(playlist, p) else log('W', logTag, 'Musikdatei fehlt: ' .. f) end
    end
    nextTrack()
  end
  log('I', logTag, 'Musik: ' .. ctx .. ' (' .. #playlist .. ' Stücke)')
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
    s.vol = s.vol - step
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
      if cur then cur.vol = cur.target; setVol(cur, cur.vol) end
    else
      nextTrack()
    end
  end
end

local function onUpdate(dtReal)
  updatePlayback(dtReal)
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
  else
    pendingCtx = nil
  end
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
        table.insert(out, { title = t.title, artist = t.artist, license = t.license, context = ctxName })
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
end

local function onExtensionUnloaded() onClientEndMission() end

M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission
M.onExtensionUnloaded = onExtensionUnloaded

return M
