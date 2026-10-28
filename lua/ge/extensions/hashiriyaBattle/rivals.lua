-- Hashiriya Battle: Rivalen laden, spawnen und im Verkehr fahren lassen
local M = {}

local logTag = 'hashiriya'
local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/rivals.json'

-- Mehrere Rivalen fahren gleichzeitig im Verkehr (settings.maxOnRoad). Wer hinter einem Rivalen die Lichthupe gibt,
-- fordert genau diesen heraus. Nach dem Battle fährt der Rivale weiter (geschlagen = Revanche möglich).
local spawnMin, spawnMax = 400, 650 -- m vor dem Spieler (außer Sichtweite)
local behindMin, behindMax = 200, 400 -- m hinter dem Spieler
local stuckSeconds = 8       -- so lange fast stehen = hängt fest
local despawnDistance = 1100 -- m Abstand, ab dem ein Rivale verschwindet
local spawnCooldown = 20     -- s zwischen automatischen Spawns
local minSpawnSpeed = 40 / 3.6 -- Spieler muss mind. 40 km/h fahren

local data = nil
local onRoad = {}   -- { data = rivalData, vehId = id, spawnDir = vec3, spawnPos = vec3, age = s }
local engaged = nil -- Eintrag aus onRoad, gegen den gerade das Battle läuft
local cooldown = 10

local function core() return extensions.hashiriyaBattle_core end

function M.loadData()
  data = jsonReadFile(dataPath) or { rivals = {}, teams = {} }
end

function M.getData()
  if not data then M.loadData() end
  return data
end

-- "Marke Modell" für die Anzeige
function M.vehicleName(model)
  local ok, info = pcall(core_vehicles.getModel, model)
  if ok and info and info.model then
    local m = info.model
    return ((m.Brand and m.Brand ~= '') and (m.Brand .. ' ') or '') .. (m.Name or model)
  end
  return model
end

local setCruise -- weiter unten
local function entryVeh(e) return e and be:getObjectByID(e.vehId) or nil end

-- Nächster Rivale zum Spieler (für die Anzeige), bzw. der aus dem laufenden Battle
local function nearest()
  local player = core().getPlayerVehicle()
  if not player then return onRoad[1] end
  local best, bestD = nil, math.huge
  for _, e in ipairs(onRoad) do
    local veh = entryVeh(e)
    if veh then
      local d = (veh:getPosition() - player:getPosition()):length()
      if d < bestD then best, bestD = e, d end
    end
  end
  return best
end

function M.getActiveRival()
  return engaged or nearest()
end

function M.getRivalVehicle()
  return entryVeh(engaged or nearest())
end

function M.getOnRoad() return onRoad end

-- Battle beginnt gegen diesen Rivalen / ist vorbei
function M.engage(e) engaged = e end
function M.disengage()
  local e = engaged
  engaged = nil
  local veh = entryVeh(e)
  if veh then
    -- weiterfahren, aber erst nach einer Pause wieder herausforderbar
    e.cooldown = (data and data.settings and data.settings.rechallengeSeconds) or 60
    setCruise(veh, e.data)
  end
end

-- Wer darf als Nächstes erscheinen? -----------------------------------------
-- Teams ab einem Rang, pro Nacht nur ein paar Mitglieder je Team, der Leader erst in einer späteren Nacht.
-- Wanderer und Bosse haben eigene Bedingungen (Rang, Siege, Spieltag, Uhrzeit, Auto, Tuningteil, besiegte Teams).

local function progress() return extensions.hashiriyaBattle_progress end
local function home() return extensions.hashiriyaBattle_home end

local function settings() return data.settings or {} end

local function teamById(id)
  for _, t in ipairs(data.teams or {}) do if t.id == id then return t end end
end

local function leaderOf(teamId)
  for _, r in ipairs(data.rivals) do if r.team == teamId and r.leader then return r end end
end

local function teamBeaten(teamId, save)
  local l = leaderOf(teamId)
  return l and save.defeated[l.id] or false
end

local function teamMembersDefeated(teamId, save, beforeNight)
  for _, r in ipairs(data.rivals) do
    if r.team == teamId and not r.leader then
      if not save.defeated[r.id] then return false end
      if beforeNight and (save.defeatedNight or {})[r.id] == beforeNight then return false end
    end
  end
  return true
end

local function membersBeatenTonight(teamId, save, night)
  local n = 0
  for _, r in ipairs(data.rivals) do
    if r.team == teamId and not r.leader and (save.defeatedNight or {})[r.id] == night then n = n + 1 end
  end
  return n
end

local function inHours(h, from, to)
  if from <= to then return h >= from and h < to end
  return h >= from or h < to
end

local function playerHasPart(word)
  local ok, cfg = pcall(function() return extensions.hashiriyaBattle_shop.currentConfig() end)
  if not ok or type(cfg) ~= 'table' then return false end
  word = word:lower()
  for slot, part in pairs(cfg.parts or {}) do
    if type(part) == 'string' and part ~= '' and (part:lower():find(word, 1, true)) then return true end
  end
  return false
end

local function playerModel()
  local veh = core().getPlayerVehicle()
  return veh and veh:getJBeamFilename() or nil
end

local function conditionsMet(c, save)
  if not c then return true end
  local rank = progress().rankIndex(save)
  if c.minRank and rank < c.minRank then return false end
  if c.minWins and (save.wins or 0) < c.minWins then return false end
  if c.minDay and (save.day or 1) < c.minDay then return false end
  local hours = c.hours or c.timeWindow
  if hours then
    local h = home().hour()
    if h and not inHours(h, hours[1], hours[2]) then return false end
  end
  if c.playerModel and playerModel() ~= c.playerModel then return false end
  if c.playerPart and not playerHasPart(c.playerPart) then return false end
  if c.speedTraps then
    local n, total = progress().speedTrapCount(save)
    local need = c.speedTraps == 'all' and total or tonumber(c.speedTraps)
    if not need or n < need then return false end
  end
  if c.beatenTeam and not teamBeaten(c.beatenTeam, save) then return false end
  for _, id in ipairs(c.beatenTeams or {}) do if not teamBeaten(id, save) then return false end end
  for _, id in ipairs(c.beatenRivals or c.requires or {}) do if not save.defeated[id] then return false end end
  return true
end

local function isOnRoad(id)
  for _, e in ipairs(onRoad) do if e.data.id == id then return true end end
  return false
end

local function isEligible(rival, save)
  local set = settings()
  if isOnRoad(rival.id) then return false end
  -- Geschlagene Rivalen kommen als Revanche wieder (stärker, weniger Belohnung)
  if save.defeated[rival.id] and not (set.rematch and set.rematch.enabled) then return false end
  local night = home().nightId()
  -- jeder Rivale nur einmal pro Nacht; nach einer Niederlage eine Nacht Pause
  local last = (save.lastBattle or {})[rival.id]
  if last then
    if set.rivalOncePerNight ~= false and last.night == night then return false end
    if not last.won and night - last.night <= (set.lostRivalCooldownNights or 0) and last.night ~= night then return false end
  end
  if save.defeated[rival.id] then return true end
  if rival.team then
    local team = teamById(rival.team)
    if team and progress().rankIndex(save) < (team.minRank or 0) then return false end
    if rival.leader then
      if not teamMembersDefeated(rival.team, save, set.leaderNotSameNight ~= false and night or nil) then return false end
    elseif membersBeatenTonight(rival.team, save, night) >= (set.teamMembersPerNight or 99) then
      return false
    end
  end
  return conditionsMet(rival.conditions, save)
end

-- Wie viele Battles diese Nacht noch gehen
function M.battlesLeftTonight()
  local save = core().save
  local max = settings().maxBattlesPerNight
  if not save or not max then return nil end
  local nb = save.nightBattles
  local used = (nb and nb.night == home().nightId()) and nb.count or 0
  return math.max(0, max - used)
end

-- Revanche: Kopie des Rivalen mit mehr Biss; Belohnung und Ruf fallen kleiner aus
local function rematchOf(r, save)
  local rm = settings().rematch or {}
  local n = ((save.rematchWins or {})[r.id] or 0)
  local copy = {}
  for k, v in pairs(r) do copy[k] = v end
  copy.rematch = true
  copy.aggression = math.min(1, (r.aggression or 0.5) + (rm.aggressionBonus or 0.08) * (1 + math.min(n, 3) * 0.5))
  copy.maxSp = math.floor((r.maxSp or 1000) * (rm.spFactor or 1.1) * (1 + math.min(n, 3) * 0.05))
  copy.cruiseKmh = (r.cruiseKmh or 100) + 5
  copy.rewardUsd = math.floor((r.rewardUsd or 1000) * (rm.rewardFactor or 0.4))
  copy.rep = math.floor((r.rep or 30) * (rm.repFactor or 0.25))
  return copy
end

-- Daten fürs Battle: ein schon geschlagener Rivale auf der Straße kämpft als Revanche
function M.challengeData(e)
  local save = core().save
  if save and save.defeated[e.data.id] and not e.data.rematch then e.data = rematchOf(e.data, save) end
  return e.data
end

local function pickRival(save)
  -- Gibt es neue Gegner, kommt meist einer davon (rematch.weight = Anteil der Revanchen); sonst eine Revanche
  local fresh, beaten = {}, {}
  for _, r in ipairs(data.rivals) do
    if isEligible(r, save) then table.insert(save.defeated[r.id] and beaten or fresh, r) end
  end
  local rw = (settings().rematch or {}).weight or 0.25
  if #fresh > 0 and (#beaten == 0 or math.random() >= rw) then return fresh[math.random(#fresh)] end
  if #beaten > 0 then return rematchOf(beaten[math.random(#beaten)], save) end
  return nil
end

-- Spawnen -----------------------------------------------------------------------

-- Sucht einen Punkt auf einer KI-Straße ungefähr `distance` m vor `pos`.
local function findRoadSpawn(pos, dir, distance)
  local target = pos + dir * distance
  local n1, n2 = map.findClosestRoad(target)
  if not n1 or not n2 then return nil end
  -- nicht auf eine Auffahrt oder eine Straße darüber/darunter ausweichen
  local np = map.getMap().nodes[n1].pos
  if math.abs(np.z - target.z) > 8 or (vec3(np.x, np.y, 0) - vec3(target.x, target.y, 0)):length() > 25 then return nil end
  local nodes = map.getMap().nodes
  local p1, p2 = nodes[n1].pos, nodes[n2].pos
  local seg = p2 - p1
  local segLen2 = seg:squaredLength()
  if segLen2 < 0.01 then return nil end
  local t = clamp((target - p1):dot(seg) / segLen2, 0, 1)
  local roadDir = seg:normalized()
  if roadDir:dot(dir) < 0 then roadDir = roadDir * -1 end
  return p1 + seg * t + vec3(0, 0, 0.5), roadDir
end

local function setRotation(veh, pos, dir)
  local rot = quatFromDir(dir, vec3(0, 0, 1))
  if spawn and spawn.safeTeleport then
    spawn.safeTeleport(veh, pos, rot)
  else
    veh:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
  end
end

function setCruise(veh, rival)
  local speed = (rival.cruiseKmh or 100) / 3.6
  veh:queueLuaCommand(string.format(
    "ai.setMode('traffic') ai.setSpeedMode('limit') ai.setSpeed(%f) ai.setAggression(%f) ai.driveInLane('on')",
    speed, math.min(rival.aggression or 0.5, 0.5)))
end
M.setCruise = setCruise

function M.spawnNext(force)
  local save = core().save
  if not save then return end
  if not data then M.loadData() end
  local player = core().getPlayerVehicle()
  if not player then return end
  if #onRoad >= (settings().maxOnRoad or 4) and not force then return end

  -- Nicht in Parkplätzen spawnen (nur der Test-Knopf darf das)
  if not force and extensions.hashiriyaBattle_parking.getCurrent() then return end
  -- Battles nur nachts und (falls eingestellt) nur bis zum Limit pro Nacht
  if not force then
    if settings().nightOnly and not home().isNight() then return end
    local left = M.battlesLeftTonight()
    if left and left <= 0 then
      if not save.nightLimitShown or save.nightLimitShown ~= home().nightId() then
        save.nightLimitShown = home().nightId()
        core().msg(core().t('msg.nightDone'), 6)
      end
      return
    end
  end

  local rival = pickRival(save)
  if not rival then
    if force then core().msg(core().t('msg.noRivals')) end
    return
  end

  -- vor oder hinter dem Spieler, in Fahrtrichtung
  local behind = not force and math.random() < 0.4
  local pos, dir, dist
  for _ = 1, 4 do
    dist = behind and -(behindMin + math.random() * (behindMax - behindMin)) or (spawnMin + math.random() * (spawnMax - spawnMin))
    if force then dist = 160 end
    pos, dir = findRoadSpawn(player:getPosition(), player:getDirectionVector(), dist)
    if pos then break end
  end
  if not pos then
    if force then core().msg(core().t('msg.noRoad')) end
    return
  end

  local veh = core_vehicles.spawnNewVehicle(rival.model, {
    config = rival.config ~= '' and rival.config or nil,
    pos = pos,
    rot = quatFromDir(dir, vec3(0, 0, 1)),
    autoEnterVehicle = false,
  })
  if not veh then
    log('E', logTag, 'Konnte Rivalen-Auto nicht spawnen: ' .. tostring(rival.model))
    return
  end

  table.insert(onRoad, { data = rival, vehId = veh:getID(), spawnDir = dir, spawnPos = pos, age = 0, rotChecked = false })
  setCruise(veh, rival)
  if force or dist > 0 then
    local nick = progress().loc(rival.nick)
    core().msg(core().t('msg.rivalSpotted', rival.name .. (nick ~= '' and (' "' .. nick .. '"') or ''))
      .. (rival.leader and core().t('msg.leader') or '') .. (rival.wanderer and core().t('msg.wanderer') or '') .. (rival.boss and core().t('msg.boss') or '')
      .. (rival.rematch and core().t('msg.rematch') or ''))
  end
  log('I', logTag, 'Rivale gespawnt: ' .. rival.id .. string.format(' (%d m, %d unterwegs)', math.floor(dist), #onRoad))
end

-- Farbklasse für Markierungen (Radar, HUD): Boss, Wanderer, Leader, Revanche, verloren, normal
function M.markerKind(rival)
  local save = core().save
  if not rival then return 'rival' end
  if rival.boss then return 'boss' end
  if save and save.defeated and save.defeated[rival.id] then return 'beaten' end
  local last = save and save.lastBattle and save.lastBattle[rival.id]
  if last and not last.won then return 'lost' end
  if rival.wanderer then return 'wanderer' end
  if rival.leader then return 'leader' end
  return 'rival'
end

-- Radar: Rivalen relativ zum Spieler (x rechts, y vorne, in Metern)
function M.radarInfo(range)
  local c = core()
  local player = c.getPlayerVehicle()
  if not player or #onRoad == 0 then return nil end
  local fwd = player:getDirectionVector(); fwd.z = 0
  if fwd:length() < 0.01 then return nil end
  fwd = fwd:normalized()
  local right = vec3(fwd.y, -fwd.x, 0)
  local list, near = {}, nil
  for _, e in ipairs(onRoad) do
    local veh = entryVeh(e)
    if veh then
      local d = veh:getPosition() - player:getPosition()
      local rdir = veh:getDirectionVector()
      local x, y = d:dot(right), d:dot(fwd)
      local dist = math.sqrt(x * x + y * y)
      local scale = math.min(1, range / math.max(dist, 1))
      local item = {
        kind = M.markerKind(e.data), name = e.data.name, engaged = e == engaged,
        x = x / range * scale, y = y / range * scale, edge = dist > range,
        heading = math.deg(math.atan2(rdir:dot(right), rdir:dot(fwd))),
        dist = dist < 1000 and string.format('%d m', math.floor(dist)) or string.format('%.1f km', dist / 1000),
        d = dist,
      }
      table.insert(list, item)
      if not near or dist < near.d then near = item end
    end
  end
  return { list = list, near = near }
end

local function despawn(e)
  local veh = entryVeh(e)
  if veh then veh:delete() end
  for i, x in ipairs(onRoad) do if x == e then table.remove(onRoad, i); break end end
  if engaged == e then engaged = nil end
end

-- Rivale aus dem Battle (oder der nächste) verschwindet, z. B. beim Abschleppen
function M.despawnActive()
  local e = engaged or nearest()
  if e then despawn(e) end
  cooldown = spawnCooldown
end

function M.despawnAll()
  for i = #onRoad, 1, -1 do despawn(onRoad[i]) end
  onRoad, engaged = {}, nil
end

-- Update -------------------------------------------------------------------------

local function onUpdate(dtReal, dtSim)
  local c = core()
  if not c or not c.active then return end
  local player = c.getPlayerVehicle()
  local busy = extensions.hashiriyaBattle_battle.isBusy()
  local night = not settings().nightOnly or home().isNight()

  for i = #onRoad, 1, -1 do
    local e = onRoad[i]
    e.age = e.age + dtSim
    if e.cooldown then e.cooldown = e.cooldown - dtSim; if e.cooldown <= 0 then e.cooldown = nil end end
    local veh = entryVeh(e)
    if not veh then
      table.remove(onRoad, i)
      if engaged == e then engaged = nil end
    else
      -- Falls das Auto falsch herum gespawnt ist, einmal umdrehen.
      if not e.rotChecked and e.age > 0.5 then
        e.rotChecked = true
        if veh:getDirectionVector():dot(e.spawnDir) < 0 then
          log('W', logTag, 'Rivale stand falsch herum, wird gedreht')
          setRotation(veh, e.spawnPos, e.spawnDir * -1)
          setCruise(veh, e.data)
        end
      end
      -- Gleich nach dem Spawn mit Reisetempo losrollen lassen, statt aus dem Stand zu starten
      if not e.launched and e.age > 0.25 then
        e.launched = true
        local v = e.spawnDir * ((e.data.cruiseKmh or 100) / 3.6)
        local ok = pcall(function() veh:applyClusterVelocityScaleAdd(veh:getRefNodeId(), 0, v.x, v.y, v.z) end)
        if not ok then
          veh:queueLuaCommand(string.format('obj:applyClusterVelocityScaleAdd(obj:getRefNodeId(), 0, %f, %f, %f)', v.x, v.y, v.z))
        end
      end
      -- Licht: nachts an, außer der Rivale fährt als Markenzeichen ohne Licht (rivals.json: "lights": "off")
      e.lightTimer = (e.lightTimer or 0.3) - dtSim
      if e.lightTimer <= 0 then
        e.lightTimer = 5
        local want = (e.data.lights == 'off' or not home().isNight()) and 0 or 1
        if e.data.lights == 'on' then want = 1 end
        veh:queueLuaCommand(string.format('if (electrics.values.lights_state or 0) ~= %d then electrics.setLightsState(%d) end', want, want))
      end
      -- Hängt fest (steht oder fährt kaum, ohne Battle): erst neu anschieben, dann verschwinden lassen, wenn weit genug weg
      if e ~= engaged and e.launched then
        if veh:getVelocity():length() < 3 then e.stuck = (e.stuck or 0) + dtSim else e.stuck = 0 end
        if e.stuck > stuckSeconds * 0.5 and not e.nudged then e.nudged = true; setCruise(veh, e.data) end
        if e.stuck > stuckSeconds and player and (veh:getPosition() - player:getPosition()):length() > 120 then
          log('I', logTag, 'Rivale hing fest und wird entfernt: ' .. tostring(e.data.id))
          despawn(e)
          goto continue
        end
        if e.stuck == 0 then e.nudged = nil end
      end
      -- Zu weit weg (oder Tag geworden) und nicht im Battle: verschwinden lassen.
      if player and e ~= engaged then
        local far = (veh:getPosition() - player:getPosition()):length() > despawnDistance
        if far or (not night and not busy) then despawn(e) end
      end
    end
    ::continue::
  end

  cooldown = cooldown - dtSim
  if cooldown > 0 or busy then return end
  if player and player:getVelocity():length() > minSpawnSpeed then
    M.spawnNext(false)
    cooldown = spawnCooldown
  end
end

local function onExtensionLoaded()
  M.loadData()
end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate

return M
