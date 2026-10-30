-- Hashiriya Battle: Tuning-Shop (Einzelteile je Slot, nach Stufen freigeschaltet)
-- Welche Teile es gibt, kommt zur Laufzeit aus BeamNG: alle Teile, die in die Slots des
-- Spielerautos passen. data/tuning.json legt fest, welche Slots im Shop auftauchen und
-- welche Stufe (LV1-3) ein Teil bekommt. Gekaufte Teile bleiben im Besitz.
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
local rulesPath = '/lua/ge/extensions/hashiriyaBattle/data/tuning.json'

local rules = nil
local catalog = nil        -- { vehId = id, slots = { [slot] = { key = configKey, options = {...} } } }
local retryTimer = 0
local activeTab = 'engine'
local warnedNoConfig = false

local function core() return extensions.hashiriyaBattle_core end

function M.loadData()
  rules = jsonReadFile(rulesPath) or { tiers = {}, tabs = {}, levelWords = {}, exclude = {}, overrides = {} }
  catalog = nil
end

local function activeCar()
  local save = core().save
  return save and save.cars[save.activeCar or 1] or nil
end

-- Hilfen -----------------------------------------------------------------------

local function tokens(str)
  local out = {}
  for w in tostring(str or ''):lower():gmatch('[%w]+') do out[w] = true end
  return out
end

local function lastSegment(key)
  return (key:gsub('/+$', ''):match('([^/]+)$')) or key
end

-- Passt der Slot zu einem Eintrag wie "_engine_ecu"? Erlaubt Varianten wie "_engine_ecu_2.0".
local function slotMatches(slot, item)
  for _, pat in ipairs(item.pattern or {}) do
    if slot:find(pat) then return true end
  end
  for _, suf in ipairs(item.slot or {}) do
    if slot:sub(-#suf) == suf or slot:find(suf .. '_[%d%.]+$') then return true end
    -- Varianten hinter dem Slot direkt nach dem Modellnamen, z. B. bx_engine_ecu_i4, bx_bumper_F_fixed
    local esc = suf:gsub('%p', '%%%0')
    if slot:find('^[^_]+' .. esc .. '_') then return true end
  end
  return false
end

-- Anzeigename aus den jbeam-Infos (Markenteile haben {txt=..., ctx={brand1=...}}).
local function niceName(desc, partName)
  if type(desc) == 'string' and desc ~= '' then return desc end
  if type(desc) == 'table' then
    local txt = tostring(desc.txt or desc[1] or '')
    txt = txt:match('([^%.]+)$') or txt
    local brand = desc.ctx and desc.ctx.brand1
    if brand then txt = txt:gsub('BRAND', (tostring(brand):match('([^%.]+)$') or brand)) end
    if txt ~= '' then return txt end
  end
  return partName
end

local function slotExcluded(slot)
  for _, pat in ipairs(rules.slotExclude or {}) do
    if slot:find(pat) then return true end
  end
  return false
end

local function partLevel(partName, display, item)
  local o = rules.overrides and rules.overrides[partName]
  if o ~= nil then return o end
  local tk = tokens(partName) -- Teilename in Wörter zerlegen (Trenner: _ . Leerzeichen)
  for w in pairs(tokens(display)) do tk[w] = true end
  for _, ex in ipairs(rules.exclude or {}) do
    if tk[ex:lower()] then return 0 end
  end
  for lv = 3, 1, -1 do
    for _, w in ipairs((rules.levelWords or {})[tostring(lv)] or {}) do
      if tk[w:lower()] then return lv end
    end
  end
  return item.defaultLevel or 0
end

local function tierInfo(level)
  for _, t in ipairs(rules.tiers or {}) do
    if t.level == level then return t end
  end
  return { level = level, unlock = {} }
end

-- Stufe freigeschaltet? Zweiter Wert = Text, was fehlt (Rang oder Siege)
local function isUnlocked(level)
  local c = core()
  local unlock = tierInfo(level).unlock
  if unlock.minRank then
    local pr = extensions.hashiriyaBattle_progress
    if pr.rankIndex(c.save) < unlock.minRank then
      local r = (extensions.hashiriyaBattle_rivals.getData().ranks or {})[unlock.minRank + 1]
      return false, c.t('shop.needRank', r and pr.loc(r.name) or tostring(unlock.minRank + 1))
    end
  end
  local need = unlock.minWins or 0
  if (c.save.wins or 0) < need then return false, c.t('shop.needWins', need) end
  return true, nil
end

local function yen(usd) return core().economy().usdToPrice(usd or 0) end

-- Katalog aus den Teilen des aktuellen Autos aufbauen ----------------------------

local function currentConfig()
  local ok, vd = pcall(function() return core_vehicle_manager.getPlayerVehicleData() end)
  if not ok or not vd then return nil end
  local cfg = vd.config or {}
  -- Ab 0.40 gibt es nur noch den Teilebaum (partsTree); BeamNG macht daraus selbst eine flache
  -- Slot -> Teil-Liste (bei doppelten Slot-Namen ist der Schlüssel der volle Pfad).
  local parts = cfg.parts
  if type(parts) ~= 'table' and cfg.partsTree and core_vehicle_partmgmt and core_vehicle_partmgmt.partsTreeToPartsMap then
    local okMap, map = pcall(core_vehicle_partmgmt.partsTreeToPartsMap, cfg.partsTree)
    if okMap then parts = map end
  end
  if type(parts) ~= 'table' then
    if not warnedNoConfig then
      warnedNoConfig = true
      log('W', logTag, 'Shop: Teileliste des Autos nicht lesbar (weder parts noch partsTree)')
    end
    return nil
  end
  local out = { parts = {}, vars = {}, paints = (deepcopy and cfg.paints) and deepcopy(cfg.paints) or cfg.paints }
  for k, v in pairs(parts) do out.parts[k] = v end
  for k, v in pairs(cfg.vars or {}) do out.vars[k] = v end
  return out, vd
end
M.currentConfig = function() return currentConfig() end

local function jbeamIO() return rawget(_G, 'jbeamIO') or require('jbeam/io') end

local function buildCatalog()
  local veh = core().getPlayerVehicle()
  local car = activeCar()
  if not veh or not car then return nil end
  local cfg, vd = currentConfig()
  if not cfg then return nil end
  if not vd.ioCtx then
    log('W', logTag, 'Shop: kein ioCtx in den Fahrzeugdaten')
    return nil
  end
  local io = jbeamIO()
  -- 0.40: getAvailableParts liefert nur noch Beschreibungen; die Slot-Zuordnung kommt aus
  -- getAvailableSlotNameMap, Preis und englischer Name aus dem Teil selbst (getPart).
  local okMap, slotMap = pcall(io.getAvailableSlotNameMap, vd.ioCtx)
  local okDesc, descs = pcall(io.getAvailableParts, vd.ioCtx)
  if not okMap or type(slotMap) ~= 'table' then
    log('E', logTag, 'Shop: Slot-Liste nicht lesbar: ' .. tostring(slotMap))
    return nil
  end
  if not okDesc or type(descs) ~= 'table' then descs = {} end

  local partCache = {}
  local function partInfo(name)
    if partCache[name] == nil then
      local info = { value = 0 }
      local ok, part = pcall(io.getPart, vd.ioCtx, name)
      if ok and type(part) == 'table' and type(part.information) == 'table' then
        info.value = tonumber(part.information.value) or 0
        info.name = part.information.name
      end
      local d = descs[name]
      info.display = niceName(d and d.description or info.name, name)
      partCache[name] = info
    end
    return partCache[name]
  end

  local bySlot = {}
  for slotType, names in pairs(slotMap) do
    bySlot[slotType] = {}
    for _, n in ipairs(names) do table.insert(bySlot[slotType], { name = n }) end
  end

  car.stock = car.stock or {}
  local cat = { vehId = veh:getID(), slots = {}, tabs = {} }
  -- Slots der festen Reiter zuerst vormerken, damit 'Extras' nur den Rest bekommt
  local usedSlots = {}
  for _, tab in ipairs(rules.tabs or {}) do
    for _, item in ipairs(tab.items) do
      if not item.all then
        for key in pairs(cfg.parts) do
          local slot = lastSegment(key)
          if slotMatches(slot, item) then usedSlots[slot] = true end
        end
      end
    end
  end
  for _, tab in ipairs(rules.tabs or {}) do
    local tabRows = {}
    for _, item in ipairs(tab.items) do
      local found = {}
      for key, part in pairs(cfg.parts) do
        local slot = lastSegment(key)
        local ok
        if item.all then
          -- Auswahl gibt es, wenn der Slot mehrere Teile hat oder ab Werk leer ist (Zubehör wie
          -- Unterbodenbeleuchtung, Käfig, Shiftlight: dann ist 'Nicht verbaut' die Serien-Option).
          local emptyStock = part == '' or car.stock[slot] == ''
          ok = not usedSlots[slot] and bySlot[slot] and (#bySlot[slot] > 1 or (emptyStock and #bySlot[slot] > 0)) and not slotExcluded(slot)
        else
          ok = slotMatches(slot, item) and bySlot[slot]
        end
        if ok then table.insert(found, { slot = slot, key = key, part = part }); usedSlots[slot] = true end
      end
      table.sort(found, function(a, b) return a.slot < b.slot end)
      for _, f in ipairs(found) do
        if car.stock[f.slot] == nil then car.stock[f.slot] = f.part end
        local options = {}
        for _, p in ipairs(bySlot[f.slot]) do
          if p.name ~= car.stock[f.slot] then
            local info = partInfo(p.name)
            local lv = partLevel(p.name, tostring(info.name or '') .. ' ' .. info.display, item)
            if lv > 0 then
              table.insert(options, { part = p.name, name = info.display, level = lv, price = math.max(yen(info.value), item.minPriceYen or 0) })
            end
          end
        end
        if #options > 0 then
          table.sort(options, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            return a.price < b.price
          end)
          local stockName = car.stock[f.slot] ~= '' and partInfo(car.stock[f.slot]).display or core().t('shop.notInstalled')
          local row = { slot = f.slot, key = f.key, item = item.id, multi = #found > 1, stockName = stockName, options = options, groupBySize = item.groupBySize }
          cat.slots[f.slot] = row
          table.insert(tabRows, row)
        end
      end
    end
    cat.tabs[tab.id] = tabRows
  end
  local n = 0
  for _ in pairs(cat.slots) do n = n + 1 end
  log('I', logTag, string.format('Shop: %d Slots mit Teilen für %s', n, tostring(car.model)))
  return cat
end

local function getCatalog()
  local veh = core().getPlayerVehicle()
  if not veh then return nil end
  if catalog and catalog.vehId == veh:getID() then return catalog end
  if retryTimer > 0 then return nil end
  retryTimer = 1
  local ok, res = pcall(buildCatalog)
  if not ok then log('E', logTag, 'Shop: ' .. tostring(res)) end
  catalog = ok and res or nil
  return catalog
end

-- Anzeigenamen ---------------------------------------------------------------

local function prettySlot(slot)
  local car = activeCar()
  local s = slot
  if car and s:sub(1, #car.model + 1) == car.model .. '_' then s = s:sub(#car.model + 2) end
  s = s:gsub('_', ' ')
  return (s:gsub('^%l', string.upper))
end

local function itemLabel(row)
  local c = core()
  if row.item == 'other' then return prettySlot(row.slot) end
  local label = c.t('shop.item.' .. row.item)
  if row.multi then
    local side = row.slot:match('_([LR])$') or row.slot:match('_F([LR])$') or row.slot:match('_([LR])_')
    label = side and (label .. ' ' .. side) or (label .. ' · ' .. prettySlot(row.slot))
  end
  return label
end

-- Lackierer: Werkslacke des Modells ---------------------------------------------

local function cleanPaint(p)
  local bc = p.baseColor or {}
  return {
    baseColor = { bc[1] or bc.r or 0.5, bc[2] or bc.g or 0.5, bc[3] or bc.b or 0.5, bc[4] or bc.a or 1.2 },
    metallic = p.metallic or 0, roughness = p.roughness or 0.5,
    clearcoat = p.clearcoat or 1, clearcoatRoughness = p.clearcoatRoughness or 0.05,
  }
end

local function factoryPaints(model)
  local list, seen = {}, {}
  local okM, m = pcall(core_vehicles.getModel, model)
  local md = okM and m and m.model or {}
  local vp = rawget(_G, 'core_vehiclePaints')
  for _, colId in ipairs(md.paintCollections or {}) do
    local okC, col = pcall(function() return vp and vp.getPaintCollectionById(colId) end)
    if okC and col then
      for _, pid in ipairs(col.paints or {}) do
        local okP, paint = pcall(vp.getPaintById, pid)
        if okP and type(paint) == 'table' and not seen[pid] then
          seen[pid] = true
          table.insert(list, { id = tostring(pid), name = paint.name or tostring(pid), paint = cleanPaint(paint) })
        end
      end
    end
  end
  for name, paint in pairs(type(md.paints) == 'table' and md.paints or {}) do
    if not seen[name] and type(paint) == 'table' then
      seen[name] = true
      table.insert(list, { id = tostring(name), name = tostring(name), paint = cleanPaint(paint) })
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

local paintCache = {}
local function paintsFor(model)
  if not paintCache[model] then
    local ok, res = pcall(factoryPaints, model)
    paintCache[model] = ok and res or {}
    if not ok then log('W', logTag, 'Shop: Werkslacke nicht lesbar: ' .. tostring(res)) end
  end
  return paintCache[model]
end

M.factoryPaints = function(model) return paintsFor(model) end

function M.paintSwatch(p)
  local bc = p and p.baseColor or {}
  local function ch(i) return math.floor(clamp(tonumber(bc[i]) or 0.5, 0, 1) * 255) end
  return string.format('rgb(%d,%d,%d)', ch(1), ch(2), ch(3))
end

local function findPaint(model, paintId)
  for _, p in ipairs(paintsFor(model)) do
    if p.id == paintId then return p end
  end
end

-- Einbauen, Warenkorb, Kaufen ------------------------------------------------------
-- Ein Klick auf ein fremdes Teil (oder einen Lack) legt es in den Warenkorb und baut es probeweise ein.
-- Alles im Warenkorb ist gleichzeitig verbaut; an der Kasse wird der Gesamtbetrag bezahlt.
-- Einzelne Teile lassen sich wieder herausnehmen; Abbrechen oder Wegfahren stellt das Auto wieder her.

local cart = nil -- { original = cfg vor dem Warenkorb, items = { { key, kind, slot, id, name, level, price, paintSlot, paint } } }

local function copyConfig(cfg)
  local out = { parts = {}, vars = {}, paints = deepcopy and deepcopy(cfg.paints) or cfg.paints }
  for k, v in pairs(cfg.parts or {}) do out.parts[k] = v end
  for k, v in pairs(cfg.vars or {}) do out.vars[k] = v end
  return out
end

-- Ausgangszustand für Änderungen am Besitz: bei vollem Warenkorb das Auto ohne die Warenkorb-Teile.
local function baseConfig()
  if cart then return copyConfig(cart.original) end
  return currentConfig()
end

local focusSlot = nil   -- Slot, dessen Teil gerade hervorgehoben ist
local refocusTimer = 0

local function respawn(cfg)
  local car = activeCar()
  catalog = nil
  retryTimer = 2 -- Katalog erst neu aufbauen, wenn das Auto neu gespawnt ist
  extensions.hashiriyaBattle_fuel.keepAfterRespawn()
  core_vehicles.replaceVehicle(car.model, { config = cfg })
  extensions.hashiriyaBattle_parking.refreshShopCamera(0.8)
  if focusSlot then refocusTimer = 1.2 end -- nach dem Respawn das Teil wieder hervorheben
end

-- Lack ohne Neuladen des Autos (wie das BeamNG-Lackmenü): Farben live setzen und in die
-- Fahrzeug-Config schreiben, damit sie beim nächsten Respawn und in currentConfig() erhalten bleiben.
function M.applyPaintsLive(paints)
  local veh = core().getPlayerVehicle()
  local vm = rawget(_G, 'core_vehicle_manager')
  if not veh or not vm or not vm.liveUpdateVehicleColors or type(paints) ~= 'table' then return false end
  local ok = pcall(function()
    local vd = vm.getPlayerVehicleData()
    if not vd or not vd.config then error('keine Fahrzeugdaten') end
    vd.config.paints = deepcopy and deepcopy(paints) or paints
    for i = 1, 3 do
      if paints[i] then vm.liveUpdateVehicleColors(veh:getID(), veh, i, paints[i]) end
    end
    veh:setField('partConfig', '', serialize(vd.config))
  end)
  return ok
end

-- Nur der Lack ändert sich: live färben. Lief vorher eine Teile-Vorschau, muss das Auto neu gespawnt werden.
local function applyPaintCfg(cfg, wasPartPreview)
  if wasPartPreview or not M.applyPaintsLive(cfg.paints) then respawn(cfg) end
end

local function withPart(cfg, slot, part)
  local changed = false
  for key in pairs(cfg.parts) do
    if lastSegment(key) == slot then cfg.parts[key] = part; changed = true end
  end
  return changed
end

local function findOption(slot, part)
  local cat = getCatalog()
  local row = cat and cat.slots[slot]
  if not row then return nil end
  for _, o in ipairs(row.options) do
    if o.part == part then return o, row end
  end
  return nil, row
end


-- Teile-Ansicht wie im BeamNG-Teilemenü: Auto durchsichtig, nur das Teil sichtbar, Kamera schwenkt drauf.
local function findPartPath(slot)
  local vd = select(2, currentConfig())
  local tree = vd and vd.config and vd.config.partsTree
  if type(tree) ~= 'table' then return nil end
  local found, parentPath = nil, nil
  local function walk(node, parent)
    if found then return end
    if node.id == slot or (type(node.path) == 'string' and lastSegment(node.path) == slot) then
      if node.chosenPartName and node.chosenPartName ~= '' and node.partPath then found = node.partPath
      else parentPath = parent and parent.partPath end
      if found or parentPath then return end
    end
    for _, child in pairs(node.children or {}) do
      if type(child) == 'table' then walk(child, node) end
    end
  end
  walk(tree, nil)
  return found or parentPath
end

local function applyFocus()
  local veh = core().getPlayerVehicle()
  local pm = rawget(_G, 'core_vehicle_partmgmt')
  if not veh or not pm then return end
  local path = focusSlot and findPartPath(focusSlot)
  if path then
    local set = { [path] = true }
    pcall(pm.selectParts, set, veh:getID(), set, { focusOffsetUp = 0.1 })
  else
    pcall(pm.showHighlightedParts, veh:getID(), {})
  end
end

function M.focusSlot(slot)
  focusSlot = (slot and slot ~= '' and slot ~= '__paint') and slot or nil
  refocusTimer = 0
  applyFocus()
end

-- Beim Wegfahren / Menü schließen: alles sichtbar, Kamera zurück.
function M.releaseFocus()
  local wasFocused = focusSlot ~= nil
  focusSlot = nil
  refocusTimer = 0
  local veh = core().getPlayerVehicle()
  local pm = rawget(_G, 'core_vehicle_partmgmt')
  if not pm or not veh then return end
  if wasFocused then pcall(pm.showHighlightedParts, veh:getID(), {}) end
  pcall(pm.releasePartFocusCamera)
  -- Shop zu Fuß: wieder die Eingangskamera
  extensions.hashiriyaBattle_parking.refreshShopCamera()
end

-- Lackschicht 1-3 (BeamNG: Haupt-, Zweit-, Drittfarbe; je nach Auto und Livery sichtbar)
local paintSlot = 1
function M.setPaintSlot(n) paintSlot = clamp(math.floor(tonumber(n) or 1), 1, 3) end

local function paintIdOf(car, slot)
  if car.paintIds and car.paintIds[slot] ~= nil then return car.paintIds[slot] end
  if slot == 1 then return car.paintId end
end

-- Lack in eine Schicht schreiben; fehlende Schichten davor mit Schicht 1 auffüllen.
local function setPaintAt(cfg, slot, paint)
  cfg.paints = type(cfg.paints) == 'table' and cfg.paints or {}
  for i = 1, slot - 1 do
    if cfg.paints[i] == nil then cfg.paints[i] = deepcopy and deepcopy(cfg.paints[1] or paint) or (cfg.paints[1] or paint) end
  end
  cfg.paints[slot] = paint
end

local function storePaintId(car, slot, id)
  car.paintIds = car.paintIds or {}
  car.paintIds[slot] = id
  if slot == 1 then car.paintId = id end
end

function M.hasPreview() return cart ~= nil end

local function cartIndex(key)
  if not cart then return nil end
  for i, it in ipairs(cart.items) do if it.key == key then return i, it end end
end

local function cartHas(key, id)
  local _, it = cartIndex(key)
  return it ~= nil and it.id == id
end

local function buildCart()
  local cfg = copyConfig(cart.original)
  for _, it in ipairs(cart.items) do
    if it.kind == 'part' then withPart(cfg, it.slot, it.id) else setPaintAt(cfg, it.paintSlot, it.paint) end
  end
  return cfg
end

-- Auto auf den Stand des Warenkorbs bringen (Teile: neu spawnen, nur Lack: live färben)
local function applyCart(partsChanged)
  if not cart then return end
  local cfg
  if #cart.items == 0 then
    cfg = cart.original
    cart = nil
  else
    cfg = buildCart()
  end
  if partsChanged then respawn(cfg) else applyPaintCfg(cfg, false) end
end

-- Fahrzeugwerte (Leistung, Drehmoment, Gewicht, Bremsen) vom Auto abfragen; Antwort über onStats
local carStats = nil      -- aktuelle Werte des Autos (mit Warenkorb-Teilen)
local baseStats = nil     -- Werte vor dem Warenkorb
local statsTimer = 0

local function requestStats()
  local veh = core().getPlayerVehicle()
  if not veh then return end
  veh:queueLuaCommand([[
    local kw, nm = 0, 0
    local ok = pcall(function()
      local eng = powertrain.getDevicesByCategory('engine')[1]
      if eng then kw = eng.maxPower or 0; nm = eng.maxTorque or 0 end -- kw-Variable enthält PS
    end)
    local kg = 0
    pcall(function() for _, n in pairs(v.data.nodes) do kg = kg + (n.nodeWeight or 0) end end)
    local brake = 0
    pcall(function() for _, w in pairs(wheels.wheels) do brake = brake + (w.brakeTorque or 0) end end)
    obj:queueGameEngineLua(string.format('if extensions.hashiriyaBattle_shop then extensions.hashiriyaBattle_shop.onStats(%f,%f,%f,%f) end', kw, nm, kg, brake))
  ]])
end

function M.onStats(kw, nm, kg, brake)
  -- combustionEngine.maxPower ist in PS (metrisch), maxTorque in Nm
  local ps
  ps, nm, kg, brake = tonumber(kw) or 0, tonumber(nm) or 0, tonumber(kg) or 0, tonumber(brake) or 0
  if kg <= 0 then return end
  carStats = { ps = ps, nm = nm, kg = kg, brake = brake, pw = ps > 0 and kg / ps or nil }
  if not cart then baseStats = nil end
end

local function statsUi()
  if not carStats then requestStats(); return nil end
  local c = core()
  local defs = {
    { k = 'ps', label = 'shop.stat.power', fmt = '%d PS', better = 1 },
    { k = 'nm', label = 'shop.stat.torque', fmt = '%d Nm', better = 1 },
    { k = 'kg', label = 'shop.stat.weight', fmt = '%d kg', better = -1 },
    { k = 'pw', label = 'shop.stat.ratio', fmt = '%.2f kg/PS', better = -1 },
    { k = 'brake', label = 'shop.stat.brake', fmt = '%d Nm', better = 1 },
  }
  local rows = {}
  for _, d in ipairs(defs) do
    local v = carStats[d.k]
    if v and v > 0 then
      local r = { label = c.t(d.label), value = string.format(d.fmt, d.k == 'pw' and v or math.floor(v + 0.5)) }
      local b = baseStats and baseStats[d.k]
      if b and math.abs(v - b) > (d.k == 'pw' and 0.005 or 0.5) then
        local diff = v - b
        r.delta = (diff > 0 and '+' or '') .. string.format(d.k == 'pw' and '%.2f' or '%d', d.k == 'pw' and diff or math.floor(diff + (diff > 0 and 0.5 or -0.5)))
        r.good = diff * d.better > 0
      end
      table.insert(rows, r)
    end
  end
  return rows
end
M.requestStats = requestStats

local function ensureCart()
  if cart then return true end
  local cfg = currentConfig()
  if not cfg then return false end
  cart = { original = copyConfig(cfg), items = {} }
  baseStats = carStats and deepcopy and deepcopy(carStats) or carStats
  return true
end

local function putInCart(item)
  local i = cartIndex(item.key)
  if i then cart.items[i] = item else table.insert(cart.items, item) end
end

function M.removeFromCart(key)
  local i, it = cartIndex(key)
  if not i then return end
  table.remove(cart.items, i)
  applyCart(it.kind == 'part')
end

function M.cancelPreview(silent)
  if not cart then return end
  local hadParts = false
  for _, it in ipairs(cart.items) do if it.kind == 'part' then hadParts = true end end
  local original = cart.original
  cart = nil
  if hadParts then respawn(original) else applyPaintCfg(original, false) end
  if not silent then core().msg(core().t('msg.previewReverted')) end
end

-- Teil fest einbauen (Serie oder bereits gekauft, also kostenlos). Ein Warenkorb bleibt dabei erhalten.
local function install(slot, part, label)
  local c = core()
  local car = activeCar()
  local cfg = baseConfig()
  if not cfg then
    c.msg(c.t('msg.partFailed'))
    return
  end
  if not withPart(cfg, slot, part) then
    c.msg(c.t('msg.partIncompatible'))
    return
  end
  car.config = cfg
  if cart then
    cart.original = copyConfig(cfg)
    local i = cartIndex('part:' .. slot)
    if i then table.remove(cart.items, i) end
    applyCart(true)
  else
    respawn(cfg)
  end
  c.writeSave()
  if part == '' then c.msg(c.t('msg.partRemoved', label)) else c.msg(c.t('msg.partInstalled', label, c.t('shop.free'))) end
  log('I', logTag, string.format('Shop: %s -> %s (Besitz)', slot, part))
end

-- Kennzeichen-Design (Plates Pack) ins Auto setzen; der Rest der Config bleibt
function M.setPlateDesign(design)
  local car = activeCar()
  local cfg = baseConfig()
  if not car or not cfg then return end
  cfg = extensions.hashiriyaBattle_plates.applyToConfig(cfg, design)
  car.config = cfg
  if cart then cart.original = copyConfig(cfg); applyCart(true) else respawn(cfg) end
end

-- Garage: nur Serie und gekaufte Teile, ohne Warenkorb.
function M.buy(slot, part, garageOnly)
  local car = activeCar()
  local option, row = findOption(slot, part)
  if not row then return end
  if part == car.stock[slot] then return install(slot, part, part == '' and itemLabel(row) or row.stockName) end
  if not option then return end
  if car.owned and car.owned[part] then return install(slot, part, option.name) end
  if not garageOnly then return M.select(slot, part) end
end

-- Shop: Klick auf eine Option legt sie in den Warenkorb (ersetzt ein anderes Teil im selben Slot).
function M.select(slot, part)
  local c = core()
  local car = activeCar()
  local option, row = findOption(slot, part)
  if not row then return end
  if part == car.stock[slot] then return install(slot, part, part == '' and itemLabel(row) or row.stockName) end
  if not option then return end
  if car.owned and car.owned[part] then return install(slot, part, option.name) end
  if not ensureCart() then
    c.msg(c.t('msg.partFailed'))
    return
  end
  if not withPart(copyConfig(cart.original), slot, part) then
    c.msg(c.t('msg.partIncompatible'))
    if #cart.items == 0 then cart = nil end
    return
  end
  putInCart({ key = 'part:' .. slot, kind = 'part', slot = slot, id = part, name = option.name, level = option.level, price = option.price })
  applyCart(true)
end

function M.selectPaint(paintId)
  local c = core()
  local car = activeCar()
  local entry = findPaint(car.model, paintId)
  if not entry then return end
  if car.ownedPaints and car.ownedPaints[paintId] then
    local cfg = baseConfig()
    if not cfg then
      c.msg(c.t('msg.partFailed'))
      return
    end
    setPaintAt(cfg, paintSlot, entry.paint)
    storePaintId(car, paintSlot, paintId)
    car.config = cfg
    if cart then
      cart.original = copyConfig(cfg)
      local i = cartIndex('paint:' .. paintSlot)
      if i then table.remove(cart.items, i) end
      applyCart(false)
    else
      applyPaintCfg(cfg, false)
    end
    c.writeSave()
    c.msg(c.t('msg.partInstalled', entry.name, c.t('shop.free')))
    return
  end
  if not ensureCart() then
    c.msg(c.t('msg.partFailed'))
    return
  end
  putInCart({ key = 'paint:' .. paintSlot, kind = 'paint', id = paintId, paintSlot = paintSlot, paint = entry.paint,
    name = entry.name, level = 0, price = rules.paintPriceYen or 29800 })
  applyCart(false)
end

-- Eigene Farbe: arg = "r,g,b,metallic,rauheit,klarlack,klarlackRauheit" (alles 0..1).
-- Wird immer neu bezahlt (neue Lackierung).
function M.selectCustomPaint(arg)
  local c = core()
  local v = {}
  for n in tostring(arg or ''):gmatch('[^,]+') do table.insert(v, clamp(tonumber(n) or 0, 0, 1)) end
  if #v ~= 7 then return end
  if not ensureCart() then
    c.msg(c.t('msg.partFailed'))
    return
  end
  putInCart({ key = 'paint:' .. paintSlot, kind = 'paint', id = 'custom', paintSlot = paintSlot,
    paint = { baseColor = { v[1], v[2], v[3], 1.2 }, metallic = v[4], roughness = v[5], clearcoat = v[6], clearcoatRoughness = v[7] },
    name = c.t('shop.customName') .. ' (' .. c.t('shop.paintSlot', paintSlot) .. ')', level = 0, price = rules.customPaintPriceYen or 98000 })
  applyCart(false)
end

local function cartTotal()
  local total = 0
  for _, it in ipairs(cart and cart.items or {}) do total = total + it.price end
  return total
end

-- Kasse: alles im Warenkorb auf einmal bezahlen
function M.confirmPreview()
  local c = core()
  local car = activeCar()
  if not cart or #cart.items == 0 then return end
  for _, it in ipairs(cart.items) do
    if it.level > 0 and not isUnlocked(it.level) then
      c.msg(c.t('msg.partLocked'))
      return
    end
  end
  local total = cartTotal()
  if c.save.money < total then
    c.msg(c.t('msg.noMoney'))
    return
  end
  -- Nach dem Respawn steht im Auto die echte Konfiguration (z. B. passende Reifen zur neuen Felge).
  local cfg = currentConfig() or buildCart()
  c.save.money = c.save.money - total
  for _, it in ipairs(cart.items) do
    extensions.hashiriyaBattle_progress.bump(c.save, it.kind == 'paint' and 'paintsBought' or 'partsBought')
    if it.kind == 'paint' then
      car.ownedPaints = car.ownedPaints or {}
      if it.id ~= 'custom' then car.ownedPaints[it.id] = true end
      storePaintId(car, it.paintSlot or 1, it.id)
    else
      car.owned = car.owned or {}
      car.owned[it.id] = true
    end
  end
  local n = #cart.items
  car.config = cfg
  cart = nil
  c.writeSave()
  c.msg(c.t('msg.cartBought', n, c.economy().formatYen(total)))
  log('I', logTag, string.format('Shop: %d Teile gekauft (%d Yen)', n, total))
end

local function previewState()
  if not cart or #cart.items == 0 then return nil end
  local c = core()
  local eco = c.economy()
  local st = { items = {}, locked = false }
  for _, it in ipairs(cart.items) do
    local unlocked, need = true, nil
    if it.level > 0 then unlocked, need = isUnlocked(it.level) end
    if not unlocked then st.locked = true end
    table.insert(st.items, { key = it.key, name = it.name, level = it.level, kind = it.kind,
      price = eco.formatYen(it.price), locked = not unlocked, lockText = not unlocked and need or nil })
  end
  local total = cartTotal()
  st.total = eco.formatYen(total)
  st.count = #cart.items
  st.affordable = c.save.money >= total
  st.after = eco.formatYen(c.save.money - total)
  return st
end

local function paintRow()
  local c = core()
  local car = activeCar()
  local eco = c.economy()
  local r = { slot = '__paint', kind = 'paint', name = c.t('shop.item.paint'), current = c.t('shop.stock'), currentLevel = 0, options = {} }
  local curId = paintIdOf(car, paintSlot)
  if curId == 'custom' then r.current = c.t('shop.customPaint') end
  r.custom = { price = eco.formatYen(rules.customPaintPriceYen or 98000) }
  -- Auswahl der Lackschicht mit der aktuellen Farbe jeder Schicht
  r.paintSlot = paintSlot
  r.paintSlots = {}
  local cur = currentConfig()
  local paints = cur and type(cur.paints) == 'table' and cur.paints or {}
  for i = 1, 3 do
    local p = paints[i] or paints[1]
    local bc = p and (p.baseColor or {}) or {}
    local function ch(k, n) return math.floor(clamp(tonumber(bc[k] or bc[n]) or 0.5, 0, 1) * 255) end
    table.insert(r.paintSlots, { id = i, name = c.t('shop.paintSlot', i), swatch = string.format('rgb(%d,%d,%d)', ch(1, 'r'), ch(2, 'g'), ch(3, 'b')) })
  end
  for _, p in ipairs(paintsFor(car.model)) do
    local owned = car.ownedPaints and car.ownedPaints[p.id]
    local price = rules.paintPriceYen or 29800
    local bc = p.paint.baseColor
    local installed = curId == p.id
    if installed then r.current = p.name end
    table.insert(r.options, {
      part = p.id, name = p.name, level = 0, installed = installed,
      previewing = cartHas('paint:' .. paintSlot, p.id),
      swatch = string.format('rgb(%d,%d,%d)', math.floor(clamp(bc[1], 0, 1) * 255), math.floor(clamp(bc[2], 0, 1) * 255), math.floor(clamp(bc[3], 0, 1) * 255)),
      price = owned and c.t('shop.owned') or eco.formatYen(price),
      affordable = owned or c.save.money >= price,
    })
  end
  return r
end

function M.setTab(tab)
  activeTab = tab
end

-- UI ---------------------------------------------------------------------------

-- Felgen nach Zoll gruppieren ("15x7" im Teilenamen -> 15"); Serie bleibt oben.
local function groupBySize(r)
  local groups, byId = {}, {}
  local keep = {}
  for i, o in ipairs(r.options) do
    if i == 1 then
      table.insert(keep, o)
    else
      local size = tostring(o.part):match('_(%d%d)x[%d%.]+') or tostring(o.name):match('(%d%d)x[%d%.]+') or tostring(o.name):match('(%d%d)"')
      local id = size or 'other'
      if not byId[id] then
        byId[id] = { id = id, name = size and (size .. '"') or core().t('shop.sizeOther'), options = {} }
        table.insert(groups, byId[id])
      end
      table.insert(byId[id].options, o)
      if o.installed or o.previewing then byId[id].active = true end
    end
  end
  table.sort(groups, function(a, b)
    if a.id == 'other' or b.id == 'other' then return b.id == 'other' and a.id ~= 'other' end
    return tonumber(a.id) < tonumber(b.id)
  end)
  for _, g in ipairs(groups) do g.count = #g.options end
  r.options = keep
  r.groups = groups
end

-- mode 'shop': alles kaufen; mode 'garage': nur Serie und gekaufte Teile, kostenlos umrüsten.
function M.getUiState(mode)
  local c = core()
  local car = activeCar()
  local garage = mode == 'garage'
  local tabId = activeTab
  if garage and tabId == 'paint' then tabId = 'engine' end
  local st = { tabs = {}, tab = tabId, rows = {}, loading = false }
  st.preview = not garage and previewState() or nil
  st.stats = statsUi()
  for _, tab in ipairs(rules.tabs or {}) do
    if not (garage and tab.id == 'paint') then
      table.insert(st.tabs, { id = tab.id, name = c.t('shop.tab.' .. tab.id) })
    end
  end
  -- Lack braucht keinen Teilekatalog, daher auch während des Ladens sichtbar
  if tabId == 'paint' then table.insert(st.rows, paintRow()) end
  local cat = getCatalog()
  if not cat then
    st.loading = true
    return st
  end
  local cfgParts = {}
  local cfg = cart and cart.original or currentConfig()
  if cfg then for k, v in pairs(cfg.parts) do cfgParts[lastSegment(k)] = v end end
  local eco = c.economy()
  for _, row in ipairs(cat.tabs[tabId] or {}) do
    local installed = cfgParts[row.slot]
    local r = { slot = row.slot, name = itemLabel(row), current = row.stockName, currentLevel = 0, options = {} }
    table.insert(r.options, { part = car.stock[row.slot], name = c.t('shop.stock') .. ' · ' .. tostring(row.stockName),
      level = 0, price = c.t('shop.free'), installed = installed == car.stock[row.slot], affordable = true })
    for _, o in ipairs(row.options) do
      local unlocked, need = isUnlocked(o.level)
      local owned = car.owned and car.owned[o.part]
      if installed == o.part then r.current, r.currentLevel = o.name, o.level end
      if not garage or owned then
        table.insert(r.options, {
          part = o.part, name = o.name, level = o.level,
          price = owned and (garage and c.t('shop.free') or c.t('shop.owned')) or eco.formatYen(o.price),
          installed = installed == o.part,
          previewing = cartHas('part:' .. row.slot, o.part),
          locked = not unlocked,
          lockText = not unlocked and need or nil,
          affordable = owned or c.save.money >= o.price,
        })
      end
    end
    if row.groupBySize then groupBySize(r) end
    if not garage or #r.options > 1 or r.groups then table.insert(st.rows, r) end
  end
  return st
end

local function onUpdate(dtReal)
  if retryTimer > 0 then retryTimer = retryTimer - dtReal end
  -- im Shop/in der Garage die Fahrzeugwerte regelmäßig auffrischen (nach jedem Respawn neu)
  local p = extensions.hashiriyaBattle_parking
  local area = p and p.isArrived() and p.getCurrent()
  if area and (area.type == 'shop' or area.type == 'garage') then
    statsTimer = statsTimer - dtReal
    if statsTimer <= 0 then statsTimer = 1.5; requestStats() end
  else
    carStats, baseStats = nil, nil
  end
  if refocusTimer > 0 then
    refocusTimer = refocusTimer - dtReal
    if refocusTimer <= 0 and focusSlot then applyFocus() end
  end
end

local function onExtensionLoaded()
  M.loadData()
end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate

return M
