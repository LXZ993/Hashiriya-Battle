-- Hashiriya Battle: Tuning-Shop (Einzelteile je Slot, nach Stufen freigeschaltet)
-- Welche Teile es gibt, kommt zur Laufzeit aus BeamNG: alle Teile, die in die Slots des
-- Spielerautos passen. data/tuning.json legt fest, welche Slots im Shop auftauchen und
-- welche Stufe (LV1-3) ein Teil bekommt. Gekaufte Teile bleiben im Besitz.
local M = {}

local logTag = 'hashiriya'
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

local function isUnlocked(level)
  local need = tierInfo(level).unlock.minWins or 0
  return (core().save.wins or 0) >= need, need
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
          local row = { slot = f.slot, key = f.key, item = item.id, multi = #found > 1, stockName = stockName, options = options }
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
    local side = row.slot:match('_([LR])$')
    label = label .. ' ' .. (side or row.slot:match('_([^_]+)$') or '')
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

local function findPaint(model, paintId)
  for _, p in ipairs(paintsFor(model)) do
    if p.id == paintId then return p end
  end
end

-- Einbauen, Vorschau, Kaufen ------------------------------------------------------
-- Ein Klick auf ein fremdes Teil (oder einen Lack) baut es nur probeweise ein (preview).
-- Erst confirmPreview() zieht das Geld ab; cancelPreview() oder Wegfahren stellt das Auto wieder her.

local preview = nil -- { kind = 'part'|'paint', slot, id, name, level, price, original = cfg }

local function copyConfig(cfg)
  local out = { parts = {}, vars = {}, paints = deepcopy and deepcopy(cfg.paints) or cfg.paints }
  for k, v in pairs(cfg.parts or {}) do out.parts[k] = v end
  for k, v in pairs(cfg.vars or {}) do out.vars[k] = v end
  return out
end

-- Ausgangszustand für Änderungen: bei laufender Vorschau das Auto vor der Vorschau.
local function baseConfig()
  if preview then return copyConfig(preview.original) end
  return currentConfig()
end

local function respawn(cfg)
  local car = activeCar()
  catalog = nil
  retryTimer = 2 -- Katalog erst neu aufbauen, wenn das Auto neu gespawnt ist
  core_vehicles.replaceVehicle(car.model, { config = cfg })
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

function M.hasPreview() return preview ~= nil end

function M.cancelPreview(silent)
  if not preview then return end
  local original = preview.original
  preview = nil
  respawn(original)
  if not silent then core().msg(core().t('msg.previewReverted')) end
end

-- Teil fest einbauen (Serie oder bereits gekauft, also kostenlos).
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
  preview = nil
  car.config = cfg
  respawn(cfg)
  c.writeSave()
  if part == '' then c.msg(c.t('msg.partRemoved', label)) else c.msg(c.t('msg.partInstalled', label, c.t('shop.free'))) end
  log('I', logTag, string.format('Shop: %s -> %s (Besitz)', slot, part))
end

-- Garage: nur Serie und gekaufte Teile, ohne Vorschau.
function M.buy(slot, part, garageOnly)
  local car = activeCar()
  local option, row = findOption(slot, part)
  if not row then return end
  if part == car.stock[slot] then return install(slot, part, part == '' and itemLabel(row) or row.stockName) end
  if not option then return end
  if car.owned and car.owned[part] then return install(slot, part, option.name) end
  if not garageOnly then return M.select(slot, part) end
end

-- Shop: Klick auf eine Option.
function M.select(slot, part)
  local c = core()
  local car = activeCar()
  local option, row = findOption(slot, part)
  if not row then return end
  if part == car.stock[slot] then return install(slot, part, part == '' and itemLabel(row) or row.stockName) end
  if not option then return end
  if car.owned and car.owned[part] then return install(slot, part, option.name) end
  local cfg = baseConfig()
  if not cfg then
    c.msg(c.t('msg.partFailed'))
    return
  end
  local original = preview and preview.original or copyConfig(cfg)
  if not withPart(cfg, slot, part) then
    c.msg(c.t('msg.partIncompatible'))
    return
  end
  preview = { kind = 'part', slot = slot, id = part, name = option.name, level = option.level, price = option.price, original = original, cfg = cfg }
  respawn(cfg)
end

function M.selectPaint(paintId)
  local c = core()
  local car = activeCar()
  local entry = findPaint(car.model, paintId)
  if not entry then return end
  local cfg = baseConfig()
  if not cfg then
    c.msg(c.t('msg.partFailed'))
    return
  end
  local original = preview and preview.original or copyConfig(cfg)
  cfg.paints = type(cfg.paints) == 'table' and cfg.paints or {}
  cfg.paints[1] = entry.paint
  if car.ownedPaints and car.ownedPaints[paintId] then
    preview = nil
    car.paintId = paintId
    car.config = cfg
    respawn(cfg)
    c.writeSave()
    c.msg(c.t('msg.partInstalled', entry.name, c.t('shop.free')))
    return
  end
  preview = { kind = 'paint', id = paintId, name = entry.name, level = 0, price = rules.paintPriceYen or 29800, original = original, cfg = cfg }
  respawn(cfg)
end

function M.confirmPreview()
  local c = core()
  local car = activeCar()
  if not preview then return end
  if preview.level > 0 and not isUnlocked(preview.level) then
    c.msg(c.t('msg.partLocked'))
    return
  end
  if c.save.money < preview.price then
    c.msg(c.t('msg.noMoney'))
    return
  end
  -- Nach dem Respawn steht im Auto die echte Konfiguration (z. B. passende Reifen zur neuen Felge).
  local cfg = currentConfig() or preview.cfg
  c.save.money = c.save.money - preview.price
  if preview.kind == 'paint' then
    car.ownedPaints = car.ownedPaints or {}
    car.ownedPaints[preview.id] = true
    car.paintId = preview.id
  else
    car.owned = car.owned or {}
    car.owned[preview.id] = true
  end
  car.config = cfg
  c.writeSave()
  c.msg(c.t('msg.partInstalled', preview.name, c.economy().formatYen(preview.price)))
  log('I', logTag, string.format('Shop: %s gekauft (%d Yen)', tostring(preview.id), preview.price))
  preview = nil
end

local function previewState()
  if not preview then return nil end
  local c = core()
  local unlocked, need = true, 0
  if preview.level > 0 then unlocked, need = isUnlocked(preview.level) end
  return {
    name = preview.name, level = preview.level,
    price = c.economy().formatYen(preview.price),
    locked = not unlocked, lockText = not unlocked and c.t('shop.needWins', need) or nil,
    affordable = c.save.money >= preview.price,
  }
end

local function paintRow()
  local c = core()
  local car = activeCar()
  local eco = c.economy()
  local r = { slot = '__paint', kind = 'paint', name = c.t('shop.item.paint'), current = c.t('shop.stock'), currentLevel = 0, options = {} }
  for _, p in ipairs(paintsFor(car.model)) do
    local owned = car.ownedPaints and car.ownedPaints[p.id]
    local price = rules.paintPriceYen or 29800
    local bc = p.paint.baseColor
    local installed = car.paintId == p.id
    if installed then r.current = p.name end
    table.insert(r.options, {
      part = p.id, name = p.name, level = 0, installed = installed,
      previewing = preview and preview.kind == 'paint' and preview.id == p.id or false,
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

-- mode 'shop': alles kaufen; mode 'garage': nur Serie und gekaufte Teile, kostenlos umrüsten.
function M.getUiState(mode)
  local c = core()
  local car = activeCar()
  local garage = mode == 'garage'
  local tabId = activeTab
  if garage and tabId == 'paint' then tabId = 'engine' end
  local st = { tabs = {}, tab = tabId, rows = {}, loading = false }
  st.preview = not garage and previewState() or nil
  for _, tab in ipairs(rules.tabs or {}) do
    if not (garage and tab.id == 'paint') then
      table.insert(st.tabs, { id = tab.id, name = c.t('shop.tab.' .. tab.id) })
    end
  end
  local cat = getCatalog()
  if not cat then
    st.loading = true
    return st
  end
  local cfgParts = {}
  local cfg = preview and preview.original or currentConfig()
  if cfg then for k, v in pairs(cfg.parts) do cfgParts[lastSegment(k)] = v end end
  local eco = c.economy()
  if tabId == 'paint' then table.insert(st.rows, paintRow()) end
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
          previewing = preview and preview.kind == 'part' and preview.id == o.part or false,
          locked = not unlocked,
          lockText = not unlocked and c.t('shop.needWins', need) or nil,
          affordable = owned or c.save.money >= o.price,
        })
      end
    end
    if not garage or #r.options > 1 then table.insert(st.rows, r) end
  end
  return st
end

local function onUpdate(dtReal)
  if retryTimer > 0 then retryTimer = retryTimer - dtReal end
end

local function onExtensionLoaded()
  M.loadData()
end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate

return M
