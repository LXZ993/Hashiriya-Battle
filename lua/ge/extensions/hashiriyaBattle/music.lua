-- Hashiriya Battle: Musik.
-- Lua entscheidet, welche Situation gerade ist (Titel, Tag, Nacht, Shop, Battle), und schickt die passende
-- Playlist an den Player im UI (ui/ui-vue/mods/hashiriyaBattle/index.js, HTML5-Audio mit Überblenden).
-- Einstellungen und Playlists: data/music.json. Lautstärke folgt den BeamNG-Reglern Gesamt und Musik.
local M = {}

local logTag = 'hashiriya.music'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/music.json'
local data = nil
local context = nil      -- zuletzt gesendete Situation
local volume = nil       -- zuletzt gesendete Lautstärke
local checkTimer = 0
local volTimer = 0
local pendingCtx, pendingTime = nil, 0 -- Tag/Nacht erst nach kurzer Bestätigung wechseln
local playerReady = false
local warnedNoPlayer = false
local uptime = 0

local function core() return extensions.hashiriyaBattle_core end

function M.loadData()
  data = jsonReadFile(dataPath) or { enabled = false, contexts = {}, tracks = {} }
  return data
end

local function cfg() return data or M.loadData() end

local function settingValue(key, default)
  local ok, v = pcall(function() return settings.getValue(key) end)
  v = ok and tonumber(v) or nil
  return v or default
end

local function currentVolume()
  local c = cfg()
  return (c.volume or 0.8) * settingValue('AudioMasterVol', 1) * settingValue('AudioMusicVol', 0.8)
end

local function fileUrl(file)
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

-- Welche Situation gerade ist ---------------------------------------------------
local function wantedContext()
  local c = cfg()
  if c.enabled == false then return 'off' end
  local career = extensions.hashiriyaBattle_career
  if career and career.isOpen() then return 'title' end
  local co = core()
  if not (co and co.active and co.save) then return 'off' end
  local battle = extensions.hashiriyaBattle_battle
  if battle and battle.isBusy() and battle.getState() ~= 'idle' then
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

local function send(ctx)
  local c = cfg()
  local msg = { context = ctx, volume = currentVolume(), fade = c.fadeSeconds or 2, tracks = {} }
  local def = (c.contexts or {})[ctx]
  if def then
    msg.intro = def.intro and fileUrl(def.intro) or nil
    local list = def.shuffle and shuffled(def.tracks or {}) or (def.tracks or {})
    for _, f in ipairs(list) do
      local url = fileUrl(f)
      if url then table.insert(msg.tracks, url) else log('W', logTag, 'Musikdatei fehlt: ' .. f) end
    end
  end
  if ctx ~= 'off' and not msg.intro and #msg.tracks == 0 then msg.context = 'off' end
  guihooks.trigger('HashiriyaMusic', msg)
  context, volume = ctx, msg.volume
  log('I', logTag, 'Musik: ' .. ctx .. ' (' .. #msg.tracks .. ' Stücke)')
end

-- Der Player meldet sich beim Laden der UI; dann aktuelle Situation erneut schicken
function M.playerReady()
  playerReady = true
  if context then send(context) end
end

function M.resend() if context then send(context) end end

function M.stop()
  if context and context ~= 'off' then send('off') end
end

local function onUpdate(dtReal)
  uptime = uptime + dtReal
  checkTimer = checkTimer - dtReal
  if checkTimer > 0 then return end
  checkTimer = 0.25
  local ctx = wantedContext()
  if ctx ~= context then
    -- Tag <-> Nacht und kurzes Wackeln (z. B. Parkplatz-Rand) erst nach 2 s übernehmen, alles andere sofort
    local slow = (ctx == 'day' or ctx == 'night') and (context == 'day' or context == 'night')
    if slow then
      if pendingCtx ~= ctx then pendingCtx, pendingTime = ctx, 0 end
      pendingTime = pendingTime + 0.25
      if pendingTime < 2 then return end
    end
    pendingCtx = nil
    send(ctx)
  else
    pendingCtx = nil
  end
  -- Lautstärke-Regler von BeamNG mitnehmen
  volTimer = volTimer - 0.25
  if volTimer <= 0 then
    volTimer = 1
    local v = currentVolume()
    if context and context ~= 'off' and volume and math.abs(v - volume) > 0.005 then
      volume = v
      guihooks.trigger('HashiriyaMusicVolume', { volume = v })
    end
  end
  if context and context ~= 'off' and not playerReady and not warnedNoPlayer and uptime > 30 then
    warnedNoPlayer = true
    log('W', logTag, 'Musik-Player im UI hat sich nicht gemeldet (ui/ui-vue/mods/hashiriyaBattle/index.js)')
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
      if t and not t.hideInCredits and not seen[f] and fileUrl(f) then
        seen[f] = true
        table.insert(out, { title = t.title, artist = t.artist, license = t.license, context = ctxName })
      end
    end
  end
  return out
end

local function onClientEndMission() M.stop() end

M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission

return M
