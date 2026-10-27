-- Hashiriya Battle: Lichthupe, Countdown und SP-Battle
local M = {}

local logTag = 'hashiriya'

-- Einstellungen (zum Feintuning) -------------------------------------------------
local cfg = {
  challengeMaxBehind = 45,  -- m: so weit darf man hinter dem Rivalen sein
  challengeMinBehind = 4,
  challengeMaxLateral = 10, -- m seitlicher Versatz
  challengeMinSpeed = 40 / 3.6,
  countdown = 3,            -- s
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

function M.isBusy()
  return state ~= 'idle'
end

function M.reset()
  state = 'idle'
  battle = nil
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

local function startCountdown(rival, rivalVeh)
  state = 'countdown'
  timer = cfg.countdown
  battle = {
    rival = rival,
    playerSp = cfg.playerMaxSp,
    rivalSp = rival.maxSp or 1000,
    rivalMaxSp = rival.maxSp or 1000,
    lastPlayerDamage = nil,
    lastRivalDamage = nil,
    rivalMode = nil,
    lastCount = nil,
  }
  setWarnSignal(rivalVeh, true)
  core().msg(rival.name .. ' nimmt die Herausforderung an!', 3)
  log('I', logTag, 'Challenge gegen ' .. rival.id)
end

function M.onHighbeam(vehId, value)
  local prev = highbeam[vehId] or 0
  highbeam[vehId] = value
  if not (value > 0 and prev == 0) then return end -- nur beim Einschalten
  if state ~= 'idle' then return end

  local player = core().getPlayerVehicle()
  if not player or player:getID() ~= vehId then return end
  local active = rivals().getActiveRival()
  local rivalVeh = rivals().getRivalVehicle()
  if not active or not rivalVeh then return end
  if playerBehindRival(player, rivalVeh) then
    startCountdown(active.data, rivalVeh)
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
  core().onBattleResult(battle.rival, won)
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
  battle.playerSp = battle.playerSp - damageSp(player:getID(), 'lastPlayerDamage')
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
    won = battle.won,
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

  if state == 'countdown' then
    timer = timer - dtSim
    -- Warnblinker wiederholt setzen, falls die KI ihn wieder ausschaltet
    battle.warnTimer = (battle.warnTimer or 0) - dtSim
    if battle.warnTimer <= 0 then
      battle.warnTimer = 0.5
      setWarnSignal(rivalVeh, true)
    end
    if timer <= 0 then
      setWarnSignal(rivalVeh, false)
      state = 'battle'
      core().msg('BATTLE!', 2)
    end
  elseif state == 'battle' then
    updateBattle(dtSim, player, rivalVeh)
  elseif state == 'result' then
    timer = timer - dtSim
    if timer <= 0 then
      rivals().despawnActive()
      M.reset()
    end
  end

end

M.onUpdate = onUpdate

return M
