-- Hashiriya Battle: Lichthupe, Countdown und SP-Battle
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

-- Einstellungen (zum Feintuning) -------------------------------------------------
local cfg = {
  challengeMaxBehind = 30,  -- m: so weit darf man hinter dem Rivalen sein
  challengeMinBehind = 4,
  challengeMaxLateral = 10, -- m seitlicher Versatz
  challengeMinSpeed = 40 / 3.6,
  countdown = 5,            -- s, startet erst, wenn der Spruch des Rivalen ausgeblendet ist
  challengeQuoteTime = 6,   -- s: so lange steht der Spruch beim Herausfordern, erst danach kommt der Countdown
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
  resultTime = 9,           -- s Ergebnis und Spruch nach dem Battle, dann fährt der Rivale weiter
  -- KI des Rivalen im Battle:
  --  'fleeGuard' = vorne BeamNG-Flucht-KI (zügig, weicht seitlich aus) plus eigener Bremsschutz (siehe guard*),
  --                hinten 'span' mit eigenem Gummiband (Standard)
  --  'span'    = freie Fahrt ohne Tempolimit und Spurzwang: weicht aus, bremst nur wenn nötig, überholt zügig
  --  'traffic' = Verkehrsmodus ohne Tempolimit: sehr vorsichtig, bremst oft mitten im Überholen
  --  'pursuit' = BeamNG flee (vorne) / chase (hinten): flee bremst nicht für Verkehr, chase rammt dich von hinten
  rivalAiMode = 'fleeGuard',
  -- Bremsschutz für die Flucht-KI (BeamNG lässt sie wegen anderer Autos nie bremsen, nur seitlich ausweichen):
  -- steht ein langsameres Auto in seiner Spur voraus und würde er in weniger als guardTtc Sekunden auffahren,
  -- wird sein Tempo kurz auf das des Vordermanns begrenzt
  guardTtc = 1.6,           -- s bis zum Aufprall, ab dann bremsen
  guardLateral = 2.2,       -- m seitlicher Abstand Mitte zu Mitte, ab dem ein Auto "in der Spur" ist
  guardLookAhead = 90,      -- m so weit schaut er nach vorne
  guardHold = 0.8,          -- s Begrenzung bleibt mindestens so lange
  guardSpeedMargin = 1.5,   -- m/s langsamer als der Vordermann, damit die Lücke wieder aufgeht
  -- Gummiband für 'span': Aggression = Grundwert des Rivalen, vorne bis rubberAhead weniger, hinten bis rubberBehind mehr
  rubberAhead = 0.25,       -- weniger Aggression bei rubberDist m Vorsprung
  rubberBehind = 0.3,       -- mehr Aggression bei rubberDist m Rückstand
  rubberDist = 200,
  -- Rivale fordert dich heraus (er fährt hinter dir und gibt Lichthupe)
  rivalChallenge = true,
  rivalChallengeMinBehind = 6,   -- m
  rivalChallengeMaxBehind = 30,  -- m
  rivalChallengeTail = 4,        -- s so lange muss er schon hinter dir fahren
  rivalChallengeChance = 0.3,    -- Chance je Prüfung (alle 2 s), sobald er lange genug hinter dir ist
  rivalChallengeOffer = 8,       -- s Zeit zum Annehmen (Warnblinker) oder Ablehnen (Blinker)
  rivalChallengePause = 45,      -- s Pause nach einem Angebot, bevor wieder einer fragt
  rivalChallengeDeclined = 180,  -- s fragt derselbe Rivale nach einem Nein nicht noch mal
}
M.cfg = cfg

-- Zustand: idle | countdown | battle | result
local state = 'idle'
local timer = 0
local battle = nil
local highbeam = {}       -- vehId -> letzter Fernlicht-Wert
local signals = {}        -- vehId -> { hazard, left, right } letzter Stand
local offer = nil         -- Herausforderung durch einen Rivalen: { entry, vehId, timer }
local tail = {}           -- vehId -> s, die der Rivale schon hinter dem Spieler fährt
local declined = {}       -- vehId -> s Sperre nach Ablehnen
local offerPause = 0
local offerCheck = 0
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

-- cooldown (optional): Sekunden bis derselbe Rivale wieder herausgefordert werden kann
local function falseStartCooldown()
  local d = rivals() and rivals().getSettings and rivals().getSettings() or {}
  return d.falseStartRechallengeSeconds or 30
end

function M.reset(cooldown)
  offer = nil
  if state == 'countdown' or state == 'sync' then releasePlayerSpeed() end
  state = 'idle'
  battle = nil
  if rivals() and rivals().disengage then rivals().disengage(cooldown) end
end

-- Lichthupe ---------------------------------------------------------------------
-- Das Fahrzeug-Lua meldet uns seinen Fernlicht-Zustand; wir reagieren auf "an".

local function pollHighbeam(veh)
  veh:queueLuaCommand(string.format([[
    local v = electrics.values
    local function b(x) return (x == true or (tonumber(x) or 0) > 0) and 1 or 0 end
    obj:queueGameEngineLua('hashiriyaBattle_battle.onLights(%d,' .. tostring(v.highbeam or 0) .. ',' .. b(v.hazard_enabled)
      .. ',' .. b(v.signal_left_input) .. ',' .. b(v.signal_right_input) .. ')')
  ]], veh:getID()))
end

-- Rivale fährt hinter dem Spieler (für seine Herausforderung)
local function rivalBehindPlayer(player, rivalVeh)
  local pd = player:getDirectionVector()
  local rel = rivalVeh:getPosition() - player:getPosition()
  local along = rel:dot(pd)
  local lateral = math.sqrt(math.max(rel:squaredLength() - along * along, 0))
  return along <= -cfg.rivalChallengeMinBehind and along >= -cfg.rivalChallengeMaxBehind
    and lateral <= cfg.challengeMaxLateral
    and player:getVelocity():length() >= cfg.challengeMinSpeed
    and rivalVeh:getDirectionVector():dot(pd) > 0.8
end

local function flashLights(veh)
  -- zweimal kurz Lichthupe
  veh:queueLuaCommand('electrics.light_flash_highbeams(true)')
  offer.flash = { 0.25, 0.5, 0.75 }
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
local function startCountdown(rival, rivalVeh, playerAhead)
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
    quoteLeft = (type(rival.lines) == 'table' and extensions.hashiriyaBattle_progress.loc(rival.lines.challenge) ~= '') and cfg.challengeQuoteTime or 0,
    time = 0,
    rivalCar = vehicleDisplayName(rival.model),
    playerAhead = playerAhead or nil,
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

local function endOffer(answer)
  if not offer then return end
  local o = offer
  offer = nil
  offerPause = cfg.rivalChallengePause
  local c = core()
  local rivalVeh = be:getObjectByID(o.vehId)
  if answer == 'accept' and rivalVeh and state == 'idle' then
    rivals().engage(o.entry)
    startCountdown(rivals().challengeData(o.entry), rivalVeh, true)
    return
  end
  declined[o.vehId] = cfg.rivalChallengeDeclined
  if answer == 'decline' then c.msg(c.t('msg.rivalDeclined', o.entry.data.name), 3) end
end

function M.getOffer()
  if not offer then return nil end
  return { name = offer.entry.data.name, timer = math.ceil(offer.timer) }
end

function M.onLights(vehId, hb, hazard, left, right)
  M.onHighbeam(vehId, hb)
  local prev = signals[vehId] or { hazard = hazard, left = left, right = right }
  signals[vehId] = { hazard = hazard, left = left, right = right }
  if not offer then return end
  local player = core().getPlayerVehicle()
  if not player or player:getID() ~= vehId then return end
  if hazard == 1 and prev.hazard == 0 then endOffer('accept')
  elseif hazard == 0 and ((left == 1 and prev.left == 0) or (right == 1 and prev.right == 0)) then endOffer('decline') end
end

-- Rivalen hinter dem Spieler beobachten; wer lange genug dranbleibt, fordert per Lichthupe heraus
local function updateRivalChallenge(dt, player)
  for id, t in pairs(declined) do
    declined[id] = t - dt
    if declined[id] <= 0 then declined[id] = nil end
  end
  if offer then
    offer.timer = offer.timer - dt
    local rivalVeh = be:getObjectByID(offer.vehId)
    if offer.flash then
      offer.flashT = (offer.flashT or 0) + dt
      local nextT = offer.flash[1]
      if nextT and offer.flashT >= nextT and rivalVeh then
        table.remove(offer.flash, 1)
        rivalVeh:queueLuaCommand('electrics.light_flash_highbeams(' .. tostring(#offer.flash % 2 == 1) .. ')')
        if #offer.flash == 0 then offer.flash = nil end
      end
    end
    if offer.timer <= 0 or not rivalVeh then endOffer('timeout') end
    return
  end
  if not cfg.rivalChallenge or not extensions.hashiriyaBattle_home.isNight() then return end
  offerPause = math.max(0, offerPause - dt)
  offerCheck = offerCheck - dt
  if offerCheck > 0 then return end
  offerCheck = 0.5
  for _, e in ipairs(rivals().getOnRoad()) do
    local rivalVeh = be:getObjectByID(e.vehId)
    if rivalVeh and not e.cooldown and not declined[e.vehId] and rivalBehindPlayer(player, rivalVeh) then
      tail[e.vehId] = (tail[e.vehId] or 0) + 0.5
      if offerPause <= 0 and tail[e.vehId] >= cfg.rivalChallengeTail then
        tail[e.vehId] = cfg.rivalChallengeTail - 2 -- nächster Versuch frühestens in 2 s
        if math.random() < cfg.rivalChallengeChance then
          local c = core()
          offer = { entry = e, vehId = e.vehId, timer = cfg.rivalChallengeOffer }
          flashLights(rivalVeh)
          c.sound('challenge')
          c.msg(c.t('msg.rivalChallenge', e.data.name), cfg.rivalChallengeOffer)
          log('I', logTag, 'Rivale fordert heraus: ' .. tostring(e.data.id))
          return
        end
      end
    else
      tail[e.vehId] = nil
    end
  end
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

local function spanCommand(playerId)
  return string.format(
    "ai.setAvoidCars('on') ai.setTargetObjectID(%d) ai.setMode('span') ai.setSpeedMode('off') ai.driveInLane('off') ai.setAggressionMode('off') ai.setAggression(%f)",
    playerId, battle.rubberAggr or battle.rival.aggression or 0.6)
end

local function setRivalAi(rivalVeh, mode)
  if battle.rivalMode == mode then return end
  battle.rivalMode = mode
  local player = core().getPlayerVehicle()
  if cfg.rivalAiMode == 'fleeGuard' then
    battle.guardSpeed, battle.guardHold = nil, 0
    if mode == 'flee' then
      -- vorne: Flucht-KI mit BeamNG-Gummiband, Bremsschutz läuft in updateGuard
      battle.spanAi = false
      rivalVeh:queueLuaCommand(string.format(
        "ai.setAvoidCars('on') ai.setTargetObjectID(%d) ai.setMode('flee') ai.setSpeedMode('off') ai.driveInLane('off') ai.setAggressionMode('rubberBand') ai.setAggression(%f)",
        player:getID(), battle.rival.aggression or 0.6))
    else
      -- hinten: span (bremst selbst für Verkehr, rammt nicht) mit eigenem Gummiband
      battle.spanAi = true
      battle.rubberTimer = 0
      rivalVeh:queueLuaCommand(spanCommand(player:getID()))
    end
    return
  end
  if cfg.rivalAiMode == 'span' then
    -- gilt vorne und hinten gleich: nur einmal setzen (ein neues setMode würde die Route neu planen)
    if battle.spanAi then return end
    battle.spanAi = true
    rivalVeh:queueLuaCommand(spanCommand(player:getID()))
    return
  end
  if cfg.rivalAiMode == 'traffic' then
    -- Verkehrsmodus ohne Tempolimit und ohne Spurzwang, Gummiband wie bei flee/chase (wartet vorne, holt hinten auf)
    -- gilt vorne und hinten gleich: nur einmal setzen (ein neues setMode würde die Route neu planen)
    if battle.trafficAi then return end
    battle.trafficAi = true
    rivalVeh:queueLuaCommand(string.format(
      "ai.setAvoidCars('on') ai.setTargetObjectID(%d) ai.setMode('traffic') ai.setSpeedMode('off') ai.driveInLane('off') ai.setAggression(%f) ai.setAggressionMode('rubberBand')",
      player:getID(), battle.rival.aggression or 0.6))
    return
  end
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

-- Bremsschutz der Flucht-KI: langsameres Auto direkt voraus in der Spur -> Tempo kurz begrenzen
local function updateGuard(dt, rivalVeh)
  battle.guardTimer = (battle.guardTimer or 0) - dt
  battle.guardHold = math.max((battle.guardHold or 0) - dt, 0)
  if battle.guardTimer > 0 then return end
  battle.guardTimer = 0.1
  local objs = map and map.objects
  if not objs and not battle.guardWarned then
    battle.guardWarned = true
    log('W', logTag, 'Bremsschutz: map.objects fehlt, Flucht-KI fährt ohne Bremsschutz')
  end
  local rid = rivalVeh:getID()
  local me = objs and objs[rid]
  if not me then return end
  local dir = rivalVeh:getDirectionVector()
  dir.z = 0
  if dir:length() < 0.1 then return end
  dir = dir:normalized()
  local right = dir:cross(vec3(0, 0, 1))
  local myV = me.vel:dot(dir)
  local want = nil
  for id, o in pairs(objs) do
    if id ~= rid and o.pos then
      local rel = o.pos - me.pos
      local along = rel:dot(dir)
      if along > 1 and along < cfg.guardLookAhead and math.abs(rel:dot(right)) < cfg.guardLateral and math.abs(rel.z) < 4 then
        local otherV = o.vel and o.vel:dot(dir) or 0
        local closing = myV - otherV
        -- Abstand Front zu Heck grob: Mitte zu Mitte minus eine Autolänge
        local gap = along - 4.5
        if closing > 0.5 and gap / closing < cfg.guardTtc then
          local v = math.max(otherV - cfg.guardSpeedMargin, 0)
          if not want or v < want then want = v end
        end
      end
    end
  end
  if want then
    battle.guardHold = cfg.guardHold
    if not battle.guardSpeed or math.abs(battle.guardSpeed - want) > 1 then
      battle.guardSpeed = want
      rivalVeh:queueLuaCommand(string.format("ai.setSpeed(%f) ai.setSpeedMode('limit')", want))
    end
  elseif battle.guardSpeed and battle.guardHold <= 0 then
    battle.guardSpeed = nil
    rivalVeh:queueLuaCommand("ai.setSpeedMode('off')")
  end
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

  if cfg.rivalAiMode == 'fleeGuard' and battle.rivalMode == 'flee' then
    local ok, err = pcall(updateGuard, dt, rivalVeh)
    if not ok and not battle.guardWarned then
      battle.guardWarned = true
      log('W', logTag, 'Bremsschutz: ' .. tostring(err))
    end
  end

  -- Eigenes Gummiband im span-Modus (BeamNG hat dort keins): vorne etwas ruhiger, hinten mehr Druck
  if battle.spanAi then
    battle.rubberTimer = (battle.rubberTimer or 0) - dt
    if battle.rubberTimer <= 0 then
      battle.rubberTimer = 1
      local base = battle.rival.aggression or 0.6
      local f = math.min(math.abs(gap) / cfg.rubberDist, 1)
      local a = gap > 0 and (base - cfg.rubberAhead * f) or (base + cfg.rubberBehind * f)
      a = math.floor(math.max(0.3, math.min(1, a)) * 100 + 0.5) / 100
      if a ~= battle.rubberAggr then
        battle.rubberAggr = a
        rivalVeh:queueLuaCommand(string.format('ai.setAggression(%f)', a))
      end
    end
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

-- Spruch des Rivalen (lines.challenge / lines.win / lines.lose aus rivals.json, aus Sicht des Rivalen):
-- challenge beim Angleichen (challengeQuoteTime lang, danach Countdown ohne Spruch), nach dem Battle win (Rivale gewinnt) oder lose (Rivale verliert).
-- Zweiter Rückgabewert = Art (challenge/win/lose) für die Farbe der Sprechblase
local function rivalQuote()
  local lines = battle.rival.lines
  if type(lines) ~= 'table' then return nil end
  local key
  if state == 'sync' and (battle.quoteLeft or 0) > 0 then key = 'challenge'
  elseif state == 'result' then key = battle.won and 'lose' or 'win' end
  local text = key and extensions.hashiriyaBattle_progress.loc(lines[key]) or ''
  if text == '' then return nil end
  return text, key
end

-- Porträt des Rivalen (art/portraits/<id>.svg aus dem Silhouetten-Tool), nil wenn keins da ist
local portraitCache = {}
local function portraitOf(rival)
  local id = rival and rival.id
  if not id then return nil end
  if portraitCache[id] == nil then
    local path = '/art/portraits/' .. id .. '.svg'
    portraitCache[id] = FS:fileExists(path) and path or false
  end
  return portraitCache[id] or nil
end

function M.getHudState()
  if not battle then return nil end
  local quote, quoteKind = rivalQuote()
  return {
    quote = quote,
    quoteKind = quoteKind,
    portrait = quote and portraitOf(battle.rival) or nil,
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
  if extensions.hashiriyaBattle_home.isResting() then return end
  local player = c.getPlayerVehicle()
  if not player then return end

  -- Fernlicht des Spielers 10x pro Sekunde abfragen
  pollTimer = pollTimer - dtReal
  if pollTimer <= 0 then
    pollTimer = 0.1
    pollHighbeam(player)
  end

  if state == 'idle' then
    updateRivalChallenge(dtSim, player)
    return
  end

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
    battle.quoteLeft = math.max(0, (battle.quoteLeft or 0) - dtSim)
    -- Tempo angleichen: Tempomat gibt Gas bzw. lässt ausrollen (er bremst nicht), dann startet der Countdown
    timer = timer - dtSim
    local gap = getGap(player, rivalVeh)
    if battle.playerAhead then
      -- Der Rivale hat herausgefordert und fährt hinten: er holt auf, du hältst das Tempo
      if gap > -2 then
        setWarnSignal(rivalVeh, false)
        core().msg(core().t('msg.falseStart', battle.rival.name), 4)
        M.reset(falseStartCooldown())
        return
      end
      local behind = -gap
      battle.rivalRelock = (battle.rivalRelock or 0) - dtSim
      if battle.rivalRelock <= 0 then
        battle.rivalRelock = 0.5
        local catchUp = math.min(cfg.syncCatchUpKmh, math.max(0, behind - cfg.syncTargetGap) * cfg.syncCatchUpPerMeter) / 3.6
        rivalVeh:queueLuaCommand(string.format("ai.setSpeedMode('set') ai.setSpeed(%f)", battle.rivalSpeed + catchUp))
      end
      battle.lockSpeed = battle.rivalSpeed
      local diff = math.abs(player:getVelocity():length() - battle.rivalSpeed) * 3.6
      if ((behind <= cfg.syncMaxGap and diff <= cfg.syncToleranceKmh) or timer <= 0) and battle.quoteLeft <= 0 then
        state = 'countdown'
        timer = cfg.countdown
        battle.startGap = gap
        battle.relock = 0
        rivalVeh:queueLuaCommand(string.format("ai.setSpeedMode('set') ai.setSpeed(%f)", battle.rivalSpeed))
      end
      return
    end
    if gap < 2 then -- in der Angleich-Phase überholt = Frühstart
      setWarnSignal(rivalVeh, false)
      core().msg(core().t('msg.falseStart', battle.rival.name), 4)
      M.reset(falseStartCooldown())
      return
    end
    -- Zu weit weg: Tempomat etwas schneller als der Rivale, bis man auf syncTargetGap dran ist
    local catchUp = math.min(cfg.syncCatchUpKmh, math.max(0, gap - cfg.syncTargetGap) * cfg.syncCatchUpPerMeter) / 3.6
    battle.lockSpeed = battle.rivalSpeed + catchUp
    local diff = math.abs(player:getVelocity():length() - battle.rivalSpeed) * 3.6
    if ((gap <= cfg.syncMaxGap and diff <= cfg.syncToleranceKmh) or timer <= 0) and battle.quoteLeft <= 0 then
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
      M.reset(falseStartCooldown())
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
