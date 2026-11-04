-- Hashiriya Battle: Schwarzes Brett (HashiNet-Forum, Alpha 0.9.x).
-- Ein Forum der Szene mit Beiträgen, die sich jeden Tag und mit deinem Fortschritt ändern:
--   rumor = Gerüchte über Wanderer und Bosse (jeden Tag ein anderer Hinweis, nie die ganze Bedingung)
--   crew  = Crew-News (wie viele Fahrer du geschlagen hast, Leader unterwegs, Crew besiegt, neue Crew in der Szene)
--   news  = Nachtbericht (wen du in den letzten Nächten geschlagen hast)
--   scene = Szene-Beiträge, Wissen über Japan und die C1, Kleinanzeigen (data/board.json "posts")
--   job   = Anzeigen zu den heutigen Nebenjobs (Taxifirma, Lieferrunde)
-- Lesen: im Garagen-PC (Reiter "Schwarzes Brett") und zu Fuß an einem Aushang auf einer PA
-- (Dev-Menü > Orte, Typ "Schwarzes Brett (Aushang)", oder "boardSpots" in maps/<level>.json), Taste T wie beim Reden.
-- Texte und Einstellungen: data/board.json. Spielstand: save.board = { seen = { [postId] = Tag } }.
local M = {}

local logTag = 'hashiriya.board'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/board.json'

local function core() return extensions.hashiriyaBattle_core end
local function progress() return extensions.hashiriyaBattle_progress end
local function home() return extensions.hashiriyaBattle_home end
local function rivals() return extensions.hashiriyaBattle_rivals end

local data = nil
local cache = nil       -- { key, posts } (wird neu gebaut, wenn sich Tag, Siege, Rang oder Sprache ändern)
local nearSpot = nil    -- Aushang in Reichweite (für den Hinweis "[T] Lesen")
local openAt = nil      -- Aushang, an dem das Brett gerade offen ist (nil = Garagen-PC oder zu)
local timer = 0

local defaults = {
  enabled = true, rumorsPerDay = 4, rumorRankAhead = 1, crewPostsMax = 6, crewNewMax = 2, scenePerDay = 4, adsPerDay = 2, factsPerDay = 1,
  newsNights = 2, readRadius = 3.5, readRadiusCar = 9, readCarKmh = 4, jobAds = true,
}

function M.loadData()
  data = jsonReadFile(dataPath) or {}
  data.settings = data.settings or {}
  data.templates = data.templates or {}
  data.posts = data.posts or {}
  data.authors = data.authors or {}
  cache = nil
end

local function cfg()
  if not data then M.loadData() end
  local s = data.settings
  return setmetatable({}, { __index = function(_, k) if s[k] ~= nil then return s[k] end return defaults[k] end })
end

local function loc(v) return progress().loc(v) end

-- {name}-Platzhalter ersetzen
local function fill(text, vars)
  text = loc(text)
  return (text:gsub('{(%w+)}', function(k) local v = vars and vars[k] if v == nil then return '{' .. k .. '}' end return tostring(v) end))
end

local function hashStr(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

local function seeded(seed)
  local x = seed % 2147483647
  if x <= 0 then x = x + 2147483646 end
  return function(a, b)
    x = (x * 16807) % 2147483647
    local f = (x - 1) / 2147483646
    if not a then return f end
    return a + math.floor(f * (b - a + 1))
  end
end

local function pick(list, rand)
  if type(list) ~= 'table' or #list == 0 then return nil end
  return list[rand(1, #list)]
end

-- Liste mischen (fest pro Seed)
local function shuffled(list, rand)
  local out = {}
  for i, v in ipairs(list) do out[i] = v end
  for i = #out, 2, -1 do local j = rand(1, i) out[i], out[j] = out[j], out[i] end
  return out
end

local function tpl(key, rand)
  local t = data.templates[key]
  if type(t) == 'table' and t[1] then return pick(t, rand) end
  return t
end

local function author(rand)
  return pick(data.authors, rand) or 'anon'
end

local function brandOf(model)
  local name = rivals().vehicleName(model) or model
  return (tostring(name):match('^(%S+)')) or name
end

local function nickOf(r)
  local n = loc(r.nick)
  if n == '' then n = r.name or r.id end
  return n
end

-- Gerüchte ------------------------------------------------------------------------------

-- Ein Hinweis aus den Bedingungen, bewusst ungenau. Jeden Tag kann ein anderer drankommen.
local function hoursWord(from)
  from = tonumber(from) or 0
  if from >= 18 and from < 22 then return 'early'
  elseif from >= 22 then return 'late'
  elseif from < 2 then return 'midnight'
  elseif from < 4 then return 'deep'
  else return 'dawn' end
end

local function clues(r, save)
  local c = r.conditions or {}
  local out = {}
  local hours = c.hours or c.timeWindow
  if type(hours) == 'table' and hours[1] then
    table.insert(out, { key = 'clueHours', vars = { when = loc((data.templates.when or {})[hoursWord(hours[1])] or '') } })
  end
  if c.playerModel then
    local m = type(c.playerModel) == 'table' and c.playerModel[1] or c.playerModel
    table.insert(out, { key = 'clueModel', vars = { brand = brandOf(m) } })
  end
  if c.playerPart then
    local part = tostring(c.playerPart):lower()
    local pk = (data.templates.parts or {})[part]
    table.insert(out, { key = pk and 'cluePartKnown' or 'cluePart', vars = { sound = pk and loc(pk) or '' } })
  end
  local rv = rivals()
  if c.beatenTeam then table.insert(out, { key = 'clueTeam', vars = { team = rv.teamName(c.beatenTeam) or c.beatenTeam } }) end
  if type(c.beatenTeams) == 'table' and #c.beatenTeams > 0 then
    local names = {}
    for _, id in ipairs(c.beatenTeams) do table.insert(names, rv.teamName(id) or id) end
    table.insert(out, { key = 'clueTeams', vars = { teams = table.concat(names, ', ') } })
  end
  local req = c.beatenRivals or c.requires
  if type(req) == 'table' and #req > 0 then
    local names = {}
    for _, id in ipairs(req) do
      local o = rv.findRival and rv.findRival(id)
      table.insert(names, o and nickOf(o) or id)
    end
    table.insert(out, { key = 'clueRivals', vars = { names = table.concat(names, ', ') } })
  end
  if c.speedTraps then table.insert(out, { key = 'clueTraps' }) end
  if c.minDay and (save.day or 1) < c.minDay then table.insert(out, { key = 'clueDay' }) end
  if c.storyChapter then table.insert(out, { key = 'clueStory' }) end
  if #out == 0 or (c.minRank and progress().rankIndex(save) < c.minRank) then
    local rk = (rv.getData().ranks or {})[(c.minRank or 0) + 1]
    table.insert(out, { key = 'clueRank', vars = { rank = rk and loc(rk.name) or '?' } })
  end
  return out
end

local function rumorPosts(save, day, rand)
  local rank = progress().rankIndex(save)
  local cands = {}
  for _, r in ipairs((rivals().getData() or {}).rivals or {}) do
    if (r.wanderer or r.boss) and not (save.defeated or {})[r.id] and not r._platzhalter then
      local need = (r.conditions or {}).minRank or 0
      if need <= rank + cfg().rumorRankAhead then table.insert(cands, r) end
    end
  end
  local out = {}
  for i, r in ipairs(shuffled(cands, rand)) do
    if i > cfg().rumorsPerDay then break end
    local list = clues(r, save)
    local cl = list[(hashStr(r.id .. ':' .. day) % #list) + 1]
    local vars = cl.vars or {}
    vars.nick = r.name or nickOf(r)
    vars.title = nickOf(r)
    vars.brand = vars.brand or brandOf(r.model)
    vars.car = rivals().vehicleName(r.model)
    local known = save.knownHints and save.knownHints[r.id]
    table.insert(out, {
      id = 'rumor_' .. r.id .. '_' .. day, cat = r.boss and 'boss' or 'rumor', author = author(rand),
      title = fill(tpl(r.boss and 'rumorTitleBoss' or 'rumorTitle', rand) or '{nick}', vars),
      text = fill(tpl('rumorSight', rand) or '', vars) .. ' ' .. fill(tpl(cl.key, rand) or '', vars),
      tag = known and core().t('board.tag.known') or nil,
    })
  end
  return out
end

-- Crew-News -----------------------------------------------------------------------------

local function crewPosts(save, day, rand)
  local rv = rivals()
  local rdata = rv.getData() or {}
  local nightNow = home().nightId()
  local rank = progress().rankIndex(save)
  local defeated, dn = save.defeated or {}, save.defeatedNight or {}
  local car = save.cars and save.cars[save.activeCar or 1]
  local vars0 = { player = save.playerName or '???', car = car and car.name or '?' }
  local out = {}
  for _, team in ipairs(rdata.teams or {}) do
    local total, beaten, recent = 0, 0, 0
    local leader = rv.leaderOf(team.id)
    for _, r in ipairs(rdata.rivals) do
      if r.team == team.id and not r.leader then
        total = total + 1
        if defeated[r.id] then beaten = beaten + 1 end
        if dn[r.id] and nightNow - dn[r.id] <= 1 then recent = recent + 1 end
      end
    end
    local vars = { team = team.name, beaten = beaten, total = total, leader = leader and leader.name or '?',
      player = vars0.player, car = vars0.car, desc = loc(team.desc) }
    local post = nil
    local prio = 0
    if leader and defeated[leader.id] then
      if dn[leader.id] and nightNow - dn[leader.id] <= cfg().newsNights then
        post = { key = 'crewBeaten', prio = 5 }
      end
    elseif leader and beaten > 0 then
      local st = rv.leaderStatus(leader, save)
      if st == 'out' then post = { key = 'crewLeaderOut', prio = 4 }
      elseif st == 'nextNight' then post = { key = 'crewLeaderNext', prio = 4 }
      else post = { key = recent > 0 and 'crewAngry' or 'crewProgress', prio = recent > 0 and 3 or 1 } end
    elseif beaten == 0 and (team.minRank or 0) <= rank and (team.minRank or 0) >= rank - 1 then
      post = { key = 'crewNew', prio = 2 }
    end
    if post then
      table.insert(out, {
        id = 'crew_' .. team.id .. '_' .. post.key .. '_' .. beaten, cat = 'crew', prio = post.prio,
        author = post.key == 'crewNew' and author(rand) or (team.jp or team.name),
        title = fill(tpl(post.key .. 'Title', rand) or '{team}', vars),
        text = fill(tpl(post.key, rand) or '', vars),
        color = team.color, logo = rv.teamLogo and rv.teamLogo(team.id, false, true) or nil,
      })
    end
  end
  table.sort(out, function(a, b) if a.prio ~= b.prio then return a.prio > b.prio end return a.id < b.id end)
  -- höchstens crewNewMax "Neu in der Szene"-Beiträge
  local newN, kept = 0, {}
  for _, p in ipairs(out) do
    if p.id:find('_crewNew_', 1, true) then newN = newN + 1 end
    if not p.id:find('_crewNew_', 1, true) or newN <= cfg().crewNewMax then table.insert(kept, p) end
  end
  out = kept
  while #out > cfg().crewPostsMax do table.remove(out) end
  return out
end

-- Nachtbericht: geschlagene Gegner der letzten Nächte
local function newsPosts(save, day, rand)
  local rdata = rivals().getData() or {}
  local nightNow = home().nightId()
  local names = {}
  for _, r in ipairs(rdata.rivals or {}) do
    local n = (save.defeatedNight or {})[r.id]
    if n and nightNow - n <= 1 and (save.defeated or {})[r.id] then table.insert(names, r.name) end
  end
  if #names == 0 then return {} end
  local car = save.cars and save.cars[save.activeCar or 1]
  local vars = { player = save.playerName or '???', car = car and car.name or '?', count = #names,
    names = table.concat(names, ', ', 1, math.min(#names, 6)) .. (#names > 6 and ' ...' or '') }
  return { { id = 'news_' .. nightNow .. '_' .. #names, cat = 'news', author = author(rand), prio = 6,
    title = fill(tpl('newsTitle', rand) or '', vars), text = fill(tpl('news', rand) or '', vars) } }
end

-- Szene, Wissen, Kleinanzeigen aus board.json
local function poolPosts(save, day, rand)
  local rank = progress().rankIndex(save)
  local byCat = {}
  for _, p in ipairs(data.posts) do
    local ok = (not p.minRank or rank >= p.minRank) and (not p.maxRank or rank <= p.maxRank) and (not p.minDay or (save.day or 1) >= p.minDay)
    if ok then
      local cat = p.cat or 'scene'
      byCat[cat] = byCat[cat] or {}
      table.insert(byCat[cat], p)
    end
  end
  local out = {}
  local function take(cat, n)
    for i, p in ipairs(shuffled(byCat[cat] or {}, rand)) do
      if i > n then break end
      table.insert(out, { id = 'post_' .. (p.id or tostring(i)), cat = cat, author = p.author or author(rand),
        title = loc(p.title), text = loc(p.text), price = p.priceYen and core().economy().formatYen(p.priceYen) or nil })
    end
  end
  take('scene', cfg().scenePerDay)
  take('fact', cfg().factsPerDay)
  take('ad', cfg().adsPerDay)
  return out
end

-- Anzeigen zu den heutigen Nebenjobs (Taxischicht, Lieferrunde)
local function jobPosts(save, day, rand)
  if not cfg().jobAds then return {} end
  local ok, offers = pcall(function() return extensions.hashiriyaBattle_jobs.todaysOffers(save) end)
  if not ok or type(offers) ~= 'table' then return {} end
  local out, seen = {}, {}
  for _, o in ipairs(offers) do
    local key = o.kind == 'taxi' and 'adTaxi' or (o.kind == 'route' and 'adRoute' or nil)
    if key and not seen[key] then
      seen[key] = true
      local vars = { company = o.company and loc(o.company) or '', pay = core().economy().formatYen(o.pay or 0), stops = o.stops and #o.stops or 0 }
      table.insert(out, { id = 'job_' .. o.id, cat = 'job', author = o.company and loc(o.company) or author(rand),
        title = fill(tpl(key .. 'Title', rand) or '', vars), text = fill(tpl(key, rand) or '', vars) })
    end
  end
  return out
end

local catOrder = { news = 1, boss = 2, crew = 3, rumor = 4, job = 5, scene = 6, fact = 7, ad = 8 }

local function build(save)
  local day = save.day or 1
  local hints = 0
  for _ in pairs(save.knownHints or {}) do hints = hints + 1 end
  local key = table.concat({ day, save.wins or 0, progress().rankIndex(save), core().lang or '', home().nightId(), hints }, ':')
  if cache and cache.key == key then return cache.posts end
  local seed = hashStr(tostring(save.dealerSeed or 1) .. ':board:' .. day)
  local posts = {}
  local parts = { newsPosts, crewPosts, rumorPosts, jobPosts, poolPosts }
  for i, fn in ipairs(parts) do
    local rand = seeded(seed + i * 7919)
    local ok, res = pcall(fn, save, day, rand)
    if ok then for _, p in ipairs(res) do table.insert(posts, p) end
    else log('E', logTag, 'Beiträge (' .. i .. '): ' .. tostring(res)) end
  end
  -- "vor x Std.": fest pro Beitrag und Tag
  for _, p in ipairs(posts) do
    local r = seeded(hashStr(p.id .. ':' .. day))
    p.hoursAgo = p.cat == 'news' and r(1, 5) or r(1, 22)
    p.catText = core().t('board.cat.' .. p.cat)
  end
  table.sort(posts, function(a, b)
    local ca, cb = catOrder[a.cat] or 9, catOrder[b.cat] or 9
    if ca ~= cb then return ca < cb end
    return a.hoursAgo < b.hoursAgo
  end)
  cache = { key = key, posts = posts }
  return posts
end

-- Gelesen-Markierung: neu = an diesem Tag noch nicht gesehen
local function boardState(save)
  save.board = save.board or {}
  save.board.seen = save.board.seen or {}
  return save.board
end

function M.getUiState()
  local c = core()
  local save = c and c.save
  if not save or not cfg().enabled then return nil end
  if not data then M.loadData() end
  local bs = boardState(save)
  local posts = {}
  local newCount = 0
  for _, p in ipairs(build(save)) do
    local e = {}
    for k, v in pairs(p) do e[k] = v end
    e.isNew = not bs.seen[p.id] or nil
    if e.isNew then newCount = newCount + 1 end
    e.ago = c.t('board.ago', tostring(p.hoursAgo))
    table.insert(posts, e)
  end
  return { posts = posts, newCount = newCount, day = home().dayText(), place = openAt and openAt.name or c.t('board.garage'),
    cats = { 'all', 'rumor', 'crew', 'scene', 'job' } }
end

-- Alles als gelesen merken (beim Schließen)
function M.markRead()
  local c = core()
  local save = c and c.save
  if not save or not cache then return end
  local bs = boardState(save)
  local day = save.day or 1
  for _, p in ipairs(cache.posts) do bs.seen[p.id] = bs.seen[p.id] or day end
  -- alte Einträge aufräumen (älter als 10 Tage)
  for id, d in pairs(bs.seen) do if type(d) == 'number' and day - d > 10 then bs.seen[id] = nil end end
end

-- Neue Beiträge (für die Kachel im Menü / den Garagen-PC)
function M.newCount()
  local c = core()
  local save = c and c.save
  if not save or not cfg().enabled then return 0 end
  local ok, posts = pcall(build, save)
  if not ok then return 0 end
  local bs = boardState(save)
  local n = 0
  for _, p in ipairs(posts) do if not bs.seen[p.id] then n = n + 1 end end
  return n
end

-- Aushänge an den PAs ---------------------------------------------------------------------

local function spotName(s)
  local n = loc(s.name or '')
  if n == '' then n = core().t('board.title') end
  return n
end

local function findNear()
  local c = core()
  local spots = c.spots('board')
  if #spots == 0 then return nil end
  local pos, radius = c.getWalkerPos(), cfg().readRadius
  if not pos then
    local veh = c.getPlayerVehicle()
    if not veh or veh:getVelocity():length() * 3.6 > cfg().readCarKmh then return nil end
    pos, radius = veh:getPosition(), cfg().readRadiusCar
  end
  local best, bestD = nil, radius
  for _, s in ipairs(spots) do
    local d = (pos - vec3(s.pos[1], s.pos[2], s.pos[3])):length()
    if d < bestD then best, bestD = s, d end
  end
  return best
end

-- Hinweis "[T] Schwarzes Brett lesen" (in der Sprechblasen-App, wie beim Reden)
function M.prompt()
  if not nearSpot or openAt then return nil end
  local c = core()
  local key = 'T'
  pcall(function() key = extensions.hashiriyaBattle_talk.keyName() end)
  local n = M.newCount()
  return { name = spotName(nearSpot) .. (n > 0 and (' · ' .. c.t('board.newCount', tostring(n))) or ''), key = key, text = c.t('board.prompt'), board = true }
end

-- Taste T: Brett am Aushang öffnen (true = gehandelt)
function M.interact()
  if not nearSpot then return false end
  if openAt then core().uiAction('boardBack') return true end
  openAt = nearSpot
  core().uiAction('board')
  pcall(function() core().sound('info') end)
  return true
end

function M.isOpenAtSpot() return openAt ~= nil end

function M.close()
  M.markRead()
  openAt = nil
end

local function onUpdate(dtReal)
  local c = core()
  if not c or not c.active or not c.save then nearSpot, openAt = nil, nil return end
  timer = timer - (dtReal or 0)
  if timer > 0 then return end
  timer = 0.4
  local ok, s = pcall(findNear)
  nearSpot = ok and s or nil
  -- weggegangen: Brett am Aushang schließen
  if openAt and not nearSpot then
    openAt = nil
    pcall(function() c.uiAction('boardBack') end)
  end
end

M.onUpdate = onUpdate
M.onClientEndMission = function() nearSpot, openAt, cache = nil, nil, nil end

return M
