-- Hashiriya Part Studio (eigenständige Mod, läuft ohne Hashiriya Battle)
--
-- Erstellt Vorschaubilder für Fahrzeugteile (Original- und Mod-Fahrzeuge) und zeigt sie in einer Galerie,
-- in der man ein Teil per Klick an das eigene Auto baut. Läuft im normalen Free Roam und in der BeamNG-Garage.
--
-- So entsteht ein Bild:
--   1. Ein "Studio-Auto" des Modells wird hoch über der Kamera gespawnt (Physik angehalten, damit es schwebt).
--   2. In einem Durchgang bekommt jeder Slot ein anderes Teil (Slots, die ineinander stecken, nie gleichzeitig),
--      so braucht ein Auto nur so viele Respawns, wie der größte Slot Teile hat.
--   3. Für jedes Teil werden alle anderen Meshes unsichtbar (setMeshAlpha), die Kamera richtet sich nach der
--      Größe des Teils aus, und eine zweite, unsichtbare Kamera (RenderView) speichert das Bild.
--      Der Bildschirm und die Oberfläche bleiben dabei unverändert.
--   4. Bilder liegen im BeamNG-Benutzerordner unter art/partPreviews/<Teilname>.jpg (ein Bild je Teilname,
--      gleiche Teile an mehreren Autos werden nur einmal fotografiert).
--
-- Bedienung: BeamNG-Hauptmenü > Mehr > "Teile-Studio", im Spiel Strg+Umschalt+P oder in der Konsole
-- extensions.hashiriyaPartStudio.toggle(). Oberfläche: ui/ui-vue/mods/hashiriyaPartStudio/.
local M = {}

local logTag = 'partStudio'
local OUT_DIR = 'art/partPreviews/'
local SETTINGS_FILE = 'settings/hashiriya_partstudio/settings.json'
local VIEWS_FILE = 'settings/hashiriya_partstudio/views.json' -- Blickwinkel pro Teil (von Hand korrigiert)
local LAST_RUN_FILE = 'settings/hashiriya_partstudio/last_run.json'
local STUDIO_LEVEL = 'smallgrid'   -- Level, wenn das Studio aus dem Hauptmenü gestartet wird
local VIEW_NAME = 'hashiriyaPartStudioView'

local defaults = {
  width = 320, height = 200,     -- Bildgröße in Pixeln
  supersampling = 2,             -- intern größer rendern und verkleinern (glattere Kanten)
  fov = 28,                      -- Blickwinkel der Studio-Kamera (Grad, vertikal)
  padding = 1.12,                -- Abstand um das Teil (1 = randvoll)
  settleDelay = 0.6,             -- Wartezeit vor jedem Bild (Belichtung der neuen Kamera)
  background = 'focus',          -- 'focus' = nur das Teil, 'scene' = Teil vor dem Himmel/der Umgebung
  bgColor = { 0.10, 0.11, 0.13 },-- Hintergrundfarbe im Modus 'focus'
  studioPaint = true,            -- alle Teile im gleichen silbergrauen Lack (einheitlicher Katalog)
  skipExisting = true,           -- schon vorhandene Bilder nicht neu machen
  noonLight = true,              -- während der Aufnahme Mittag einstellen (gleiches Licht für alle Bilder)
  heightAboveCamera = 150,       -- Studio-Auto so weit über der Kamera
  light = 1.0,                   -- Stärke der Studio-Lampen (Haupt-, Füll-, Kantenlicht), 0 = aus
  exposure = 1.0,                -- Belichtung in Blendenstufen (+1 = doppelt so hell)
  singlePair = true,             -- Paare (Felgen, Reifen, Bremsen links/rechts) nur einmal zeigen
  autoView = true,               -- mehrere Blickwinkel gleichzeitig aufnehmen und den besten nehmen
  lighting = 'day',              -- 'day' = Tageslicht + Lampen als Aufhellung; 'studio' = Nacht, nur Lampen (Versuch, Lampen gehen noch nicht)
  types = { Car = true, Truck = true }, -- Fahrzeugtypen in der Modell-Liste
}

local cfg = deepcopy and deepcopy(defaults) or defaults
local active = false         -- Panel offen
local pendingOpen = false    -- Studio-Level lädt gerade, danach Panel öffnen
local openFallback = nil
local job = nil              -- laufende Bilderstellung
local galleryVehId = nil     -- Fahrzeug, für das die Galerie zuletzt gesendet wurde
local galleryDirty = false
local modelsCache = nil
local views = { _auto = {} } -- Teilname -> { yaw, pitch, zoom } (Grad, Grad, Faktor)

local function send(data) guihooks.trigger('HashiriyaPartStudio', data) end
local function jbeamIO() return rawget(_G, 'jbeamIO') or require('jbeam/io') end

local function fileOf(partName)
  return OUT_DIR .. tostring(partName):gsub('[^%w_%-%.]', '_') .. '.jpg'
end
M.fileOf = fileOf

local function hasImage(partName)
  return partName and partName ~= '' and FS:fileExists('/' .. fileOf(partName)) or false
end

-- Einstellungen -------------------------------------------------------------------------------------

local function loadSettings()
  local ok, data = pcall(jsonReadFile, SETTINGS_FILE)
  if ok and type(data) == 'table' then
    for k, v in pairs(data) do if defaults[k] ~= nil then cfg[k] = v end end
  end
end

local function saveSettings()
  pcall(jsonWriteFile, SETTINGS_FILE, cfg, true)
end

local function loadViews()
  local ok, data = pcall(jsonReadFile, VIEWS_FILE)
  views = (ok and type(data) == 'table') and data or {}
  if type(views._auto) ~= 'table' then views._auto = {} end
end

local function saveViews()
  pcall(jsonWriteFile, VIEWS_FILE, views, true)
end

-- Modelle -------------------------------------------------------------------------------------------

local function modelList()
  if modelsCache then return modelsCache end
  local out = {}
  local ok, res = pcall(core_vehicles.getModelList, true)
  for _, m in ipairs(ok and res and res.models or {}) do
    if m.key and cfg.types[m.Type or ''] then
      local src = m.Source or ''
      table.insert(out, {
        key = m.key,
        name = ((m.Brand and m.Brand ~= '') and (m.Brand .. ' ') or '') .. tostring(m.Name or m.key),
        type = m.Type,
        official = src == 'BeamNG - Official',
        source = src,
      })
    end
  end
  table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
  modelsCache = out
  return out
end

-- Teilebaum -----------------------------------------------------------------------------------------

-- Alle Slots des Baums mit Pfad, Schlüssel (wie partsTreeToPartsMap: Slot-ID, bei doppelten IDs der Pfad),
-- gewähltem Teil und Tiefe.
local function collectSlots(tree)
  local list, idCount = {}, {}
  local function walk(node, depth)
    for _, child in pairs(node.children or {}) do
      if type(child) == 'table' and child.id then
        idCount[child.id] = (idCount[child.id] or 0) + 1
        table.insert(list, { id = child.id, path = child.path or child.id, chosen = child.chosenPartName or '',
          partPath = child.partPath, parentPart = node.chosenPartName, depth = depth })
        walk(child, depth + 1)
      end
    end
  end
  if type(tree) == 'table' then walk(tree, 1) end
  for _, s in ipairs(list) do s.key = (idCount[s.id] or 0) > 1 and s.path or s.id end
  return list
end

local function partsMapOf(tree)
  local pm = rawget(_G, 'core_vehicle_partmgmt') or extensions.core_vehicle_partmgmt
  if pm and pm.partsTreeToPartsMap then
    local ok, map = pcall(pm.partsTreeToPartsMap, tree)
    if ok and type(map) == 'table' then return map end
  end
  local map = {}
  for _, s in ipairs(collectSlots(tree)) do map[s.key] = s.chosen end
  return map
end

-- Passende Teile eines Slots (Slot-ID = Typ, sonst allowTypes aus dem Eltern-Teil)
local function candidatesOf(ioCtx, slotMap, slot)
  local out, seen = {}, {}
  local function add(list)
    for _, n in ipairs(list or {}) do
      if n ~= '' and not seen[n] then seen[n] = true; table.insert(out, n) end
    end
  end
  add(slotMap[slot.id])
  if #out == 0 and slot.parentPart then
    local ok, part = pcall(jbeamIO().getPart, ioCtx, slot.parentPart)
    if ok and type(part) == 'table' then
      for _, s in ipairs(part.slots2 or {}) do
        if s.name == slot.id then
          for _, t in ipairs(type(s.allowTypes) == 'table' and s.allowTypes or { s.type }) do add(slotMap[t]) end
        end
      end
    end
  end
  return out
end

-- Hat das Teil überhaupt etwas Sichtbares? (Steuergeräte, Tuning-Teile usw. haben keine Meshes)
local function partHasMesh(ioCtx, name, cache)
  if cache[name] ~= nil then return cache[name] end
  local ok, part = pcall(jbeamIO().getPart, ioCtx, name)
  local has = true
  if ok and type(part) == 'table' then
    has = (type(part.flexbodies) == 'table' and next(part.flexbodies) ~= nil)
      or (type(part.props) == 'table' and next(part.props) ~= nil)
  end
  cache[name] = has
  return has
end

local function partDescriptions(ioCtx)
  local ok, descs = pcall(jbeamIO().getAvailableParts, ioCtx)
  return ok and type(descs) == 'table' and descs or {}
end

local function displayName(descs, name)
  local d = descs[name]
  local t = type(d) == 'table' and d.description or (type(d) == 'string' and d) or nil
  if type(t) == 'table' then t = t.description end
  return (type(t) == 'string' and t ~= '') and t or name
end

-- Meshes und Rahmen ---------------------------------------------------------------------------------

local function isMeshName(m)
  return type(m) == 'string' and m ~= '' and m ~= 'SPOTLIGHT' and m ~= 'POINTLIGHT'
end

local function isOccupant(entry)
  local k = entry.originalMesh or entry.mesh
  return (k == 'character_torso' or k == 'character_head')
end

-- Alle Meshes des Autos und die Meshes eines Teils (eigene; hat es keine, die seiner Kind-Teile)
local function meshesOf(vdata, partPath)
  local all, allSeen, own, sub = {}, {}, {}, {}
  local ownFlex, subFlex = {}, {}
  local ownEntries, subEntries = {}, {}
  local function scan(list, isFlex)
    for _, e in pairs(list or {}) do
      if type(e) == 'table' and isMeshName(e.mesh) then
        if not allSeen[e.mesh] then allSeen[e.mesh] = true; table.insert(all, e.mesh) end
        if not isOccupant(e) and e.partPath and partPath then
          if e.partPath == partPath then
            own[e.mesh] = true
            table.insert(ownEntries, e)
            if isFlex then table.insert(ownFlex, e) end
          elseif e.partPath:sub(1, #partPath) == partPath then
            sub[e.mesh] = true
            table.insert(subEntries, e)
            if isFlex then table.insert(subFlex, e) end
          end
        end
      end
    end
  end
  scan(vdata.flexbodies, true)
  scan(vdata.props, false)
  if next(own) then return all, own, ownFlex, ownEntries end
  return all, sub, subFlex, subEntries
end

local function axesOf(veh)
  local fx, fy, fz = veh:getDirectionVectorXYZ()
  local ux, uy, uz = veh:getDirectionVectorUpXYZ()
  local fwd, up = vec3(fx, fy, fz), vec3(ux, uy, uz)
  local right = fwd:cross(up)
  return right, fwd, up
end

-- Knoten-Box (lokal in Fahrzeugachsen) aus den aktuellen Knotenpositionen
local function liveNodeBox(veh, ids, right, fwd, up)
  local mn = vec3(math.huge, math.huge, math.huge)
  local mx = vec3(-math.huge, -math.huge, -math.huge)
  for _, cid in ipairs(ids) do
    local px, py, pz = veh:getNodePositionXYZ(cid)
    if px then
      local p = vec3(px, py, pz)
      local x, y, z = p:dot(right), p:dot(fwd), p:dot(up)
      mn.x, mn.y, mn.z = math.min(mn.x, x), math.min(mn.y, y), math.min(mn.z, z)
      mx.x, mx.y, mx.z = math.max(mx.x, x), math.max(mx.y, y), math.max(mx.z, z)
    end
  end
  if mn.x > mx.x then return nil end
  return mn, mx
end

local meshBoundsCache = {}
local function meshBounds(veh, flex)
  local key = flex.mesh
  if meshBoundsCache[key] ~= nil then return meshBoundsCache[key] or nil end
  local b = false
  local ok, obj = pcall(function() return flex.fid and veh:getFlexmesh(flex.fid) end)
  local count = ok and obj and obj:getVertexCount() or 0
  if count > 0 then
    local mn = { math.huge, math.huge, math.huge }
    local mx = { -math.huge, -math.huge, -math.huge }
    for i = 0, count - 1 do
      local p = obj:getInitVertexPos(i)
      if p.x < mn[1] then mn[1] = p.x end; if p.y < mn[2] then mn[2] = p.y end; if p.z < mn[3] then mn[3] = p.z end
      if p.x > mx[1] then mx[1] = p.x end; if p.y > mx[2] then mx[2] = p.y end; if p.z > mx[3] then mx[3] = p.z end
    end
    b = { mn, mx }
  end
  meshBoundsCache[key] = b
  return b or nil
end

-- Mittelpunkt (Welt) und halbe Größe (lokal) eines Teils.
-- Die Knoten eines Teils sitzen innerhalb des sichtbaren Meshes: Größe kommt darum aus dem Mesh,
-- die Lage aus den Knoten (Ruheposition von Mesh und Knoten vergleichen, dann auf die echten Knoten legen).
-- jbeam-Achsen zeigen lokal als (-x, -y, z), weil rechts/vorne die negativen jbeam-Achsen sind.
local function frameOf(veh, vdata, partPath, flexList, side)
  local ids, located = {}, false
  for key, node in pairs(vdata.nodes or {}) do
    if type(node) == 'table' and node.partPath == partPath then
      table.insert(ids, node.cid or key); located = true
    end
  end
  if not located then
    local seen = {}
    for _, f in ipairs(flexList) do
      for _, cid in ipairs(f._group_nodes or {}) do
        if not seen[cid] then seen[cid] = true; table.insert(ids, cid) end
      end
    end
  end
  local right, fwd, up = axesOf(veh)
  -- nur eine Seite eines Paares: Knoten der anderen Seite weglassen
  if side then
    local kept = {}
    for _, cid in ipairs(ids) do
      local px, py, pz = veh:getNodePositionXYZ(cid)
      if px and (vec3(px, py, pz):dot(right) - side.cx) * side.s > 0 then table.insert(kept, cid) end
    end
    if #kept > 0 then ids = kept end
  end
  if #ids == 0 then return nil end

  local nMin, nMax = liveNodeBox(veh, ids, right, fwd, up)
  if not nMin then return nil end
  local c = (nMin + nMax) * 0.5
  local half = (nMax - nMin) * 0.5

  local mMin = { math.huge, math.huge, math.huge }
  local mMax = { -math.huge, -math.huge, -math.huge }
  for _, f in ipairs(flexList) do
    local b = meshBounds(veh, f)
    if b then
      for i = 1, 3 do mMin[i] = math.min(mMin[i], b[1][i]); mMax[i] = math.max(mMax[i], b[2][i]) end
    end
  end
  if mMin[1] <= mMax[1] then
    local rMin = { math.huge, math.huge, math.huge }
    local rMax = { -math.huge, -math.huge, -math.huge }
    for _, cid in ipairs(ids) do
      local n = vdata.nodes[cid]
      local p = n and n.pos
      if p then
        rMin[1] = math.min(rMin[1], p.x); rMin[2] = math.min(rMin[2], p.y); rMin[3] = math.min(rMin[3], p.z)
        rMax[1] = math.max(rMax[1], p.x); rMax[2] = math.max(rMax[2], p.y); rMax[3] = math.max(rMax[3], p.z)
      end
    end
    if rMin[1] <= rMax[1] then
      half = vec3((mMax[1] - mMin[1]) * 0.5, (mMax[2] - mMin[2]) * 0.5, (mMax[3] - mMin[3]) * 0.5)
      c = c + vec3(-((mMin[1] + mMax[1]) - (rMin[1] + rMax[1])) * 0.5,
                   -((mMin[2] + mMax[2]) - (rMin[2] + rMax[2])) * 0.5,
                    ((mMin[3] + mMax[3]) - (rMin[3] + rMax[3])) * 0.5)
    end
  end
  half = vec3(math.max(half.x, 0.06), math.max(half.y, 0.06), math.max(half.z, 0.06))
  return { local_ = c, half = half, right = right, fwd = fwd, up = up }
end

-- Ganzes Auto (lokale Box aller Knoten), für die Blickrichtung
local function carBox(veh, vdata)
  local ids = {}
  for key, node in pairs(vdata.nodes or {}) do
    if type(node) == 'table' then table.insert(ids, node.cid or key) end
  end
  local right, fwd, up = axesOf(veh)
  local mn, mx = liveNodeBox(veh, ids, right, fwd, up)
  if not mn then return nil end
  return { center = (mn + mx) * 0.5, half = (mx - mn) * 0.5 }
end

local function sign(v) return v < 0 and -1 or 1 end
local function clamp1(v) return math.max(-1, math.min(1, v)) end

-- Kamera: von der Seite des Autos, auf der das Teil sitzt (vorne/hinten, links/rechts), leicht von oben.
-- Flache Teile an der Seite (Felgen, Spiegel, Türen, Schweller) eher von der Seite.
-- Paare (nur die rechte Seite wird gezeigt): immer von rechts, leicht von vorne, damit alle Felgen gleich aussehen.
local function autoDir(frame, car, side)
  if side then return vec3(side.s * 1, 0.42, 0.42):normalized() end
  local rel = frame.local_ - (car and car.center or vec3())
  local nx = car and clamp1(rel.x / math.max(car.half.x, 0.3)) or 0
  local ny = car and clamp1(rel.y / math.max(car.half.y, 0.5)) or 0
  local sx = math.abs(nx) < 0.15 and -0.55 or sign(nx) * (0.35 + 0.9 * math.abs(nx))
  local sy = math.abs(ny) < 0.15 and 0.8 or sign(ny) * (0.35 + 0.9 * math.abs(ny))
  local h = frame.half
  if h.x < 0.4 * math.max(h.y, h.z) and math.abs(nx) > 0.5 then sy = sy * 0.3 end
  return vec3(sx, sy, 0.5):normalized()
end

-- Kandidaten für die automatische Suche: die geschätzte Richtung, gespiegelt (andere Seite, vorne/hinten)
-- und von oben. Einseitige Meshes sieht man nur von einer Seite, das Bild mit dem meisten Inhalt gewinnt.
local function candidateDirs(frame, car, side)
  local d = autoDir(frame, car, side)
  if side then return { d } end
  return { d, vec3(-d.x, d.y, d.z), vec3(d.x, -d.y, d.z), vec3(-d.x, -d.y, d.z), vec3(d.x * 0.25, d.y * 0.25, 1):normalized() }
end

-- von Hand korrigierter Blickwinkel (Galerie: drehen, kippen) auf eine Richtung anwenden
local function applyView(dirLocal, view)
  if type(view) ~= 'table' then return dirLocal end
  local az = math.atan2(dirLocal.x, dirLocal.y) + math.rad(tonumber(view.yaw) or 0)
  local el = math.asin(math.max(-1, math.min(1, dirLocal.z))) + math.rad(tonumber(view.pitch) or 0)
  el = math.max(math.rad(-80), math.min(math.rad(85), el))
  return vec3(math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el))
end

local function cameraFrom(veh, frame, dirLocal, view)
  local dir = (frame.right * dirLocal.x + frame.fwd * dirLocal.y + frame.up * dirLocal.z):normalized()
  local vehPos = veh:getPosition()
  local center = vehPos + frame.right * frame.local_.x + frame.fwd * frame.local_.y + frame.up * frame.local_.z
  local radius = frame.half:length()
  local aspect = cfg.width / cfg.height
  local fovV = math.rad(cfg.fov)
  local fovH = 2 * math.atan(math.tan(fovV * 0.5) * aspect)
  local fit = math.min(fovV, fovH)
  local zoom = type(view) == 'table' and tonumber(view.zoom) or 1
  local dist = math.max(0.4, radius / math.sin(fit * 0.5) * cfg.padding / math.max(0.3, zoom))
  local pos = center + dir * dist
  local rot = quatFromDir((center - pos):normalized(), vec3(0, 0, 1))
  return pos, rot, center
end

-- Aufnahme -------------------------------------------------------------------------------------------

local aaRestore = nil
local function disableTemporalAA()
  local okType, aaType = pcall(settings.getValue, 'GraphicAntialiasType')
  local okAA, aa = pcall(settings.getValue, 'GraphicAntialias')
  if okType and okAA and aa == 4 and (aaType == 'fxaa' or aaType == 'smaaT2x') then
    settings.setValue('GraphicAntialias', 0)
    aaRestore = aa
  end
end
local function restoreAA()
  if aaRestore then settings.setValue('GraphicAntialias', aaRestore); aaRestore = nil end
end

local function mainExposure()
  local le = scenetree.findObject('PostEffectLocalExposureObject')
  if not le then return nil, nil end
  local view = RenderViewManagerInstance:getView('main')
  if le.autoExposure == true then return nil, view and view.currentExposure or nil end
  return le.manualEV, nil
end

-- Studio-Lampen: sechs Spots rundum (vier schräg von oben, eins von oben, eins schwach von unten).
-- Sie hängen nicht an der Kamera, damit mehrere Blickwinkel gleichzeitig gleich hell aufgenommen werden können.
-- lux = Beleuchtungsstärke am Teil; wie bei den BeamNG-Thumbnails (1000 lx bei Belichtung EV 8.3).
local studioLights = {}
local lightRoles = {
  { name = 'fr', az = 45,  el = 35, lux = 700 },
  { name = 'fl', az = -45, el = 35, lux = 600 },
  { name = 'rr', az = 135, el = 35, lux = 450 },
  { name = 'rl', az = -135, el = 35, lux = 450 },
  { name = 'top', az = 0,  el = 89, lux = 500 },
  { name = 'low', az = 90, el = -35, lux = 200 },
}

local function createLights()
  if #studioLights > 0 then return end
  for _, r in ipairs(lightRoles) do
    local ok, l = pcall(function()
      local o = createObject('SpotLight')
      o:setField('color', 0, '1 1 1 1')
      o:setField('isEnabled', 0, '1')
      o:registerObject('hashiriyaPartStudio_' .. r.name)
      o.canSave = false
      if scenetree.MissionGroup then scenetree.MissionGroup:addObject(o) end
      return o
    end)
    if ok and l then table.insert(studioLights, l) else log('W', logTag, 'Studio-Lampe nicht angelegt: ' .. tostring(l)) end
  end
end

local function deleteLights()
  for _, l in ipairs(studioLights) do pcall(function() l:delete() end) end
  studioLights = {}
end

local lightErrLogged, lightInfoLogged = false, false
local function studioMode() return cfg.lighting == 'studio' and cfg.background == 'focus' end

-- Lampen um das Teil stellen (Richtungen in Fahrzeugachsen: az 0 = vorne, 90 = rechts)
local function placeLights(frame, center)
  local mult = tonumber(cfg.light) or 1
  if not studioMode() then mult = mult * 3 end -- bei Tageslicht nur als Aufhellung
  local radius = frame.half:length()
  for i, l in ipairs(studioLights) do
    local r = lightRoles[i]
    local d = math.max(3, radius * 3 + 2)
    local a, e = math.rad(r.az), math.rad(r.el)
    local dirLocal = vec3(math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e))
    local dir = (frame.right * dirLocal.x + frame.fwd * dirLocal.y + frame.up * dirLocal.z):normalized()
    local pos = center + dir * d
    local up = math.abs(dir.z) > 0.98 and frame.fwd or vec3(0, 0, 1)
    local q = quatFromDir((center - pos):normalized(), up)
    local okL, errL = pcall(function()
      local m = QuatF(q.x, q.y, q.z, q.w):getMatrix()
      m:setPosition(pos)
      l:setTransform(m)
      local cone = math.min(150, 2 * math.deg(math.asin(math.min(1, (radius + 0.5) / d))) + 5)
      l:setField('intensity', 0, tostring(r.lux * mult * d * d))
      l:setField('range', 0, tostring(d + radius * 2 + 5))
      l:setField('innerAngle', 0, tostring(cone))
      l:setField('outerAngle', 0, tostring(math.min(170, cone + 20)))
      l:setField('castShadows', 0, '0')
      l:setField('isEnabled', 0, mult > 0 and '1' or '0')
      if l.postApply then l:postApply() end
    end)
    if not okL and not lightErrLogged then
      lightErrLogged = true
      log('W', logTag, 'Studio-Lampe nicht gestellt: ' .. tostring(errL))
    end
  end
  if not lightInfoLogged and studioLights[1] then
    lightInfoLogged = true
    local l = studioLights[1]
    pcall(function()
      log('I', logTag, string.format('Lampe 1: Klasse=%s an=%s Stärke=%s Reichweite=%s Pos=%s', tostring(l:getClassName()),
        tostring(l:getField('isEnabled', 0)), tostring(l:getField('intensity', 0)), tostring(l:getField('range', 0)),
        tostring(l:getPosition())))
    end)
  end
end

local function fileSize(path)
  local ok, data = pcall(readFile, path)
  if ok and type(data) == 'string' then return #data end
  local ok2, st = pcall(function() return FS:stat(path) end)
  if ok2 and type(st) == 'table' then return tonumber(st.filesize) or 0 end
  return 0
end

-- Offscreen-Bilder über eigene RenderViews (eine je Blickwinkel, alle gleichzeitig).
-- Der Bildschirm und die Oberfläche bleiben unverändert. Bei mehreren Blickwinkeln gewinnt das Bild
-- mit dem meisten Inhalt (größte JPG-Datei; leerer Hintergrund packt sich klein), der geschätzte Blickwinkel
-- bekommt einen kleinen Vorsprung, der Blick von oben einen kleinen Nachteil.
local function shoot(veh, shots, filename, done)
  local ss = math.max(1, math.floor(tonumber(cfg.supersampling) or 1))
  local w, h = math.floor(cfg.width * ss), math.floor(cfg.height * ss)
  local manualEV, curExp = mainExposure()
  local boost = tonumber(cfg.exposure) or 0
  local views_ = {}
  for i, sh in ipairs(shots) do
    local name = VIEW_NAME .. i
    local rv = RenderViewManagerInstance:getOrCreateView(name)
    rv.luaOwned = true
    local mat = QuatF(sh.rot.x, sh.rot.y, sh.rot.z, sh.rot.w):getMatrix()
    mat:setPosition(sh.pos)
    rv.renderCubemap = false
    rv.cameraMatrix = mat
    rv.resolution = Point2I(w, h)
    rv.viewPort = RectI(0, 0, w, h)
    rv.namedTexTargetColor = name
    rv.frustum = Frustum.construct(false, math.rad(cfg.fov), w / h, 0.05, 2000)
    rv.fov = cfg.fov
    rv.renderEditorIcons = false
    if cfg.background == 'focus' then
      pcall(function()
        rv:enterFocusObjectsMode()
        rv:addFocusObject(veh)
        for _, l in ipairs(studioLights) do rv:addFocusObject(l) end
      end)
      local c = cfg.bgColor or defaults.bgColor
      pcall(function() rv.clearColor = ColorF(c[1], c[2], c[3], 1) end)
    end
    if studioMode() then
      -- feste Belichtung wie im BeamNG-Thumbnail-Studio (EV 8.3), Regler „Belichtung“: +1 = doppelt so hell
      rv.useManualEV = true
      rv.manualEV = 9.3 - boost
    else
      rv.useManualEV = manualEV ~= nil
      -- Tageslicht: eine Blendenstufe heller als die Hauptansicht als Grundwert (die Schattenseite ist sonst zu dunkel)
      local stops = boost + 1
      rv.manualEV = (manualEV or 0) - stops
      if not rv.useManualEV and curExp and curExp > 0 then rv.currentExposure = curExp * (2 ^ stops) end
    end
    table.insert(views_, rv)
  end

  core_jobsystem.create(function(j)
    j.sleep(cfg.settleDelay or 0.6)
    local best, bestScore, bestBmp = nil, -1, nil
    for i, rv in ipairs(views_) do
      local tmp = filename .. '.tmp' .. i .. '.png'
      FS:removeFile(tmp)
      if rv:saveToDisk(tmp) then
        local bmp = GBitmap()
        if bmp:loadFile(tmp) then
          bmp:setFormat(10) -- R8G8B8
          local out = ss > 1 and bmp:createDownscaledBitmap(ss) or bmp
          if out then
            local score = 1
            if #views_ > 1 then
              local cand = filename .. '.cand' .. i .. '.jpg'
              if out:saveFile(cand) then score = fileSize('/' .. cand) end
              FS:removeFile(cand)
              if i == 1 then score = score * 1.12 elseif i == 5 then score = score * 0.88 end
            end
            if score > bestScore then best, bestScore, bestBmp = i, score, out end
          end
        end
      end
      FS:removeFile(tmp)
      RenderViewManagerInstance:destroyView(rv)
    end
    local ok = bestBmp and bestBmp:saveFile(filename) or false
    done(ok and true or false, best)
  end)
end

local function now() return os.clock() end
local function waitSeconds(s)
  local t = now() + s
  while now() < t do coroutine.yield() end
end
local function waitFrames(n) for _ = 1, n do coroutine.yield() end end

-- heller, kaum metallischer Lack: im Fokus-Modus gibt es keine Umgebung zum Spiegeln, Metallic wirkt dort fast schwarz
local studioPaint = {
  baseColor = { 0.78, 0.79, 0.81, 1 }, metallic = 0.1, roughness = 0.45, clearcoat = 0.3, clearcoatRoughness = 0.2,
}

local function pushJob()
  if not job then send({ job = false }); return end
  local j = job
  send({ job = {
    running = not j.finished, stopping = j.stop, finished = j.finished,
    model = j.modelName, modelIndex = j.modelIndex, modelCount = #j.models,
    done = j.done, skipped = j.skipped, failed = j.failed, noMesh = j.noMesh, planned = j.planned,
    round = j.round, rounds = j.rounds, last = j.last, lastName = j.lastName, text = j.text,
    elapsed = math.floor(now() - j.started),
  } })
end

local function setText(t) if job then job.text = t; pushJob() end end

local function deleteStudio()
  if job and job.vehId then
    local v = getObjectByID(job.vehId)
    if v then v:delete() end
    job.vehId = nil
  end
end

-- Studio-Auto mit dieser Konfiguration spawnen und warten, bis die Fahrzeugdaten da sind
local function spawnStudio(model, config)
  deleteStudio()
  table.clear(meshBoundsCache)
  local opt = { pos = job.pos, rot = quat(0, 0, 0, 1), autoEnterVehicle = false, cling = false,
    canSpawnAnotherVehicleCheck = false, licenseText = 'STUDIO' }
  if config then opt.config = config end
  local ok, veh = pcall(core_vehicles.spawnNewVehicle, model, opt)
  if not ok or not veh then
    log('E', logTag, 'Studio-Auto nicht gespawnt: ' .. tostring(model) .. ' ' .. tostring(veh))
    return nil
  end
  job.vehId = veh:getID()
  local t = now() + 8
  while now() < t do
    coroutine.yield()
    local vd = core_vehicle_manager.getVehicleData(job.vehId)
    if vd and vd.vdata and vd.config and vd.config.partsTree then
      local fid = false
      for _, f in pairs(vd.vdata.flexbodies or {}) do if f.fid then fid = true; break end end
      if fid or not next(vd.vdata.flexbodies or {}) then break end
    end
  end
  waitSeconds(0.3)
  local veh2 = getObjectByID(job.vehId)
  local vd = core_vehicle_manager.getVehicleData(job.vehId)
  if not veh2 or not vd or not vd.vdata then return nil end
  return veh2, vd
end

-- Ein Teil fotografieren: andere Meshes aus, Kamera ausrichten, Bild speichern
-- Seite (lokal x, relativ zur Automitte) eines Mesh-Eintrags aus seinen Knoten
local function entrySide(veh, e, right, cx)
  local ids = e._group_nodes or (e.idRef and { e.idRef }) or {}
  local sum, n = 0, 0
  for _, cid in ipairs(ids) do
    local px, py, pz = veh:getNodePositionXYZ(cid)
    if px then sum = sum + vec3(px, py, pz):dot(right); n = n + 1 end
  end
  if n == 0 then return nil end
  return sum / n - cx
end

-- Paar (z. B. Felgen links + rechts): alle Meshes klar links oder rechts, beide Seiten vorhanden.
-- Dann nur die Seite behalten, die zum Betrachter zeigt (wie bei einer Einzelteil-Vorschau).
local function splitPair(veh, entries, flexList, sel)
  if not cfg.singlePair or not job.car then return sel, flexList, nil end
  local right = axesOf(veh)
  local cx = job.car.center.x
  local sides, left, rightN = {}, 0, 0
  for _, e in ipairs(entries) do
    local x = entrySide(veh, e, right, cx)
    if not x or math.abs(x) < 0.2 then return sel, flexList, nil end
    sides[e] = x
    if x < 0 then left = left + 1 else rightN = rightN + 1 end
  end
  if left == 0 or rightN == 0 then return sel, flexList, nil end
  local keep = 1
  local sel2, flex2 = {}, {}
  for _, e in ipairs(entries) do
    if sides[e] * keep > 0 then sel2[e.mesh] = true end
  end
  for _, f in ipairs(flexList) do
    if sides[f] and sides[f] * keep > 0 then table.insert(flex2, f) end
  end
  return sel2, flex2, { s = keep, cx = cx }
end

-- Blickwinkel-Korrektur eines Teils: eigene, sonst die seines Slots (gilt für alle Teile im Slot)
local function viewOf(partName, slotId)
  local v = views[partName]
  if type(v) == 'table' then return v end
  v = slotId and views['slot:' .. tostring(slotId)]
  return type(v) == 'table' and v or nil
end

local function capturePart(veh, vd, partPath, partName, slotId)
  local all, sel, flexList, entries = meshesOf(vd.vdata, partPath)
  if not next(sel) then job.noMesh = job.noMesh + 1; return 'nomesh' end
  local side
  sel, flexList, side = splitPair(veh, entries, flexList, sel)
  local frame = frameOf(veh, vd.vdata, partPath, flexList, side)
  if not frame then job.failed = job.failed + 1; return 'noframe' end
  for _, m in ipairs(all) do veh:setMeshAlpha(sel[m] and 1 or 0, m, false) end

  local dirs = candidateDirs(frame, job.car, side)
  local view = viewOf(partName, slotId)
  local picked = tonumber(views._auto[partName])
  local list
  if view or not cfg.autoView or #dirs == 1 then
    -- feste Richtung: früher automatisch gefundene (falls vorhanden), darauf die Korrektur
    local base = dirs[(picked and dirs[picked]) and picked or 1]
    list = { applyView(base, view) }
  else
    list = dirs
  end
  local shots, center = {}, nil
  for _, d in ipairs(list) do
    local pos, rot, c = cameraFrom(veh, frame, d, view)
    center = c
    table.insert(shots, { pos = pos, rot = rot })
  end
  placeLights(frame, center)
  waitFrames(2)
  local file = fileOf(partName)
  local finished, result, bestIdx = false, false, nil
  shoot(veh, shots, file, function(ok, idx) finished, result, bestIdx = true, ok, idx end)
  local t = now() + (cfg.settleDelay or 0.6) + 8
  while not finished and now() < t do coroutine.yield() end
  if result then
    if #list > 1 and bestIdx then views._auto[partName] = bestIdx; job.viewsChanged = true end
    job.done = job.done + 1
    job.last = '/' .. file
    job.lastName = partName
    galleryDirty = true
  else
    job.failed = job.failed + 1
    log('W', logTag, 'Bild fehlgeschlagen: ' .. tostring(partName))
  end
  table.insert(job.log, { part = partName, model = job.model, ok = result })
  pushJob()
  return result and 'ok' or 'fail'
end

local function findSlotNode(tree, path)
  local found = nil
  local function walk(node)
    if found then return end
    for _, child in pairs(node.children or {}) do
      if type(child) == 'table' then
        if child.path == path then found = child; return end
        walk(child)
      end
    end
  end
  if type(tree) == 'table' then walk(tree) end
  return found
end

local function isAncestor(a, b) -- Slot-Pfad a enthält Slot-Pfad b
  return #a < #b and b:sub(1, #a) == a
end

local function runModel(model)
  job.model = model
  setText('Lade ' .. tostring(job.modelName))
  local veh, vd = spawnStudio(model, nil)
  if not veh then job.failed = job.failed + 1; return end
  if job.stop then return end

  local tree = vd.config.partsTree
  local baseParts = partsMapOf(tree)
  local base = { parts = baseParts, vars = deepcopy(vd.config.vars or {}), paints = deepcopy(vd.config.paints or {}) }
  if cfg.studioPaint then base.paints = { deepcopy(studioPaint), deepcopy(studioPaint), deepcopy(studioPaint) } end
  local okMap, slotMap = pcall(jbeamIO().getAvailableSlotNameMap, vd.ioCtx)
  if not okMap or type(slotMap) ~= 'table' then
    log('E', logTag, 'Slot-Liste nicht lesbar: ' .. tostring(model))
    job.failed = job.failed + 1
    return
  end

  -- Plan: je Slot die noch fehlenden Teile
  local meshCache = {}
  local slots = collectSlots(tree)
  local pending, planned = {}, 0
  local planSeen = {}
  local function wanted(n)
    if n == '' or job.seen[n] or planSeen[n] then return false end
    if cfg.skipExisting and hasImage(n) then job.skipped = job.skipped + 1; job.seen[n] = true; return false end
    if not partHasMesh(vd.ioCtx, n, meshCache) then job.seen[n] = true; return false end
    return true
  end
  for _, s in ipairs(slots) do
    local list = {}
    for _, n in ipairs(candidatesOf(vd.ioCtx, slotMap, s)) do
      if n ~= s.chosen and wanted(n) then planSeen[n] = true; table.insert(list, n) end
    end
    pending[s.path] = list
    planned = planned + #list
  end
  local baseWanted = {}
  for _, s in ipairs(slots) do
    if s.chosen ~= '' and wanted(s.chosen) then planSeen[s.chosen] = true; table.insert(baseWanted, s); planned = planned + 1 end
  end
  job.planned = job.planned + planned
  local maxRounds = 0
  for _, l in pairs(pending) do maxRounds = math.max(maxRounds, #l) end
  job.round, job.rounds = 0, maxRounds + 1
  pushJob()
  if planned == 0 then return end

  -- Durchgang 0: Serien-Teile
  veh, vd = spawnStudio(model, deepcopy(base))
  if not veh then job.failed = job.failed + 1; return end
  job.car = carBox(veh, vd.vdata)
  for _, s in ipairs(baseWanted) do
    if job.stop then return end
    local node = findSlotNode(vd.config.partsTree, s.path)
    if node and node.chosenPartName == s.chosen and node.partPath then
      setText(job.modelName .. ' · Serie · ' .. s.chosen)
      capturePart(veh, vd, node.partPath, s.chosen, s.id)
    end
    job.seen[s.chosen] = true
  end

  -- weitere Durchgänge: je Slot ein anderes Teil, ineinander steckende Slots nie gleichzeitig
  local order = {}
  for _, s in ipairs(slots) do table.insert(order, s) end
  table.sort(order, function(a, b) return #a.path > #b.path end)
  while true do
    if job.stop then return end
    local picks, pickedNames = {}, {}
    for _, s in ipairs(order) do
      local list = pending[s.path]
      while list and #list > 0 and (job.seen[list[1]] or pickedNames[list[1]]) do table.remove(list, 1) end
      if list and #list > 0 then
        local free = true
        for _, p in ipairs(picks) do
          if isAncestor(p.slot.path, s.path) or isAncestor(s.path, p.slot.path) then free = false; break end
        end
        if free then
          local n = table.remove(list, 1)
          pickedNames[n] = true
          table.insert(picks, { slot = s, part = n })
        end
      end
    end
    if #picks == 0 then break end
    job.round = job.round + 1
    local c = deepcopy(base)
    for _, p in ipairs(picks) do c.parts[p.slot.key] = p.part end
    setText(string.format('%s · Durchgang %d/%d (%d Teile)', job.modelName, job.round, job.rounds, #picks))
    veh, vd = spawnStudio(model, c)
    if not veh then
      for _, p in ipairs(picks) do job.seen[p.part] = true end
      job.failed = job.failed + #picks
    else
      job.car = carBox(veh, vd.vdata) or job.car
      for _, p in ipairs(picks) do
        if job.stop then return end
        local node = findSlotNode(vd.config.partsTree, p.slot.path)
        if node and node.chosenPartName == p.part and node.partPath then
          capturePart(veh, vd, node.partPath, p.part, p.slot.id)
        else
          job.failed = job.failed + 1
        end
        job.seen[p.part] = true
      end
    end
  end
end

-- Teile neu aufnehmen: Konfiguration des eigenen Autos, nacheinander mit jedem dieser Teile im Slot
local function runSingle(s)
  job.model = s.model
  job.planned = #s.parts
  for i, part in ipairs(s.parts) do
    if job.stop then return end
    setText(string.format('Neu aufnehmen %d/%d: %s', i, #s.parts, tostring(part)))
    local c = deepcopy(s.config)
    c.parts[s.key] = part
    local veh, vd = spawnStudio(s.model, c)
    if not veh then
      job.failed = job.failed + 1
    else
      job.car = carBox(veh, vd.vdata)
      local node = findSlotNode(vd.config.partsTree, s.path)
      if node and node.chosenPartName == part and node.partPath then
        capturePart(veh, vd, node.partPath, part, s.slotId)
      else
        log('W', logTag, 'Teil nach dem Spawn nicht im Slot: ' .. tostring(part))
        job.failed = job.failed + 1
      end
    end
  end
end

local saved = nil
local function prepareScene()
  saved = {}
  local ok, running = pcall(function() return be:getPhysicsRunning() end)
  saved.physics = (not ok) or running == true
  pcall(function() be:setPhysicsRunning(false) end)
  if (cfg.noonLight or studioMode()) and core_environment and core_environment.getTimeOfDay then
    local okT, tod = pcall(core_environment.getTimeOfDay)
    if okT and type(tod) == 'table' then
      saved.tod = deepcopy(tod)
      local t = deepcopy(tod)
      -- BeamNG: 0 = 12:00 Uhr, 0.5 = Mitternacht. Im Studio-Modus Nacht, damit nur die Studio-Lampen leuchten.
      t.time = studioMode() and 0.5 or 0
      t.play = false
      pcall(core_environment.setTimeOfDay, t)
    end
  end
  disableTemporalAA()
  createLights()
  pcall(FS.directoryCreate, FS, OUT_DIR, true)
end

local function restoreScene()
  deleteLights()
  if not saved then return end
  if saved.tod then pcall(core_environment.setTimeOfDay, saved.tod) end
  if saved.physics ~= false then pcall(function() be:setPhysicsRunning(true) end) end
  restoreAA()
  saved = nil
end

local function runJob()
  prepareScene()
  if job.single then
    job.modelIndex = 1
    job.modelName = job.models[1].name or job.models[1].key
    local ok, err = pcall(runSingle, job.single)
    if not ok then
      log('E', logTag, 'Neu aufnehmen fehlgeschlagen: ' .. tostring(err))
      job.failed = job.failed + 1
    end
  end
  for i, m in ipairs(job.single and {} or job.models) do
    if job.stop then break end
    job.modelIndex = i
    job.modelName = m.name or m.key
    local ok, err = pcall(runModel, m.key)
    if not ok then
      log('E', logTag, 'Fehler bei ' .. tostring(m.key) .. ': ' .. tostring(err))
      job.failed = job.failed + 1
    end
  end
  deleteStudio()
  restoreScene()
  if job.viewsChanged then saveViews() end
  job.finished = true
  job.text = job.stop and 'Abgebrochen' or 'Fertig'
  pcall(jsonWriteFile, LAST_RUN_FILE, {
    date = os.date('%Y-%m-%d %H:%M'), models = job.models, done = job.done, skipped = job.skipped,
    failed = job.failed, noMesh = job.noMesh, seconds = math.floor(now() - job.started), parts = job.log,
  }, true)
  log('I', logTag, string.format('Bilder: %d neu, %d schon da, %d fehlgeschlagen, %d ohne Mesh', job.done, job.skipped, job.failed, job.noMesh))
  pushJob()
end

-- Öffentliche Funktionen (Oberfläche) ----------------------------------------------------------------

local function studioPos()
  local ok, p = pcall(core_camera.getPosition)
  if not ok or not p then p = vec3(0, 0, 0) end
  return vec3(p.x, p.y, p.z + (cfg.heightAboveCamera or 150))
end

local function newJob(models)
  return { models = models, modelIndex = 0, done = 0, skipped = 0, failed = 0, noMesh = 0, planned = 0,
    round = 0, rounds = 0, seen = {}, log = {}, started = now(), pos = studioPos(), stop = false, finished = false }
end

-- models: Liste von Modell-Schlüsseln, oder 'current' (Modell des eigenen Autos)
function M.start(arg)
  if job and not job.finished then return end
  local data = type(arg) == 'string' and jsonDecode(arg) or arg or {}
  local keys = data.models
  if keys == 'current' then
    local v = getPlayerVehicle(0)
    keys = v and { v:getJBeamFilename() } or {}
  end
  local byKey = {}
  for _, m in ipairs(modelList()) do byKey[m.key] = m end
  local models = {}
  for _, k in ipairs(type(keys) == 'table' and keys or {}) do
    table.insert(models, byKey[k] or { key = k, name = k })
  end
  if #models == 0 then send({ status = { ok = false, text = 'Kein Fahrzeug ausgewählt' } }); return end
  job = newJob(models)
  job.co = coroutine.create(runJob)
  log('I', logTag, 'Bilderstellung gestartet: ' .. #models .. ' Fahrzeug(e)')
  pushJob()
end

-- Teile des eigenen Autos neu fotografieren (z. B. nach dem Korrigieren des Blickwinkels).
-- arg: { key = Slot-Schlüssel, path = Slot-Pfad, slotId, part = Teilname, parts = { Teilnamen } }
function M.reshoot(arg)
  local data = type(arg) == 'string' and jsonDecode(arg) or arg or {}
  if job and not job.finished then
    send({ status = { ok = false, text = 'Es läuft schon eine Bilderstellung' } }); return
  end
  local veh = getPlayerVehicle(0)
  if not veh or not data.key then return end
  local parts = {}
  for _, p in ipairs(type(data.parts) == 'table' and data.parts or { data.part }) do
    if type(p) == 'string' and p ~= '' then table.insert(parts, p) end
  end
  if #parts == 0 then return end
  local vd = core_vehicle_manager.getVehicleData(veh:getID())
  if not vd or not vd.config then return end
  local c = { parts = partsMapOf(vd.config.partsTree), vars = deepcopy(vd.config.vars or {}),
    paints = deepcopy(vd.config.paints or {}) }
  if cfg.studioPaint then c.paints = { deepcopy(studioPaint), deepcopy(studioPaint), deepcopy(studioPaint) } end
  local model = veh:getJBeamFilename()
  local name = model
  for _, m in ipairs(modelList()) do if m.key == model then name = m.name end end
  job = newJob({ { key = model, name = name } })
  job.single = { model = model, key = data.key, path = data.path, slotId = data.slotId, parts = parts, config = c }
  job.co = coroutine.create(runJob)
  pushJob()
end

-- Blickwinkel von Hand korrigieren und die Bilder gleich neu machen.
-- arg: { scope = 'slot' (alle Teile im Slot) oder 'part', slotId, part, parts, key, path,
--        dyaw = Grad, dpitch = Grad, dzoom = Faktor, reset = true }
function M.setView(arg)
  local data = type(arg) == 'string' and jsonDecode(arg) or arg or {}
  local vkey
  if data.scope == 'slot' and data.slotId then vkey = 'slot:' .. tostring(data.slotId)
  elseif data.part and data.part ~= '' then vkey = data.part end
  if not vkey then return end
  local v = views[vkey]
  if type(v) ~= 'table' then
    -- vom Teil-Wert ausgehen, falls das Teil schon eine eigene Korrektur hatte
    v = deepcopy(viewOf(data.part, data.slotId) or { yaw = 0, pitch = 0, zoom = 1 })
  end
  if data.reset then
    v = { yaw = 0, pitch = 0, zoom = 1 }
  else
    v.yaw = ((tonumber(v.yaw) or 0) + (tonumber(data.dyaw) or 0) + 180) % 360 - 180
    v.pitch = math.max(-90, math.min(90, (tonumber(v.pitch) or 0) + (tonumber(data.dpitch) or 0)))
    v.zoom = math.max(0.3, math.min(4, (tonumber(v.zoom) or 1) * (tonumber(data.dzoom) or 1)))
  end
  local neutral = v.yaw == 0 and v.pitch == 0 and math.abs(v.zoom - 1) < 0.001
  if neutral then views[vkey] = nil else views[vkey] = v end
  if data.scope == 'slot' then
    -- Slot-Korrektur ersetzt die eigenen Korrekturen der Teile in diesem Slot
    for _, p in ipairs(type(data.parts) == 'table' and data.parts or {}) do views[p] = nil end
  end
  if data.reset then
    -- „Auto“: auch die automatisch gefundene Richtung vergessen, damit neu gesucht wird
    for _, p in ipairs(type(data.parts) == 'table' and data.parts or { data.part }) do
      if type(p) == 'string' then views._auto[p] = nil end
    end
  end
  saveViews()
  galleryDirty = true
  if data.key then M.reshoot(data) end
end

function M.stop()
  if job and not job.finished then job.stop = true; setText('Wird abgebrochen …') end
end

function M.setSetting(key, value)
  if defaults[key] == nil then return end
  if type(value) == 'string' then
    if value == 'true' then value = true
    elseif value == 'false' then value = false
    elseif tonumber(value) then value = tonumber(value)
    elseif value:match('^[%[{]') then
      local ok, v = pcall(jsonDecode, value)
      if ok and v ~= nil then value = v end
    end
  end
  cfg[key] = value
  if key == 'types' then modelsCache = nil end
  saveSettings()
  send({ settings = cfg })
end

function M.resetSettings()
  cfg = deepcopy(defaults)
  modelsCache = nil
  saveSettings()
  send({ settings = cfg })
end

function M.openFolder()
  pcall(FS.directoryCreate, FS, OUT_DIR, true)
  pcall(function() Engine.Platform.exploreFolder('/' .. OUT_DIR) end)
end

-- Anzeigename eines Slots aus dem Eltern-Teil (slots2 description), sonst die Slot-ID
local function slotDescription(ioCtx, slot, cache)
  local parent = slot.parentPart
  if parent and cache[parent] == nil then
    local map = {}
    local ok, part = pcall(jbeamIO().getPart, ioCtx, parent)
    if ok and type(part) == 'table' then
      for _, s in ipairs(part.slots2 or part.slots or {}) do
        if type(s) == 'table' and s.name and type(s.description) == 'string' then map[s.name] = s.description end
      end
    end
    cache[parent] = map
  end
  local d = parent and cache[parent][slot.id]
  if d and d ~= '' then return d end
  return (tostring(slot.id):gsub('_', ' '))
end

-- Galerie: Slots des eigenen Autos mit allen passenden Teilen und ihren Bildern
local function galleryPayload()
  local veh = getPlayerVehicle(0)
  if not veh then return { vehicle = false } end
  local vd = core_vehicle_manager.getVehicleData(veh:getID())
  if not vd or not vd.config or not vd.ioCtx then return { vehicle = false } end
  local okMap, slotMap = pcall(jbeamIO().getAvailableSlotNameMap, vd.ioCtx)
  if not okMap or type(slotMap) ~= 'table' then return { vehicle = false } end
  local descs = partDescriptions(vd.ioCtx)
  local meshCache, slotDescCache = {}, {}
  local rows = {}
  local withImg, total = 0, 0
  for _, s in ipairs(collectSlots(vd.config.partsTree)) do
    local cands = candidatesOf(vd.ioCtx, slotMap, s)
    if #cands > 1 or (#cands == 1 and cands[1] ~= s.chosen) then
      local opts = {}
      for _, n in ipairs(cands) do
        local img = hasImage(n) and ('/' .. fileOf(n)) or nil
        if img then withImg = withImg + 1 end
        total = total + 1
        table.insert(opts, { part = n, name = displayName(descs, n), img = img,
          visual = partHasMesh(vd.ioCtx, n, meshCache), on = n == s.chosen, view = viewOf(n, s.id) })
      end
      table.sort(opts, function(a, b) return a.name:lower() < b.name:lower() end)
      table.insert(rows, { key = s.key, id = s.id, path = s.path, depth = s.depth,
        name = slotDescription(vd.ioCtx, s, slotDescCache), slotView = views['slot:' .. tostring(s.id)],
        parent = s.parentPart and displayName(descs, s.parentPart) or '', chosen = s.chosen,
        chosenName = s.chosen ~= '' and displayName(descs, s.chosen) or 'leer', options = opts })
    end
  end
  local model = veh:getJBeamFilename()
  local mName = model
  for _, m in ipairs(modelList()) do if m.key == model then mName = m.name end end
  return { vehicle = true, vehId = veh:getID(), model = model, modelName = mName, rows = rows,
    withImg = withImg, total = total }
end

function M.requestGallery()
  local ok, data = pcall(galleryPayload)
  if not ok then log('E', logTag, 'Galerie: ' .. tostring(data)); data = { vehicle = false, error = tostring(data) } end
  galleryVehId = data.vehId
  galleryDirty = false
  send({ gallery = data })
end

-- Teil am eigenen Auto einbauen (wie die BeamNG-Teileauswahl: das Auto wird neu aufgebaut)
function M.install(arg)
  local data = type(arg) == 'string' and jsonDecode(arg) or arg or {}
  local veh = getPlayerVehicle(0)
  if not veh or not data.key then return end
  local vd = core_vehicle_manager.getVehicleData(veh:getID())
  if not vd or not vd.config then return end
  local c = { parts = partsMapOf(vd.config.partsTree), vars = deepcopy(vd.config.vars or {}),
    paints = deepcopy(vd.config.paints or {}) }
  c.parts[data.key] = data.part or ''
  local ok, err = pcall(core_vehicles.replaceVehicle, veh:getJBeamFilename(), { config = c })
  if not ok then
    log('E', logTag, 'Einbau fehlgeschlagen: ' .. tostring(err))
    send({ status = { ok = false, text = 'Einbau fehlgeschlagen' } })
    return
  end
  send({ status = { ok = true, text = 'Eingebaut: ' .. tostring(data.name or data.part) } })
  galleryDirty = true
end

function M.requestState()
  send({ active = active, settings = cfg, models = modelList() })
  pushJob()
end

local function levelLoaded()
  local ok, n = pcall(function() return getCurrentLevelIdentifier and getCurrentLevelIdentifier() end)
  return ok and n ~= nil and n ~= ''
end

local closeMenuTimer = nil
function M.closeMenu()
  local router = extensions.ui_router or rawget(_G, 'ui_router')
  if not router then pcall(extensions.load, 'ui_router'); router = extensions.ui_router end
  if router and router.navigate then pcall(router.navigate, 'play') end
end

function M.open()
  if not levelLoaded() then
    -- aus dem Hauptmenü: kleines Test-Level laden, danach das Panel öffnen
    local ff = rawget(_G, 'freeroam_freeroam') or (extensions.load('freeroam_freeroam') and freeroam_freeroam)
    if ff and ff.startFreeroamByName and ff.startFreeroamByName(STUDIO_LEVEL) then
      pendingOpen = true
      return
    end
  end
  active = true
  -- Aus dem Menü (Esc > Mehr) geöffnet: das Menü schließen, sonst bleibt es über dem Spiel stehen
  -- und das Fenster (nur im Spiel sichtbar) erscheint nie. Kurz danach noch einmal, falls das Menü
  -- nach dem Klick selbst noch einmal umschaltet.
  M.closeMenu()
  closeMenuTimer = 0.4
  M.requestState()
  M.requestGallery()
end

function M.close()
  active = false
  send({ active = false })
end

function M.toggle()
  if active then M.close() else M.open() end
end

-- Hooks ---------------------------------------------------------------------------------------------

local galleryTimer = 0
function M.onUpdate(dtReal)
  if job and job.co and coroutine.status(job.co) ~= 'dead' then
    local ok, err = coroutine.resume(job.co)
    if not ok then
      log('E', logTag, 'Bilderstellung abgebrochen: ' .. tostring(err))
      pcall(deleteStudio)
      restoreScene()
      job.finished = true
      job.text = 'Fehler: ' .. tostring(err)
      pushJob()
    end
  end
  if closeMenuTimer then
    closeMenuTimer = closeMenuTimer - (dtReal or 0)
    if closeMenuTimer <= 0 then closeMenuTimer = nil; M.closeMenu() end
  end
  if openFallback then
    openFallback = openFallback - (dtReal or 0)
    if openFallback <= 0 then openFallback = nil; M.onLoadingScreenFadeout() end
  end
  -- Galerie nachziehen (neue Bilder, anderes Auto, Teil eingebaut)
  if active then
    galleryTimer = galleryTimer - (dtReal or 0)
    if galleryTimer <= 0 then
      galleryTimer = 1.5
      local v = getPlayerVehicle(0)
      local id = v and v:getID() or nil
      if galleryDirty or id ~= galleryVehId then M.requestGallery() end
    end
  end
end

function M.onClientStartMission()
  if pendingOpen then openFallback = 6 end
end

function M.onLoadingScreenFadeout()
  if not pendingOpen then return end
  pendingOpen = false
  openFallback = nil
  M.closeMenu()
  active = true
  M.requestState()
  M.requestGallery()
end

function M.onVehicleSpawned(vid)
  if not job or job.finished or job.vehId ~= vid then galleryDirty = true end
end

function M.onVehicleSwitched() galleryDirty = true end

function M.onClientEndMission()
  if job and not job.finished then job.stop = true end
end

function M.onExtensionLoaded()
  loadSettings()
  loadViews()
end

function M.onExtensionUnloaded()
  if job and not job.finished then pcall(deleteStudio); restoreScene() end
end

return M
