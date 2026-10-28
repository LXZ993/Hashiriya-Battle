-- Hashiriya Battle: Ruf, Rang und Spitzname (B.A.D.-Stil)
-- Siege bringen Ruf (rep des Rivalen), Niederlagen kosten etwas. Der Rang ergibt sich aus dem Ruf (ranks in rivals.json),
-- der letzte Rang erst nach dem Endboss. Der Spitzname kommt aus dem Fahrstil (Statistiken in save.stats).
local M = {}

local function core() return extensions.hashiriyaBattle_core end
local function data() return extensions.hashiriyaBattle_rivals.getData() end

-- Text in der Spielsprache aus { de = ..., en = ... } (oder einfacher Text)
function M.loc(v)
  if type(v) ~= 'table' then return v or '' end
  return v[core().lang or 'en'] or v.en or v.de or ''
end

local function stats(save)
  save.stats = save.stats or {}
  return save.stats
end

local function bump(save, key, n)
  local s = stats(save)
  s[key] = (s[key] or 0) + (n or 1)
end
M.bump = bump

-- Rang als Index ab 0
function M.rankIndex(save)
  save = save or core().save
  if not save then return 0 end
  local idx = 0
  for i, r in ipairs(data().ranks or {}) do
    if (save.rep or 0) >= (r.rep or 0) and (not r.requiresFinal or save.finalBeaten) then idx = i - 1 end
  end
  return idx
end

function M.rankName(save)
  local r = (data().ranks or {})[M.rankIndex(save) + 1]
  return r and M.loc(r.name) or core().t('hud.title.rookie')
end

-- Spitzname: die Regel, die am weitesten über ihrem Mindestwert liegt
function M.nickname(save)
  save = save or core().save
  if not save then return nil end
  local s = stats(save)
  local best, bestScore = nil, 0
  for _, n in ipairs(data().nicknames or {}) do
    local v = s[n.stat] or (n.stat == 'losses' and save.losses) or 0
    local score = v / math.max(n.min or 1, 1)
    if score >= 1 and score > bestScore then best, bestScore = n, score end
  end
  return best and M.loc(best.name) or nil
end

function M.getUiState()
  local save = core().save
  if not save then return nil end
  local ranks = data().ranks or {}
  local idx = M.rankIndex(save)
  local cur, nxt = ranks[idx + 1], ranks[idx + 2]
  local st = { rank = M.rankName(save), rankNo = idx + 1, rankCount = #ranks, rep = save.rep or 0, nick = M.nickname(save) }
  if cur and nxt then
    local span = math.max((nxt.rep or 0) - (cur.rep or 0), 1)
    st.next = M.loc(nxt.name)
    st.repNext = nxt.rep
    st.progress = math.floor(math.min(math.max(((save.rep or 0) - (cur.rep or 0)) / span, 0), 1) * 100 + 0.5)
  else
    st.progress = 100
  end
  return st
end

-- Nach jedem Battle (von core.onBattleResult)
function M.onBattle(rival, won, result)
  local c = core()
  local save = c.save
  local set = data().settings or {}
  local before = M.rankIndex(save)
  local night = extensions.hashiriyaBattle_home.nightId()
  save.nightBattles = save.nightBattles or {}
  if save.nightBattles.night ~= night then save.nightBattles = { night = night, count = 0 } end
  save.nightBattles.count = save.nightBattles.count + 1
  save.lastBattle = save.lastBattle or {}
  save.lastBattle[rival.id] = { night = night, won = won }
  if won then
    save.rep = (save.rep or 0) + (rival.rep or 30)
    save.defeatedNight = save.defeatedNight or {}
    if rival.rematch then
      save.rematchWins = save.rematchWins or {}
      save.rematchWins[rival.id] = (save.rematchWins[rival.id] or 0) + 1
      bump(save, 'rematchWins')
    else
      save.defeatedNight[rival.id] = night
    end
    if rival.final then save.finalBeaten = true end
    result = result or {}
    if (result.damageSp or 0) <= (set.cleanWinMaxDamageSp or 60) then bump(save, 'cleanWins') end
    if result.playerMaxSp and result.playerSp and result.playerSp / result.playerMaxSp * 100 <= (set.closeWinMaxSpPercent or 15) then bump(save, 'closeWins') end
    if result.time and result.time <= (set.quickWinSeconds or 30) then bump(save, 'quickWins') end
    if rival.leader then bump(save, 'leaderWins') end
    if rival.boss then bump(save, 'bossWins') end
  else
    save.rep = math.max(0, (save.rep or 0) + (set.lossRep or -10))
  end
  local after = M.rankIndex(save)
  if after > before then
    c.msg(c.t('msg.rankUp', M.rankName(save)), 7)
    c.sound('levelUp')
  end
end

-- Neue Nacht zählen (Statistik für den Spitznamen)
function M.onNight(night)
  local save = core().save
  if not save or save.lastNight == night then return end
  save.lastNight = night
  bump(save, 'nights')
end

return M
