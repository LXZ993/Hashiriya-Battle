-- Hashiriya Battle: Tankstelle
-- Der Tankinhalt kommt aus der Fahrzeug-Lua (energyStorage); Volltanken kostet je Liter.
local M = {}

local logTag = 'hashiriya'
local yenPerLiter = 175
local pollInterval = 1

local info = nil      -- { capacity, remaining } in Litern
local pollTimer = 0

local function core() return extensions.hashiriyaBattle_core end

local function atGas()
  local p = extensions.hashiriyaBattle_parking
  local a = p.isArrived() and p.getCurrent()
  return a and a.type == 'gas'
end

-- Fragt den Tankinhalt beim Auto ab; Antwort kommt über onFuelInfo.
local function request()
  local veh = core().getPlayerVehicle()
  if not veh then return end
  veh:queueLuaCommand([[
    local cap, rem = 0, 0
    for _, s in pairs(energyStorage.getStorages()) do
      if s.capacity and s.remainingVolume and s.setRemainingVolume then cap = cap + s.capacity; rem = rem + s.remainingVolume end
    end
    obj:queueGameEngineLua('if extensions.hashiriyaBattle_fuel then extensions.hashiriyaBattle_fuel.onFuelInfo(' .. cap .. ',' .. rem .. ') end')
  ]])
end

function M.onFuelInfo(capacity, remaining)
  info = { capacity = tonumber(capacity) or 0, remaining = tonumber(remaining) or 0 }
end

local function missingLiters()
  if not info or info.capacity <= 0 then return 0 end
  return math.max(0, info.capacity - info.remaining)
end

local function cost()
  return math.floor(missingLiters() * yenPerLiter / 10 + 0.5) * 10
end

function M.refuel()
  local c = core()
  local veh = c.getPlayerVehicle()
  if not veh or not c.save or not atGas() then return end
  local liters, price = missingLiters(), cost()
  if liters < 0.5 then return end
  if c.save.money < price then
    c.msg(c.t('msg.noMoney'))
    return
  end
  c.save.money = c.save.money - price
  pcall(function() core_vehicleBridge.executeAction(veh, 'setIgnitionLevel', 0) end)
  veh:queueLuaCommand([[
    for _, s in pairs(energyStorage.getStorages()) do
      if s.capacity and s.setRemainingVolume then s:setRemainingVolume(s.capacity) end
    end
  ]])
  info.remaining = info.capacity
  c.writeSave()
  c.msg(c.t('msg.refueled', string.format('%.1f', liters), c.economy().formatYen(price)), 5)
  log('I', logTag, string.format('Getankt: %.1f l für %d Yen', liters, price))
end

function M.getUiState()
  if not info then return { loading = true } end
  local c = core()
  local price = cost()
  return {
    level = info.capacity > 0 and math.floor(info.remaining / info.capacity * 100 + 0.5) or 0,
    liters = string.format('%.1f / %.0f l', info.remaining, info.capacity),
    perLiter = c.economy().formatYen(yenPerLiter),
    cost = c.economy().formatYen(price),
    full = missingLiters() < 0.5,
    affordable = c.save and c.save.money >= price,
  }
end

local function onUpdate(dtReal)
  if not atGas() then
    info = nil
    return
  end
  pollTimer = pollTimer - dtReal
  if pollTimer <= 0 then
    pollTimer = pollInterval
    request()
  end
end

M.onUpdate = onUpdate

return M
