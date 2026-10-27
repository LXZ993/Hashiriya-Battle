-- Hashiriya Battle: Parkplätze (Garage, Tuning-Shop)
-- Die Parkplätze stehen in data/maps/<level>.json. Hält der Spieler in einem Parkplatz an,
-- öffnet sich das passende Menü; beim Wegfahren schließt es sich wieder.
local M = {}

local logTag = 'hashiriya'
local saveDir = 'settings/hashiriya_battle/'

local enterSpeed = 8 / 3.6   -- km/h -> m/s: unter diesem Tempo gilt man als "angekommen"
local checkInterval = 0.25
local repairYenPerDamage = 2 -- Reparaturpreis je BeamNG-Schadenspunkt (zum Feintuning)

local checkTimer = 0
local current = nil          -- Parkplatz, in dem der Spieler gerade steht
local arrived = false        -- im Parkplatz angehalten (Menü offen)
local dumpedModels = {}

local function core() return extensions.hashiriyaBattle_core end

local function areas()
  local mapData = core().mapData
  return mapData and mapData.parkingAreas or {}
end

local function toVec(t) return vec3(t[1], t[2], t[3]) end

function M.getCurrent()
  return current
end

function M.isArrived()
  return arrived and current ~= nil
end

-- Erster Parkplatz eines Typs, z. B. die Garage als Startpunkt.
function M.find(areaType)
  for _, a in ipairs(areas()) do
    if a.type == areaType then return a end
  end
  return nil
end

function M.spawnTransform(area)
  if not area then return nil end
  return toVec(area.pos) + vec3(0, 0, 0.3), quatFromDir(toVec(area.dir), vec3(0, 0, 1))
end

-- Reparatur ---------------------------------------------------------------------

local function playerDamage()
  local veh = core().getPlayerVehicle()
  local o = veh and map.objects[veh:getID()]
  return o and o.damage or 0
end

function M.repairCost()
  return math.floor(playerDamage() * repairYenPerDamage / 10) * 10
end

function M.repair()
  local c = core()
  local veh = c.getPlayerVehicle()
  if not veh or not c.save then return end
  local cost = M.repairCost()
  if cost <= 0 then return end
  if c.save.money < cost then
    c.msg(c.t('msg.noMoney'))
    return
  end
  c.save.money = c.save.money - cost
  veh:queueLuaCommand('obj:requestReset(RESET_PHYSICS)')
  c.writeSave()
  c.msg(c.t('msg.repaired', c.economy().formatYen(cost)))
end

-- Teile-Export (Grundlage für den Tuning-Katalog) --------------------------------
-- Schreibt die aktuellen Teile und alle verfügbaren Teile des Spielerautos nach
-- settings/hashiriya_battle/parts_<modell>.json.

local function plain(t, depth)
  if type(t) ~= 'table' then
    local tv = type(t)
    return (tv == 'string' or tv == 'number' or tv == 'boolean') and t or nil
  end
  if depth <= 0 then return nil end
  local out = {}
  for k, v in pairs(t) do
    if type(k) == 'string' or type(k) == 'number' then out[k] = plain(v, depth - 1) end
  end
  return out
end

function M.dumpParts(force)
  local c = core()
  local veh = c.getPlayerVehicle()
  if not veh then return end
  local model = veh:getJBeamFilename()
  if dumpedModels[model] and not force then return end
  dumpedModels[model] = true

  local out = { model = model }
  local ok, vd = pcall(function() return core_vehicle_manager.getPlayerVehicleData() end)
  if ok and vd then
    out.config = plain(vd.config, 4)
    local okParts, available = pcall(function() return jbeamIO.getAvailableParts(vd.ioCtx) end)
    if okParts and available then
      local parts = {}
      for name, info in pairs(available) do
        parts[name] = {
          slotType = info.slotType,
          description = info.description,
          value = info.value,
          authors = info.authors,
        }
      end
      out.availableParts = parts
    else
      out.availablePartsError = tostring(available)
    end
  else
    out.error = tostring(vd)
  end
  jsonWriteFile(saveDir .. 'parts_' .. model .. '.json', out, true)
  log('I', logTag, 'Teile-Export: ' .. model)
  if force then c.msg(c.t('msg.partsDump', model)) end
end

-- Update ------------------------------------------------------------------------

local function onUpdate(dtReal)
  local c = core()
  if not c or not c.active then
    current, arrived = nil, false
    return
  end
  checkTimer = checkTimer - dtReal
  if checkTimer > 0 then return end
  checkTimer = checkInterval

  local veh = c.getPlayerVehicle()
  if not veh then return end
  local pos = veh:getPosition()
  local found = nil
  for _, a in ipairs(areas()) do
    if (pos - toVec(a.pos)):length() <= (a.radius or 30) then found = a; break end
  end

  if found ~= current then
    if current and arrived then c.onParkingLeft(current) end
    current, arrived = found, false
  end
  if current and not arrived and veh:getVelocity():length() < enterSpeed
    and not extensions.hashiriyaBattle_battle.isBusy() then
    arrived = true
    if current.type == 'shop' then pcall(M.dumpParts, false) end
    c.onParkingArrived(current)
  end
end

M.onUpdate = onUpdate

return M
