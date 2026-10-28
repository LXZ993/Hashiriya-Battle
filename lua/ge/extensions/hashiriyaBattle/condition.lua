-- Hashiriya Battle: Zustand (Laufleistung und Verschleiß) des Spielerautos
-- Starterautos sind gebraucht (cars.json: starterCars[].condition). BeamNG rechnet daraus über partCondition
-- Reibung und Zündaussetzer am Motor. Pro Teil merken wir Laufleistung und Grundzustand am Auto im Spielstand
-- (car.parts) und setzen beides nach jedem Respawn wieder. Neu gekaufte Teile starten neu (0 km, Zustand 1).
local M = {}

local logTag = 'hashiriya'
local pollInterval = 10

local pollTimer = pollInterval
local restoreWindow = 0  -- nach keepAfterRespawn: nächster Spawn des Spielerautos bekommt den Zustand
local restoreTimer = nil
local pending = nil      -- Zustand für das gerade gespawnte Auto

local function core() return extensions.hashiriyaBattle_core end

local function activeCar()
  local save = core().save
  return save and save.cars and save.cars[save.activeCar or 1] or nil
end

-- Zustand ins Auto schreiben: parts = { [partId] = { o, i, v } } oder nur Grundwerte (frisch gekaufter Gebrauchtwagen)
local function apply(veh, car)
  local wear = car.wear or {}
  local parts = car.parts
  local tbl = 'nil'
  if parts and next(parts) then
    local list = {}
    for id, p in pairs(parts) do
      list[id] = { odometer = p.o or 0, integrityValue = p.i or 1, visualValue = p.v or 1 }
    end
    tbl = serialize(list)
  end
  -- Ohne Teile-Liste: Grundwerte für alle Teile. Mit Liste: fehlende (neue) Teile frisch.
  local odo, integ, vis = 0, 1, 1
  if tbl == 'nil' then odo, integ, vis = (wear.odometerKm or 0) * 1000, wear.integrity or 1, wear.visual or 1 end
  veh:queueLuaCommand(string.format([[
    if partCondition then
      pcall(partCondition.reset)
      partCondition.initConditions(%s, %f, %f, %f)
    end
  ]], tbl, odo, integ, vis))
  pollTimer = 2
  log('I', logTag, string.format('Fahrzeugzustand gesetzt (%s)', tbl == 'nil' and 'Grundwerte' or 'je Teil'))
end

-- Laufleistung je Teil abfragen; Antwort über onConditions
local function request(veh)
  veh:queueLuaCommand([[
    if partCondition then
      local c = partCondition.getConditions()
      if c then
        local out = {}
        for id, p in pairs(c) do out[id] = math.floor(p.odometer or 0) end
        obj:queueGameEngineLua('if extensions.hashiriyaBattle_condition then extensions.hashiriyaBattle_condition.onConditions(' .. serialize(out) .. ') end')
      end
    end
  ]])
end

function M.onConditions(list)
  local car = activeCar()
  if not car or type(list) ~= 'table' or restoreTimer or restoreWindow > 0 then return end
  local old = car.parts or {}
  local wear = car.wear or {}
  local parts = {}
  local first = not car.parts
  for id, odo in pairs(list) do
    local p = old[id]
    if p then
      parts[id] = { o = odo, i = p.i, v = p.v }
    elseif first then
      -- erste Abfrage nach dem Kauf: alle Teile haben den Grundzustand
      parts[id] = { o = odo, i = wear.integrity or 1, v = wear.visual or 1 }
    else
      parts[id] = { o = odo, i = 1, v = 1 } -- neu eingebaut
    end
  end
  car.parts = parts
  local root = 0
  for _, p in pairs(parts) do root = math.max(root, p.o or 0) end
  car.odometerKm = math.floor(root / 1000 + 0.5)
end

-- Frisch gekaufter Gebrauchtwagen (Starter, später Händler): Grundzustand setzen und sofort anwenden
function M.initUsedCar(car, condition, veh)
  if not car then return end
  condition = condition or {}
  car.wear = { odometerKm = condition.odometerKm or 0, integrity = condition.integrity or 1, visual = condition.visual or 1 }
  car.parts = nil
  if veh then apply(veh, car) end
end

-- Vor einem Respawn des Spielerautos (über core.engineOffAfterSpawn)
function M.keepAfterRespawn() restoreWindow = 5 end

function M.onVehicleSpawned(vehId)
  if restoreWindow <= 0 then return end
  local veh = be:getObjectByID(vehId)
  if not veh or veh:getJBeamFilename() == 'unicycle' then return end
  restoreWindow = 0
  pending = vehId
  restoreTimer = 1
end

function M.onUpdate(dtReal)
  if restoreWindow > 0 then restoreWindow = restoreWindow - dtReal end
  local c = core()
  if restoreTimer then
    restoreTimer = restoreTimer - dtReal
    if restoreTimer <= 0 then
      restoreTimer = nil
      local veh = pending and be:getObjectByID(pending)
      local car = activeCar()
      pending = nil
      if veh and car and (car.wear or car.parts) then apply(veh, car) end
    end
    return
  end
  if not c or not c.active then return end
  pollTimer = pollTimer - dtReal
  if pollTimer > 0 then return end
  pollTimer = pollInterval
  local car = activeCar()
  local veh = c.getPlayerVehicle()
  if car and veh and (car.wear or car.parts) and veh:getJBeamFilename() == car.model then request(veh) end
end

return M
