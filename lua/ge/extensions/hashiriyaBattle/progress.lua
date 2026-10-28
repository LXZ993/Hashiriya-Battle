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
  local st = stats(save)
  if result and result.time then st.longestBattle = math.max(st.longestBattle or 0, result.time) end
  if won then
    if result and result.time then st.bestWinTime = math.min(st.bestWinTime or 1e9, result.time) end
    if extensions.hashiriyaBattle_home.unwatch(rival.id) then c.msg(c.t('msg.watchDone', rival.name), 4) end
    save.rep = (save.rep or 0) + math.floor((rival.rep or 30) * ((result and result.repFactor) or 1) + 0.5)
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
    if rival.leader and not rival.rematch then bump(save, 'leaderWins') end
    if rival.boss and not rival.rematch then bump(save, 'bossWins') end
  else
    save.rep = math.max(0, (save.rep or 0) + (set.lossRep or -10))
  end
  local after = M.rankIndex(save)
  if after > before then
    c.msg(c.t('msg.rankUp', M.rankName(save)), 7)
    c.sound('levelUp')
  end
end

-- Radarfallen -----------------------------------------------------------------
-- Pro Map zählt jede ausgelöste Radarfalle einmal (save.speedTraps[level][name] = höchstes Tempo in km/h).
-- Gesamtzahl aus der Kartendatei (speedTrapsTotal). Alle ausgelöst = Bedingung "speedTraps": "all" bei einem Rivalen.

function M.speedTrapCount(save)
  save = save or core().save
  local c = core()
  local list = save and save.speedTraps and save.speedTraps[c.levelName or ''] or {}
  local n = 0
  for _ in pairs(list) do n = n + 1 end
  local total = c.mapData and c.mapData.speedTrapsTotal or nil
  return n, total
end

local function onSpeedTrap(name, kmh)
  local c = core()
  local save = c.save
  if not save or not c.active or not name or name == '' then return end
  save.speedTraps = save.speedTraps or {}
  local lvl = c.levelName or ''
  save.speedTraps[lvl] = save.speedTraps[lvl] or {}
  local list = save.speedTraps[lvl]
  local isNew = list[name] == nil
  list[name] = math.max(list[name] or 0, math.floor(kmh or 0))
  local s = stats(save)
  s.topTrapKmh = math.max(s.topTrapKmh or 0, math.floor(kmh or 0))
  if isNew then
    local n, total = M.speedTrapCount(save)
    c.msg(c.t('msg.speedTrap', n, total or '?', math.floor(kmh or 0)), 4)
    if total and n >= total then c.msg(c.t('msg.speedTrapsAll'), 7); c.sound('levelUp') end
  end
end

-- BeamNG meldet Radarfallen über den Freeroam-Hook; als Rückfall zählen Trigger mit "speed" im Namen.
-- BeamNG (gameplay/speedTraps.lua): onSpeedTrapTriggered(data, playerSpeed m/s, overSpeed) feuert nur bei zu hohem Tempo.
-- Gezählt wird jede Radarfalle schon beim Durchfahren (onBeamNGTrigger mit speedTrapType), Schlüssel = triggerName.
local function trapKey(data)
  if type(data) ~= 'table' then return tostring(data) end
  return tostring(data.triggerName or data.triggerID or data.name or '')
end

function M.onSpeedTrapTriggered(trapData, playerSpeed)
  local veh = core().getPlayerVehicle()
  if type(trapData) == 'table' and trapData.subjectID and (not veh or trapData.subjectID ~= veh:getID()) then return end
  local kmh = tonumber(playerSpeed) and playerSpeed * 3.6 or (veh and veh:getVelocity():length() * 3.6) or 0
  onSpeedTrap(trapKey(trapData), kmh)
end

function M.onBeamNGTrigger(data)
  if type(data) ~= 'table' or data.event ~= 'enter' or data.speedTrapType ~= 'speed' then return end
  local veh = core().getPlayerVehicle()
  if not veh or data.subjectID ~= veh:getID() then return end
  onSpeedTrap(trapKey(data), veh:getVelocity():length() * 3.6)
end

-- Laufende Statistik: Strecke, Höchsttempo, Geld rein/raus ------------------------
local lastMoney = nil
local function onUpdate(dtReal, dtSim)
  local c = core()
  local save = c.save
  if not c.active or not save then lastMoney = nil; return end
  local s = stats(save)
  local veh = c.getPlayerVehicle()
  if veh and dtSim and dtSim > 0 then
    local v = veh:getVelocity():length()
    if v > 1 and v < 150 then
      s.distanceKm = (s.distanceKm or 0) + v * dtSim / 1000
      if extensions.hashiriyaBattle_battle.isBusy() then s.battleKm = (s.battleKm or 0) + v * dtSim / 1000 end
    end
    if v < 150 then s.topKmh = math.max(s.topKmh or 0, math.floor(v * 3.6)) end
  end
  if lastMoney and save.money ~= lastMoney then
    local d = save.money - lastMoney
    if d > 0 then s.moneyEarned = (s.moneyEarned or 0) + d else s.moneySpent = (s.moneySpent or 0) - d end
  end
  lastMoney = save.money
end
M.onUpdate = onUpdate
function M.resetMoneyWatch() lastMoney = nil end

-- Statistik-Seite im Menü
function M.getStatsUi()
  local c = core()
  local save = c.save
  if not save then return nil end
  local s = stats(save)
  local eco = c.economy()
  local function km(v) return string.format('%.1f km', v or 0) end
  local function time(t) if not t then return '—' end return string.format('%d:%04.1f', math.floor(t / 60), t % 60) end
  local battles = (save.wins or 0) + (save.losses or 0)
  local beaten, total = 0, 0
  for _, r in ipairs(data().rivals or {}) do
    total = total + 1
    if save.defeated and save.defeated[r.id] then beaten = beaten + 1 end
  end
  local traps, trapTotal = M.speedTrapCount(save)
  local groups = {
    { id = 'battle', rows = {
      { k = 'stats.rivals', v = beaten .. ' / ' .. total },
      { k = 'stats.record', v = (save.wins or 0) .. ' / ' .. (save.losses or 0) },
      { k = 'stats.winRate', v = battles > 0 and string.format('%d %%', math.floor((save.wins or 0) / battles * 100 + 0.5)) or '—' },
      { k = 'stats.leaderWins', v = s.leaderWins or 0 },
      { k = 'stats.bossWins', v = s.bossWins or 0 },
      { k = 'stats.rematchWins', v = s.rematchWins or 0 },
      { k = 'stats.cleanWins', v = s.cleanWins or 0 },
      { k = 'stats.closeWins', v = s.closeWins or 0 },
      { k = 'stats.quickWins', v = s.quickWins or 0 },
      { k = 'stats.bestWin', v = time(s.bestWinTime) },
      { k = 'stats.longestBattle', v = time(s.longestBattle) },
    } },
    { id = 'drive', rows = {
      { k = 'stats.distance', v = km(s.distanceKm) },
      { k = 'stats.battleKm', v = km(s.battleKm) },
      { k = 'stats.topSpeed', v = (s.topKmh or 0) .. ' km/h' },
      { k = 'stats.speedTraps', v = traps .. ' / ' .. (trapTotal or '?') },
      { k = 'stats.topTrap', v = (s.topTrapKmh or 0) .. ' km/h' },
      { k = 'stats.bestStreak', v = s.bestStreak or 0 },
      { k = 'stats.bestCombo', v = s.bestCombo or 0 },
      { k = 'stats.nearMisses', v = s.nearMisses or 0 },
      { k = 'stats.maneuvers', v = s.maneuvers or 0 },
      { k = 'stats.comboYen', v = eco.formatYen(s.comboYen or 0) },
      { k = 'stats.nights', v = s.nights or 0 },
      { k = 'stats.day', v = save.day or 1 },
    } },
    { id = 'money', rows = {
      { k = 'stats.earned', v = eco.formatYen(s.moneyEarned or 0) },
      { k = 'stats.spent', v = eco.formatYen(s.moneySpent or 0) },
      { k = 'stats.partsBought', v = s.partsBought or 0 },
      { k = 'stats.paintsBought', v = s.paintsBought or 0 },
      { k = 'stats.carsOwned', v = #(save.cars or {}) },
      { k = 'stats.fuel', v = string.format('%.0f l', s.fuelLiters or 0) },
      { k = 'stats.repairs', v = s.repairs or 0 },
      { k = 'stats.tows', v = s.tows or 0 },
    } },
  }
  return { groups = groups, rank = M.rankName(save), nick = M.nickname(save), rep = save.rep or 0 }
end

-- Neue Nacht zählen (Statistik für den Spitznamen)
function M.onNight(night)
  local save = core().save
  if not save or save.lastNight == night then return end
  save.lastNight = night
  bump(save, 'nights')
end

return M
