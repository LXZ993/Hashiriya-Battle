-- Hashiriya Battle: Lichthupe, Countdown und SP-Battle
local M = {}

local logTag = 'hashiriya'

-- Einstellungen (zum Feintuning) -------------------------------------------------
local cfg = {
  challengeMaxBehind = 30,  -- m: so weit darf man hinter dem Rivalen sein
  challengeMinBehind = 4,
  challengeMaxLateral = 10, -- m seitlicher Versatz
  challengeMinSpeed = 40 / 3.6,
  countdown = 3,            -- s
  maxChallengeDiffKmh = 30, -- km/h: größerer Tempounterschied zum Rivalen = Herausfordern nicht möglich
  syncToleranceKmh = 5,     -- so nah am Battle-Tempo, dann startet der Countdown
  syncTimeout = 25,         -- s: spätestens dann startet der Countdown trotzdem
  syncMaxGap = 18,          -- m Mitte zu Mitte (ca. 4-5 m Autolänge enthalten): Countdown erst, wenn man so nah dran ist
  syncTargetGap = 13,       -- m Mitte zu Mitte: bis hierhin holt der Tempomat beim Angleichen auf
  syncCatchUpKmh = 25,      -- km/h: so viel schneller als der Rivale fährt man beim Aufholen höchstens
  syncCatchUpPerMeter = 1.5,-- km/h mehr pro Meter über syncTargetGap
  falseStartGap = 3,        -- m: so viel näher am Rivalen als beim Herausfordern = Frühstart
  falseStartKmh = 10,       -- km/h über dem Tempomat-Tempo = Frühstart
  playerMaxSp = 1000,
  drainBase = 8,            -- SP/s, die der Hintere immer verliert
  drainPerMeter = 0.25,     -- zusätzliche SP/s pro Meter Abstand
  drainMax = 80,            -- SP/s Obergrenze
  spPerDamage = 0.02,       -- Sim: SP-Verlust pro Schadenspunkt (BeamNG-Schadenswert)
  maxDamageSpPerTick = 150,
  winGap = 250,             -- m Vorsprung = Sofortsieg
  modeSwitchHysteresis = 10,-- m, bevor die Gegner-KI zwischen Flucht und Jagd wechselt
  resultTime = 6,           -- s bis der Rivale nach dem Battle verschwindet
}
M.cfg = cfg

-- Zustand: idle | countdown | battle | result
local state = 'idle'
local timer = 0
local battle = nil
local highbeam = {}       -- vehId -> letzter Fernlicht-Wert
local pollTimer = 0

local function core() return extensions.hashiriyaBattle_core end
local function rivals() return extensions.hashiriyaBattle_rivals end

function M.getState() return state end

function M.isBusy()
  return state ~= 'idle'
end

-- Countdown: Tempomat beim Spieler (übersteuert das Gaspedal), der Rivale fährt dasselbe Tempo.
local function lockPlayerSpeed(veh, speed)
  veh:queueLuaCommand(string.format([[
    if not extensions.cruiseControl then extensions.load('cruiseControl') end
    if extensions.cruiseControl then extensions.cruiseControl.setSpeed(%f) extensions.cruiseControl.setEnabled(true) end
  ]], speed))
end

local function releasePlayerSpeed()
  local veh = core().getPlayerVehicle()
  if veh then veh:queueLuaCommand('if extensions.cruiseControl then extensions.cruiseControl.setEnabled(false) end') end
end

function M.reset()
  if state == 'countdown' or state == 'sync' then releasePlayerSpeed() end
  state = 'idle'
  battle = nil
  if rivals() and rivals().disengage then rivals().disengage() end
end

-- Lichthupe ---------------------------------------------------------------------
-- Das Fahrzeug-Lua meldet uns seinen Fernlicht-Zustand; wir reagieren auf "an".

local function pollHighbeam(veh)
  veh:queueLuaCommand(string.format(
    "obj:queueGameEngineLua('hashiriyaBattle_battle.onHighbeam(%d,' .. tostring(electrics.values.highbeam or 0) .. ')')",
    veh:getID()))
end

local function playerBehindRival(player, rivalVeh)
  local rd = rivalVeh:getDirectionVector()
  local rel = player:getPosition() - rivalVeh:getPosition()
  local along = rel:dot(rd)
  local lateral = math.sqrt(math.max(rel:squaredLength() - along * along, 0))
  return along <= -cfg.challengeMinBehind and along >= -cfg.challengeMaxBehind
    and lateral <= cfg.challengeMaxLateral
    and player:getVelocity():length() >= cfg.challengeMinSpeed
end

local function setWarnSignal(veh, on)
  veh:queueLuaCommand('electrics.set_warn_signal(' .. tostring(on) .. ')')
end

-- Schaltet den Warnblinker nur ein, wenn er gerade aus ist. Ein erneutes Setzen bei laufendem
-- Blinker setzt den Blinktakt zurück, dann leuchtet er dauerhaft statt zu blinken.
local function ensureWarnSignal(veh)
  veh:queueLuaCommand('if (electrics.values.hazard_enabled or 0) == 0 then electrics.set_warn_signal(true) end')
end

-- Diagnose: meldet, ob der Warnblinker beim Rivalen wirklich an ist.
local function logWarnSignal(veh)
  veh:queueLuaCommand([[
    local v = electrics.values
    obj:queueGameEngineLua(string.format('log(%q, %q, %q)', 'I', 'hashiriya',
      'Warnblinker Rivale: hazard_enabled=' .. tostring(v.hazard_enabled) .. ' hazard=' .. tostring(v.hazard)
      .. ' signal_L=' .. tostring(v.signal_L) .. ' signal_R=' .. tostring(v.signal_R)))
  ]])
end

local function vehicleDisplayName(model)
  local ok, info = pcall(core_vehicles.getModel, model)
  if ok and info and info.model then
    local m = info.model
    return ((m.Brand and m.Brand ~= '') and (m.Brand .. ' ') or '') .. (m.Name or model)
  end
  return model
end

-- Erst Tempo angleichen (Tempomat auf das Tempo des Rivalen), dann Countdown
local function startCountdown(rival, rivalVeh)
  state = 'sync'
  timer = cfg.syncTimeout
  battle = {
    rival = rival,
    playerSp = cfg.playerMaxSp,
    rivalSp = rival.maxSp or 1000,
    rivalMaxSp = rival.maxSp or 1000,
    lastPlayerDamage = nil,
    lastRivalDamage = nil,
    rivalMode = nil,
    lastCount = nil,
    time = 0,
    rivalCar = vehicleDisplayName(rival.model),
  }
  local save = core().save
  local car = save and save.cars[save.activeCar or 1]
  battle.playerCar = car and car.name or ''
  setWarnSignal(rivalVeh, true)
  local player = core().getPlayerVehicle()
  if player then
    local speed = math.max(rivalVeh:getVelocity():length(), (rival.cruiseKmh or 100) / 3.6 * 0.9)
    battle.lockSpeed = speed
    battle.rivalSpeed = speed
    lockPlayerSpeed(player, speed)
    rivalVeh:queueLuaCommand(string.format("ai.setSpeedMode('set') ai.setSpeed(%f)", speed))
  end
  core().msg(core().t('msg.challenge', rival.name), 3)
  log('I', logTag, 'Challenge gegen ' .. rival.id)
end

function M.onHighbeam(vehId, value)
  local prev = highbeam[vehId] or 0
  highbeam[vehId] = value
  if not (value > 0 and prev == 0) then return end -- nur beim Einschalten
  if state ~= 'idle' then return end

  local player = core().getPlayerVehicle()
  if not player or player:getID() ~= vehId then return end
  -- den Rivalen herausfordern, hinter dem man gerade fährt
  for _, e in ipairs(rivals().getOnRoad()) do
    local rivalVeh = be:getObjectByID(e.vehId)
    if rivalVeh and not e.cooldown and playerBehindRival(player, rivalVeh) then
      local diff = (player:getVelocity():length() - rivalVeh:getVelocity():length()) * 3.6
      if math.abs(diff) > cfg.maxChallengeDiffKmh then
        core().msg(core().t(diff > 0 and 'msg.tooFast' or 'msg.tooSlow'), 2)
        return
      end
      rivals().engage(e)
      startCountdown(rivals().challengeData(e), rivalVeh)
      return
    end
  end
end

-- SP-Battle -------------------------------------------------------------------------

local function getDamage(vehId)
  local o = map.objects[vehId]
  return o and o.damage or 0
end

-- Positiver Wert = Rivale liegt vorne.
local function getGap(player, rivalVeh)
  local dir = (player:getDirectionVector() + rivalVeh:getDirectionVector()):normalized()
  return (rivalVeh:getPosition() - player:getPosition()):dot(dir)
end

local function setRivalAi(rivalVeh, mode)
  if battle.rivalMode == mode then return end
  battle.rivalMode = mode
  local player = core().getPlayerVehicle()
  rivalVeh:queueLuaCommand(string.format(
    "ai.setSpeedMode('off') ai.setAggression(%f) ai.setAvoidCars('on') ai.setTargetObjectID(%d) ai.setMode('%s')",
    battle.rival.aggression or 0.6, player:getID(), mode))
end

local function finishBattle(won)
  state = 'result'
  timer = cfg.resultTime
  battle.won = won
  local rivalVeh = rivals().getRivalVehicle()
  if rivalVeh then
    setWarnSignal(rivalVeh, false)
    rivals().setCruise(rivalVeh, battle.rival)
  end
  core().onBattleResult(battle.rival, won, {
    time = battle.time, playerSp = battle.playerSp, playerMaxSp = cfg.playerMaxSp, damageSp = battle.damageTaken or 0 })
end

local function damageSp(vehId, lastKey)
  local dmg = getDamage(vehId)
  local last = battle[lastKey] or dmg
  battle[lastKey] = dmg
  return math.min(math.max(dmg - last, 0) * cfg.spPerDamage, cfg.maxDamageSpPerTick)
end

local function updateBattle(dt, player, rivalVeh)
  local gap = getGap(player, rivalVeh)
  battle.gap = gap

  -- Gegner-KI: vorne -> flüchten, hinten -> jagen
  if gap > cfg.modeSwitchHysteresis then
    setRivalAi(rivalVeh, 'flee')
  elseif gap < -cfg.modeSwitchHysteresis then
    setRivalAi(rivalVeh, 'chase')
  elseif not battle.rivalMode then
    setRivalAi(rivalVeh, gap >= 0 and 'flee' or 'chase')
  end

  -- Wer hinten liegt, verliert SP
  local drain = math.min(cfg.drainBase + math.abs(gap) * cfg.drainPerMeter, cfg.drainMax) * dt
  if gap > 0 then
    battle.playerSp = battle.playerSp - drain
  else
    battle.rivalSp = battle.rivalSp - drain
  end

  -- Sim: Schaden kostet zusätzlich SP
  local taken = damageSp(player:getID(), 'lastPlayerDamage')
  battle.damageTaken = (battle.damageTaken or 0) + taken
  battle.playerSp = battle.playerSp - taken
  battle.rivalSp = battle.rivalSp - damageSp(rivalVeh:getID(), 'lastRivalDamage')

  if battle.playerSp <= 0 or gap > cfg.winGap then
    battle.playerSp = math.max(battle.playerSp, 0)
    finishBattle(false)
  elseif battle.rivalSp <= 0 or gap < -cfg.winGap then
    battle.rivalSp = math.max(battle.rivalSp, 0)
    finishBattle(true)
  end
end

-- HUD-Daten für die UI-App ------------------------------------------------------------

function M.getHudState()
  if not battle then return nil end
  return {
    state = state,
    rivalName = battle.rival.name,
    playerSp = math.max(math.floor(battle.playerSp), 0),
    playerMaxSp = cfg.playerMaxSp,
    rivalSp = math.max(math.floor(battle.rivalSp), 0),
    rivalMaxSp = battle.rivalMaxSp,
    gap = battle.gap and math.floor(battle.gap) or 0,
    countdown = state == 'countdown' and math.ceil(timer) or nil,
    syncing = state == 'sync' or nil,
    won = battle.won,
    time = battle.time,
    playerCar = battle.playerCar,
    rivalCar = battle.rivalCar,
    rivalTag = battle.rival.boss and 'boss' or (battle.rival.leader and 'leader' or (battle.rival.wanderer and 'wanderer' or 'rival')),
    rivalNick = extensions.hashiriyaBattle_progress.loc(battle.rival.nick),
    playerTitle = extensions.hashiriyaBattle_progress.nickname() or extensions.hashiriyaBattle_progress.rankName(),
  }
end

-- Update ----------------------------------------------------------------------------

local function onUpdate(dtReal, dtSim)
  local c = core()
  if not c or not c.active then return end
  local player = c.getPlayerVehicle()
  if not player then return end

  -- Fernlicht des Spielers 10x pro Sekunde abfragen
  pollTimer = pollTimer - dtReal
  if pollTimer <= 0 then
    pollTimer = 0.1
    pollHighbeam(player)
  end

  if state == 'idle' then return end

  local rivalVeh = rivals().getRivalVehicle()
  if not rivalVeh then M.reset(); return end

  if state == 'sync' or state == 'countdown' then
    -- Der BeamNG-Tempomat schaltet sich beim Bremsen ab: regelmäßig wieder einschalten
    battle.relock = (battle.relock or 0.5) - dtSim
    if battle.relock <= 0 then
      battle.relock = 0.5
      player:queueLuaCommand(string.format('if extensions.cruiseControl then extensions.cruiseControl.setSpeed(%f) extensions.cruiseControl.setEnabled(true) end', battle.lockSpeed))
    end
  end

  if state == 'sync' then
    -- Tempo angleichen: Tempomat gibt Gas bzw. lässt ausrollen (er bremst nicht), dann startet der Countdown
    timer = timer - dtSim
    local gap = getGap(player, rivalVeh)
    if gap < 2 then -- in der Angleich-Phase überholt = Frühstart
      setWarnSignal(rivalVeh, false)
      core().msg(core().t('msg.falseStart', battle.rival.name), 4)
      M.reset()
      return
    end
    -- Zu weit weg: Tempomat etwas schneller als der Rivale, bis man auf syncTargetGap dran ist
    local catchUp = math.min(cfg.syncCatchUpKmh, math.max(0, gap - cfg.syncTargetGap) * cfg.syncCatchUpPerMeter) / 3.6
    battle.lockSpeed = battle.rivalSpeed + catchUp
    local diff = math.abs(player:getVelocity():length() - battle.rivalSpeed) * 3.6
    if (gap <= cfg.syncMaxGap and diff <= cfg.syncToleranceKmh) or timer <= 0 then
      state = 'countdown'
      timer = cfg.countdown
      battle.startGap = gap
      battle.lockSpeed = math.max(battle.rivalSpeed, math.min(player:getVelocity():length(), battle.rivalSpeed + cfg.syncToleranceKmh / 3.6))
      battle.relock = 0
    end
    return
  end

  if state == 'countdown' then
    timer = timer - dtSim
    local count = math.ceil(timer)
    if count ~= battle.beep and count > 0 then
      battle.beep = count
      core().sound('countdown')
    end
    -- Warnblinker prüfen und nur bei Bedarf wieder einschalten (falls die KI ihn ausschaltet)
    battle.warnTimer = (battle.warnTimer or 1) - dtSim
    if battle.warnTimer <= 0 then
      battle.warnTimer = 1
      ensureWarnSignal(rivalVeh)
      if not battle.warnLogged and timer < cfg.countdown - 1 then
        battle.warnLogged = true
        logWarnSignal(rivalVeh)
      end
    end
    -- Frühstart: vorgefahren oder schneller als der Tempomat
    local gap = getGap(player, rivalVeh)
    if battle.startGap and (gap < battle.startGap - cfg.falseStartGap
        or player:getVelocity():length() > battle.lockSpeed + cfg.falseStartKmh / 3.6) then
      setWarnSignal(rivalVeh, false)
      core().msg(core().t('msg.falseStart', battle.rival.name), 4)
      log('I', logTag, 'Frühstart gegen ' .. tostring(battle.rival.id))
      M.reset()
      return
    end
    if timer <= 0 then
      setWarnSignal(rivalVeh, false)
      releasePlayerSpeed()
      state = 'battle'
      core().msg(core().t('msg.battle'), 2)
    end
  elseif state == 'battle' then
    battle.time = battle.time + dtSim
    updateBattle(dtSim, player, rivalVeh)
  elseif state == 'result' then
    timer = timer - dtSim
    if timer <= 0 then
      -- der Rivale fährt weiter (TXR-Stil); geschlagen = später Revanche möglich
      M.reset()
    end
  end

end

M.onUpdate = onUpdate

return M
