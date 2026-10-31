-- Hashiriya Battle: Tankstelle (24/7)
-- Tanken solange der Knopf gedrückt ist: der Sprit läuft in Echtzeit, bezahlt wird je Liter.
-- Nachts (nightFrom bis nightTo aus data/world.json) ist der Liter teurer.
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
local yenPerLiter = 175
local nightFactor = 1.45     -- Nachtzuschlag
local litersPerSecond = 1.2
local pollInterval = 1

local info = nil      -- { capacity, remaining } in Litern
local pollTimer = 0
local holding = false
local session = nil   -- laufender Tankvorgang { liters, cost }
local restoreTimer = nil -- nach einem Respawn: Tankinhalt zurücksetzen statt voll
local restoreWindow = 0

local function core() return extensions.hashiriyaBattle_core end

local function atGas()
  local p = extensions.hashiriyaBattle_parking
  local a = p.isArrived() and p.getCurrent()
  return a and a.type == 'gas'
end

-- Nacht wie in data/world.json (dieselbe Uhr wie für die Battles)
local function isNight()
  return extensions.hashiriyaBattle_home.isNight()
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

local function activeCar()
  local save = core().save
  return save and save.cars and save.cars[save.activeCar or 1] or nil
end

function M.onFuelInfo(capacity, remaining)
  if session then return end -- während des Tankens zählen wir selbst
  info = { capacity = tonumber(capacity) or 0, remaining = tonumber(remaining) or 0 }
  -- Tankinhalt am Auto im Spielstand merken (nicht, solange ein Respawn noch zurückgesetzt wird)
  local car = activeCar()
  if car and info.capacity > 0 and not restoreTimer and restoreWindow <= 0 then car.fuel = info.remaining end
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

-- Vor einem Respawn des Spielerautos aufrufen (Teile, Setup, Garage, Weiterspielen):
-- BeamNG füllt beim Spawnen den Tank, wir setzen danach den gemerkten Inhalt wieder.
-- Dev-Tool: Tank gratis voll
function M.devFill()
  local veh = core().getPlayerVehicle()
  if not veh then return end
  setTotal(veh, 9999)
  local car = activeCar()
  if car and info and info.capacity and info.capacity > 0 then car.fuel = info.capacity end
end

function M.keepAfterRespawn() restoreWindow = 5 end

function M.onVehicleSpawned(vehId)
  if restoreWindow <= 0 then return end
  -- Showroom im Starterkauf: Tank kommt aus dem angezeigten Zustand (condition.previewAfterSpawn)
  local career = extensions.hashiriyaBattle_career
  if career and career.isOpen and career.isOpen() then restoreWindow = 0 return end
  local veh = be:getObjectByID(vehId)
  if not veh or veh:getJBeamFilename() == 'unicycle' then return end
  restoreTimer = 1
end

-- Zurücksetzen (Reparatur, Abschleppen, R-Taste) füllt in BeamNG ebenfalls den Tank
function M.onVehicleResetted(vehId)
  local veh = core().getPlayerVehicle()
  if not veh or veh:getID() ~= vehId or session then return end
  restoreTimer = 0.5
end

local function restore()
  restoreTimer = nil
  restoreWindow = 0
  local car = activeCar()
  local veh = core().getPlayerVehicle()
  if not car or not veh or not car.fuel then return end
  setTotal(veh, car.fuel)
  info = nil
  pollTimer = 0.5
  log('I', logTag, string.format('Tankinhalt nach Respawn: %.1f l', car.fuel))
end

-- Tanksound: Schleife wie im BeamNG-Karrieremodus (createSource + play/stop), playOnce liefe endlos
local fuelSoundId = nil
local function fuelSound(on)
  pcall(function()
    if on and not fuelSoundId then fuelSoundId = Engine.Audio.createSource('AudioGui', 'event:>UI>Career>Fueling_Petrol') end
    local snd = fuelSoundId and scenetree.findObjectById(fuelSoundId)
    if not snd then return end
    if on then snd:play(-1) else snd:stop(-1) end
    snd:setTransform(getCameraTransform())
  end)
end

local function finish()
  fuelSound(false)
  holding = false
  local s = session
  session = nil
  if not s or s.liters < 0.05 then return end
  local c = core()
  local pr = extensions.hashiriyaBattle_progress
  pr.bump(c.save, 'fuelLiters', s.liters)
  pr.bump(c.save, 'fuelCost', s.cost)
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
    fuelSound(true)
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
  if restoreWindow > 0 then restoreWindow = restoreWindow - dtReal end
  if restoreTimer then
    restoreTimer = restoreTimer - dtReal
    if restoreTimer <= 0 then restore() end
    return
  end
  local gas = atGas()
  if not gas and session then finish() end
  if gas and holding and session and info then
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
    pollTimer = gas and pollInterval or 3
    if core().save then request() end
  end
end

M.onUpdate = onUpdate
M.onClientEndMission = function() fuelSoundId = nil end

return M
