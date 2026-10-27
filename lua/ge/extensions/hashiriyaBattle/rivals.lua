-- Hashiriya Battle: Rivalen laden, spawnen und im Verkehr fahren lassen
local M = {}

local logTag = 'hashiriya'
local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/rivals.json'

local spawnDistance = 160   -- m vor dem Spieler
local despawnDistance = 900 -- m Abstand, ab dem ein Rivale verschwindet
local spawnCooldown = 45    -- s zwischen automatischen Spawns
local minSpawnSpeed = 60 / 3.6 -- Spieler muss mind. 60 km/h fahren

local data = nil
local active = nil -- { data = rivalData, vehId = id, spawnDir = vec3, spawnPos = vec3, age = s }
local cooldown = 10

local function core() return extensions.hashiriyaBattle_core end

function M.loadData()
  data = jsonReadFile(dataPath) or { rivals = {}, teams = {} }
end

function M.getActiveRival()
  return active
end

function M.getRivalVehicle()
  return active and be:getObjectByID(active.vehId) or nil
end

-- Wer darf als Nächstes erscheinen? -----------------------------------------

local function teamMembersDefeated(teamId, save)
  for _, r in ipairs(data.rivals) do
    if r.team == teamId and not r.leader and not save.defeated[r.id] then return false end
  end
  return true
end

local function isEligible(rival, save)
  if save.defeated[rival.id] then return false end
  if rival.leader and not teamMembersDefeated(rival.team, save) then return false end
  local c = rival.conditions
  if c then
    if c.minWins and save.wins < c.minWins then return false end
    -- weitere Bedingungen (Uhrzeit, Auto, Tuningteil) folgen in einem späteren Schritt
  end
  return true
end

local function pickRival(save)
  local candidates = {}
  for _, r in ipairs(data.rivals) do
    if isEligible(r, save) then table.insert(candidates, r) end
  end
  if #candidates == 0 then return nil end
  return candidates[math.random(#candidates)]
end

-- Spawnen -----------------------------------------------------------------------

-- Sucht einen Punkt auf einer KI-Straße ungefähr `distance` m vor `pos`.
local function findRoadSpawn(pos, dir, distance)
  local target = pos + dir * distance
  local n1, n2 = map.findClosestRoad(target)
  if not n1 or not n2 then return nil end
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

local function setCruise(veh, rival)
  local speed = (rival.cruiseKmh or 100) / 3.6
  veh:queueLuaCommand(string.format(
    "ai.setMode('traffic') ai.setSpeedMode('limit') ai.setSpeed(%f) ai.setAggression(%f) ai.driveInLane('on')",
    speed, math.min(rival.aggression or 0.5, 0.5)))
end
M.setCruise = setCruise

function M.spawnNext(force)
  local save = core().save
  if not save or active then return end
  if not data then M.loadData() end
  local player = core().getPlayerVehicle()
  if not player then return end

  local rival = pickRival(save)
  if not rival then
    if force then core().msg(core().t('msg.noRivals')) end
    return
  end

  local pos, dir = findRoadSpawn(player:getPosition(), player:getDirectionVector(), spawnDistance)
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

  active = { data = rival, vehId = veh:getID(), spawnDir = dir, spawnPos = pos, age = 0, rotChecked = false }
  setCruise(veh, rival)
  core().msg(core().t('msg.rivalSpotted', rival.name) .. (rival.leader and core().t('msg.leader') or '') .. (rival.wanderer and core().t('msg.wanderer') or ''))
  log('I', logTag, 'Rivale gespawnt: ' .. rival.id)
end

function M.despawnActive()
  if not active then return end
  local veh = be:getObjectByID(active.vehId)
  if veh then veh:delete() end
  active = nil
  cooldown = spawnCooldown
end

function M.despawnAll()
  M.despawnActive()
end

-- Update -------------------------------------------------------------------------

local function onUpdate(dtReal, dtSim)
  local c = core()
  if not c or not c.active then return end

  if active then
    active.age = active.age + dtSim
    local veh = be:getObjectByID(active.vehId)
    if not veh then active = nil; return end

    -- Falls das Auto falsch herum gespawnt ist, einmal umdrehen.
    if not active.rotChecked and active.age > 0.5 then
      active.rotChecked = true
      if veh:getDirectionVector():dot(active.spawnDir) < 0 then
        log('W', logTag, 'Rivale stand falsch herum, wird gedreht')
        setRotation(veh, active.spawnPos, active.spawnDir * -1)
        setCruise(veh, active.data)
      end
    end

    -- Zu weit weg und nicht im Battle: verschwinden lassen.
    local player = c.getPlayerVehicle()
    local battle = extensions.hashiriyaBattle_battle
    if player and not battle.isBusy() then
      if (veh:getPosition() - player:getPosition()):length() > despawnDistance then
        M.despawnActive()
      end
    end
    return
  end

  cooldown = cooldown - dtSim
  if cooldown > 0 then return end
  local player = c.getPlayerVehicle()
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
