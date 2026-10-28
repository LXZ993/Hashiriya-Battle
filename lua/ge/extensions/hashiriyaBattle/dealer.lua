-- Hashiriya Battle: Autohändler (Auktionsseite) und eigene Autos
-- Jeden Spieltag gibt es eine Auswahl aus data/dealer.json (offersPerDay Angebote, zufällig je Spielstand und Tag).
-- Gekaufte Autos stehen in der Garage; dort wechselt man das aktive Auto.
local M = {}

local logTag = 'hashiriya'
local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/dealer.json'

local data = nil
local offersCache = nil -- { key = 'seed:day', list = {...} }

local function core() return extensions.hashiriyaBattle_core end

local function loadData()
  data = data or jsonReadFile(dataPath) or { cars = {}, offersPerDay = 5 }
  return data
end

-- Einfacher Zufallsgenerator mit festem Startwert (gleiche Angebote den ganzen Tag)
local function rng(seed)
  local state = seed % 2147483647
  if state <= 0 then state = state + 2147483646 end
  return function(a, b)
    state = (state * 16807) % 2147483647
    local r = (state - 1) / 2147483646
    if a then return a + math.floor(r * (b - a + 1)) end
    return r
  end
end

local function excluded(key, info)
  local text = (tostring(key) .. ' ' .. tostring(info.Configuration or '')):lower()
  for _, word in ipairs(loadData().exclude or {}) do
    if text:find(word, 1, true) then return true end
  end
  return false
end

-- Alle möglichen Angebote: Einträge mit config = genau diese Config, ohne config = jede passende Config des Modells
local function pool()
  local list = {}
  for _, entry in ipairs(loadData().cars or {}) do
    local okM, m = pcall(core_vehicles.getModel, entry.model)
    if okM and m and m.configs then
      local brand = m.model and m.model.Brand or ''
      local name = m.model and m.model.Name or entry.model
      local function add(key, info)
        if tonumber(info.Value) and tonumber(info.Value) > 0 then
          table.insert(list, { model = entry.model, key = key, info = info, brand = brand, name = name })
        end
      end
      if entry.config and entry.config ~= '' then
        local key = entry.config:match('([^/]+)%.pc$') or entry.config
        if m.configs[key] then add(key, m.configs[key]) end
      else
        local keys = {}
        for key in pairs(m.configs) do table.insert(keys, key) end
        table.sort(keys)
        for _, key in ipairs(keys) do
          if not excluded(key, m.configs[key]) then add(key, m.configs[key]) end
        end
      end
    end
  end
  return list
end

local conditions = {
  { id = 'A', factor = 1.0 },
  { id = 'B', factor = 0.88 },
  { id = 'C', factor = 0.75 },
}

local function makeOffers()
  local c = core()
  local save = c.save
  if not save then return {} end
  local key = tostring(save.dealerSeed or 1) .. ':' .. tostring(save.day or 1)
  if offersCache and offersCache.key == key then return offersCache.list end
  local rand = rng((save.dealerSeed or 1) * 31 + (save.day or 1) * 7919)
  local all = pool()
  local list = {}
  local count = math.min(loadData().offersPerDay or 5, #all)
  for i = 1, count do
    local pick = table.remove(all, rand(1, #all))
    local cond = conditions[rand(1, #conditions)]
    local km = rand(8, 190) * 1000
    local kmFactor = 1 - math.min(0.3, km / 190000 * 0.3)
    local base = c.economy().usdToPrice(tonumber(pick.info.Value))
    local price = math.max(10000, math.floor(base * cond.factor * kmFactor / 10000 + 0.5) * 10000)
    table.insert(list, {
      index = i, model = pick.model, key = pick.key, info = pick.info,
      title = (pick.brand ~= '' and (pick.brand .. ' ') or '') .. pick.name,
      config = pick.info.Configuration or pick.key,
      preview = pick.info.preview or ('/vehicles/' .. pick.model .. '/' .. pick.key .. '.jpg'),
      km = km, condition = cond.id, price = price,
      lot = string.format('%02d-%03d', (save.day or 1) % 100, rand(100, 999)),
    })
  end
  offersCache = { key = key, list = list }
  return list
end

local function soldKey(i)
  local save = core().save
  return tostring(save.day or 1) .. ':' .. tostring(i)
end

local function randomPlate()
  local ok, text = pcall(function()
    local skia = extensions.core_skiaTemplate or (extensions.load('core_skiaTemplate') and extensions.core_skiaTemplate)
    return skia and skia.generateText(nil, nil)
  end)
  if ok and type(text) == 'string' and text ~= '' then return text end
  return string.format('%d%d-%02d', math.random(1, 9), math.random(0, 9), math.random(0, 99))
end

function M.buy(i)
  local c = core()
  local save = c.save
  if not save or not i then return end
  local offer = makeOffers()[i]
  if not offer then return end
  save.dealerSold = save.dealerSold or {}
  if save.dealerSold[soldKey(i)] then return end
  if save.money < offer.price then
    c.msg(c.t('msg.noMoney'))
    return
  end
  save.money = save.money - offer.price
  save.dealerSold[soldKey(i)] = true
  local name = offer.title .. ' ' .. offer.config
  table.insert(save.cars, {
    model = offer.model, config = '/vehicles/' .. offer.model .. '/' .. offer.key .. '.pc',
    name = name, plate = randomPlate(), km = offer.km,
  })
  c.writeSave()
  c.msg(c.t('msg.carBought', name, c.economy().formatYen(offer.price)), 6)
  log('I', logTag, string.format('Autohändler: %s/%s für %d Yen', offer.model, offer.key, offer.price))
end

-- Auswahl der Specs für die Auktionskarte
local function specs(info)
  local t = {}
  local function add(v) if v and v ~= '' then table.insert(t, v) end end
  local power, weight = tonumber(info.Power), tonumber(info.Weight)
  add(power and string.format('%d PS', math.floor(power + 0.5)))
  add(weight and string.format('%d kg', math.floor(weight + 0.5)))
  add(info.Drivetrain)
  add(info.Transmission)
  return t
end

local function formatKm(km)
  local s = tostring(math.floor(km)):reverse():gsub('(%d%d%d)', '%1.'):reverse()
  if s:sub(1, 1) == '.' then s = s:sub(2) end
  return s .. ' km'
end

function M.getUiState()
  local c = core()
  local save = c.save
  local st = { day = save and save.day or 1, offers = {} }
  for i, o in ipairs(makeOffers()) do
    local sold = save and save.dealerSold and save.dealerSold[soldKey(i)] or false
    table.insert(st.offers, {
      index = i, title = o.title, config = o.config, preview = o.preview, specs = specs(o.info),
      km = formatKm(o.km), condition = o.condition, lot = o.lot,
      price = c.economy().formatYen(o.price), sold = sold,
      affordable = save and save.money >= o.price,
    })
  end
  return st
end

-- Eigene Autos (Garage) -----------------------------------------------------------

function M.ownedCars()
  local save = core().save
  local list = {}
  for i, car in ipairs(save and save.cars or {}) do
    table.insert(list, { index = i, name = car.name or car.model, plate = car.plate, active = i == (save.activeCar or 1) })
  end
  return list
end

-- Anderes Auto aus der Garage holen (nur in der Garage)
function M.switchCar(i)
  local c = core()
  local save = c.save
  if not save or not i or not save.cars[i] or i == (save.activeCar or 1) then return end
  local p = extensions.hashiriyaBattle_parking
  local area = p.isArrived() and p.getCurrent()
  if not area or area.type ~= 'garage' then return end
  -- aktuellen Stand des alten Autos sichern
  local old = save.cars[save.activeCar or 1]
  local cfg = extensions.hashiriyaBattle_shop.currentConfig()
  if old and cfg then old.config = cfg end
  extensions.hashiriyaBattle_shop.cancelPreview(true)
  save.activeCar = i
  c.spawnActiveCar()
  c.writeSave()
  c.msg(c.t('msg.carSwitched', save.cars[i].name or save.cars[i].model), 4)
end

return M
