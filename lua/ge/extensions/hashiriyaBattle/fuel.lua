-- Hashiriya Battle: Tankstelle (24/7)
-- Tanken solange der Knopf gedrückt ist: der Sprit läuft in Echtzeit, bezahlt wird je Liter.
-- Nachts (nightFrom bis nightTo Uhr) ist der Liter teurer.
local M = {}

local logTag = 'hashiriya'
local yenPerLiter = 175
local nightFactor = 1.45     -- Nachtzuschlag
local nightFrom, nightTo = 20, 6
local litersPerSecond = 1.2
local pollInterval = 1

local info = nil      -- { capacity, remaining } in Litern
local pollTimer = 0
local holding = false
local session = nil   -- laufender Tankvorgang { liters, cost }

local function core() return extensions.hashiriyaBattle_core end

local function atGas()
  local p = extensions.hashiriyaBattle_parking
  local a = p.isArrived() and p.getCurrent()
  return a and a.type == 'gas'
end

local function isNight()
  local ok, tod = pcall(function() return core_environment.getTimeOfDay() end)
  local t = ok and tod and tonumber(tod.time)
  if not t then return false end
  local hour = (t * 24 + 12) % 24
  return hour >= nightFrom or hour < nightTo
end

local function pricePerLiter()
  return isNight() and math.floor(yenPerLiter * nightFactor + 0.5) or yenPerLiter
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
  if session then return end -- während des Tankens zählen wir selbst
  info = { capacity = tonumber(capacity) or 0, remaining = tonumber(remaining) or 0 }
end

-- Gesamtmenge im Auto setzen (Tanks der Reihe nach füllen)
local function setTotal(veh, liters)
  veh:queueLuaCommand(string.format([[
    local left = %f
    for _, s in pairs(energyStorage.getStorages()) do
      if s.capacity and s.setRemainingVolume then
        local v = math.min(s.capacity, math.max(0, left))
        s:setRemainingVolume(v)
        left = left - v
      end
    end
  ]], liters))
end

local function finish()
  holding = false
  local s = session
  session = nil
  if not s or s.liters < 0.05 then return end
  local c = core()
  c.writeSave()
  c.msg(c.t('msg.refueled', string.format('%.1f', s.liters), c.economy().formatYen(s.cost)), 5)
  log('I', logTag, string.format('Getankt: %.1f l für %d Yen', s.liters, s.cost))
end

-- Knopf gedrückt (true) / losgelassen (false)
function M.setHolding(on)
  local c = core()
  local veh = c.getPlayerVehicle()
  if on then
    if not veh or not c.save or not atGas() or not info or info.remaining >= info.capacity - 0.05 then return end
    if c.save.money < pricePerLiter() then
      c.msg(c.t('msg.noMoney'))
      return
    end
    holding = true
    session = { liters = 0, cost = 0, paid = 0 }
    pcall(function() core_vehicleBridge.executeAction(veh, 'setIgnitionLevel', 0) end)
    c.sound('fuel')
  else
    finish()
  end
end

function M.isHolding() return holding end

function M.getUiState()
  if not info then return { loading = true } end
  local c = core()
  local free = math.max(0, info.capacity - info.remaining)
  return {
    level = info.capacity > 0 and math.floor(info.remaining / info.capacity * 100 + 0.5) or 0,
    liters = string.format('%.1f / %.0f l', info.remaining, info.capacity),
    perLiter = c.economy().formatYen(pricePerLiter()),
    night = isNight(),
    fullCost = c.economy().formatYen(math.floor(free * pricePerLiter() / 10 + 0.5) * 10),
    session = session and { liters = string.format('%.1f l', session.liters), cost = c.economy().formatYen(session.cost) } or nil,
    holding = holding,
    full = free < 0.05,
    affordable = c.save and c.save.money >= pricePerLiter(),
  }
end

local function onUpdate(dtReal)
  if not atGas() then
    if session then finish() end
    info = nil
    return
  end
  if holding and session and info then
    local c = core()
    local veh = c.getPlayerVehicle()
    local price = pricePerLiter()
    local add = math.min(litersPerSecond * dtReal, info.capacity - info.remaining)
    -- nur so viel, wie das Geld reicht
    add = math.min(add, (c.save.money) / price)
    if not veh or add <= 0 then
      finish()
      return
    end
    info.remaining = info.remaining + add
    session.liters = session.liters + add
    local total = math.floor(session.liters * price + 0.5)
    c.save.money = c.save.money - (total - session.paid)
    session.paid = total
    session.cost = total
    setTotal(veh, info.remaining)
    if info.remaining >= info.capacity - 0.01 or c.save.money < 1 then finish() end
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
