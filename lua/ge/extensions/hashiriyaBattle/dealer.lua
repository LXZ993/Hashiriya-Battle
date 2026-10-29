-- Hashiriya Battle: Autohändler (Auktionsseite) und eigene Autos
-- Jeden Spieltag gibt es eine Auswahl aus data/dealer.json (offersPerDay Angebote, zufällig je Spielstand und Tag).
-- Gekaufte Autos stehen in der Garage; dort wechselt man das aktive Auto.
-- Wie in den Originalspielen gibt es nur Autos, die zum Fortschritt passen: Leistungsgrenze (PS) aus den Rivalen,
-- die man beim aktuellen Rang schon treffen kann (powerCap in dealer.json). Die Grenze gilt jeweils für den ganzen Tag.
-- Jedes Angebot hat einen Mindestrang (minRank) und eine Seltenheit (rarity): Importe sind sehr selten, je älter und teurer, desto seltener.
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
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

-- Leistung einer Config in PS (nil, wenn BeamNG keinen Wert kennt)
local powerCache = {}
local function configPower(model, key)
  local id = tostring(model) .. '/' .. tostring(key)
  if powerCache[id] == nil then
    local okM, m = pcall(core_vehicles.getModel, model)
    local info = okM and m and m.configs and m.configs[key]
    powerCache[id] = info and tonumber(info.Power) or false
  end
  return powerCache[id] or nil
end

-- Ab welchem Rang ein Rivale auftauchen kann (Team-Rang oder eigene Bedingung)
local function rivalMinRank(r, teams)
  local rank = r.conditions and r.conditions.minRank or 0
  if r.team and teams[r.team] then rank = math.max(rank, teams[r.team].minRank or 0) end
  return rank
end

-- PS-Grenze für die Angebote: stärkster Rivale, den man beim aktuellen Rang treffen kann, mal factor.
-- Bosse zählen erst, wenn sie geschlagen sind. byRank (Liste je Rang) überschreibt die Rechnung.
local function computeCap(save)
  local set = loadData().powerCap
  if not set or set.enabled == false then return nil end
  local rank = extensions.hashiriyaBattle_progress.rankIndex(save)
  local fixed = set.byRank and set.byRank[rank + 1]
  if tonumber(fixed) then return tonumber(fixed) end
  local rd = extensions.hashiriyaBattle_rivals.getData() or {}
  local teams = {}
  for _, t in ipairs(rd.teams or {}) do teams[t.id] = t end
  local best = 0
  for _, r in ipairs(rd.rivals or {}) do
    -- Crew-Mitglieder zählen ab ihrem Rang; Leader, Wanderer und Bosse erst nach dem Sieg
    -- (sonst würden einzelne starke Sonderautos die Grenze früh hochziehen)
    local counts
    if r.boss or r.leader or r.wanderer then counts = save.defeated and save.defeated[r.id]
    else counts = rivalMinRank(r, teams) <= rank end
    if counts and r.model and r.config then
      local key = tostring(r.config):match('([^/]+)%.pc$') or tostring(r.config)
      local ps = configPower(r.model, key)
      if ps and ps > best then best = ps end
    end
  end
  local cap = math.max(tonumber(set.minPs) or 0, best * (tonumber(set.factor) or 1.1))
  return math.floor(cap / 10 + 0.5) * 10
end

-- Grenze einmal pro Tag festlegen (bessere Autos gibt es ab dem nächsten Tag, Angebote bleiben stabil)
local function dayCap(save)
  local day = save.day or 1
  if not save.dealerCap or save.dealerCap.day ~= day then
    save.dealerCap = { day = day, ps = computeCap(save) }
    if save.dealerCap.ps then log('I', logTag, string.format('Autohändler: Angebote bis %d PS (Tag %d)', save.dealerCap.ps, day)) end
  end
  return save.dealerCap.ps
end

-- Alle möglichen Angebote: Einträge mit config = genau diese Config, ohne config = jede passende Config des Modells
local function pool(cap, rank)
  local list = {}
  for _, entry in ipairs(loadData().cars or {}) do
    if not (rank and entry.minRank and rank < entry.minRank) then
      local okM, m = pcall(core_vehicles.getModel, entry.model)
      if okM and m and m.configs then
        local brand = m.model and m.model.Brand or ''
        local name = m.model and m.model.Name or entry.model
        local function add(key, info)
          local ps = tonumber(info.Power)
          if cap and (not ps or ps > cap) then return end
          if tonumber(info.Value) and tonumber(info.Value) > 0 then
            table.insert(list, { model = entry.model, key = key, info = info, brand = brand, name = name,
              weight = tonumber(entry.rarity) or 1 })
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
  end
  return list
end

-- Gewichtete Auswahl: rarity in dealer.json (1 = normal, 0.01 = sehr selten)
local function pickWeighted(all, rand)
  local total = 0
  for _, o in ipairs(all) do total = total + math.max(0.0001, o.weight or 1) end
  local x = rand() * total
  for i, o in ipairs(all) do
    x = x - math.max(0.0001, o.weight or 1)
    if x <= 0 then return table.remove(all, i) end
  end
  return table.remove(all, #all)
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
  local all = pool(dayCap(save), extensions.hashiriyaBattle_progress.rankIndex(save))
  local list = {}
  local count = math.min(loadData().offersPerDay or 5, #all)
  for i = 1, count do
    local pick = pickWeighted(all, rand)
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
  extensions.hashiriyaBattle_progress.bump(save, 'carsBought')
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
  if save then makeOffers() end
  local st = { day = save and save.day or 1, offers = {} }
  local cap = save and save.dealerCap and save.dealerCap.ps
  if cap then st.capText = c.t('dealer.cap', cap) end
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
