-- Hashiriya Battle: Crew-Battles (Alpha 0.9.3)
--  * Begleiter: Leader und Bosse fahren mit 2 Begleitern im Konvoi (Auswahl hier, Spawn in rivals.lua, Kette in battle.lua)
--  * Crew-Taktik: übrige Begleiter / Crew-Mitglieder blocken während des Battles für ihren Leader
--  * Ablehnen: Rivale lehnt deine Lichthupe sichtbar ab (Blinker + Stopp-Zeichen in der Bildschirmmitte)
--  * Wette: Yen-Einsatz vor dem Battle (Angebot beim Tempo-Angleichen)
-- Einstellungen: data/crewbattle.json (im Handbuch unter "Crew-Battles, Ablehnen und Wetten").
local M = {}

local logTag = 'hashiriya.crew'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/crewbattle.json'
local data = nil

local function core() return extensions.hashiriyaBattle_core end
local function rivals() return extensions.hashiriyaBattle_rivals end
local function driver() return extensions.hashiriyaBattle_driver end
local function progress() return extensions.hashiriyaBattle_progress end

-- Grundwerte, falls crewbattle.json fehlt oder ein Wert nicht drinsteht
local defaults = {
  escorts = { enabled = true, leaders = true, bosses = true, count = 2, spacing = 20, ai = 'follow', followExtraKmh = 10,
    chainWaitSeconds = 90, chainStartDistance = 70, chainPauseSeconds = 3,
    mode = 'group', groupEscortSp = 0.6, groupOutGap = 150, groupExtraDrain = 3 },
  blocking = { enabled = true, range = 180, maxHelpers = 2, targetGap = 12, releaseDistance = 320 },
  decline = { enabled = true, chance = { rival = 0.08, leader = 0, wanderer = 0, boss = 0 }, moodCooldown = 90, blinkSeconds = 3.5, showSeconds = 2.6 },
  bet = { enabled = true, minRank = 1, chance = { rival = 0.3, leader = 0.6, wanderer = 0.5, boss = 1.0 }, stakeOfReward = 0.5,
    raise = { 1, 2, 3 }, maxMoneyShare = 0.5, minStake = 5000, round = 1000, offerSeconds = 7 },
}

function M.loadData()
  data = jsonReadFile(dataPath) or {}
  return data
end

-- Einstellungen eines Abschnitts (escorts, blocking, decline, bet) mit Grundwerten
function M.cfg(section)
  if not data then M.loadData() end
  local d = data[section] or {}
  local def = defaults[section] or {}
  return setmetatable({}, { __index = function(_, k) if d[k] ~= nil then return d[k] end return def[k] end })
end

function M.tierOf(rival)
  if not rival then return 'rival' end
  return rival.boss and 'boss' or (rival.leader and 'leader' or (rival.wanderer and 'wanderer' or 'rival'))
end

-- Begleiter -----------------------------------------------------------------------

local function rivalById(id)
  local d = rivals().getData()
  for _, r in ipairs(d and d.rivals or {}) do if r.id == id then return r end end
end

local function shuffle(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

-- Wer begleitet diesen Rivalen? Rückgabe: Liste von Rivalen-Daten (aus rivals.json), höchstens escorts.count.
-- isFree(r) = darf gerade spawnen (nicht schon unterwegs oder an einer PA)
function M.escortsFor(rival, save, isFree)
  local s = M.cfg('escorts')
  if not s.enabled or not rival then return {} end
  local ids = {}
  if type(rival.escorts) == 'table' then
    ids = rival.escorts
  elseif rival.boss and s.bosses then
    local c = rival.conditions or {}
    local teams = c.beatenTeams or (c.beatenTeam and { c.beatenTeam }) or {}
    for _, t in ipairs(teams) do
      local l = rivals().leaderOf(t)
      if l then ids[#ids + 1] = l.id end
    end
    if #ids == 0 then for _, id in ipairs(c.beatenRivals or c.requires or {}) do ids[#ids + 1] = id end end
  elseif rival.leader and s.leaders and rival.team then
    -- erst geschlagene Mitglieder (die kennen dich schon), dann die übrigen
    local beaten, other = {}, {}
    local d = rivals().getData()
    for _, r in ipairs(d and d.rivals or {}) do
      if r.team == rival.team and not r.leader and not r.wanderer and not r.boss then
        table.insert((save and save.defeated and save.defeated[r.id]) and beaten or other, r.id)
      end
    end
    shuffle(beaten); shuffle(other)
    for _, id in ipairs(beaten) do ids[#ids + 1] = id end
    for _, id in ipairs(other) do ids[#ids + 1] = id end
  else
    return {}
  end
  local out = {}
  local list = {}
  for _, id in ipairs(ids) do list[#list + 1] = id end
  -- Bosse: zufällig aus ihren Leadern; feste Listen und Crews behalten ihre Reihenfolge
  if rival.boss and type(rival.escorts) ~= 'table' then shuffle(list) end
  for _, id in ipairs(list) do
    if #out >= (s.count or 2) then break end
    local r = rivalById(id)
    if r and r.id ~= rival.id and (not isFree or isFree(r)) then out[#out + 1] = r end
  end
  return out
end

-- Crew-Taktik: Blocker -----------------------------------------------------------
-- Ein Blocker bekommt den eigenen Fahrer (hashiriyaDriver) mit Blocker-Charakter. Er glaubt, er liege im Rennen
-- vorne (gap > 0), darum macht er dir die Linie zu. Sein Höchsttempo hält ihn knapp vor dir (targetGap).

local helpers = {} -- vehId -> { entry, timer }

local function isHelperFor(e, engaged)
  if not e or not engaged or e == engaged then return false end
  if e.battleOut then return false end -- im Gruppen-Battle ausgeschieden
  if e.data.wanderer or e.data.boss then return false end
  local group = engaged.group
  if group and e.group == group and e.escortOf then
    -- für den Leader/Boss blocken alle Begleiter (auch die schon geschlagenen),
    -- bei einem Begleiter-Battle nur die, die noch nicht dran waren
    if engaged == group.leader then return true end
    return not e.leftGroup
  end
  -- Crew-Mitglieder des Leaders, die gerade sowieso unterwegs sind
  if engaged.data.leader and engaged.data.team and e.data.team == engaged.data.team and not e.data.leader and not e.group then return true end
  return false
end

local function aheadOf(player, veh)
  local dir = player:getDirectionVector()
  return (veh:getPosition() - player:getPosition()):dot(dir)
end

local function startHelper(e, veh, player)
  local d = {}
  for k, v in pairs(e.data) do d[k] = v end
  d.character = 'blocker'
  driver().start(veh, d, player:getID())
  veh:queueLuaCommand('if hashiriyaDriver then hashiriyaDriver.setParams({blockMinAggression=0,blockCooldown=1.5,tacticsRate=0}) end')
  helpers[veh:getID()] = { entry = e, timer = 0 }
  log('I', logTag, 'Blockt für den Leader: ' .. tostring(e.data.id))
end

local function stopHelper(id, h)
  local veh = be:getObjectByID(id)
  helpers[id] = nil
  if veh then
    driver().stop(veh)
    if h and h.entry then rivals().resume(h.entry) end
  end
end

function M.releaseHelpers()
  for id, h in pairs(helpers) do stopHelper(id, h) end
end

-- zählt nur echte Blocker; Begleiter im Gruppen-Battle (racer) haben eine eigene SP-Leiste
function M.helperCount()
  local n = 0
  for _, h in pairs(helpers) do if not h.racer then n = n + 1 end end
  return n
end

-- Gruppen-Battle (JDMArsch 09.11.2026): Begleiter fahren gleichzeitig mit dem Leader gegen dich.
-- Sie fahren wie Blocker (knapp vor dir, Linie zu), werden aber nicht wegen Entfernung freigegeben.
function M.addRacer(e, player)
  local veh = e and be:getObjectByID(e.vehId)
  if not veh or not player then return false end
  if not helpers[e.vehId] then startHelper(e, veh, player) end
  if helpers[e.vehId] then helpers[e.vehId].racer = true end
  return true
end

function M.dropRacer(e)
  if e and helpers[e.vehId] then stopHelper(e.vehId, helpers[e.vehId]) end
end

-- jedes Frame im Battle: Blocker suchen, steuern und wieder freigeben
function M.updateHelpers(dt, player, engaged)
  local s = M.cfg('blocking')
  if not player or not engaged then M.releaseHelpers(); return end
  -- laufende Blocker steuern
  for id, h in pairs(helpers) do
    local veh = be:getObjectByID(id)
    if not veh or driver().hasFailed(id) or (not h.racer and (not s.enabled or not isHelperFor(h.entry, engaged))) then
      stopHelper(id, h)
    else
      local dist = (veh:getPosition() - player:getPosition()):length()
      if not h.racer and dist > (s.releaseDistance or 320) then
        stopHelper(id, h)
      else
        h.timer = h.timer - dt
        if h.timer <= 0 then
          h.timer = 0.4
          local ahead = aheadOf(player, veh)
          local pv = player:getVelocity():length()
          local vmax = 95
          if ahead > -6 then
            vmax = math.max(pv + math.max(-6, math.min(4, ((s.targetGap or 12) - ahead) * 0.3)), 5)
          end
          veh:queueLuaCommand(string.format('if hashiriyaDriver then hashiriyaDriver.setRace({gap=%.1f,ownSp=1,otherSp=1}) hashiriyaDriver.setParams({maxSpeed=%.2f}) end', ahead, vmax))
        end
      end
    end
  end
  -- neue Blocker in der Nähe
  if not s.enabled then return end
  if M.helperCount() >= (s.maxHelpers or 2) then return end
  for _, e in ipairs(rivals().getOnRoad()) do
    if M.helperCount() >= (s.maxHelpers or 2) then break end
    if not helpers[e.vehId] and isHelperFor(e, engaged) then
      local veh = be:getObjectByID(e.vehId)
      if veh and (veh:getPosition() - player:getPosition()):length() < (s.range or 180) then startHelper(e, veh, player) end
    end
  end
end

-- Ablehnen ------------------------------------------------------------------------

local blinks = {}      -- { vehId, side, t }
local lastDecline = {} -- vehId -> os.clock() der letzten Anzeige

-- Lehnt der Rivale deine Lichthupe ab? Rückgabe: Grund (cooldown | nightDone | mood) oder nil
function M.declineReason(e)
  local s = M.cfg('decline')
  if e.cooldown then return 'cooldown' end
  if not s.enabled then return nil end
  local left = rivals().battlesLeftTonight()
  if left and left <= 0 then return 'nightDone' end
  if e.data.paChallenge then return nil end
  local chance = (s.chance or {})[M.tierOf(e.data)] or 0
  if chance > 0 and math.random() < chance then
    e.cooldown = s.moodCooldown or 90
    e.moodDeclined = true
    return 'mood'
  end
  return nil
end

-- Blinker links/rechts (BeamNG 0.40 electrics.lua: set_left_signal/set_right_signal, Zustand in values.turnsignal
-- -1 = links, 1 = rechts, 0 = aus). Die Verkehrs-KI schaltet Blinker bei Spurwechseln selbst aus, darum setzt
-- M.tick ihn während der Ablehnung jede Sekunde neu, falls er weg ist.
local function setSignal(veh, side, on)
  local want = on and (side == 'left' and -1 or 1) or 0
  veh:queueLuaCommand(string.format([[
    if (electrics.values.turnsignal or 0) ~= %d then
      local f = electrics.set_%s_signal
      if f then f(%s)
      elseif electrics.toggle_%s_signal then electrics.toggle_%s_signal() end
    end
  ]], want, side, tostring(on), side, side))
end

-- Stopp-Zeichen in der Bildschirmmitte (App HashiriyaSpHud, Hook HashiriyaBattleFx)
function M.showFx(kind, who, name, text)
  guihooks.trigger('HashiriyaBattleFx', { kind = kind, who = who, name = name, text = text, ttl = M.cfg('decline').showSeconds or 2.6 })
end

-- Rivale lehnt sichtbar ab: Blinker links oder rechts + Stopp-Zeichen. Höchstens alle 3 s pro Rivale.
function M.showDecline(e, reason)
  local veh = e and be:getObjectByID(e.vehId)
  if not veh then return end
  local now = os.clock()
  if lastDecline[e.vehId] and now - lastDecline[e.vehId] < 3 then return end
  lastDecline[e.vehId] = now
  local side = math.random() < 0.5 and 'left' or 'right'
  veh:queueLuaCommand('electrics.set_warn_signal(false)')
  setSignal(veh, side, true)
  table.insert(blinks, { vehId = e.vehId, side = side, t = M.cfg('decline').blinkSeconds or 3.5 })
  local c = core()
  local key = e.moodDeclined and reason == 'cooldown' and 'mood' or reason
  M.showFx('decline', 'rival', e.data.name, c.t('fx.decline.' .. tostring(key)))
  c.sound('declined')
  log('I', logTag, 'Rivale lehnt ab: ' .. tostring(e.data.id) .. ' (' .. tostring(reason) .. ')')
end

-- jedes Frame (von battle.lua): Blinker nach der Ablehnung wieder aus
function M.tick(dt)
  for i = #blinks, 1, -1 do
    local b = blinks[i]
    b.t = b.t - dt
    b.refresh = (b.refresh or 1) - dt
    if b.t > 0 and b.refresh <= 0 then
      b.refresh = 1
      local veh = be:getObjectByID(b.vehId)
      if veh then setSignal(veh, b.side, true) end
    end
    if b.t <= 0 then
      local veh = be:getObjectByID(b.vehId)
      if veh then setSignal(veh, b.side, false) end
      table.remove(blinks, i)
    end
  end
end

-- Wette ---------------------------------------------------------------------------

local function roundTo(x, step)
  step = math.max(step or 1000, 1)
  return math.floor(x / step) * step
end

-- Preisgeld des Rivalen in Yen (wie core.onBattleResult, ohne Serien-Bonus)
local function rewardYen(rival)
  local exact = tonumber(rival.rewardYen)
  if exact and exact > 0 then return exact end
  local rs = rivals().getData()
  local scale = tonumber(rs and rs.settings and rs.settings.rewardScale) or 1
  return core().economy().usdToPrice(rival.rewardUsd or 1000) * scale
end

-- Bietet der Rivale eine Wette an? Rückgabe: Wett-Tabelle oder nil
function M.betOffer(rival)
  local s = M.cfg('bet')
  local save = core().save
  if not s.enabled or not save or not rival or rival.pinkSlip then return nil end
  if progress().rankIndex(save) < (s.minRank or 0) then return nil end
  local chance = (s.chance or {})[M.tierOf(rival)] or 0
  if math.random() >= chance then return nil end
  local cap = roundTo((save.money or 0) * (s.maxMoneyShare or 0.5), s.round)
  local base = math.min(roundTo(rewardYen(rival) * (s.stakeOfReward or 0.5), s.round), cap)
  if base < (s.minStake or 0) or base <= 0 then return nil end
  return { base = base, stake = base, step = 1, cap = cap, offer = true, timer = s.offerSeconds or 7 }
end

-- Lichthupe beim Angebot: nächste Einsatz-Stufe (am Ende wieder von vorn)
function M.raiseBet(bet)
  local s = M.cfg('bet')
  local steps = s.raise or { 1, 2, 3 }
  bet.step = bet.step % #steps + 1
  -- höchstens maxMoneyShare deines Geldes (cap); passt eine Stufe nicht mehr, bleibt es beim Höchstbetrag
  bet.stake = math.max(math.min(roundTo(bet.base * (steps[bet.step] or 1), s.round), bet.cap), bet.base)
  bet.timer = math.max(bet.timer, 3)
end

-- Nach dem Battle: Einsatz gewinnen oder verlieren
function M.settleBet(bet, won, rivalName)
  local c = core()
  if not bet or not bet.accepted or not c.save then return end
  local eco = c.economy()
  if won then
    c.save.money = (c.save.money or 0) + bet.stake
    c.msg(c.t('msg.betWon', eco.formatYen(bet.stake), rivalName or ''), 6)
  else
    c.save.money = math.max((c.save.money or 0) - bet.stake, 0)
    c.msg(c.t('msg.betLost', eco.formatYen(bet.stake), rivalName or ''), 6)
  end
  c.writeSave()
  log('I', logTag, string.format('Wette %s: %d Yen', won and 'gewonnen' or 'verloren', bet.stake))
end

function M.formatYen(v) return core().economy().formatYen(v) end

local function onExtensionLoaded() M.loadData() end
M.onExtensionLoaded = onExtensionLoaded

return M
