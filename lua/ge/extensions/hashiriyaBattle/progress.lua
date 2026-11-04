-- Hashiriya Battle: Ruf, Rang und Spitzname (B.A.D.-Stil)
-- Siege bringen Ruf (rep des Rivalen), Niederlagen kosten etwas. Der Rang ergibt sich aus dem Ruf (ranks in rivals.json),
-- der letzte Rang erst nach dem Endboss. Spitznamen werden über den Fahrstil verdient (Statistiken in save.stats),
-- jeder verdiente bleibt wählbar (Trophäenwand, Reiter Spitznamen).
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

-- Spitznamen (wie die Titel in TXR) ------------------------------------------------
-- Liste in rivals.json "nicknames": { id, group, stat, min, name, desc }. Ein Spitzname ist verdient, sobald der Wert
-- des Zählers (save.stats[stat], Sonderfälle siehe statValue) min erreicht; min "all" = alle (nur bei speedTraps).
-- Verdiente Spitznamen bleiben für immer (save.nickEarned[id] = laufende Nummer, je höher desto neuer).
-- save.playerNick = gewählter Spitzname (nil = automatisch der zuletzt verdiente). Jeder Spielstand hat seine eigene Wahl.

local function statValue(save, stat)
  local s = stats(save)
  if stat == 'wins' then return save.wins or 0 end
  if stat == 'losses' then return save.losses or 0 end
  if stat == 'speedTraps' then return (M.speedTrapCount(save)) end
  if stat == 'talks' then return (save.talk and save.talk.count) or 0 end
  if stat == 'logos' then
    local ok, info = pcall(function() return extensions.hashiriyaBattle_logos.tileInfo() end)
    return ok and info and info.have or 0
  end
  return s[stat] or 0
end

-- Zielwert eines Spitznamens (min "all" = Gesamtzahl der Radarfallen, nil wenn unbekannt)
local function targetOf(save, n)
  if n.min == 'all' then
    if n.stat == 'speedTraps' then local _, total = M.speedTrapCount(save); return total end
    return nil
  end
  return tonumber(n.min) or 1
end

-- Titel pro Automodell (wie in TXR 2025): rivals.json "modelTitles" = Stufen { id, min, name = "%s-Fahrer" }.
-- Gezählt werden Siege mit dem jeweiligen Modell (save.stats.modelWins[model]), der Name kommt aus BeamNG
-- (save.modelNames[model], beim Sieg gemerkt, damit er auch ohne das Fahrzeug-Mod bleibt).
local function modelName(save, model)
  local names = save.modelNames or {}
  if names[model] then return names[model] end
  local ok, m = pcall(core_vehicles.getModel, model)
  local n = ok and m and m.model and m.model.Name or nil
  if n then save.modelNames = names; names[model] = n end
  return n or model
end

-- Alle Spitznamen als einheitliche Liste: feste aus "nicknames" + Modelltitel für jedes Modell mit Siegen.
-- Einträge: { id, group, name, desc, value, target }
local function allNicks(save)
  local list = {}
  for _, n in ipairs(data().nicknames or {}) do
    if n.id then
      table.insert(list, { id = n.id, group = n.group or 'battle', name = M.loc(n.name), desc = M.loc(n.desc),
        value = statValue(save, n.stat), target = targetOf(save, n) })
    end
  end
  local tiers = data().modelTitles or {}
  local mw = stats(save).modelWins or {}
  local models = {}
  for model in pairs(mw) do table.insert(models, model) end
  table.sort(models, function(x, y) return (mw[x] or 0) > (mw[y] or 0) end)
  for _, model in ipairs(models) do
    local name = modelName(save, model)
    local shown = false
    for _, t in ipairs(tiers) do
      local min = tonumber(t.min) or 10
      local id = 'm:' .. model .. ':' .. (t.id or tostring(min))
      local got = (save.nickEarned or {})[id] or mw[model] >= min
      -- verdiente Stufen alle zeigen, von den offenen nur die nächste
      if got or not shown then
        if not got then shown = true end
        table.insert(list, { id = id, group = 'cars', name = string.format(M.loc(t.name), name),
          desc = core().t('nicks.modelDesc', min, name), value = mw[model], target = min })
      end
    end
  end
  return list
end

-- Neu verdiente Spitznamen eintragen. silent = ohne Meldung (erster Start mit einem alten Spielstand).
function M.checkNicknames(silent)
  local c = core()
  local save = c.save
  if not save then return end
  local first = save.nickEarned == nil
  save.nickEarned = save.nickEarned or {}
  local earned = save.nickEarned
  local seq = 0
  for _, v in pairs(earned) do seq = math.max(seq, tonumber(v) or 0) end
  local newOnes = {}
  for _, n in ipairs(allNicks(save)) do
    if not earned[n.id] and n.target and (n.value or 0) >= n.target then
      seq = seq + 1
      earned[n.id] = seq
      table.insert(newOnes, n)
    end
  end
  if #newOnes > 0 then c.writeSave() end
  if #newOnes > 0 and not (silent or first) then
    for _, n in ipairs(newOnes) do c.msg(c.t('msg.nickEarned', n.name), 6) end
    c.sound('unlock')
  end
  return #newOnes
end

-- Aktiver Spitzname (gewählt oder der zuletzt verdiente)
local function activeNick(save)
  local earned = save.nickEarned or {}
  local list = allNicks(save)
  if save.playerNick and earned[save.playerNick] then
    for _, n in ipairs(list) do if n.id == save.playerNick then return n end end
  end
  local best, bestSeq = nil, -1
  for _, n in ipairs(list) do
    local q = earned[n.id]
    if q and q > bestSeq then best, bestSeq = n, q end
  end
  return best
end

function M.nickname(save)
  save = save or core().save
  if not save then return nil end
  if save.nickEarned == nil then M.checkNicknames(true) end
  local n = activeNick(save)
  return n and n.name or nil
end

-- Sieg mit dem aktiven Auto zählen (für die Modelltitel)
local function countModelWin(save)
  local car = save.cars and save.cars[save.activeCar or 1]
  if not car or not car.model then return end
  local s = stats(save)
  s.modelWins = s.modelWins or {}
  s.modelWins[car.model] = (s.modelWins[car.model] or 0) + 1
  modelName(save, car.model)
end

-- Spitznamen wählen (nil / 'auto' = automatisch). Nur verdiente.
function M.chooseNick(id)
  local c = core()
  local save = c.save
  if not save then return false end
  if id == nil or id == '' or id == 'auto' then
    save.playerNick = nil
  else
    if not (save.nickEarned or {})[id] then return false end
    save.playerNick = id
  end
  c.writeSave()
  pcall(c.sound, 'click')
  return true
end

-- Daten für den Reiter "Spitznamen" der Trophäenwand
function M.getNickUi()
  local c = core()
  local save = c.save
  if not save then return nil end
  if save.nickEarned == nil then M.checkNicknames(true) end
  local earned = save.nickEarned or {}
  local act = activeNick(save)
  local order = { 'battle', 'style', 'road', 'life', 'cars' }
  local groups, byKey = {}, {}
  for _, k in ipairs(order) do
    local g = { key = k, name = c.t('nicks.g.' .. k), list = {}, have = 0 }
    table.insert(groups, g); byKey[k] = g
  end
  local have, total = 0, 0
  for _, n in ipairs(allNicks(save)) do
    local g = byKey[n.group] or byKey.battle
    local got = earned[n.id] and true or false
    local v, target = n.value or 0, n.target
    total = total + 1
    if got then have = have + 1; g.have = g.have + 1 end
    table.insert(g.list, {
      id = n.id, name = n.name, desc = n.desc, earned = got,
      selected = act and act.id == n.id or false,
      progress = got and 100 or (target and math.floor(math.min(v / math.max(target, 1), 1) * 100) or 0),
      value = (not got and target) and (math.floor(v) .. ' / ' .. math.floor(target)) or nil,
    })
  end
  local out = {}
  for _, g in ipairs(groups) do g.total = #g.list; if g.total > 0 or g.key == 'cars' then table.insert(out, g) end end
  return { have = have, total = total, auto = save.playerNick == nil, current = act and act.name or nil, groups = out }
end

-- ID der aktiven Spitznamen-Regel (für die Rivalen-Bedingung "nickname")
function M.nicknameId(save)
  save = save or core().save
  if not save then return nil end
  if save.nickEarned == nil then M.checkNicknames(true) end
  local n = activeNick(save)
  return n and n.id or nil
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
    if rival.wanderer and not rival.boss and not rival.rematch then bump(save, 'wandererWins') end
    countModelWin(save)
    if result.playerMaxSp and result.playerSp and result.playerSp / result.playerMaxSp * 100 > (set.dominantWinMinSpPercent or 90) then bump(save, 'dominantWins') end
    if result.time and result.time >= (set.marathonWinSeconds or 120) then bump(save, 'marathonWins') end
    if (result.damageSp or 0) >= (set.wreckWinMinDamageSp or 250) then bump(save, 'wreckWins') end
    -- Uhrzeit des Siegs (Spielzeit): 20-22 Uhr, 2-4 Uhr, 4-6 Uhr
    local h = extensions.hashiriyaBattle_home.hour()
    if h then
      if h >= 20 and h < 22 then bump(save, 'earlyWins')
      elseif h >= 2 and h < 4 then bump(save, 'lateWins')
      elseif h >= 4 and h < 6 then bump(save, 'dawnWins') end
    end
  else
    save.rep = math.max(0, (save.rep or 0) + (set.lossRep or -10))
  end
  local after = M.rankIndex(save)
  if after > before then
    c.msg(c.t('msg.rankUp', M.rankName(save)), 7)
    c.sound('levelUp')
  end
end

-- Nach dem Battle, wenn alles gezählt ist (core.onBattleResult ruft das nach wins/losses/defeated)
function M.afterBattle()
  M.checkNicknames()
end

-- Nach dem Sieg über das letzte Mitglied eines Teams: Hinweis, wann der Leader auftaucht (core ruft das nach save.defeated)
function M.leaderHint(rival)
  local c = core()
  local save = c.save
  local rv = extensions.hashiriyaBattle_rivals
  if not (rival.team and not rival.leader and not rival.rematch and rv.leaderOf) then return end
  local leader = rv.leaderOf(rival.team)
  if not leader or (save.defeated or {})[leader.id] then return end
  local ls = rv.leaderStatus(leader, save)
  if ls == 'nextNight' or ls == 'out' then c.msg(c.t('msg.leader.' .. ls, leader.name), 8) end
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
-- BeamNG (gameplay/speedTraps.lua): onSpeedTrapTriggered(data, playerSpeed m/s, overSpeed) feuert nur, wenn man
-- geblitzt wird (über Limit + Toleranz, in Fahrtrichtung). Nur das zählt. Schlüssel = triggerName.
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


-- Laufende Statistik: Strecke, Höchsttempo, Geld rein/raus ------------------------
local lastMoney = nil
local nickTimer = 0
local function onUpdate(dtReal, dtSim)
  local c = core()
  local save = c.save
  if not c.active or not save then lastMoney = nil; nickTimer = 0; return end
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
  -- Spitznamen für Fahrstil, Strecke und Co. alle paar Sekunden prüfen (Battles prüfen sofort)
  nickTimer = nickTimer + (dtReal or 0)
  if nickTimer >= 3 then
    nickTimer = 0
    M.checkNicknames()
  end
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
      { k = 'stats.services', v = s.services or 0 },
      { k = 'stats.rivalCarsBought', v = s.rivalCarsBought or 0 },
      { k = 'stats.tows', v = s.tows or 0 },
      { k = 'stats.unstucks', v = s.unstucks or 0 },
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
