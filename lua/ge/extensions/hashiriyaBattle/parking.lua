-- Hashiriya Battle: Parkplätze (Garage, Tuning-Shop)
-- Die Parkplätze stehen in data/maps/<level>.json. Hält der Spieler in einem Parkplatz an,
-- öffnet sich das passende Menü; beim Wegfahren schließt es sich wieder.
local M = {}

local logTag = 'hashiriya'
local saveDir = 'settings/hashiriya_battle/'

local enterSpeed = 8 / 3.6   -- km/h -> m/s: unter diesem Tempo gilt man als "angekommen"
local checkInterval = 0.25
local repairYenPerDamage = 2 -- Reparaturpreis je BeamNG-Schadenspunkt (zum Feintuning)

local markerDistance = 150   -- m: ab hier ist die Markierung sichtbar
local bayWidth, bayLength = 3.4, 6.0 -- Größe der markierten Parkbucht in m

local checkTimer = 0
local markersOn = true       -- im Menü abschaltbar
local photoMode = false      -- im Fotomodus immer aus
local groundZ = {}           -- Bodenhöhe je Parkplatz (einmal ermittelt)
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
    local okParts, available = pcall(function()
      local io = rawget(_G, 'jbeamIO') or require('jbeam/io')
      return io.getAvailableParts(vd.ioCtx)
    end)
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

-- Markierung -------------------------------------------------------------------
-- Dezente Parkbucht auf dem Boden (flache Fläche mit Eckwinkeln), nur in der Nähe.

local colors = {
  garage = { 255, 102, 0 },
  shop   = { 63, 182, 255 },
}

function M.markersEnabled() return markersOn end
function M.setMarkersEnabled(on)
  markersOn = on and true or false
  local c = core()
  if c.save then
    c.save.settings = c.save.settings or {}
    c.save.settings.markers = markersOn
    c.writeSave()
  end
end
function M.setPhotoMode(on) photoMode = on and true or false end
function M.loadSettings(save)
  markersOn = not (save and save.settings and save.settings.markers == false)
end

local function ground(a)
  if groundZ[a.id] == nil then
    local p = toVec(a.pos)
    local ok, h = pcall(function() return be:getSurfaceHeightBelow(p + vec3(0, 0, 2)) end)
    groundZ[a.id] = (ok and type(h) == 'number' and h > p.z - 5) and h or (p.z - 0.4)
  end
  return groundZ[a.id]
end

local function drawMarkers(playerPos)
  if not markersOn or photoMode or not debugDrawer then return end
  for _, a in ipairs(areas()) do
    local center = toVec(a.pos)
    local dist = (playerPos - center):length()
    if dist <= markerDistance then
      center.z = ground(a) + 0.04
      local col = colors[a.type] or colors.garage
      -- näher = etwas deutlicher, angekommen = fast unsichtbar
      local fade = clamp(1 - (dist - 20) / (markerDistance - 20), 0.25, 1)
      if current == a and arrived then fade = 0.15 end
      local fwd = toVec(a.dir); fwd.z = 0; fwd = fwd:normalized()
      local right = fwd:cross(vec3(0, 0, 1)):normalized()
      local hl, hw = fwd * (bayLength / 2), right * (bayWidth / 2)
      local c1, c2, c3, c4 = center - hl - hw, center + hl - hw, center + hl + hw, center - hl + hw
      pcall(function()
        local fill = ColorI(col[1], col[2], col[3], math.floor(38 * fade))
        debugDrawer:drawTriangleFilled(c1, c2, c3, fill)
        debugDrawer:drawTriangleFilled(c1, c3, c4, fill)
      end)
      pcall(function()
        local line = ColorF(col[1] / 255, col[2] / 255, col[3] / 255, 0.85 * fade)
        local k = 0.9 -- Länge der Eckwinkel in m
        for _, corner in ipairs({ { c1, fwd, right }, { c2, -fwd, right }, { c3, -fwd, -right }, { c4, fwd, -right } }) do
          local p, d1, d2 = corner[1], corner[2], corner[3]
          debugDrawer:drawLine(p, p + d1 * k, line)
          debugDrawer:drawLine(p, p + d2 * k, line)
        end
        if dist < 60 then
          debugDrawer:drawTextAdvanced(center + vec3(0, 0, 1.2), String(core().t('pa.' .. a.type)),
            ColorF(1, 1, 1, 0.9 * fade), true, false, ColorI(20, 20, 22, math.floor(150 * fade)))
        end
      end)
    end
  end
end

-- Navigation zum nächsten Parkplatz (für die HUD-Anzeige) ------------------------
-- Keine 3D-Markierungen in der Welt: Name, Entfernung und Richtung stehen dezent im HUD.

local function navInfo(veh)
  local pos = veh:getPosition()
  local best, bestDist = nil, math.huge
  for _, a in ipairs(areas()) do
    local d = (pos - toVec(a.pos)):length()
    if d < bestDist then best, bestDist = a, d end
  end
  if not best then return nil end
  local fwd = veh:getDirectionVector()
  local to = toVec(best.pos) - pos
  -- Winkel im Uhrzeigersinn relativ zur Fahrtrichtung (0 = geradeaus)
  local angle = math.deg(math.atan2(fwd.x * to.y - fwd.y * to.x, fwd.x * to.x + fwd.y * to.y)) * -1
  return {
    type = best.type,
    dist = math.floor(bestDist),
    angle = math.floor(angle + 0.5),
    inside = (current == best),
    arrived = (current == best) and arrived,
  }
end

function M.getNavInfo()
  local veh = core().getPlayerVehicle()
  return veh and navInfo(veh) or nil
end

-- Update ------------------------------------------------------------------------

local function onUpdate(dtReal)
  local c = core()
  if not c or not c.active then
    current, arrived = nil, false
    return
  end
  local veh = c.getPlayerVehicle()
  if not veh then return end
  local pos = veh:getPosition()
  drawMarkers(pos) -- muss jeden Frame gezeichnet werden

  checkTimer = checkTimer - dtReal
  if checkTimer > 0 then return end
  checkTimer = checkInterval
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
