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

function M.getActiveRival()
  return active
end

function M.getRivalVehicle()
  return active and be:getObjectByID(active.vehId) or nil
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
  if c.beatenTeam and not teamBeaten(c.beatenTeam, save) then return false end
  for _, id in ipairs(c.beatenTeams or {}) do if not teamBeaten(id, save) then return false end end
  for _, id in ipairs(c.beatenRivals or c.requires or {}) do if not save.defeated[id] then return false end end
  return true
end

local function isEligible(rival, save)
  local set = settings()
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

  -- Nicht in Parkplätzen spawnen (nur der Test-Knopf darf das)
  if not force and extensions.hashiriyaBattle_parking.getCurrent() then return end
  -- Battles nur nachts und nur bis zum Limit pro Nacht
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
  local nick = progress().loc(rival.nick)
  core().msg(core().t('msg.rivalSpotted', rival.name .. (nick ~= '' and (' "' .. nick .. '"') or ''))
    .. (rival.leader and core().t('msg.leader') or '') .. (rival.wanderer and core().t('msg.wanderer') or '') .. (rival.boss and core().t('msg.boss') or '')
    .. (rival.rematch and core().t('msg.rematch') or ''))
  log('I', logTag, 'Rivale gespawnt: ' .. rival.id)
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
  if not player or not active then return nil end
  local veh = be:getObjectByID(active.vehId)
  if not veh then return nil end
  local fwd = player:getDirectionVector(); fwd.z = 0
  if fwd:length() < 0.01 then return nil end
  fwd = fwd:normalized()
  local right = vec3(fwd.y, -fwd.x, 0)
  local d = veh:getPosition() - player:getPosition()
  local rdir = veh:getDirectionVector()
  local x, y = d:dot(right), d:dot(fwd)
  local heading = math.deg(math.atan2(rdir:dot(right), rdir:dot(fwd)))
  local dist = math.sqrt(x * x + y * y)
  local scale = math.min(1, range / math.max(dist, 1))
  return { list = { {
    kind = M.markerKind(active.data), name = active.data.name,
    x = x / range * scale, y = y / range * scale, heading = heading, edge = dist > range,
    dist = dist < 1000 and string.format('%d m', math.floor(dist)) or string.format('%.1f km', dist / 1000),
  } } }
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
