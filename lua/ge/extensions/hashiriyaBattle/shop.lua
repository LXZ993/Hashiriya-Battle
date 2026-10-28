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
local function slotMatches(slot, suffixes)
  for _, suf in ipairs(suffixes) do
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
  local out = { parts = {}, vars = {}, paints = cfg.paints }
  for k, v in pairs(parts) do out.parts[k] = v end
  for k, v in pairs(cfg.vars or {}) do out.vars[k] = v end
  return out, vd
end

local function availableParts(vd)
  local io = rawget(_G, 'jbeamIO') or require('jbeam/io')
  return io.getAvailableParts(vd.ioCtx)
end

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
  local okParts, available = pcall(availableParts, vd)
  if not okParts or type(available) ~= 'table' then
    log('E', logTag, 'Shop: Teileliste nicht lesbar: ' .. tostring(available))
    return nil
  end

  -- Teile nach Slot-Typ sortieren
  local bySlot = {}
  for name, info in pairs(available) do
    local st = info.slotType
    local list = type(st) == 'table' and st or { st }
    for _, s in ipairs(list) do
      if s then bySlot[s] = bySlot[s] or {}; table.insert(bySlot[s], { name = name, info = info }) end
    end
  end

  car.stock = car.stock or {}
  local cat = { vehId = veh:getID(), slots = {}, tabs = {} }
  for _, tab in ipairs(rules.tabs or {}) do
    local tabRows = {}
    for _, item in ipairs(tab.items) do
      local found = {}
      for key, part in pairs(cfg.parts) do
        local slot = lastSegment(key)
        if slotMatches(slot, item.slot) and bySlot[slot] then table.insert(found, { slot = slot, key = key, part = part }) end
      end
      table.sort(found, function(a, b) return a.slot < b.slot end)
      for _, f in ipairs(found) do
        if car.stock[f.slot] == nil then car.stock[f.slot] = f.part end
        local options = {}
        for _, p in ipairs(bySlot[f.slot]) do
          local display = niceName(p.info.description or (p.info.information and p.info.information.name), p.name)
          local lv = partLevel(p.name, display, item)
          if lv > 0 and p.name ~= car.stock[f.slot] then
            table.insert(options, { part = p.name, name = display, level = lv, price = yen(p.info.value) })
          end
        end
        if #options > 0 then
          table.sort(options, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            return a.price < b.price
          end)
          local stockName = car.stock[f.slot]
          for _, p in ipairs(bySlot[f.slot]) do
            if p.name == stockName then stockName = niceName(p.info.description, p.name) end
          end
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

-- Kaufen / Einbauen ---------------------------------------------------------------

function M.buy(slot, part)
  local c = core()
  local car = activeCar()
  local cat = getCatalog()
  local row = cat and cat.slots[slot]
  if not row then return end

  local option, price = nil, 0
  if part == car.stock[slot] then
    price = 0
  else
    for _, o in ipairs(row.options) do
      if o.part == part then option = o end
    end
    if not option then return end
    if not isUnlocked(option.level) then
      c.msg(c.t('msg.partLocked'))
      return
    end
    car.owned = car.owned or {}
    price = car.owned[part] and 0 or option.price
  end
  if c.save.money < price then
    c.msg(c.t('msg.noMoney'))
    return
  end

  local cfg = currentConfig()
  if not cfg then
    c.msg(c.t('msg.partFailed'))
    return
  end
  local changed = false
  for key in pairs(cfg.parts) do
    if lastSegment(key) == slot then cfg.parts[key] = part; changed = true end
  end
  if not changed then
    c.msg(c.t('msg.partIncompatible'))
    return
  end

  c.save.money = c.save.money - price
  if option then car.owned[part] = true end
  car.config = cfg
  catalog = nil
  retryTimer = 2 -- Katalog erst neu aufbauen, wenn das Auto neu gespawnt ist
  core_vehicles.replaceVehicle(car.model, { config = cfg })
  c.writeSave()
  local label = option and option.name or row.stockName
  c.msg(c.t('msg.partInstalled', label, price > 0 and c.economy().formatYen(price) or c.t('shop.free')))
  log('I', logTag, string.format('Shop: %s -> %s (%d Yen)', slot, part, price))
end

function M.setTab(tab)
  activeTab = tab
end

-- UI ---------------------------------------------------------------------------

local function itemLabel(row)
  local c = core()
  local label = c.t('shop.item.' .. row.item)
  if row.multi then
    local side = row.slot:match('_([LR])$')
    label = label .. ' ' .. (side or row.slot:match('_([^_]+)$') or '')
  end
  return label
end

function M.getUiState()
  local c = core()
  local car = activeCar()
  local st = { tabs = {}, tab = activeTab, rows = {}, loading = false }
  for _, tab in ipairs(rules.tabs or {}) do
    table.insert(st.tabs, { id = tab.id, name = c.t('shop.tab.' .. tab.id) })
  end
  local cat = getCatalog()
  if not cat then
    st.loading = true
    return st
  end
  local cfgParts = {}
  local cfg = currentConfig()
  if cfg then for k, v in pairs(cfg.parts) do cfgParts[lastSegment(k)] = v end end
  local eco = c.economy()
  for _, row in ipairs(cat.tabs[activeTab] or {}) do
    local installed = cfgParts[row.slot]
    local r = { slot = row.slot, name = itemLabel(row), current = row.stockName, currentLevel = 0, options = {} }
    table.insert(r.options, { part = car.stock[row.slot], name = c.t('shop.stock') .. ' · ' .. tostring(row.stockName),
      level = 0, price = c.t('shop.free'), installed = installed == car.stock[row.slot], affordable = true })
    for _, o in ipairs(row.options) do
      local unlocked, need = isUnlocked(o.level)
      local owned = car.owned and car.owned[o.part]
      if installed == o.part then r.current, r.currentLevel = o.name, o.level end
      table.insert(r.options, {
        part = o.part, name = o.name, level = o.level,
        price = owned and c.t('shop.owned') or eco.formatYen(o.price),
        installed = installed == o.part,
        locked = not unlocked,
        lockText = not unlocked and c.t('shop.needWins', need) or nil,
        affordable = owned or c.save.money >= o.price,
      })
    end
    table.insert(st.rows, r)
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
