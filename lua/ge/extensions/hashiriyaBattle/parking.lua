-- Hashiriya Battle: Parkplätze (Garage, Tuning-Shop)
-- Die Parkplätze stehen in data/maps/<level>.json. Hält der Spieler in einem Parkplatz an,
-- öffnet sich das passende Menü; beim Wegfahren schließt es sich wieder.
local M = {}

local logTag = 'hashiriya'
local saveDir = 'settings/hashiriya_battle/'

local enterSpeed = 8 / 3.6   -- km/h -> m/s: unter diesem Tempo gilt man als "angekommen"
local checkInterval = 0.25
local repairYenPerDamage = 2 -- Reparaturpreis je BeamNG-Schadenspunkt (zum Feintuning)
local triggerRadius = 4       -- m um die Buchtmitte, in denen der Parkplatz auslöst (Kartendatei: radius)
local leaveMargin = 2         -- m zusätzlich, bevor er als verlassen gilt (kein Flackern am Rand)
local footRadius = 2.5        -- m um footPos (zu Fuß, z. B. vor der Garagentür)
local towBaseYen = 30000      -- Abschleppen: Grundgebühr
local towYenPerKm = 2500      -- plus je km Luftlinie zur Garage
local towMaxSpeed = 5 / 3.6   -- nur im Stand

local bayWidth, bayLength = 2.5, 5.0 -- Größe der markierten Parkbucht in m (wie Vanilla)

local checkTimer = 0
local markersOn = true       -- im Menü abschaltbar
local photoMode = false      -- im Fotomodus immer aus
local groundZ = {}           -- Bodenhöhe je Parkplatz (einmal ermittelt)
local current = nil          -- Parkplatz, in dem der Spieler gerade steht
local arrived = false        -- im Parkplatz angehalten (Menü offen)
local onFoot = false         -- Parkplatz zu Fuß betreten (Fußbereich statt Bucht)
local footShop = nil         -- Shop zu Fuß betreten: Spieler sitzt fürs Menü im Auto in der Bucht
local shopCamTimer = 0       -- verzögert die Eingangskamera (nach Einsteigen/Neuspawn setzt BeamNG seine Kamera)
local footBlocked = nil      -- Fußbereich erst wieder auslösen, wenn man ihn verlassen hat
local bayHint = nil          -- Hinweis "zu Fuß zum Eingang" nur einmal je Bucht
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

function M.isOnFoot() return onFoot and arrived end

-- Startpunkt zu Fuß: playerSpawn der Kartendatei, sonst 4 m seitlich neben der Garagenbucht.
function M.footSpawnTransform()
  local md = core().mapData
  local g = M.find('garage')
  local up = vec3(0, 0, 1)
  if md and md.playerSpawn and md.playerSpawn.pos then
    local dir = toVec(md.playerSpawn.dir or (g and g.dir) or { 0, 1, 0 })
    return toVec(md.playerSpawn.pos) + vec3(0, 0, 0.2), quatFromDir(dir, up)
  end
  if not g then return nil end
  local dir = toVec(g.markerDir or g.dir); dir.z = 0; dir = dir:normalized()
  local side = dir:cross(up):normalized()
  return toVec(g.markerPos or g.pos) + side * 4 + vec3(0, 0, 0.3), quatFromDir(dir, up)
end

-- Steht das Auto in der Bucht des Parkplatzes?
function M.carInBay(veh, a)
  local okC, center = pcall(function() return veh:getSpawnWorldOOBB():getCenter() end)
  local p = (a.markerPos and okC and center) and vec3(center) or veh:getPosition()
  local d = p - toVec(a.markerPos or a.pos)
  d.z = d.z * 0.5
  return d:length() <= (a.radius or triggerRadius)
end

function M.isFootShop() return footShop ~= nil end

-- Öffnungszeiten eines Shops: area.hours = {von, bis}, sonst world.json shopHours (Standard 8 bis 20 Uhr)
function M.isOpen(a)
  if not a or a.type ~= 'shop' then return true end
  local home = extensions.hashiriyaBattle_home
  local hours = a.hours or (home.world and home.world().shopHours) or { 8, 20 }
  local h = home.hour() or 12
  local from, to = hours[1], hours[2]
  local open = (from <= to) and (h >= from and h < to) or (from > to and (h >= from or h < to))
  return open, string.format('%02d:00 - %02d:00', from, to)
end
function M.refreshShopCamera(delay) if footShop then shopCamTimer = delay or 0.2 end end

-- Shop zu Fuß verlassen: aussteigen und wieder am Eingang stehen.
-- Kamera beim Shop zu Fuß: vom Eingang (Augenhöhe, etwas zurück) aufs Auto in der Bucht.
-- Intern sitzt der Spieler fürs Menü im Auto (die Tuning-Funktionen brauchen das Spielerauto), zu sehen ist das nicht.
function M.applyShopCamera()
  local a = footShop
  local c = core()
  local carVeh = a and c.carVehId and be:getObjectByID(c.carVehId)
  if not carVeh then return end
  local okC, center = pcall(function() return vec3(carVeh:getSpawnWorldOOBB():getCenter()) end)
  local target = (okC and center) or carVeh:getPosition()
  local eye = toVec(a.footPos) + vec3(0, 0, 1.65)
  local away = eye - target; away.z = 0
  if away:length() > 0.1 then eye = eye + away:normalized() * 1.5 end
  local rot = quatFromDir((target - eye):normalized(), vec3(0, 0, 1))
  -- Orbit-Kamera ums Auto statt Freikamera: kein Herumfliegen (Noclip) im Shop, Maus dreht nur um das Auto
  pcall(function() core_camera.setByName(0, 'orbit') end)
end

function M.leaveFootShop()
  local a = footShop
  if not a then return end
  footShop = nil
  if current and arrived then core().onParkingLeft(current) end
  current, arrived, onFoot = nil, false, false
  footBlocked = a
  local dir = toVec(a.footDir or a.dir); dir.z = 0
  core().goOnFoot(nil, toVec(a.footPos) + vec3(0, 0, 0.2), quatFromDir(dir:normalized(), vec3(0, 0, 1)))
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
  extensions.hashiriyaBattle_progress.bump(c.save, 'repairs')
  veh:queueLuaCommand('obj:requestReset(RESET_PHYSICS)')
  c.writeSave()
  c.msg(c.t('msg.repaired', c.economy().formatYen(cost)))
end

-- Abschleppen zur Garage -----------------------------------------------------------
-- Teuer genug, dass es keine Abkürzung ist; nicht während eines Battles und nur im Stand.

function M.towInfo()
  local c = core()
  local veh = c.getPlayerVehicle()
  local garage = M.find('garage')
  if not veh or not garage or not c.save then return nil end
  local km = (veh:getPosition() - toVec(garage.pos)):length() / 1000
  local cost = math.floor((towBaseYen + km * towYenPerKm) / 100) * 100
  local reason = nil
  if current == garage then reason = 'atGarage'
  elseif extensions.hashiriyaBattle_battle.isBusy() then reason = 'battle'
  elseif veh:getVelocity():length() > towMaxSpeed then reason = 'moving'
  elseif c.save.money < cost then reason = 'money' end
  return { cost = cost, km = km, reason = reason }
end

function M.towToGarage()
  local c = core()
  local info = M.towInfo()
  if not info then return end
  if info.reason then
    c.msg(c.t('msg.tow.' .. info.reason))
    return
  end
  local veh = c.getPlayerVehicle()
  local pos, rot = M.spawnTransform(M.find('garage'))
  c.save.money = c.save.money - info.cost
  extensions.hashiriyaBattle_progress.bump(c.save, 'tows')
  pcall(extensions.hashiriyaBattle_rivals.despawnActive)
  local ok = pcall(function() spawn.safeTeleport(veh, pos, rot) end)
  if not ok then veh:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w) end
  c.writeSave()
  c.msg(c.t('msg.towed', c.economy().formatYen(info.cost)), 6)
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
-- Wie die Parkplätze in der BeamNG-Karriere: flacher Rahmen (park_outline_marker) und
-- ein Streifen-Decal auf dem Boden, beides leicht eingefärbt. Der Rahmen taucht erst in
-- der Nähe auf. Im Fotomodus (photoModeOpen) und per Menü-Schalter ausgeblendet.

local outlineShape = 'art/shapes/interface/park_outline_marker.dae'
local decalTexture = 'art/shapes/interface/parkDecalStripes.png'
local decalAlpha = 0.28       -- Deckkraft der Streifen (dezent)
local decalFadeStart, decalFadeEnd = 30, 55 -- Ausblenden des Decals über die Kameraentfernung
local outlineNear, outlineFar = 12, 45      -- m: Rahmen voll sichtbar / unsichtbar

local colors = {
  garage = { 1.0, 0.45, 0.1 },
  shop   = { 0.3, 0.72, 1.0 },
  gas    = { 0.35, 0.9, 0.45 },
  home   = { 1.0, 0.82, 0.45 },
}

local footMarkerSize = { 1.6, 1.6 } -- m, kleine Markierung für Punkte zu Fuß
local footMarkerAreas = {}           -- [areaId] = Markierungs-Eintrag am Fußpunkt

local markers = {} -- [areaId] = { outlineId, decal, decalArr, alpha }

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

-- Fahrbahnhöhe an der Parkbucht. Die C1 ist aufgeständert, daher ein kurzer Strahl von knapp
-- über der gespeicherten Position nach unten (trifft das Deck, nicht den Boden darunter).
local function ground(a)
  if groundZ[a.id] == nil then
    local p = toVec(a.markerPos or a.pos)
    local z = nil
    local ok, dist = pcall(function() return castRayStatic(p + vec3(0, 0, 1.0), vec3(0, 0, -1), 5) end)
    if ok and type(dist) == 'number' and dist < 5 then z = p.z + 1.0 - dist end
    groundZ[a.id] = z or (p.z - 0.35)
    log('I', logTag, string.format('Parkplatz %s: Boden bei %.2f (Position %.2f)', a.id, groundZ[a.id], p.z))
  end
  return groundZ[a.id]
end

local function clearMarkers()
  for id, m in pairs(markers) do
    local obj = m.outlineId and scenetree.findObjectById(m.outlineId)
    if obj then obj:delete() end
    markers[id] = nil
  end
end
M.clearMarkers = clearMarkers

-- Optional je Parkplatz in der Kartendatei: markerPos/markerDir (Mitte und Richtung einer echten
-- Bucht) und markerSize {Breite, Länge}. Ohne Angaben wird die Spawn-Position genommen.
local function bayOf(a)
  local w, l = bayWidth, bayLength
  if type(a.markerSize) == 'table' then w, l = a.markerSize[1] or w, a.markerSize[2] or l end
  return w, l
end

local function createMarker(a)
  local pos = toVec(a.markerPos or a.pos)
  pos.z = ground(a) + 0.02
  local fwd = toVec(a.markerDir or a.dir); fwd.z = 0; fwd = fwd:normalized()
  local w, l = bayOf(a)
  local rot = quatFromDir(fwd, vec3(0, 0, 1))
  local m = { alpha = -1, pos = pos, w = w, l = l }
  local ok, err = pcall(function()
    local outline = createObject('TSStatic')
    outline:setField('shapeName', 0, outlineShape)
    outline:setPosition(pos)
    outline.scale = vec3(1, 1, 1)
    outline.useInstanceRenderData = true
    outline:setField('instanceColor', 0, '1 1 1 0')
    outline:setField('collisionType', 0, 'None')
    outline:setField('decalType', 0, 'None')
    outline.canSave = false
    outline:registerObject('hashiriya_pa_' .. a.id)
    local tq = rot:toTorqueQuat()
    outline:setField('rotation', 0, tq.x .. ' ' .. tq.y .. ' ' .. tq.z .. ' ' .. tq.w)
    outline:setScaleXYZ(w, l / 2.05, 0.01)
    m.outlineId = outline:getId()
  end)
  if not ok then log('W', logTag, 'Parkplatz-Rahmen nicht erstellt: ' .. tostring(err)) end
  local c = colors[a.type] or colors.garage
  m.color = c
  m.decal = {
    texture = decalTexture,
    position = vec3(pos),
    forwardVec = fwd,
    color = ColorF(c[1], c[2], c[3], decalAlpha),
    scale = vec3(w, l, 1), -- Projektionstiefe 1 m wie Vanilla
    fadeStart = decalFadeStart,
    fadeEnd = decalFadeEnd,
  }
  m.decalArr = { m.decal }
  markers[a.id] = m
  return m
end

local function setOutline(m, alpha)
  if math.abs(alpha - m.alpha) < 0.01 then return end
  m.alpha = alpha
  local obj = m.outlineId and scenetree.findObjectById(m.outlineId)
  if not obj then return end
  local c = m.color
  local lin = ColorF(c[1], c[2], c[3], alpha):asLinear4F()
  obj.instanceColor = lin
  obj:updateInstanceRenderData()
  obj:setScaleXYZ(m.w, m.l / 2.05, math.max(alpha * 0.2, 0.01)) -- 1 bis 20 cm hoch wie in der Karriere
end

-- Alles, was markiert wird: Buchten für das Auto und Punkte zu Fuß (Zuhause, Shop-Eingang)
local function markerAreas()
  local list = {}
  for _, a in ipairs(areas()) do
    if not a.footOnly then table.insert(list, a) end
    if a.footPos then
      local f = footMarkerAreas[a.id]
      if not f then
        f = { id = a.id .. '_foot', type = a.type, pos = a.footPos, dir = a.footDir or a.dir, markerSize = footMarkerSize, owner = a }
        footMarkerAreas[a.id] = f
      end
      table.insert(list, f)
    end
  end
  return list
end

local function drawMarkers(playerPos)
  local show = markersOn and not photoMode and not rawget(_G, 'photoModeOpen')
    and not (editor and editor.active)
  for _, a in ipairs(markerAreas()) do
    local m = markers[a.id] or (show and createMarker(a))
    if m then
      local dist = (playerPos - m.pos):length()
      if not show or dist > decalFadeEnd + 100 then
        setOutline(m, 0)
      else
        local near = clamp(1 - (dist - outlineNear) / (outlineFar - outlineNear), 0, 1)
        if (current == a or current == a.owner) and arrived then near = near * 0.35 end
        setOutline(m, near * 0.9)
        if Engine and Engine.Render and Engine.Render.DynamicDecalMgr then
          m.decal.color = ColorF(m.color[1], m.color[2], m.color[3], decalAlpha * (((current == a or current == a.owner) and arrived) and 0.5 or 1))
          pcall(Engine.Render.DynamicDecalMgr.addDecals, m.decalArr, 1)
        end
      end
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
    if d < bestDist and not a.footOnly then best, bestDist = a, d end
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
  if shopCamTimer > 0 then
    shopCamTimer = shopCamTimer - dtReal
    if shopCamTimer <= 0 and footShop then M.applyShopCamera() end
  end
  local c = core()
  if not c or not c.active then
    current, arrived = nil, false
    for _, m in pairs(markers) do setOutline(m, 0) end
    return
  end
  local veh = c.getPlayerVehicle()
  if not veh then
    -- Zu Fuß: nur die Fußbereiche (footPos/footRadius in der Kartendatei, z. B. Garagentür)
    local wpos = c.getWalkerPos()
    if not wpos then return end
    drawMarkers(wpos)
    checkTimer = checkTimer - dtReal
    if checkTimer > 0 then return end
    checkTimer = checkInterval
    local foundFoot = nil
    for _, a in ipairs(areas()) do
      if a.footPos then
        local r = (a.footRadius or footRadius) + ((a == current and onFoot or a == footBlocked) and leaveMargin or 0)
        local d = wpos - toVec(a.footPos)
        d.z = d.z * 0.5
        if d:length() <= r then foundFoot = a; break end
      end
    end
    if footBlocked and foundFoot ~= footBlocked then footBlocked = nil end
    if foundFoot and foundFoot == footBlocked then return end
    if foundFoot ~= current or not onFoot then
      if current and arrived then c.onParkingLeft(current) end
      current, arrived, onFoot = foundFoot, false, foundFoot ~= nil
      if current and current.footEntry then
        -- Shop: Auto muss in der Bucht stehen, dann setzt man sich fürs Menü hinein
        local carVeh = c.carVehId and be:getObjectByID(c.carVehId)
        local isOpen, openText = M.isOpen(current)
        if not isOpen then
          footBlocked = current
          current, onFoot = nil, false
          c.msg(c.t('msg.shopClosed', openText), 5)
        elseif carVeh and M.carInBay(carVeh, current) then
          footShop = current
          onFoot = false
          arrived = true
          c.enterCarForShop(carVeh)
          shopCamTimer = 0.4 -- nach dem Einsteigen setzt BeamNG die Kamera, danach unsere
          c.onParkingArrived(current)
        else
          footBlocked = current
          current, onFoot = nil, false
          c.msg(c.t('msg.needCarInBay'), 4)
        end
      elseif current then
        arrived = true
        c.onParkingArrived(current)
      end
    end
    return
  end
  local pos = veh:getPosition()
  drawMarkers(pos) -- muss jeden Frame gezeichnet werden

  checkTimer = checkTimer - dtReal
  if checkTimer > 0 then return end
  checkTimer = checkInterval
  if onFoot then
    -- gerade eingestiegen: Fußbereich verlassen
    if current and arrived then c.onParkingLeft(current) end
    current, arrived, onFoot = nil, false, false
  end
  if footShop then return end -- sitzt nur fürs Shop-Menü im Auto
  -- Auslösen nur in der Bucht selbst: Fahrzeugmitte nahe der Buchtmitte (mit markerPos), sonst
  -- Referenzpunkt nahe der gespeicherten Position. Zum Verlassen etwas mehr Abstand.
  local okC, center = pcall(function() return veh:getSpawnWorldOOBB():getCenter() end)
  local found = nil
  for _, a in ipairs(areas()) do
    if not a.footOnly then
      local p = (a.markerPos and okC and center) and vec3(center) or pos
      local r = (a.radius or triggerRadius) + (a == current and leaveMargin or 0)
      local d = p - toVec(a.markerPos or a.pos)
      d.z = d.z * 0.5 -- Höhe zählt weniger (Fahrzeugmitte liegt über der Fahrbahn)
      if d:length() <= r then found = a; break end
    end
  end

  if found ~= current then
    if current and arrived then c.onParkingLeft(current) end
    current, arrived = found, false
  end
  if current and current.footEntry then
    -- Shop-Bucht: nicht per Auto öffnen, sondern zu Fuß am Eingang
    if bayHint ~= current and veh:getVelocity():length() < enterSpeed then
      bayHint = current
      local isOpen, openText = M.isOpen(current)
      if isOpen then c.msg(c.t('msg.walkToEntrance'), 5) else c.msg(c.t('msg.shopClosed', openText), 5) end
    end
    return
  end
  if not current then bayHint = nil end
  if current and not arrived and veh:getVelocity():length() < enterSpeed
    and not extensions.hashiriyaBattle_battle.isBusy() then
    arrived = true
    if current.type == 'shop' then pcall(M.dumpParts, false) end
    c.onParkingArrived(current)
  end
end

local function onClientEndMission()
  clearMarkers()
  groundZ = {}
  footMarkerAreas = {}
end

local function onExtensionUnloaded()
  clearMarkers()
end

M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission
M.onExtensionUnloaded = onExtensionUnloaded

return M
