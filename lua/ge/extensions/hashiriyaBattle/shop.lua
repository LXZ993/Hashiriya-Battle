-- Hashiriya Battle: Tuning-Shop (Teile in Stufen kaufen und einbauen)
-- Katalog: data/parts.json. Eine Stufe ersetzt mehrere Teile auf einmal (Slot -> Teil).
-- Gekaufte Stufen bleiben im Besitz und lassen sich kostenlos wieder einbauen.
local M = {}

local logTag = 'hashiriya'
local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/parts.json'

local data = nil
local loggedKeys = false

local function core() return extensions.hashiriyaBattle_core end

function M.loadData()
  data = jsonReadFile(dataPath) or { tiers = {}, categories = {}, models = {} }
end

local function activeCar()
  local save = core().save
  return save and save.cars[save.activeCar or 1] or nil
end

local function modelData(car)
  if not data then M.loadData() end
  return car and data.models[car.model] or nil
end

local function tierInfo(level)
  for _, t in ipairs(data.tiers or {}) do
    if t.level == level then return t end
  end
  return { level = level, unlock = {} }
end

local function isUnlocked(level)
  local need = tierInfo(level).unlock.minWins or 0
  return (core().save.wins or 0) >= need, need
end

local function priceOf(entry)
  return core().economy().usdToPrice(entry.valueUsd or 0)
end

-- Aktuelle Teile des Spielerautos ---------------------------------------------

local function currentConfig()
  local ok, vd = pcall(function() return core_vehicle_manager.getPlayerVehicleData() end)
  if not ok or not vd then return nil end
  local cfg = vd.config or {}
  local parts = cfg.parts or vd.chosenParts
  if type(parts) ~= 'table' then return nil end
  local out = { parts = {}, vars = {}, paints = cfg.paints }
  for k, v in pairs(parts) do out.parts[k] = v end
  for k, v in pairs(cfg.vars or {}) do out.vars[k] = v end
  return out
end

-- Setzt die Teile einer Stufe in die Config. Slots, die das Auto nicht hat, werden übersprungen.
-- Unterstützt flache Slot-Namen ("covet_exhaust") und Slot-Pfade ("/covet_body/.../covet_exhaust").
local function applyParts(cfg, parts)
  local changed = 0
  for slot, part in pairs(parts) do
    for key in pairs(cfg.parts) do
      if key == slot or key:sub(-(#slot + 1)) == '/' .. slot or key:sub(-(#slot + 2)) == '/' .. slot .. '/' then
        cfg.parts[key] = part
        changed = changed + 1
      end
    end
  end
  return changed
end

local function respawnWith(car, cfg)
  car.config = cfg
  core_vehicles.replaceVehicle(car.model, { config = cfg })
end

-- Kaufen / Einbauen ------------------------------------------------------------

function M.buy(category, level)
  local c = core()
  local car = activeCar()
  local md = modelData(car)
  level = tonumber(level)
  local entry = md and md[category] and md[category][level]
  if not entry then return end

  local unlocked = isUnlocked(level)
  if not unlocked then
    c.msg(c.t('msg.partLocked'))
    return
  end

  car.owned = car.owned or {}
  car.owned[category] = car.owned[category] or {}
  local owned = car.owned[category][tostring(level)] == true
  local price = owned and 0 or priceOf(entry)
  if c.save.money < price then
    c.msg(c.t('msg.noMoney'))
    return
  end

  local cfg = currentConfig()
  if not cfg then
    c.msg(c.t('msg.partFailed'))
    log('E', logTag, 'Shop: aktuelle Config nicht lesbar')
    return
  end
  if not loggedKeys then
    loggedKeys = true
    local keys = {}
    for k in pairs(cfg.parts) do table.insert(keys, k); if #keys >= 8 then break end end
    log('I', logTag, 'Shop: Slot-Beispiele: ' .. table.concat(keys, ', '))
  end
  if applyParts(cfg, entry.parts) == 0 then
    c.msg(c.t('msg.partIncompatible'))
    return
  end

  c.save.money = c.save.money - price
  car.owned[category][tostring(level)] = true
  car.tuning = car.tuning or {}
  car.tuning[category] = level
  respawnWith(car, cfg)
  c.writeSave()
  c.msg(c.t('msg.partInstalled', c.t('shop.cat.' .. category), level,
    price > 0 and c.economy().formatYen(price) or c.t('shop.free')))
  log('I', logTag, string.format('Shop: %s Lv%d eingebaut (%d Yen)', category, level, price))
end

-- UI ---------------------------------------------------------------------------

function M.getUiState()
  local c = core()
  local car = activeCar()
  local md = modelData(car)
  if not md then return { available = false } end
  local eco = c.economy()
  local st = { available = true, categories = {} }
  for _, cat in ipairs(data.categories or {}) do
    local tiers = md[cat]
    if tiers then
      local row = { id = cat, name = c.t('shop.cat.' .. cat), installed = car.tuning and car.tuning[cat] or 0, tiers = {} }
      for level, entry in ipairs(tiers) do
        local unlocked, need = isUnlocked(level)
        local owned = car.owned and car.owned[cat] and car.owned[cat][tostring(level)] == true
        local price = priceOf(entry)
        table.insert(row.tiers, {
          level = level,
          price = owned and c.t('shop.owned') or eco.formatYen(price),
          locked = not unlocked,
          lockText = not unlocked and c.t('shop.needWins', need) or nil,
          installed = row.installed == level,
          affordable = owned or c.save.money >= price,
        })
      end
      table.insert(st.categories, row)
    end
  end
  return st
end

local function onExtensionLoaded()
  M.loadData()
end

M.onExtensionLoaded = onExtensionLoaded

return M
