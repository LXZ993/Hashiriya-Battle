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
  --  'own'     = eigener Fahrer (hashiriyaDriver, Standard): Ideallinie, weicht knapp aus, bremst erst zuletzt;
  --              Werte in data/driver.json und pro Rivale in rivals.json "driver". Gibt er auf, übernimmt 'fleeGuard'
  --  'fleeGuard' = vorne BeamNG-Flucht-KI (zügig, weicht seitlich aus) plus eigener Bremsschutz (siehe guard*),
  --                hinten 'span' mit eigenem Gummiband (Standard)
  --  'span'    = freie Fahrt ohne Tempolimit und Spurzwang: weicht aus, bremst nur wenn nötig, überholt zügig
  --  'traffic' = Verkehrsmodus ohne Tempolimit: sehr vorsichtig, bremst oft mitten im Überholen
  --  'pursuit' = BeamNG flee (vorne) / chase (hinten): flee bremst nicht für Verkehr, chase rammt dich von hinten
  rivalAiMode = 'own',
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

-- Zustand: idle | sync | countdown | battle | result | chainWait (Kette: wartet auf den nächsten Gegner)
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
-- Crew-Battle-Kette (Alpha 0.9.3): { group, order = { Begleiter von hinten nach vorne ..., Leader }, step, target }
local chain = nil

local function core() return extensions.hashiriyaBattle_core end
local function rivals() return extensions.hashiriyaBattle_rivals end
local function crew() return extensions.hashiriyaBattle_crew end

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

-- keepChain = true: nur dieses eine Battle ist vorbei, die Kette geht mit dem nächsten Gegner weiter
function M.reset(cooldown, keepChain)
  offer = nil
  if crew() then pcall(crew().releaseHelpers) end
  -- Battle abgebrochen: eigenen Fahrer stoppen, BeamNG-KI fährt im Verkehr weiter
  if battle and battle.ownAi then
    local veh = rivals() and rivals().getRivalVehicle()
    if veh then
      extensions.hashiriyaBattle_driver.stop(veh)
      rivals().setCruise(veh, battle.rival)
    end
  end
  if state == 'countdown' or state == 'sync' then releasePlayerSpeed() end
  if state == 'countdown' and battle and battle.launchDone then
    local veh = rivals() and rivals().getRivalVehicle()
    if veh then extensions.hashiriyaBattle_driver.cancelLaunch(veh) end
  end
  state = 'idle'
  battle = nil
  -- Kette vorbei oder gerissen (Niederlage, Frühstart, Gegner weg): die Gruppe fährt wieder zusammen,
  -- beim nächsten Mal geht es wieder beim ersten Begleiter los
  local group = (not keepChain) and chain and chain.group or nil
  if not keepChain then chain = nil end
  if rivals() and rivals().disengage then rivals().disengage(cooldown) end
  if group and rivals().regroup then
    rivals().regroup(group, cooldown or (rivals().getSettings().rechallengeSeconds or 60))
  end
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
    pinkSlip = rival.pinkSlip or nil,
    playerAhead = playerAhead or nil,
    chainStep = chain and chain.step or nil,
    chainTotal = chain and #chain.order or nil,
  }
  -- Wette (crew.lua): nicht bei Pink Slip, in einer Kette nur gegen den Leader/Boss am Ende
  if not battle.pinkSlip and (not chain or chain.step == #chain.order) and crew() then
    local okB, bet = pcall(crew().betOffer, rival)
    if okB and bet then
      battle.bet = bet
      core().msg(core().t('msg.betOffer', rival.name, crew().formatYen(bet.stake)), bet.timer + 1)
    elseif not okB then
      log('E', logTag, 'Wette: ' .. tostring(bet))
    end
  end
  local save = core().save
  local car = save and save.cars[save.activeCar or 1]
  battle.playerCar = car and car.name or ''
  -- fährt er dein altes Auto (Pink Slip verloren), steht dessen Name da
  local held = save and save.pinkHeld and save.pinkHeld[rival.baseId or rival.id]
  if held then battle.rivalCar = held.name or vehicleDisplayName(held.model) end
  setWarnSignal(rivalVeh, true)
  local player = core().getPlayerVehicle()
  if player then
    local speed = math.max(rivalVeh:getVelocity():length(), (rival.cruiseKmh or 100) / 3.6 * 0.9)
    battle.lockSpeed = speed
    battle.rivalSpeed = speed
    lockPlayerSpeed(player, speed)
    rivalVeh:queueLuaCommand(string.format("ai.setSpeedMode('limit') ai.setSpeed(%f)", speed))
  end
  core().msg(core().t('msg.challenge', rival.name), 3)
  log('I', logTag, 'Challenge gegen ' .. rival.id)
end

-- Kette: nächster Gegner wartet (vorne langsamer) bzw. holt auf (hinten), bis er nah genug ist
local function chainWaitFor(e)
  rivals().engage(e)
  state = 'chainWait'
  local cc = crew().cfg('escorts')
  timer = cc.chainWaitSeconds or 60
  chain.target = e
  chain.pause = cc.chainPauseSeconds or 3
  chain.relock = 0
  core().msg(core().t('msg.chainNext', e.data.name, chain.step, #chain.order), 5)
  log('I', logTag, string.format('Kette %d/%d: wartet auf %s', chain.step, #chain.order, tostring(e.data.id)))
end

-- Herausforderung beginnt. Gehört der Rivale zu einem Konvoi (Leader/Boss mit Begleitern), wird daraus eine Kette:
-- erst die Begleiter von hinten nach vorne, zuletzt der Leader/Boss.
local function beginChallenge(e, playerAhead)
  local rivalVeh = be:getObjectByID(e.vehId)
  if not rivalVeh then return end
  chain = nil
  local group = e.group
  local leader = group and group.leader
  if group and leader and be:getObjectByID(leader.vehId) and crew() and crew().cfg('escorts').enabled then
    local order = {}
    local esc = group.escorts or {}
    for i = #esc, 1, -1 do
      local m = esc[i]
      if not m.leftGroup and be:getObjectByID(m.vehId) then order[#order + 1] = m end
    end
    if #order > 0 then
      order[#order + 1] = leader
      chain = { group = group, order = order, step = 1 }
      local c = core()
      c.msg(c.t('msg.chainStart', leader.data.name, #order), 5)
      log('I', logTag, 'Kette gegen ' .. tostring(leader.data.id) .. ': ' .. #order .. ' Gegner')
      if order[1] ~= e then chainWaitFor(order[1]); return end
    end
  end
  rivals().engage(e)
  startCountdown(rivals().challengeData(e), rivalVeh, playerAhead)
end

local function endOffer(answer)
  if not offer then return end
  local o = offer
  offer = nil
  offerPause = cfg.rivalChallengePause
  local c = core()
  local rivalVeh = be:getObjectByID(o.vehId)
  if answer == 'accept' and rivalVeh and state == 'idle' then
    beginChallenge(o.entry, true)
    return
  end
  declined[o.vehId] = cfg.rivalChallengeDeclined
  if answer == 'decline' then
    c.msg(c.t('msg.rivalDeclined', o.entry.data.name), 3)
    if crew() then crew().showFx('decline', 'player', o.entry.data.name, c.t('fx.decline.player')) end
  end
end

function M.getOffer()
  if not offer then return nil end
  return { name = offer.entry.data.name, timer = math.ceil(offer.timer) }
end

function M.onLights(vehId, hb, hazard, left, right)
  M.onHighbeam(vehId, hb)
  local prev = signals[vehId] or { hazard = hazard, left = left, right = right }
  signals[vehId] = { hazard = hazard, left = left, right = right }
  -- Wett-Angebot beim Angleichen: Warnblinker = Wette angenommen
  if state == 'sync' and battle and battle.bet and battle.bet.offer then
    local player = core().getPlayerVehicle()
    if player and player:getID() == vehId and hazard == 1 and prev.hazard == 0 then
      battle.bet.offer = false
      battle.bet.accepted = true
      core().msg(core().t('msg.betAccepted', crew().formatYen(battle.bet.stake)), 3)
      core().sound('bet')
      log('I', logTag, 'Wette angenommen: ' .. tostring(battle.bet.stake))
    end
    return
  end
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
    -- Begleiter fordern nicht selbst heraus (sie fahren im Konvoi ihres Leaders)
    if rivalVeh and not e.cooldown and not e.escortOf and not declined[e.vehId] and rivalBehindPlayer(player, rivalVeh) then
      tail[e.vehId] = (tail[e.vehId] or 0) + 0.5
      if offerPause <= 0 and tail[e.vehId] >= cfg.rivalChallengeTail then
        tail[e.vehId] = cfg.rivalChallengeTail - 2 -- nächster Versuch frühestens in 2 s
        -- an der PA verabredet: er fordert sicher heraus
        if e.data.paChallenge or math.random() < cfg.rivalChallengeChance then
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
  -- Wett-Angebot beim Angleichen: Lichthupe = Einsatz erhöhen
  if state == 'sync' and battle and battle.bet and battle.bet.offer then
    local p = core().getPlayerVehicle()
    if p and p:getID() == vehId then
      crew().raiseBet(battle.bet)
      core().msg(core().t('msg.betRaise', crew().formatYen(battle.bet.stake)), 3)
    end
    return
  end
  if state ~= 'idle' then return end

  local player = core().getPlayerVehicle()
  if not player or player:getID() ~= vehId then return end
  -- den Rivalen herausfordern, hinter dem man gerade fährt
  for _, e in ipairs(rivals().getOnRoad()) do
    local rivalVeh = be:getObjectByID(e.vehId)
    if rivalVeh and playerBehindRival(player, rivalVeh) then
      -- Rivale lehnt sichtbar ab (Blinker + Stopp-Zeichen): gerade erst gefahren, Nacht-Limit oder keine Lust
      local reason = crew() and crew().declineReason(e)
      if reason then
        crew().showDecline(e, reason)
        return
      end
      local diff = (player:getVelocity():length() - rivalVeh:getVelocity():length()) * 3.6
      if math.abs(diff) > cfg.maxChallengeDiffKmh then
        core().msg(core().t(diff > 0 and 'msg.tooFast' or 'msg.tooSlow'), 2)
        return
      end
      beginChallenge(e)
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

local function driver() return extensions.hashiriyaBattle_driver end

-- welche KI gerade gilt: eigener Fahrer, solange er nicht aufgegeben hat
local function aiMode(rivalVeh)
  if cfg.rivalAiMode == 'own' then
    local d = driver()
    if d and d.enabled() and not d.hasFailed(rivalVeh:getID()) then return 'own' end
    return 'fleeGuard'
  end
  return cfg.rivalAiMode
end

local function setRivalAi(rivalVeh, mode)
  local ai = aiMode(rivalVeh)
  local player = core().getPlayerVehicle()
  if ai == 'own' then
    -- eigener Fahrer: entscheidet vorne und hinten selbst, nur einmal starten
    if not battle.ownAi then
      battle.ownAi = true
      battle.rivalMode = 'own'
      driver().start(rivalVeh, battle.rival, player:getID())
    end
    return
  end
  if battle.ownAi then
    -- Fahrer hat aufgegeben: BeamNG-KI übernimmt
    battle.ownAi = false
    battle.rivalMode = nil
  end
  if battle.rivalMode == mode then return end
  battle.rivalMode = mode
  if ai == 'fleeGuard' then
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
  if ai == 'span' then
    -- gilt vorne und hinten gleich: nur einmal setzen (ein neues setMode würde die Route neu planen)
    if battle.spanAi then return end
    battle.spanAi = true
    rivalVeh:queueLuaCommand(spanCommand(player:getID()))
    return
  end
  if ai == 'traffic' then
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
    if battle.ownAi then driver().stop(rivalVeh); battle.ownAi = false end
    rivals().setCruise(rivalVeh, battle.rival)
  end
  if crew() then pcall(crew().releaseHelpers) end
  core().onBattleResult(battle.rival, won, {
    time = battle.time, playerSp = battle.playerSp, playerMaxSp = cfg.playerMaxSp, damageSp = battle.damageTaken or 0 })
  -- Wette auszahlen bzw. Einsatz abziehen
  if battle.bet and battle.bet.accepted then
    local okB, err = pcall(crew().settleBet, battle.bet, won, battle.rival.name)
    if not okB then log('E', logTag, 'Wette: ' .. tostring(err)) end
  end
  -- Kette: geschlagener Begleiter fällt zurück; eine Niederlage lässt die Kette reißen (M.reset nach dem Ergebnis)
  if chain then
    local c = core()
    if not won then
      c.msg(c.t('msg.chainBroken', chain.group.leader and chain.group.leader.data.name or ''), 7)
    elseif chain.step < #chain.order then
      chain.order[chain.step].leftGroup = true
    else
      c.msg(c.t('msg.chainDone', battle.rival.name), 7)
    end
  end
  -- PA-Verabredung und Pink Slip gelten nur für dieses eine Battle
  battle.rival.paChallenge, battle.rival.pinkSlip = nil, nil
  local e = rivals().getActiveRival()
  if e and e.data then e.data.paChallenge, e.data.pinkSlip = nil, nil end
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

  if battle.ownAi then
    driver().update(dt, rivalVeh, gap, battle.rivalSp / math.max(battle.rivalMaxSp, 1), battle.playerSp / math.max(cfg.playerMaxSp, 1))
  end

  -- Crew-Taktik: Begleiter und Crew-Mitglieder in der Nähe blocken für ihren Leader (crew.lua)
  if crew() then
    local okH, err = pcall(crew().updateHelpers, dt, player, rivals().getActiveRival())
    if not okH and not battle.helperWarned then
      battle.helperWarned = true
      log('W', logTag, 'Crew-Blocker: ' .. tostring(err))
    end
  end

  if not battle.ownAi and aiMode(rivalVeh) == 'fleeGuard' and battle.rivalMode == 'flee' then
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

-- Porträt des Rivalen, nil wenn keins da ist. Reihenfolge: rivals.json "portrait" (eigener Pfad),
-- dann art/portraits/<id>.png / .jpg (eigenes Bild), dann <id>.svg (Silhouetten-Tool).
local portraitCache = {}
local function portraitOf(rival)
  local id = rival and (rival.baseId or rival.id)
  if not id then return nil end
  local hit = portraitCache[id]
  -- gefundene Bilder bleiben gemerkt; fehlende werden nach 30 s neu gesucht (Bild während des Spiels eingefügt)
  if hit and hit.path then return hit.path end
  if hit and os.clock() - hit.t < 30 then return nil end
  local list = {}
  if type(rival.portrait) == 'string' and rival.portrait ~= '' then list[1] = '/' .. (rival.portrait:gsub('^/', '')) end
  for _, ext in ipairs({ 'png', 'jpg', 'svg' }) do list[#list + 1] = '/art/portraits/' .. id .. '.' .. ext end
  local found = nil
  for _, path in ipairs(list) do
    if FS:fileExists(path) then found = path; break end
  end
  portraitCache[id] = { path = found, t = os.clock() }
  log(found and 'I' or 'W', logTag, 'Porträt ' .. id .. ': ' .. (found or ('keins gefunden (' .. table.concat(list, ', ') .. ')')))
  return found
end

-- Für die Aura (aura.lua): wer gerade gegen wen fährt und wie viel SP beide noch haben (0..1)
function M.auraInfo()
  if not battle then return nil end
  return { state = state, rival = battle.rival,
    rivalSp = math.max(battle.rivalSp or 0, 0) / math.max(battle.rivalMaxSp or 1, 1),
    playerSp = math.max(battle.playerSp or 0, 0) / math.max(cfg.playerMaxSp or 1, 1) }
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
    -- Team-Logo bzw. Wanderer-Siegel/Boss-Emblem, immer sichtbar im Duell (art/logos, siehe rivals.logoOf)
    rivalLogo = rivals().logoOf and rivals().logoOf(battle.rival, true) or nil,
    -- eigenes Logo oben links (Logo-Sammlung, logos.lua); ohne Wahl das Hashiriya-Zeichen
    playerLogo = extensions.hashiriyaBattle_logos and extensions.hashiriyaBattle_logos.playerLogo() or nil,
    rivalTeam = battle.rival.team and rivals().teamName and rivals().teamName(battle.rival.team) or nil,
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
    pinkSlip = battle.pinkSlip,
    -- Wette: Angebot (offer, Restzeit) oder angenommener Einsatz
    bet = battle.bet and (battle.bet.offer or battle.bet.accepted) and {
      stake = crew().formatYen(battle.bet.stake), offer = battle.bet.offer or nil, accepted = battle.bet.accepted or nil,
      timer = battle.bet.offer and math.ceil(battle.bet.timer) or nil } or nil,
    -- Kette: Gegner Nr. step von total
    chain = battle.chainTotal and { step = battle.chainStep, total = battle.chainTotal } or nil,
    blockers = (crew() and crew().helperCount() > 0) and crew().helperCount() or nil,
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

  if crew() then crew().tick(dtSim) end

  if state == 'idle' then
    updateRivalChallenge(dtSim, player)
    return
  end

  local rivalVeh = rivals().getRivalVehicle()
  if not rivalVeh then M.reset(); return end

  if state == 'chainWait' then
    local target = chain and chain.target
    if not target or not be:getObjectByID(target.vehId) or rivals().getActiveRival() ~= target then
      core().msg(core().t('msg.chainLost'), 5)
      M.reset()
      return
    end
    rivalVeh = be:getObjectByID(target.vehId)
    timer = timer - dtSim
    chain.pause = (chain.pause or 0) - dtSim
    local gap = getGap(player, rivalVeh)
    local cc = crew().cfg('escorts')
    if chain.pause <= 0 and math.abs(gap) <= (cc.chainStartDistance or 45) then
      startCountdown(rivals().challengeData(target), rivalVeh, gap < 0)
      return
    end
    if timer <= 0 then
      core().msg(core().t('msg.chainLost'), 5)
      M.reset()
      return
    end
    chain.relock = (chain.relock or 0) - dtSim
    if chain.relock <= 0 then
      chain.relock = 1
      local cruise = (target.data.cruiseKmh or 100) / 3.6
      local pv = player:getVelocity():length()
      if gap > 0 then
        -- vorne: er wartet auf dich (fährt langsamer)
        local v = math.max(math.min(cruise, pv) * 0.75, 50 / 3.6)
        rivalVeh:queueLuaCommand(string.format("ai.setMode('traffic') ai.setSpeedMode('limit') ai.setSpeed(%f) ai.driveInLane('on')", v))
      else
        -- hinten: er holt auf
        local v = math.max(pv, cruise) + 25 / 3.6
        rivalVeh:queueLuaCommand(string.format("ai.setMode('traffic') ai.setSpeedMode('limit') ai.setSpeed(%f) ai.driveInLane('off')", v))
      end
    end
    return
  end

  if state == 'sync' or state == 'countdown' then
    -- echtes Tempo des Rivalen (geglättet): die KI bremst für Verkehr und Kurven, dein Tempomat folgt ihr
    local rvNow = rivalVeh:getVelocity():length()
    battle.rivalV = battle.rivalV and (battle.rivalV + (rvNow - battle.rivalV) * math.min(1, dtSim * 2)) or rvNow
    -- Der BeamNG-Tempomat schaltet sich beim Bremsen ab: regelmäßig wieder einschalten
    battle.relock = (battle.relock or 0.5) - dtSim
    if battle.relock <= 0 then
      battle.relock = 0.5
      player:queueLuaCommand(string.format('if extensions.cruiseControl then extensions.cruiseControl.setSpeed(%f) extensions.cruiseControl.setEnabled(true) end', battle.lockSpeed))
    end
  end

  if state == 'sync' then
    battle.quoteLeft = math.max(0, (battle.quoteLeft or 0) - dtSim)
    -- Wett-Angebot läuft: Countdown wartet, bis du annimmst (Warnblinker) oder die Zeit um ist
    local bet = battle.bet
    if bet and bet.offer then
      bet.timer = bet.timer - dtSim
      if bet.timer <= 0 then
        bet.offer = false
        core().msg(core().t('msg.betNone'), 3)
      end
    end
    local betPending = bet and bet.offer
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
        rivalVeh:queueLuaCommand(string.format("ai.setSpeedMode('limit') ai.setSpeed(%f)", battle.rivalSpeed + catchUp))
      end
      battle.lockSpeed = battle.rivalSpeed
      local diff = math.abs(player:getVelocity():length() - battle.rivalSpeed) * 3.6
      if ((behind <= cfg.syncMaxGap and diff <= cfg.syncToleranceKmh) or timer <= 0) and battle.quoteLeft <= 0 and not betPending then
        state = 'countdown'
        timer = cfg.countdown
        battle.startGap = gap
        battle.relock = 0
        rivalVeh:queueLuaCommand(string.format("ai.setSpeedMode('limit') ai.setSpeed(%f)", battle.rivalSpeed))
      end
      return
    end
    -- in der Angleich-Phase überholt = Frühstart, aber nur wenn du schneller warst
    -- (bremst der Rivale für Verkehr und du rollst ran, ist das nicht deine Schuld)
    local playerFaster = player:getVelocity():length() > battle.rivalV + 3 / 3.6
    if gap < 2 and (playerFaster or gap < -4) then
      setWarnSignal(rivalVeh, false)
      core().msg(core().t('msg.falseStart', battle.rival.name), 4)
      M.reset(falseStartCooldown())
      return
    end
    -- Zu weit weg: Tempomat etwas schneller als der Rivale, bis man auf syncTargetGap dran ist
    local catchUp = math.min(cfg.syncCatchUpKmh, math.max(0, gap - cfg.syncTargetGap) * cfg.syncCatchUpPerMeter) / 3.6
    battle.lockSpeed = battle.rivalV + catchUp
    local diff = math.abs(player:getVelocity():length() - battle.rivalV) * 3.6
    if ((gap <= cfg.syncMaxGap and diff <= cfg.syncToleranceKmh) or timer <= 0) and battle.quoteLeft <= 0 and not betPending then
      state = 'countdown'
      timer = cfg.countdown
      battle.startGap = gap
      battle.lockSpeed = math.max(battle.rivalV, math.min(player:getVelocity():length(), battle.rivalV + cfg.syncToleranceKmh / 3.6))
      battle.relock = 0
    end
    return
  end

  if state == 'countdown' then
    timer = timer - dtSim
    -- Erfahrene Rivalen schalten kurz vor "Los" runter (eigener Fahrer)
    if battle.launchAt == nil then
      battle.launchAt = false
      if aiMode(rivalVeh) == 'own' then battle.launchAt = driver().launchLead(battle.rival) or false end
    end
    if battle.launchAt and not battle.launchDone and timer <= battle.launchAt then
      battle.launchDone = true
      driver().prepareLaunch(rivalVeh)
    end
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
    -- Tempomat folgt dem Rivalen und hält den Abstand vom Countdown-Start
    if battle.startGap then
      battle.lockSpeed = math.max(battle.rivalV + math.max(-2, math.min(2, (gap - battle.startGap) * 0.4)), 5)
    end
    local playerFaster = player:getVelocity():length() > battle.rivalV + 3 / 3.6
    if battle.startGap and ((gap < battle.startGap - cfg.falseStartGap and playerFaster)
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
      -- Kette: gewonnen und noch Gegner übrig -> der nächste wartet
      if chain and battle and battle.won and chain.step < #chain.order then
        M.reset(nil, true)
        chain.step = chain.step + 1
        local nxt = chain.order[chain.step]
        if nxt and be:getObjectByID(nxt.vehId) then
          chainWaitFor(nxt)
        else
          core().msg(core().t('msg.chainLost'), 5)
          M.reset()
        end
        return
      end
      -- der Rivale fährt weiter (TXR-Stil); geschlagen = später Revanche möglich
      M.reset()
    end
  end

end

M.onUpdate = onUpdate

return M
