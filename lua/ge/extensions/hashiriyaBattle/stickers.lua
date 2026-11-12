-- Hashiriya Battle: Aufkleber (Sticker) für das eigene Auto, wie in TXR
--
-- Garage, Reiter „Aufkleber“. Nutzt die Aufkleber-Technik des Spiels (editor_api_dynamicDecals, dieselbe wie der
-- Livery-Editor): der gewählte Aufkleber wird von der Kamera aus auf die Karosserie projiziert (Live-Vorschau),
-- „Aufkleben“ setzt ihn fest. Kamera = Orbit-Kamera des Spiels mit festen Ansichten (Links, Rechts, Vorne, Hinten,
-- Oben) und Drehen in kleinen Schritten; die Lage auf dem Auto verschiebt man über den Zielpunkt im Bild.
--
-- Welche Aufkleber: dieselben wie in der Trophäenwand (logos.lua): Crew-Logo und Crew-Symbol nach dem Sieg gegen den
-- Leader (Leader-Varianten mit Goldrand dazu), Wanderer-Siegel und Boss-Embleme nach dem Sieg, dazu immer das 走.
-- Bilder: art/stickers/<logo>.png (erzeugt von tools/logos/build_stickers.py aus art/logos/*.svg).
--
-- Preis: data/stickers.json "price" (3000 ¥) pro aufgeklebtem Sticker, Entfernen kostenlos (kein Geld zurück).
-- Gespeichert pro Auto: Ebenen-Datei settings/hashiriya_battle/stickers/<skin>.dynDecals.json, dazu exportiert das
-- Spiel einen Lack-Skin (Mod-Ordner mods/unpacked/<skin>), der als paint_design im Auto steht. car.stickerSkin merkt
-- sich den Namen, car.stickerCount die Anzahl.
local M = {}

local logTag = 'hashiriyaBattle.stickers'
local function log(level, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, logTag, text) else _G.log(level, logTag, text) end end
local function core() return extensions.hashiriyaBattle_core end
local function rivals() return extensions.hashiriyaBattle_rivals end

local data = nil
local function cfg()
  if not data then data = jsonReadFile('/lua/ge/extensions/hashiriyaBattle/data/stickers.json') or {} end
  return data
end

local SAVE_DIR = 'settings/hashiriya_battle/stickers/'
local ART = '/art/stickers/'

-- Laufender Sticker-Modus
local session = nil   -- { vehId, skinBefore, skinName, count, placed, sel, scale, rot, view, dirty }

local function api() return extensions.editor_api_dynamicDecals end

-- Sammlung -----------------------------------------------------------------------------------------
-- Liste aller Aufkleber mit Freischaltung, in Reihenfolge der Trophäenwand
function M.entries(save)
  local list = { { id = 'hashiriya', name = core().t('logos.default'), file = cfg().defaultSticker or '/ui/ui-vue/mods/hashiriyaBattle/assets/icon.png', unlocked = true, kind = 'default' } }
  local logos = extensions.hashiriyaBattle_logos
  if not logos or not logos.entries then return list end
  for _, e in ipairs(logos.entries(save)) do
    if e.kind == 'crew' then
      local id = e.id
      table.insert(list, { id = id .. '_icon', name = e.name, file = ART .. id .. '_icon.png', unlocked = e.unlocked, kind = 'crew', color = e.color })
      table.insert(list, { id = id, name = e.name, file = ART .. id .. '.png', unlocked = e.unlocked, kind = 'crew', color = e.color })
      table.insert(list, { id = id .. '_leader_icon', name = e.name, file = ART .. id .. '_leader_icon.png', unlocked = e.unlocked, kind = 'leader', color = e.color })
      table.insert(list, { id = id .. '_leader', name = e.name, file = ART .. id .. '_leader.png', unlocked = e.unlocked, kind = 'leader', color = e.color })
    else
      table.insert(list, { id = e.id, name = e.name, file = ART .. e.id .. '.png', unlocked = e.unlocked, kind = e.kind, hidden = not e.unlocked })
    end
  end
  return list
end

local function find(save, id)
  for _, e in ipairs(M.entries(save)) do if e.id == id then return e end end
end

-- Hilfen ---------------------------------------------------------------------------------------------
local function activeCar()
  local save = core().save
  return save and save.cars and save.cars[save.activeCar or 1] or nil, save
end

local function skinNameFor(save, car)
  -- nur Buchstaben, Ziffern, _ und - (Regel der Spiel-Speicherfunktion)
  local slot = tostring(core().currentSlot and core().currentSlot() or 1):gsub('[^%w]', '')
  car.stickerId = car.stickerId or (tostring(os.time()) .. tostring(math.random(100, 999)))
  return 'hashiriya_s' .. slot .. '_' .. tostring(car.stickerId):gsub('[^%w_%-]', '')
end

local function hasDynamicSlot(veh)
  local ok, res = pcall(function()
    return core_vehicle_partmgmt.hasAvailablePart(veh.JBeam .. '_skin_dynamicTextures')
  end)
  return ok and res and true or false
end

local function currentSkin(veh)
  local ok, res = pcall(function()
    local vd = core_vehicle_manager.getPlayerVehicleData()
    local parts = vd and vd.config and core_vehicle_partmgmt.partsTreeToPartsMap(vd.config.partsTree) or {}
    for slot, part in pairs(parts) do
      if type(slot) == 'string' and slot:match('paint_design$') and type(part) == 'string' and part ~= '' then
        local prefix = veh.JBeam .. '_skin_'
        if part:sub(1, #prefix) == prefix then return part:sub(#prefix + 1) end
      end
    end
    return nil
  end)
  return ok and res or nil
end

local function setCursor()
  local a = api()
  local s = session
  if not a or not s then return end
  local e = s.sel and find(core().save, s.sel)
  if not e or not e.unlocked then
    -- Vorschau aus (wie der Livery-Editor: Farbe unsichtbar, dann Projektion aus)
    pcall(function()
      a.setDecalColor(Point4F(1, 1, 1, 0))
      a.onUpdate_()
      a.setProjectDynamicDecalsState(false)
    end)
    return
  end
  pcall(function()
    a.setCursorPosition(Point2F(0.5 + s.cx, 0.5 + s.cy))
    a.setDecalTexturePath('color', e.file)
    a.setDecalColor(Point4F(1, 1, 1, 1))
    a.setDecalScale(vec3(s.scale, 1, s.scale))
    a.setDecalSkew(Point2F(0, 0))
    a.setDecalRotation(math.rad(s.rot))
    a.setMirrored(false)
    a.setProjectDynamicDecalsState(true)
  end)
end

-- Kamera: feste Ansichten wie im Livery-Editor (ui/liveries/camera.lua): Orbit-Kamera, Standard-Drehung setzen, zurücksetzen
local VIEWS = { top = vec3(90, -90, 0), left = vec3(-90, 0, 0), right = vec3(90, 0, 0), back = vec3(0, 0, 0), front = vec3(180, 0, 0) }
local function vehId() return be:getPlayerVehicleID(0) end
local function setView(name)
  local v = VIEWS[name]
  if not v or not session then return end
  session.view = name
  session.camRot = vec3(v)
  pcall(function()
    commands.setGameCamera()
    core_camera.setByName(0, 'orbit', false)
    core_camera.setDefaultRotation(vehId(), session.camRot)
    core_camera.resetCamera(0)
  end)
end

-- Kamera in kleinen Schritten drehen (Gier/Neigung in Grad)
local function turnCamera(dYaw, dPitch)
  local s = session
  if not s or not s.camRot then return end
  s.camRot = vec3(s.camRot.x + dYaw, math.max(-85, math.min(30, s.camRot.y + dPitch)), 0)
  s.view = nil
  pcall(function()
    core_camera.setDefaultRotation(vehId(), s.camRot)
    core_camera.setRotation(vehId(), s.camRot)
  end)
end

local function rememberCamera()
  local ok, rot = pcall(function()
    local cam = core_camera.getCameraDataById(vehId())
    return cam and cam.orbit and cam.orbit.defaultRotation and vec3(cam.orbit.defaultRotation) or nil
  end)
  return ok and rot or nil
end

local function restoreCamera(rot)
  pcall(function()
    commands.setGameCamera()
    core_camera.setByName(0, 'orbit', false)
    if rot then core_camera.setDefaultRotation(vehId(), rot) end
    core_camera.resetCamera(0)
  end)
end

local function keepState()
  -- setSkin baut das Auto neu: Tank und Verschleiß wie bei jedem Respawn der Mod mitnehmen
  pcall(function() extensions.hashiriyaBattle_fuel.keepAfterRespawn() end)
  pcall(function() extensions.hashiriyaBattle_condition.keepAfterRespawn() end)
end

-- Modus starten / beenden ----------------------------------------------------------------------------
function M.isActive() return session ~= nil end

function M.start()
  if session then return true end
  local car, save = activeCar()
  local veh = core().getPlayerVehicle()
  if not car or not veh then return false end
  if not hasDynamicSlot(veh) then
    session = { unsupported = 'model' }
    return false
  end
  -- Das Auto wird beim Wechsel des Lack-Slots neu gebaut, das würde Schäden wegreparieren
  if (extensions.hashiriyaBattle_parking.repairCost() or 0) > 0 then
    session = { unsupported = 'damage' }
    return false
  end
  local ok = pcall(function() extensions.load('editor_api_dynamicDecals') end)
  local a = api()
  if not ok or not a then
    log('E', 'editor_api_dynamicDecals nicht ladbar')
    session = { unsupported = 'api' }
    return false
  end
  session = {
    vehId = veh:getID(), skinBefore = currentSkin(veh), skinName = skinNameFor(save, car),
    count = tonumber(car.stickerCount) or 0, placed = 0, sel = nil,
    scale = cfg().defaultScale or 0.5, rot = 0, view = 'left', cx = 0, cy = 0,
    camBefore = rememberCamera(),
  }
  keepState()
  local okS, err = pcall(function()
    a.setProjectDynamicDecalsState(false)
    a.setLayerNameBuildString('@type { - @colormap}')
    a.setup()
    core_vehicle_partmgmt.setSkin('dynamicTextures')
    a.clearLayerStack()
    local file = SAVE_DIR .. session.skinName .. '.dynDecals.json'
    if FS:fileExists(file) then
      a.loadLayerStackFromFile(file)
    else
      -- leere Grundebene in Lackfarbe des Autos (wie der Livery-Editor ohne Speicherstand)
      if a.setFillLayerColorPaletteMapId then
        pcall(function() extensions.load('ui_liveries_paint') end)
        local lp = extensions.ui_liveries_paint
        a.setFillLayerColorPaletteMapId((lp and lp.EDITABLE_COLOR_PALETTE_MAP_ID) or cfg().paletteMapId or 1)
      end
      a.setFillLayerColor(veh.color or Point4F(1, 1, 1, 1))
      a.addFillLayer()
    end
    local h = a.getHistory and a.getHistory()
    if h and h.clear then h:clear() end
    a.onUpdate_()
    a.setEnabled(true)
  end)
  if not okS then
    log('E', 'Sticker-Modus: ' .. tostring(err))
    M.cancel()
    session = { unsupported = 'api', error = tostring(err) }
    return false
  end
  setView('left')
  log('I', 'Sticker-Modus gestartet: ' .. session.skinName .. ' (vorher ' .. tostring(session.skinBefore) .. ')')
  return true
end

-- Ohne Speichern raus (Fehler)
function M.cancel()
  local s = session
  session = nil
  local a = api()
  if a then
    pcall(a.setProjectDynamicDecalsState, false)
    pcall(a.setEnabled, false)
  end
  if s and not s.unsupported then
    keepState()
    pcall(function() core_vehicle_partmgmt.setSkin(s.skinBefore or '') end)
    restoreCamera(s.camBefore)
  end
end

-- Fertig: speichern, Skin exportieren und anlegen
function M.finish()
  local s = session
  if not s then return end
  if s.unsupported then session = nil; return end
  local a = api()
  local car, save = activeCar()
  session = nil
  if not a or not car then return end
  pcall(a.setProjectDynamicDecalsState, false)
  restoreCamera(s.camBefore)
  if not s.dirty then
    pcall(a.setEnabled, false)
    keepState()
    pcall(function() core_vehicle_partmgmt.setSkin(s.skinBefore or '') end)
    return
  end
  local veh = core().getPlayerVehicle()
  local ok, err = pcall(function()
    a.saveLayerStackToFile(SAVE_DIR .. s.skinName .. '.dynDecals.json')
    a.exportSkin(veh.JBeam, s.skinName)
  end)
  pcall(a.setEnabled, false)
  if not ok then
    log('E', 'Aufkleber speichern: ' .. tostring(err))
    keepState()
    pcall(function() core_vehicle_partmgmt.setSkin(s.skinBefore or '') end)
    core().msg(core().t('stickers.saveFailed'), 6)
    return
  end
  car.stickerSkin = s.count > 0 and s.skinName or nil
  car.stickerCount = s.count
  -- der neue Skin ist ein frischer Mod-Ordner: warten, bis das Spiel das Teil kennt (hasAvailablePart), dann anlegen.
  -- Ohne Sticker (alle entfernt): alten Lack-Skin zurück.
  local back = (s.skinBefore and s.skinBefore ~= s.skinName and s.skinBefore ~= 'dynamicTextures') and s.skinBefore or ''
  M.pendingApply = { skin = s.count > 0 and s.skinName or back, wait = cfg().applyTimeout or 8, poll = 0.3,
    carIdx = save.activeCar or 1, jbeam = veh.JBeam }
  core().writeSave()
end

-- Anlegen nach dem Export; danach die Config des Autos mit dem neuen Lack-Skin speichern
local function applyPending(dt)
  local p = M.pendingApply
  if not p then return end
  p.poll = p.poll - dt
  p.wait = p.wait - dt
  if p.poll > 0 then return end
  p.poll = 0.3
  if p.skin ~= '' then
    local okA, avail = pcall(function() return core_vehicle_partmgmt.hasAvailablePart(p.jbeam .. '_skin_' .. p.skin) end)
    if not (okA and avail) then
      if p.wait > 0 then return end
      M.pendingApply = nil
      log('W', 'Aufkleber-Skin ' .. p.skin .. ' nach dem Export nicht gefunden; er erscheint nach dem nächsten Neuladen der Mods')
      core().msg(core().t('stickers.applyLater'), 7)
      return
    end
  end
  M.pendingApply = nil
  keepState()
  local ok, err = pcall(function() core_vehicle_partmgmt.setSkin(p.skin) end)
  if not ok then log('E', 'Skin anlegen: ' .. tostring(err)); return end
  M.pendingCapture = { timer = 1.5, carIdx = p.carIdx }
end

local function capturePending(dt)
  local p = M.pendingCapture
  if not p then return end
  p.timer = p.timer - dt
  if p.timer > 0 then return end
  M.pendingCapture = nil
  local save = core().save
  local car = save and save.cars and save.cars[p.carIdx]
  if not car or (save.activeCar or 1) ~= p.carIdx then return end
  local cfgNow = extensions.hashiriyaBattle_shop.currentConfig()
  if cfgNow then
    car.config = cfgNow
    core().writeSave()
    log('I', 'Aufkleber-Skin in der Config gespeichert: ' .. tostring(car.stickerSkin))
  end
end

-- Bedienung ------------------------------------------------------------------------------------------
function M.select(id)
  if not session or session.unsupported then return end
  local e = find(core().save, id)
  if not e or not e.unlocked then return end
  session.sel = (session.sel == id) and nil or id
  setCursor()
end

function M.adjust(what, dir)
  local s = session
  if not s or s.unsupported then return end
  dir = tonumber(dir) or 0
  local c = cfg()
  if what == 'size' then
    s.scale = math.max(c.minScale or 0.1, math.min(c.maxScale or 2.5, s.scale * ((dir > 0) and (c.scaleStep or 1.15) or 1 / (c.scaleStep or 1.15))))
  elseif what == 'rot' then
    s.rot = (s.rot + dir * (c.rotStep or 15)) % 360
  elseif what == 'x' then
    s.cx = math.max(-0.4, math.min(0.4, s.cx + dir * (c.moveStep or 0.03)))
  elseif what == 'y' then
    s.cy = math.max(-0.4, math.min(0.4, s.cy + dir * (c.moveStep or 0.03)))
  elseif what == 'yaw' then
    turnCamera(dir * (c.turnStep or 15), 0)
  elseif what == 'pitch' then
    turnCamera(0, dir * (c.turnStep or 15))
  elseif what == 'reset' then
    s.cx, s.cy, s.rot, s.scale = 0, 0, 0, c.defaultScale or 0.5
  end
  setCursor()
end

function M.view(name) if session and not session.unsupported then setView(name) end end

function M.place()
  local s = session
  if not s or s.unsupported or not s.sel then return end
  local save = core().save
  local price = cfg().price or 3000
  if (save.money or 0) < price then
    core().msg(core().t('stickers.noMoney', core().economy().formatYen(price)), 4)
    return
  end
  local ok, err = pcall(function() api().addDecal() end)
  if not ok then log('E', 'Aufkleben: ' .. tostring(err)); return end
  save.money = save.money - price
  s.count = s.count + 1
  s.placed = s.placed + 1
  s.dirty = true
  pcall(function() extensions.hashiriyaBattle_progress.bump(save, 'stickersPlaced') end)
  if core().sound then pcall(core().sound, 'buy') end
  core().writeSave()
end

-- Letzten Sticker entfernen (kostenlos)
function M.removeLast()
  local s = session
  if not s or s.unsupported then return end
  local a = api()
  local ok, n = pcall(function() return #a.getLayerStack() end)
  if not ok or not n or n <= 1 then return end -- unterste Ebene ist der Lack
  pcall(function() a.removeLayer(n, nil) end)
  s.count = math.max(0, s.count - 1)
  s.dirty = true
end

function M.removeAll()
  local s = session
  if not s or s.unsupported then return end
  local a = api()
  for _ = 1, 200 do
    local ok, n = pcall(function() return #a.getLayerStack() end)
    if not ok or not n or n <= 1 then break end
    pcall(function() a.removeLayer(n, nil) end)
  end
  s.count = 0
  s.dirty = true
end

-- Menü ----------------------------------------------------------------------------------------------
function M.getUiState()
  local save = core().save
  if not save then return nil end
  local s = session
  local t = function(k, ...) return core().t(k, ...) end
  local car = activeCar()
  local out = {
    active = s ~= nil and not s.unsupported,
    unsupported = s and s.unsupported or nil,
    moved = s and not s.unsupported and (s.cx ~= 0 or s.cy ~= 0) or nil,
    price = core().economy().formatYen(cfg().price or 3000),
    count = s and not s.unsupported and s.count or (car and car.stickerCount or 0),
    sel = s and s.sel or nil, view = s and s.view or nil,
    scale = s and s.scale and math.floor(s.scale * 100 + 0.5) or nil, rot = s and s.rot or nil,
    canPay = (save.money or 0) >= (cfg().price or 3000),
    groups = {},
  }
  local groups = {
    { key = 'default', name = t('stickers.g.default'), list = {} },
    { key = 'crew', name = t('aura.g.crew'), list = {} },
    { key = 'wanderer', name = t('logos.g.wanderer'), list = {} },
    { key = 'boss', name = t('logos.g.boss'), list = {} },
  }
  local byKey = { default = groups[1], crew = groups[2], leader = groups[2], wanderer = groups[3], boss = groups[4] }
  for _, e in ipairs(M.entries(save)) do
    local g = byKey[e.kind]
    if g then
      table.insert(g.list, { id = e.id, unlocked = e.unlocked, name = e.hidden and '???' or e.name,
        img = (not e.hidden) and e.file or nil, selected = s and s.sel == e.id or false })
      if e.unlocked then g.have = (g.have or 0) + 1 end
    end
  end
  for _, g in ipairs(groups) do g.have = g.have or 0; g.total = #g.list end
  out.groups = groups
  return out
end

function M.onUpdate(dtReal)
  -- Reiter gewechselt oder Garage verlassen: speichern und beenden
  if session and core().stickerTabOpen and not core().stickerTabOpen() then
    if session.unsupported then session = nil else M.finish() end
  end
  if session and not session.unsupported then
    local a = api()
    local veh = core().getPlayerVehicle()
    if not veh then
      -- Auto weg: ohne Speichern beenden
      M.cancel()
      return
    end
    if a then
      local ok, err = pcall(a.onUpdate_)
      if not ok then log('E', 'onUpdate_: ' .. tostring(err)); M.cancel() end
    end
  end
  applyPending(dtReal or 0)
  capturePending(dtReal or 0)
end

function M.onClientEndMission() if session then M.cancel() end end

return M
