-- Hashiriya Battle: Story und Kapitel (Alpha 0.6).
-- Kapitel, Szenen und Handy-Nachrichten stehen in data/story.json. Ein Kapitel beginnt, sobald seine Startbedingungen
-- erfüllt sind (gleiche Bedingungen wie bei Rivalen: minRank, beatenRivals, beatenTeams, minDay ... siehe Handbuch).
-- Dann kommt die Kapitelkarte (Titel, japanischer Titel, kurzer Text), danach die Szenen mit Auslöser "start".
-- Weitere Auslöser: garage, home, wake (Aufwachen zuhause), pa (zu Fuß an einer PA), win/lose (nach einem Battle,
-- optional nur gegen "rival" oder "team"), rank (Rangaufstieg), day (neuer Tag).
-- Szenen laufen in der Sprechblase der PA-Gespräche (Taste Reden = weiter). Handy-Nachrichten ("style": "phone")
-- erscheinen auch beim Fahren und laufen von selbst weiter.
-- Spielstand: save.story = { chapter = Index, seen = {Szene = true}, log = {Szenen-IDs in Reihenfolge} }.
local M = {}

local logTag = 'hashiriya.story'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local storyPath = '/lua/ge/extensions/hashiriyaBattle/data/story.json'

local function core() return extensions.hashiriyaBattle_core end
local function rivals() return extensions.hashiriyaBattle_rivals end
local function progress() return extensions.hashiriyaBattle_progress end
local function home() return extensions.hashiriyaBattle_home end

local data = nil
local queue = {}      -- wartende Szenen { scene, chapter }
local current = nil   -- laufende Szene { scene, index, t, phone }
local card = nil      -- Kapitelkarte { chapter, t }
local timer = 0
local lastRank = nil
local lastDay = nil
local paInside = {}   -- [PA-Name] = true, solange du zu Fuß dort bist

local defaults = { enabled = true, cardSeconds = 8, phoneSeconds = 5, phoneCharsPerSecond = 22, paRadius = 60, stopKmh = 5 }

local function cfg()
  local s = data and data.settings or {}
  return setmetatable({}, { __index = function(_, k) if s[k] ~= nil then return s[k] end return defaults[k] end })
end

function M.loadData()
  data = jsonReadFile(storyPath) or { chapters = {}, characters = {} }
  data.chapters = data.chapters or {}
  data.characters = data.characters or {}
end

function M.getData()
  if not data then M.loadData() end
  return data
end

local function loc(v) return progress().loc(v) end

local function state(save)
  save = save or core().save
  if not save then return nil end
  save.story = save.story or { chapter = 0, seen = {}, log = {} }
  save.story.seen = save.story.seen or {}
  save.story.log = save.story.log or {}
  return save.story
end

-- Bedingungen: wie bei Rivalen, dazu night = true/false und chapter = Kapitel-ID (mindestens erreicht)
local function condOk(c, save)
  if not c then return true end
  if c.night ~= nil and (home().isNight() and true or false) ~= c.night then return false end
  if c.chapter and not M.reached(c.chapter, save) then return false end
  if c.notChapter and M.reached(c.notChapter, save) then return false end
  if c.minWins and (save.wins or 0) < c.minWins then return false end
  local okC, res = pcall(rivals().conditionsMet, c, save)
  return okC and res or false
end
M.conditionsMet = condOk

local function chapterIndex(id)
  for i, ch in ipairs(M.getData().chapters) do if ch.id == id then return i end end
  return nil
end

-- Hast du dieses Kapitel schon erreicht?
function M.reached(id, save)
  local st = state(save)
  local i = chapterIndex(id)
  return st and i and st.chapter >= i or false
end

function M.currentChapter(save)
  local st = state(save)
  if not st or st.chapter < 1 then return nil end
  return M.getData().chapters[st.chapter]
end

-- Szene in die Warteschlange (einmal pro Spielstand, außer "repeat": true)
local function enqueue(scene, ch)
  local st = state()
  if not st or (st.seen[scene.id] and not scene['repeat']) then return end
  for _, q in ipairs(queue) do if q.scene == scene then return end end
  if current and current.scene == scene then return end
  table.insert(queue, { scene = scene, chapter = ch })
end

-- Freie Handy-Nachricht (z. B. gekaufter Tipp): kommt wie eine Story-Nachricht, auch beim Fahren
function M.phoneMessage(id, speaker, lines)
  if not state() or type(lines) ~= 'table' or #lines == 0 then return end
  enqueue({ id = id, style = 'phone', speaker = speaker or 'genzo', lines = lines, ['repeat'] = true }, nil)
end

-- Ereignis aus dem Spiel: passende Szenen des aktuellen Kapitels (und Szenen ohne Kapitel) einreihen
local function matches(scene, kind, info)
  local trig = scene.trigger or 'start'
  if trig ~= kind then return false end
  info = info or {}
  if scene.rival and scene.rival ~= (info.rival and (info.rival.baseId or info.rival.id)) then return false end
  if scene.team and scene.team ~= (info.rival and info.rival.team) then return false end
  if scene.boss ~= nil and (info.rival and info.rival.boss and true or false) ~= scene.boss then return false end
  if scene.place and scene.place ~= info.place then return false end
  if scene.area and scene.area ~= info.area then return false end
  if scene.rank and (info.rank or -1) < scene.rank then return false end
  return condOk(scene.conditions, core().save)
end

function M.onEvent(kind, info)
  local c = core()
  if not c or not c.active or not c.save or not cfg().enabled then return end
  local d = M.getData()
  local ch = M.currentChapter()
  local lists = { { list = d.scenes or {}, ch = nil } }
  if ch then table.insert(lists, 1, { list = ch.scenes or {}, ch = ch }) end
  for _, l in ipairs(lists) do
    for _, scene in ipairs(l.list) do
      if matches(scene, kind, info) then enqueue(scene, l.ch) end
    end
  end
end

-- Kapitel weiterschalten ------------------------------------------------------------

local function startChapter(i, silent)
  local st = state()
  local ch = M.getData().chapters[i]
  if not st or not ch then return end
  st.chapter = i
  log('I', logTag, 'Kapitel ' .. tostring(ch.id) .. (silent and ' (übersprungen)' or ''))
  if silent then return end
  -- Die Karte wartet, solange ein Battle samt Ergebnis-Spruch läuft (sonst überlappt sie den Rivalentext)
  if ch.title then card = { chapter = ch, t = 0, shown = false } else core().sound('levelUp') end
  for _, scene in ipairs(ch.scenes or {}) do
    if (scene.trigger or 'start') == 'start' and condOk(scene.conditions, core().save) then enqueue(scene, ch) end
  end
  core().writeSave()
end

-- Alter Spielstand ohne Story: alle schon erreichten Kapitel still überspringen, nur das letzte zeigen
local function catchUp(save)
  local st = state(save)
  if st.init then return end
  st.init = true
  if (save.wins or 0) == 0 and (save.losses or 0) == 0 then return end
  local chs = M.getData().chapters
  local last = 0
  for i, ch in ipairs(chs) do
    if condOk(ch.start, save) then last = i else break end
  end
  for i = 1, last - 1 do startChapter(i, true) end
end

local function checkChapter(save)
  local st = state(save)
  local chs = M.getData().chapters
  local nextCh = chs[st.chapter + 1]
  if not nextCh then return end
  -- erst wenn die Szenen des aktuellen Kapitels durch sind
  if card or current or #queue > 0 then return end
  if condOk(nextCh.start, save) then startChapter(st.chapter + 1) end
end

-- Anzeige ---------------------------------------------------------------------------

local function speakerInfo(id)
  local c = core()
  if id == 'player' then return { name = c.save and c.save.playerName or '', side = 'right', tag = 'player' } end
  local ch = M.getData().characters[id or '']
  if ch then
    local p = ch.portrait
    if p and not FS:fileExists('/' .. p:gsub('^/', '')) then p = nil end
    return { name = loc(ch.name), nick = loc(ch.nick), portrait = p and ('/' .. p:gsub('^/', '')) or nil, side = ch.side or 'left', tag = ch.tag or 'story' }
  end
  local r = id and rivals().findRival and rivals().findRival(id)
  if r then
    local portrait
    for _, ext in ipairs({ 'png', 'jpg', 'svg' }) do
      local p = '/art/portraits/' .. r.id .. '.' .. ext
      if FS:fileExists(p) then portrait = p break end
    end
    return { name = r.name, nick = loc(r.nick), portrait = portrait, side = 'left', tag = rivals().markerKind(r) }
  end
  return { name = '', side = 'left', tag = 'story' }
end

local function playerSpeedKmh()
  local veh = core().getPlayerVehicle()
  if not veh then return 0 end
  local ok, v = pcall(function() return veh:getVelocity():length() * 3.6 end)
  return ok and v or 0
end

-- Darf jetzt eine Szene laufen? Gespräche nur im Stand oder zu Fuß, Nachrichten auch beim Fahren.
local function canShow(scene)
  local c = core()
  if extensions.hashiriyaBattle_battle.isBusy() then return false end
  if home().isResting() then return false end
  local okT, talking = pcall(function() return extensions.hashiriyaBattle_talk.isTalking() end)
  if okT and talking then return false end
  if extensions.hashiriyaBattle_career.isOpen() then return false end
  if scene.style == 'phone' then return true end
  return c.getWalkerPos() ~= nil or playerSpeedKmh() < cfg().stopKmh
end

local function lineText(line)
  if type(line) == 'table' and (line.de or line.en) then return loc(line) end
  if type(line) == 'table' then return loc(line.text) end
  return tostring(line or '')
end

local function lineSpeaker(scene, line)
  if type(line) == 'table' and line.speaker then return line.speaker end
  return scene.speaker
end

local function phoneSeconds(text)
  local s = cfg()
  return math.max(s.phoneSeconds, #text / s.phoneCharsPerSecond)
end

local function finishScene()
  local st = state()
  if current and st then
    local id = current.scene.id
    if id and not st.seen[id] then
      st.seen[id] = true
      table.insert(st.log, id)
    end
    -- Belohnung (optional): money in Yen, rep, hint (Lexikon-Hinweis)
    local s = current.scene
    local c = core()
    if s.money then
      c.save.money = c.save.money + math.floor(tonumber(s.money) or 0)
      c.msg(c.t('msg.storyMoney', c.economy().formatYen(s.money)), 5)
    end
    if s.rep then c.save.rep = (c.save.rep or 0) + math.floor(tonumber(s.rep) or 0) end
    if s.hint then pcall(home().learnHint, s.hint) end
  end
  current = nil
  core().writeSave()
end

local function startScene(q)
  current = { scene = q.scene, chapter = q.chapter, index = 1, t = 0, phone = q.scene.style == 'phone' }
  core().sound(current.phone and 'talkHint' or 'talk')
  log('I', logTag, 'Szene ' .. tostring(q.scene.id))
end

-- Taste Reden: Karte schließen, nächster Satz
function M.interact()
  if card and card.shown then
    card = nil
    core().sendUiState()
    return true
  end
  if not current then return false end
  current.index = current.index + 1
  current.t = 0
  if current.index > #(current.scene.lines or {}) then finishScene() else core().sound('talk') end
  core().sendUiState()
  return true
end

function M.isShowing() return (card ~= nil and card.shown) or current ~= nil end

-- Kapitelziel (HUD und Menü)
function M.goal()
  local c = core()
  local ch = M.currentChapter()
  if not ch or not ch.goal then return nil end
  local d = M.getData()
  local i = chapterIndex(ch.id)
  -- Ziel erreicht, nächstes Kapitel wartet noch auf etwas anderes (z. B. Uhrzeit): Ziel des nächsten zeigen
  local nextCh = d.chapters[(i or 0) + 1]
  local text = loc(ch.goal)
  if ch.done and condOk(ch.done, c.save) and nextCh and nextCh.goalBefore then text = loc(nextCh.goalBefore) end
  return { chapter = loc(ch.label) ~= '' and loc(ch.label) or c.t('story.chapter', ch.number or i), title = loc(ch.title), text = text }
end

function M.getHudState()
  local c = core()
  if card and card.shown then
    local ch = card.chapter
    return { card = { label = loc(ch.label) ~= '' and loc(ch.label) or c.t('story.chapter', ch.number or chapterIndex(ch.id)),
      title = loc(ch.title), jp = ch.jp, text = loc(ch.intro), key = extensions.hashiriyaBattle_talk.keyName(), next = c.t('talk.next') } }
  end
  if not current then return nil end
  local lines = current.scene.lines or {}
  local line = lines[current.index]
  if not line then return nil end
  local sp = speakerInfo(lineSpeaker(current.scene, line))
  local last = current.index >= #lines
  return { talk = {
    text = lineText(line), name = sp.name, nick = sp.nick, portrait = sp.portrait, side = sp.side,
    kind = current.phone and 'phone' or 'story', tag = current.phone and 'phone' or sp.tag,
    step = current.index, steps = #lines,
    topic = current.phone and c.t('story.phone') or (current.chapter and loc(current.chapter.title)) or nil,
    key = extensions.hashiriyaBattle_talk.keyName(), next = c.t(last and 'talk.end' or 'talk.next'),
    timer = current.phone and math.max(0, 1 - current.t / phoneSeconds(lineText(line))) or nil,
  } }
end

-- Lexikon: Seite "Story" mit allen Kapiteln und gesehenen Szenen
function M.lexiconGroup()
  local c = core()
  local st = state()
  if not st then return nil end
  local d = M.getData()
  local g = { name = c.t('story.lexicon'), color = '#ff6600', list = {}, story = true }
  local seenIn = {}
  for _, id in ipairs(st.log) do seenIn[id] = true end
  for i, ch in ipairs(d.chapters) do
    if i <= st.chapter then
      local label = loc(ch.label) ~= '' and loc(ch.label) or c.t('story.chapter', ch.number or i)
      table.insert(g.list, { name = label .. ': ' .. loc(ch.title), nick = '', car = ch.jp or '', desc = loc(ch.intro), beaten = i < st.chapter, chapter = true })
      for _, s in ipairs(ch.scenes or {}) do
        if seenIn[s.id] then
          local parts = {}
          for _, line in ipairs(s.lines or {}) do
            local sp = speakerInfo(lineSpeaker(s, line))
            table.insert(parts, (sp.name ~= '' and (sp.name .. ': ') or '') .. lineText(line))
          end
          table.insert(g.list, { name = loc(s.title) ~= '' and loc(s.title) or '', nick = '', car = s.style == 'phone' and c.t('story.phone') or '',
            desc = table.concat(parts, '\n'), beaten = true, scene = true })
        end
      end
    end
  end
  g.count = math.max(st.chapter, 0) .. ' / ' .. #d.chapters
  return g
end

function M.reset()
  queue, current, card = {}, nil, nil
  lastRank, lastDay = nil, nil
  paInside = {}
end

-- Laufend ---------------------------------------------------------------------------

local function checkPa(c)
  local wpos = c.getWalkerPos()
  local md = c.mapData
  local list = md and (md.talkSpots or md.napSpots) or {}
  for _, pa in ipairs(list) do
    local inside = wpos and (wpos - vec3(pa.pos[1], pa.pos[2], pa.pos[3])):length() < cfg().paRadius or false
    if inside and not paInside[pa.name] then M.onEvent('pa', { place = pa.name }) end
    paInside[pa.name] = inside or nil
  end
end

local function onUpdate(dtReal)
  local c = core()
  if not c or not c.active or not c.save then
    if current or card or #queue > 0 then M.reset() end
    return
  end
  if not cfg().enabled then return end
  local save = c.save
  -- Karte und Handy-Nachrichten laufen mit der Zeit weiter
  if card and not card.shown and not extensions.hashiriyaBattle_battle.isBusy() then
    card.shown = true
    c.sound('levelUp')
    c.sendUiState()
  end
  if card and card.shown then
    card.t = card.t + dtReal
    if card.t >= cfg().cardSeconds then card = nil c.sendUiState() end
  end
  if current and current.phone and not card then
    current.t = current.t + dtReal
    local line = (current.scene.lines or {})[current.index]
    if not line or current.t >= phoneSeconds(lineText(line)) then M.interact() end
  end
  timer = timer - dtReal
  if timer > 0 then return end
  timer = 0.5
  local ok, err = pcall(function()
    catchUp(save)
    -- Rang und Tag beobachten
    local rank = progress().rankIndex(save)
    if lastRank and rank > lastRank then M.onEvent('rank', { rank = rank }) end
    lastRank = rank
    local day = save.day or 1
    if lastDay and day > lastDay then M.onEvent('day', { day = day }) end
    lastDay = day
    checkPa(c)
    checkChapter(save)
    if not card and not current and #queue > 0 and canShow(queue[1].scene) then
      startScene(table.remove(queue, 1))
      c.sendUiState()
    end
  end)
  if not ok then log('E', logTag, 'Story: ' .. tostring(err)) end
end

M.onUpdate = onUpdate
M.onClientEndMission = function() M.reset() end

return M
