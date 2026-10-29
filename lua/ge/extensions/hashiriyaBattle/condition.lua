-- Hashiriya Battle: Zustand (Laufleistung und Verschleiß) des Spielerautos
-- Starterautos sind gebraucht (Seed-System in career.lua, cars.json: conditionRange). BeamNG rechnet daraus über partCondition
-- Reibung und Zündaussetzer am Motor. Pro Teil merken wir Laufleistung und Grundzustand am Auto im Spielstand
-- (car.parts) und setzen beides nach jedem Respawn wieder. Neu gekaufte Teile starten neu (0 km, Zustand 1).
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
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
local function apply(veh, car, fresh)
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
  -- Kühler: Zustand des Kühlerteils, sonst Grundzustand
  local radInteg = tbl == 'nil' and integ or (wear.integrity or 1)
  for id, p in pairs(parts or {}) do
    if tostring(id):find('radiator') then radInteg = p.i or 1 break end
  end
  local cd = core().carsData or {}
  -- BeamNG setzt bei Zustand < 1 auch den Tank auf denselben Anteil und lässt den Motor stark aussetzen.
  -- Darum: Zündaussetzer abschwächen (conditionMisfireScale), Tank beim Kauf nie unter conditionMinFuel,
  -- bei einem Respawn den Tankinhalt unverändert lassen. Danach den Reset-Stand neu speichern (R-Taste, Reparatur).
  veh:queueLuaCommand(string.format([[
    if partCondition then
      local fresh, minFuel, misfire, cooling, fuelShare = %s, %f, %f, %f, %f
      local before = {}
      for name, st in pairs(energyStorage.getStorages()) do
        if st.capacity and st.remainingVolume then before[name] = st.remainingVolume end
      end
      pcall(partCondition.reset)
      partCondition.initConditions(%s, %f, %f, %f)
      for _, e in ipairs(powertrain.getDevicesByCategory('engine') or {}) do
        if e.fastIgnitionErrorChance then e.fastIgnitionErrorChance = e.fastIgnitionErrorChance * misfire end
        if e.slowIgnitionErrorChance then e.slowIgnitionErrorChance = e.slowIgnitionErrorChance * misfire end
        -- Überhitzen abschwächen: Reibung und Kühler (weniger Kühlmittel, Kühlerschaden) nur anteilig
        if e.damageDynamicFrictionCoef then e.damageDynamicFrictionCoef = 1 + (e.damageDynamicFrictionCoef - 1) * cooling end
        if e.damageFrictionCoef then e.damageFrictionCoef = 1 + (e.damageFrictionCoef - 1) * cooling end
        if e.thermals and e.thermals.setPartConditionRadiator then
          pcall(e.thermals.setPartConditionRadiator, %f, 1 - (1 - %f) * cooling, 1)
        end
      end
      for name, st in pairs(energyStorage.getStorages()) do
        if st.capacity and st.setRemainingVolume and st.remainingVolume then
          if fresh then
            -- Kaufzustand: Tank aus dem Seed (fuelShare), sonst BeamNG-Wert; nie unter minFuel
            local want = fuelShare >= 0 and math.max(fuelShare, minFuel) or math.max(st.remainingVolume / st.capacity, minFuel)
            st:setRemainingVolume(st.capacity * want)
          elseif before[name] then
            st:setRemainingVolume(before[name])
          end
        end
      end
      pcall(partCondition.createConditionSnapshot, 'reset')
    end
  ]], tostring(fresh == true), cd.conditionMinFuel or 0.25, cd.conditionMisfireScale or 0.1, cd.conditionCoolingScale or 0.4,
      wear.fuel or -1,
      tbl, odo, integ, vis, odo, radInteg))
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
  car.wear = { odometerKm = condition.odometerKm or 0, integrity = condition.integrity or 1, visual = condition.visual or 1, fuel = condition.fuel }
  car.parts = nil
  if veh then apply(veh, car, true) end
end

-- Starterautos im Spielstand an geänderte Werte aus cars.json anpassen (Balancing beim Testen):
-- Grundzustand und Zustand der Originalteile neu, Laufleistung bleibt.
function M.syncStarterWear(save)
  local cd = core().carsData or {}
  for _, car in ipairs(save and save.cars or {}) do
    if car.wear and not car.seeded then
      for _, st in ipairs(cd.starterCars or {}) do
        local cond = st.condition
        if cond and st.model == car.model and (car.wearFrom == nil or car.wearFrom == st.id) then
          local oldI, oldV = car.wear.integrity, car.wear.visual
          if oldI ~= cond.integrity or oldV ~= cond.visual then
            car.wear.integrity, car.wear.visual = cond.integrity or 1, cond.visual or 1
            for _, p in pairs(car.parts or {}) do
              if p.i == oldI then p.i = car.wear.integrity end
              if p.v == oldV then p.v = car.wear.visual end
            end
            log('I', logTag, 'Zustand des Starterautos an cars.json angepasst: ' .. tostring(car.model))
          end
          car.wearFrom = st.id
          break
        end
      end
    end
  end
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
