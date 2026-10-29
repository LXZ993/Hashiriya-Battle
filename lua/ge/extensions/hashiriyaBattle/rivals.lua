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
function M.disengage(cooldown)
  local e = engaged
  engaged = nil
  local veh = entryVeh(e)
  if veh then
    -- weiterfahren, aber erst nach einer Pause wieder herausforderbar
    e.cooldown = cooldown or (data and data.settings and data.settings.rechallengeSeconds) or 60
    setCruise(veh, e.data)
  end
end

-- Wer darf als Nächstes erscheinen? -----------------------------------------
-- Teams ab einem Rang, pro Nacht nur ein paar Mitglieder je Team, der Leader erst in einer späteren Nacht.
-- Wanderer und Bosse haben eigene Bedingungen (Rang, Siege, Spieltag, Uhrzeit, Auto, Tuningteil, besiegte Teams).

local function progress() return extensions.hashiriyaBattle_progress end
local function home() return extensions.hashiriyaBattle_home end

local function settings() return data.settings or {} end
function M.getSettings() return data and data.settings or {} end

local function teamById(id)
  for _, t in ipairs(data.teams or {}) do if t.id == id then return t end end
end

-- Kennzeichen (Agent's Japanese Plates Pack) und fester Lack ----------------------
-- plate.design ist ein Teil im Slot licenseplate_design_2_1 und muss in die Config; der Text kommt per licenseText.
-- paint gilt nur, wenn die Config keine Livery (paint_design) hat.
local pcCache = {}
local function readPc(path)
  if pcCache[path] == nil then pcCache[path] = jsonReadFile('/' .. tostring(path):gsub('^/', '')) or false end
  return pcCache[path] or nil
end

local function hasLivery(parts)
  for slot, part in pairs(parts or {}) do
    if type(slot) == 'string' and slot:match('paint_design$') and type(part) == 'string' and part ~= '' then return true end
  end
  return false
end

local function rivalPaint(p)
  if type(p) ~= 'table' or type(p.color) ~= 'table' then return nil end
  return {
    baseColor = { p.color[1] or 0.5, p.color[2] or 0.5, p.color[3] or 0.5, 1.2 },
    metallic = p.metallic or 0, roughness = p.roughness or 0.5, clearcoat = 1, clearcoatRoughness = 0.05,
  }
end

-- Config fürs Spawnen: Pfad, oder Tabelle mit Kennzeichen-Design und Lack. Zweiter Wert = Lack (oder nil)
local function spawnSetup(rival)
  local path = rival.config ~= '' and rival.config or nil
  local design = rival.plate and rival.plate.design
  local paint = rivalPaint(rival.paint)
  if not path or (not design and not paint) then return path, nil end
  local pc = readPc(path)
  if not pc or type(pc.parts) ~= 'table' then return path, nil end
  if paint and hasLivery(pc.parts) then paint = nil end
  local cfg = { parts = {}, vars = {}, paints = pc.paints }
  for k, v in pairs(pc.parts) do cfg.parts[k] = v end
  for k, v in pairs(pc.vars or {}) do cfg.vars[k] = v end
  if design then
    local set = false
    for k in pairs(cfg.parts) do
      if type(k) == 'string' and k:match('licenseplate_design_2_1$') then cfg.parts[k] = design; set = true end
    end
    if not set then cfg.parts.licenseplate_design_2_1 = design end
  end
  if paint then cfg.paints = { paint, paint, paint } end
  return cfg, paint
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

-- Leader: "appear": "sameNight" (kommt noch in derselben Nacht) oder "nextNight"; ohne Angabe gilt settings.leaderNotSameNight
local function leaderWaitsNight(rival)
  if rival.appear == 'sameNight' then return false end
  if rival.appear == 'nextNight' then return true end
  return settings().leaderNotSameNight ~= false
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
      if not teamMembersDefeated(rival.team, save, leaderWaitsNight(rival) and night or nil) then return false end
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
  -- Ein Leader, dessen Mitglieder alle geschlagen sind, kommt bevorzugt (settings.leaderChance)
  local fresh, beaten, leaders = {}, {}, {}
  for _, r in ipairs(data.rivals) do
    if isEligible(r, save) then
      table.insert(save.defeated[r.id] and beaten or fresh, r)
      if r.leader and not save.defeated[r.id] then table.insert(leaders, r) end
    end
  end
  if #leaders > 0 and math.random() < (settings().leaderChance or 0.7) then return leaders[math.random(#leaders)] end
  local rw = (settings().rematch or {}).weight or 0.25
  if #fresh > 0 and (#beaten == 0 or math.random() >= rw) then return fresh[math.random(#fresh)] end
  if #beaten > 0 then return rematchOf(beaten[math.random(#beaten)], save) end
  return nil
end

-- Spawnen -----------------------------------------------------------------------

-- Fahrtrichtung auf Einbahn-Kanten. Auf C1 passte inNode -> outNode nicht immer zur echten Fahrtrichtung,
-- deshalb lernen wir sie vom Verkehr: Wie fahren die KI-Autos auf Einbahn-Kanten? (+1 = inNode -> outNode)
local oneWaySign, oneWayVotes = nil, { plus = 0, minus = 0 }
local calibTimer = 0

local function isRivalVeh(id)
  for _, e in ipairs(onRoad) do if e.vehId == id then return true end end
  return false
end

local function calibrateOneWay(player)
  local nodes = map.getMap().nodes
  if not nodes then return end
  local pid = player and player:getID()
  for i = 0, be:getObjectCount() - 1 do
    local o = be:getObject(i)
    if o and o:getID() ~= pid and not isRivalVeh(o:getID()) then
      local vel = o:getVelocity()
      if vel and vel:length() > 8 then
        local p = o:getPosition()
        local n1, n2, dist = map.findClosestRoad(p)
        local l = n1 and n2 and nodes[n1] and nodes[n1].links and nodes[n1].links[n2]
        if l and dist and dist < 5 and l.oneWay and l.inNode and l.outNode and nodes[l.inNode] and nodes[l.outNode] then
          local d = (nodes[l.outNode].pos - nodes[l.inNode].pos):normalized():dot(vel:normalized())
          if d > 0.7 then oneWayVotes.plus = oneWayVotes.plus + 1 elseif d < -0.7 then oneWayVotes.minus = oneWayVotes.minus + 1 end
        end
      end
    end
  end
  local total = oneWayVotes.plus + oneWayVotes.minus
  if total >= 6 then
    local sign = oneWayVotes.plus >= oneWayVotes.minus and 1 or -1
    if sign ~= oneWaySign then
      log('I', logTag, string.format('Einbahn-Richtung vom Verkehr gelernt: %s (%d / %d)', sign > 0 and 'inNode->outNode' or 'outNode->inNode', oneWayVotes.plus, oneWayVotes.minus))
    end
    oneWaySign = sign
    -- weiter lernen, aber alte Stimmen langsam vergessen
    if total > 60 then oneWayVotes.plus, oneWayVotes.minus = oneWayVotes.plus * 0.5, oneWayVotes.minus * 0.5 end
  end
end

-- Darf man von `from` nach `to` fahren? nil = Richtung noch unbekannt (Einbahn, aber noch nichts gelernt)
local function linkAllowed(nodes, from, to)
  local l = nodes[from] and nodes[from].links and nodes[from].links[to]
  if not l then return false, nil end
  if not (l.oneWay and l.inNode and l.outNode) then return true, l end
  if not oneWaySign then return nil, l end
  local forward = (l.inNode == from) == (oneWaySign > 0)
  return forward, l
end

-- Suche über die nächste Straße am Zielpunkt (Rückfall, falls das Straßennetz unterwegs endet).
-- Einbahn-Kanten in Gegenrichtung (= Gegenfahrbahn) werden abgelehnt.
local function closestRoadSpawn(pos, dir, distance)
  local target = pos + dir * distance
  local n1, n2 = map.findClosestRoad(target)
  if not n1 or not n2 then return nil, 'keine Straße am Ziel' end
  local nodes = map.getMap().nodes
  if not nodes[n1] or not nodes[n2] then return nil, 'Knoten fehlt' end
  local np = nodes[n1].pos
  if math.abs(np.z - target.z) > 8 or (vec3(np.x, np.y, 0) - vec3(target.x, target.y, 0)):length() > 25 then return nil, 'Ziel neben der Straße' end
  local p1, p2 = nodes[n1].pos, nodes[n2].pos
  local seg = p2 - p1
  local segLen2 = seg:squaredLength()
  if segLen2 < 0.01 then return nil, 'Kante zu kurz' end
  local t = clamp((target - p1):dot(seg) / segLen2, 0, 1)
  local a, b = n1, n2
  if seg:dot(dir) < 0 then a, b = n2, n1 end
  local ok = linkAllowed(nodes, a, b)
  if ok == nil then return nil, 'Einbahn-Richtung noch unbekannt' end
  if not ok then return nil, 'Gegenfahrbahn' end
  return p1 + seg * t + vec3(0, 0, 0.5), (nodes[b].pos - nodes[a].pos):normalized()
end

-- Läuft das Straßennetz entlang, in erlaubter Fahrtrichtung. Endet eine Straße (nicht verbundene Straßenstücke),
-- wird ein paar Meter weiter geradeaus die nächste passende Kante gesucht.
local function walkRoad(nodes, pos, dir, distance)
  local n1, n2 = map.findClosestRoad(pos)
  if not n1 or not n2 or not nodes[n1] or not nodes[n2] then return nil, 'Spieler nicht auf Straße' end
  local back = distance < 0
  local travel = back and dir * -1 or dir
  local prev, cur = n1, n2
  if (nodes[cur].pos - nodes[prev].pos):dot(travel) < 0 then prev, cur = cur, prev end
  local function allowed(from, to)
    if back then return linkAllowed(nodes, to, from) end
    return linkAllowed(nodes, from, to)
  end
  local okStart = allowed(prev, cur)
  if okStart == nil then return nil, 'Einbahn-Richtung noch unbekannt' end
  if not okStart then return nil, 'Spieler auf Gegenfahrbahn' end
  local remaining = math.abs(distance) - (nodes[cur].pos - pos):length()
  local heading = (nodes[cur].pos - nodes[prev].pos):normalized()
  local bridges, walked = 0, 0
  for _ = 1, 800 do
    local best, bestScore
    for nid in pairs(nodes[cur].links or {}) do
      if nid ~= prev and nodes[nid] then
        local ok, l = allowed(cur, nid)
        if ok then
          local d = nodes[nid].pos - nodes[cur].pos
          local len = d:length()
          if len > 0.1 then
            local align = (d / len):dot(heading)
            if align > 0 then
              -- geradeaus bevorzugen, breitere Hauptstraße vor Ausfahrt
              local score = align + ((l and l.drivability) or 1) * 0.1 + math.min(nodes[nid].radius or 0, 10) * 0.02
              if not bestScore or score > bestScore then best, bestScore = nid, score end
            end
          end
        end
      end
    end
    if not best then
      -- Lücke überbrücken: nächste Kante kurz voraus, die in dieselbe Richtung läuft
      local bridged = false
      if bridges < 20 then
        local probe = nodes[cur].pos + heading * 6
        local a, b, dist = map.findClosestRoad(probe)
        if a and b and dist and dist < 4 and nodes[a] and nodes[b] and a ~= cur and b ~= cur then
          local e = nodes[b].pos - nodes[a].pos
          if e:dot(heading) < 0 then a, b, e = b, a, e * -1 end
          if e:length() > 0.1 and e:normalized():dot(heading) > 0.8 and allowed(a, b) then
            bridges = bridges + 1
            remaining = remaining - (nodes[a].pos - nodes[cur].pos):length()
            prev, cur = cur, a
            bridged = true
          end
        end
      end
      if not bridged then return nil, string.format('Straßennetz endet nach %d m', math.floor(walked)) end
    else
      local seg = nodes[best].pos - nodes[cur].pos
      local len = seg:length()
      if remaining <= len then
        local t = math.max(remaining, 0) / len
        local fwd = seg:normalized()
        if back then fwd = fwd * -1 end
        return nodes[cur].pos + seg * t + vec3(0, 0, 0.5), fwd
      end
      remaining = remaining - len
      walked = walked + len
      heading = seg:normalized()
      prev, cur = cur, best
    end
  end
  return nil, 'zu viele Knoten'
end

-- Sucht einen Spawnpunkt `distance` m vor (negativ: hinter) dem Spieler auf seiner Fahrbahn.
-- Zuerst das Straßennetz entlang, sonst die nächste Straße am Ziel (beides nur in erlaubter Fahrtrichtung).
local function findRoadSpawn(pos, dir, distance)
  local nodes = map.getMap().nodes
  local p, d, why1
  if nodes then
    p, d = walkRoad(nodes, pos, dir, distance)
    if p then return p, d end
    why1 = d
  end
  p, d = closestRoadSpawn(pos, dir, distance)
  if p then return p, d end
  return nil, string.format('Netz: %s / Ziel: %s', tostring(why1), tostring(d))
end

-- Kein anderes Fahrzeug (Verkehr) in der Nähe des Spawnpunkts?
local function spawnFree(pos, radius)
  local ok, free = pcall(function()
    for i = 0, be:getObjectCount() - 1 do
      local o = be:getObject(i)
      if o and (o:getPosition() - pos):length() < radius then return false end
    end
    return true
  end)
  if not ok then return true end
  return free
end

-- Abstand zum nächsten Fahrzeug vor einem Punkt in Fahrtrichtung (für das Losrollen)
local function gapAhead(veh, dir, range)
  local best = range
  local p = veh:getPosition()
  for i = 0, be:getObjectCount() - 1 do
    local o = be:getObject(i)
    if o and o:getID() ~= veh:getID() then
      local d = o:getPosition() - p
      local along = d:dot(dir)
      if along > 0 and along < best and (d - dir * along):length() < 4 then best = along end
    end
  end
  return best
end

local function setRotation(veh, pos, dir)
  local rot = quatFromDir(dir, vec3(0, 0, 1))
  if spawn and spawn.safeTeleport then
    spawn.safeTeleport(veh, pos, rot)
  else
    veh:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
  end
end

-- Reisetempo im Verkehr: vorsichtig (niedrige Aggression), Autos ausweichen, in der Spur bleiben.
-- Die Battle-Aggression aus rivals.json gilt erst im Battle.
local cruiseAggression = 0.3

function setCruise(veh, rival)
  local speed = (rival.cruiseKmh or 100) / 3.6
  veh:queueLuaCommand(string.format(
    "ai.setMode('traffic') ai.setAvoidCars('on') ai.setSpeedMode('limit') ai.setSpeed(%f) ai.setAggression(%f) ai.driveInLane('on')",
    speed, cruiseAggression))
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

  -- vor oder hinter dem Spieler, in Fahrtrichtung: neue Gegner fast immer vorne, Revanchen öfter auch hinten
  local behindChance = rival.rematch and (settings().spawnBehindRematch or 0.25) or (settings().spawnBehindNew or 0.05)
  local behind = not force and math.random() < behindChance
  local pos, dir, dist, failWhy
  for _ = 1, 4 do
    dist = behind and -(behindMin + math.random() * (behindMax - behindMin)) or (spawnMin + math.random() * (spawnMax - spawnMin))
    if force then dist = 160 end
    pos, dir = findRoadSpawn(player:getPosition(), player:getDirectionVector(), dist)
    if pos then
      if spawnFree(pos, 20) then break end
      failWhy = 'Verkehr am Spawnpunkt'
    else
      failWhy = dir
    end
    pos = nil
  end
  if not pos then
    log('I', logTag, 'Kein Rivalen-Spawnpunkt (' .. tostring(dist and math.floor(dist)) .. ' m): ' .. tostring(failWhy))
    if force then core().msg(core().t('msg.noRoad')) end
    return
  end

  local cfg, paint = spawnSetup(rival)
  local plateText = rival.plate and rival.plate.text
  local opts = { config = cfg, pos = pos, rot = quatFromDir(dir, vec3(0, 0, 1)), autoEnterVehicle = false, licenseText = plateText }
  if paint then opts.paint, opts.paint2, opts.paint3 = paint, paint, paint end
  local okSpawn, veh = pcall(core_vehicles.spawnNewVehicle, rival.model, opts)
  if (not okSpawn or not veh) and type(cfg) == 'table' then
    -- Ersatz: Original-Config ohne Kennzeichen-Design und Lack
    log('W', logTag, 'Rivale mit eigener Config nicht gespawnt, nehme Original: ' .. tostring(rival.id) .. ' ' .. tostring(veh))
    opts.config, opts.paint, opts.paint2, opts.paint3 = rival.config, nil, nil, nil
    okSpawn, veh = pcall(core_vehicles.spawnNewVehicle, rival.model, opts)
  end
  if not okSpawn then veh = nil end
  if veh and plateText then pcall(core_vehicles.setPlateText, plateText, veh:getID()) end
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
      .. (rival.rematch and core().t('msg.rematch') or '') .. (home().isWatched(rival.id) and core().t('msg.watched') or ''))
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
        -- nur so schnell, wie Platz nach vorne ist (sonst fährt er direkt ins nächste Verkehrsauto)
        local room = gapAhead(veh, e.spawnDir, 120)
        local launch = math.min((e.data.cruiseKmh or 100) / 3.6 * 0.8, room * 0.5)
        local v = e.spawnDir * launch
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

  calibTimer = calibTimer - dtSim
  if calibTimer <= 0 then
    calibTimer = 2
    pcall(calibrateOneWay, player)
  end

  cooldown = cooldown - dtSim
  if cooldown > 0 or busy then return end
  if player and player:getVelocity():length() > minSpawnSpeed then
    cooldown = spawnCooldown
    local ok, err = pcall(M.spawnNext, false)
    if not ok then log('E', logTag, 'Rivalen-Spawn fehlgeschlagen: ' .. tostring(err)) end
  end
end

local function onExtensionLoaded()
  M.loadData()
end

-- Leader-Status für Lexikon und Hinweis: 'members' (noch Mitglieder offen), 'nextNight' (letzte heute geschlagen), 'out' (unterwegs)
function M.leaderStatus(rival, save)
  save = save or core().save
  if not (rival and rival.leader and save) then return nil end
  if not teamMembersDefeated(rival.team, save) then return 'members' end
  if leaderWaitsNight(rival) and not teamMembersDefeated(rival.team, save, extensions.hashiriyaBattle_home.nightId()) then return 'nextNight' end
  return 'out'
end

function M.leaderOf(teamId) return leaderOf(teamId) end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate

return M
