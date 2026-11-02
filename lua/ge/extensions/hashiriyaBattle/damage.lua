-- Hashiriya Battle: Unfallschaden des Spielerautos im Spielstand behalten
-- BeamNG speichert Beulen, gebrochene Teile und Motorschäden nicht. Darum sichern wir sie selbst, je Auto eine Datei
-- settings/hashiriya_battle/damage/<car.uid>.json, und spielen sie nach dem Spawnen wieder auf das Auto:
-- - Knotenpositionen (im Fahrzeug-Koordinatensystem, damit es an jedem Ort und in jeder Richtung passt),
--   Balken (Ruhelänge, gebrochen, Verformung) -> über beamstate.load; gebrochene Balken brechen dabei wieder,
--   abgefallene Teile fallen also wieder ab.
-- - Motorschaden je Motor (Reibung, Zündaussetzer, Zylinderkopfdichtung usw.) und Kühler (Leck, Kühlmittel).
-- - Schadenswert (Reparaturpreis) über beamstate.damageExt.
-- Gesichert wird automatisch, sobald sich der Schaden ändert und 3 s ruhig bleibt. Fällt der Schaden auf 0
-- (Reparatur), wird die Datei gelöscht. Passt die Datei nicht mehr zum Auto (andere Teile, andere Knotenzahl),
-- lehnt beamstate.load sie ab und das Auto bleibt heil.
local M = {}

local logTag = 'hashiriya'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local dir = 'settings/hashiriya_battle/damage/'
local minDamage = 5      -- darunter gilt das Auto als heil (wie parking.repairCost: Preis 0)
local settleTime = 3     -- so lange muss der Schaden gleich bleiben, bevor gesichert wird
local restoreDelay = 2.5 -- nach dem Spawn: erst nach dem Verschleiß (condition.lua, 1 s) aufspielen

local lastDamage = nil
local stableTimer = 0
local savedDamage = nil  -- Schaden, der zuletzt gesichert wurde
local savedFor = nil     -- uid des Autos, für das savedDamage gilt
local suppress = 0       -- keine Sicherung (Spawn, Reparatur)
local restoreWindow = 0
local restoreVeh = nil
local restoreTimer = nil

local function core() return extensions.hashiriyaBattle_core end

local function activeCar()
  local save = core().save
  return save and save.cars and save.cars[save.activeCar or 1] or nil
end

local function carUid(car, create)
  if not car then return nil end
  if not car.uid and create then
    car.uid = string.format('%x%x', os.time(), math.random(0, 0xfffffff))
    core().writeSave()
  end
  return car.uid
end

local function pathOf(uid) return dir .. uid .. '.json' end

local function playerDamage(veh)
  local o = veh and map.objects[veh:getID()]
  return o and o.damage or 0
end

local function removeFile(uid)
  local p = pathOf(uid)
  if FS:fileExists(p) then
    FS:removeFile(p)
    log('I', logTag, 'Schaden: Datei gelöscht (Auto heil)')
  end
end

-- Schaden des Spielerautos in die Datei schreiben (läuft im Fahrzeug-Lua, schreibt dort direkt)
local function snapshot(veh, uid)
  veh:queueLuaCommand(string.format([[
    local path = %q
    local dir = obj:getDirectionVector():normalized()
    local up = obj:getDirectionVectorUp():normalized()
    local right = dir:cross(up):normalized()
    up = right:cross(dir):normalized()
    local s = { format = 'hb1', model = v.data.model, vehicleDirectory = v.data.vehicleDirectory,
      nodeCount = tableSizeC(v.data.nodes), beamCount = tableSizeC(v.data.beams), damage = beamstate.damage,
      nodes = {}, beams = {}, engines = {} }
    for _, node in pairs(v.data.nodes) do
      local p = obj:getNodePosition(node.cid)
      local d = { p:dot(right), p:dot(dir), p:dot(up) }
      if math.abs(obj:getOriginalNodeMass(node.cid) - obj:getNodeMass(node.cid)) > 0.1 then d[4] = obj:getNodeMass(node.cid) end
      s.nodes[node.cid + 1] = d
    end
    for _, beam in pairs(v.data.beams) do
      s.beams[beam.cid + 1] = { obj:getBeamRestLength(beam.cid), obj:beamIsBroken(beam.cid), obj:getBeamDeformation(beam.cid) }
    end
    for _, e in ipairs(powertrain.getDevicesByCategory('engine') or {}) do
      if e.getPartCondition then
        local okM, _, main = pcall(e.getPartCondition, e, nil)
        local okR, _, rad = pcall(e.getPartCondition, e, 'radiator')
        s.engines[e.name] = { main = okM and main or nil, radiator = okR and rad or nil }
      end
    end
    jsonWriteFile(path, s, false)
  ]], pathOf(uid)))
end

-- Gesicherten Schaden auf das frisch gespawnte Auto spielen
local function restore(veh, uid)
  veh:queueLuaCommand(string.format([[
    local s = jsonReadFile(%q)
    if not s or s.format ~= 'hb1' then return end
    if s.vehicleDirectory ~= v.data.vehicleDirectory or s.nodeCount ~= tableSizeC(v.data.nodes) or s.beamCount ~= tableSizeC(v.data.beams) then
      log('W', 'hashiriya', 'Schaden: Datei passt nicht zum Auto (andere Teile), nicht aufgespielt')
      return
    end
    local dir = obj:getDirectionVector():normalized()
    local up = obj:getDirectionVectorUp():normalized()
    local right = dir:cross(up):normalized()
    up = right:cross(dir):normalized()
    local out = { format = 'v2', model = v.data.model, vehicleDirectory = v.data.vehicleDirectory,
      nodeCount = s.nodeCount, beamCount = s.beamCount, luaState = serialize({}), hydros = {}, nodes = {}, beams = s.beams }
    for i, d in pairs(s.nodes) do
      local p = right * d[1] + dir * d[2] + up * d[3]
      local n = { p.x, p.y, p.z }
      out.nodes[i] = d[4] and { n, d[4] } or { n }
    end
    local tmp = 'settings/hashiriya_battle/damage/_load.json'
    jsonWriteFile(tmp, out, false)
    beamstate.load(tmp)
    -- Motor und Kühler
    local odo = partCondition and partCondition.getRootPartOdometerValue and partCondition.getRootPartOdometerValue() or 0
    for _, e in ipairs(powertrain.getDevicesByCategory('engine') or {}) do
      local st = s.engines and s.engines[e.name]
      if st and e.setPartCondition then
        if st.main then pcall(e.setPartCondition, e, nil, odo, st.main, 1) end
        if st.radiator then pcall(e.setPartCondition, e, 'radiator', odo, st.radiator, 1) end
      end
    end
    beamstate.damageExt = math.max(0, (s.damage or 0) - obj:getDissipatedEnergy())
    log('I', 'hashiriya', 'Schaden aufgespielt: ' .. tostring(math.floor(s.damage or 0)))
  ]], pathOf(uid)))
end

-- Vor einem Spawn des Spielerautos aus dem Spielstand (Weiterspielen, Autowechsel): Schaden danach aufspielen
function M.restoreAfterSpawn()
  restoreWindow = 5
  suppress = math.max(suppress, 5 + restoreDelay + settleTime)
end

-- Reparatur: Datei sofort löschen (nicht erst nach der Ruhezeit), damit ein Neuladen das Auto heil lässt
function M.clear()
  local uid = carUid(activeCar(), false)
  if uid then removeFile(uid) end
  savedDamage, savedFor = 0, uid
  suppress = settleTime + 1
end

-- Gibt es für das aktive Auto gesicherten Schaden? (z. B. für Anzeigen)
function M.hasSaved()
  local uid = carUid(activeCar(), false)
  return uid and FS:fileExists(pathOf(uid)) or false
end

function M.onVehicleSpawned(vehId)
  if restoreWindow <= 0 then return end
  local veh = be:getObjectByID(vehId)
  if not veh or veh:getJBeamFilename() == 'unicycle' then return end
  restoreWindow = 0
  restoreVeh = vehId
  restoreTimer = restoreDelay
  lastDamage, stableTimer = nil, 0
end

function M.onUpdate(dtReal)
  if restoreWindow > 0 then restoreWindow = restoreWindow - dtReal end
  if suppress > 0 then suppress = suppress - dtReal end
  local c = core()
  if restoreTimer then
    restoreTimer = restoreTimer - dtReal
    if restoreTimer > 0 then return end
    restoreTimer = nil
    local veh = restoreVeh and be:getObjectByID(restoreVeh)
    local car = activeCar()
    local uid = carUid(car, false)
    restoreVeh = nil
    if c and c.active and veh and car and uid and veh:getJBeamFilename() == car.model and FS:fileExists(pathOf(uid)) then
      restore(veh, uid)
    end
    suppress = math.max(suppress, settleTime + 1)
    savedDamage, savedFor = nil, uid
    return
  end
  if not c or not c.active or not c.save or suppress > 0 then return end
  local car = activeCar()
  local veh = c.getPlayerVehicle()
  if not car or not veh or veh:getJBeamFilename() ~= car.model then return end
  local dmg = playerDamage(veh)
  if lastDamage == nil or math.abs(dmg - lastDamage) > 1 then
    lastDamage, stableTimer = dmg, 0
    return
  end
  stableTimer = stableTimer + dtReal
  if stableTimer < settleTime then return end
  local uid = carUid(car, dmg >= minDamage)
  if savedFor ~= uid then savedDamage, savedFor = nil, uid end
  if savedDamage and math.abs(dmg - savedDamage) <= 1 then return end
  savedDamage = dmg
  if not uid then return end
  if dmg < minDamage then
    removeFile(uid)
  else
    snapshot(veh, uid)
    log('I', logTag, 'Schaden gesichert: ' .. tostring(math.floor(dmg)))
  end
end

return M
