-- Hashiriya Battle: Wartung (Öl, Kühlwasser, Reifen)
-- Jedes eigene Auto hat drei Wartungswerte von 100 % (frisch) bis 0 %. Sie sinken mit den gefahrenen Kilometern
-- (Laufleistung aus condition.lua) und werden in der Garage (Tab Service) gegen Geld wieder auf 100 % gebracht.
-- Einstellungen: data/maintenance.json (Intervalle in km, Preise in Yen, Wirkung, Warnschwelle).
-- Spielstand: car.maint = { oil = km, coolant = km, tires = km } = Kilometerstand beim letzten Service.
-- Wirkung im Auto (erst unter effectBelow, dann stärker bis 0 %):
--   Öl      -> mehr Motorreibung (weniger Leistung, wärmer)
--   Wasser  -> schwächerer Kühler (Motor wird schneller heiß)
--   Reifen  -> weniger Grip (Reibwert der Reifen-Nodes)
local M = {}

local logTag = 'hashiriya.maint'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/maintenance.json'

M.items = { 'oil', 'coolant', 'tires' }

local defaults = {
  enabled = true,
  intervalKm = { oil = 1200, coolant = 2500, tires = 900 },
  priceYen = { oil = 6980, coolant = 4980, tires = 29800 },
  tiresValueShare = 0.02,
  effectBelow = 0.5,
  effect = { oilFriction = 0.6, coolantRadiator = 0.5, tiresGrip = 0.12 },
  warnBelow = 0.2,
  usedStart = { 0.35, 0.9 },
}

local data = nil
local pollTimer = 5
local resetTimer = nil
local resetVeh = nil
local lastApplied = nil -- zuletzt gesetzte Faktoren (nur neu senden, wenn sie sich ändern)

local function core() return extensions.hashiriyaBattle_core end

function M.settings()
  if not data then
    local d = jsonReadFile(dataPath) or {}
    data = {}
    for k, v in pairs(defaults) do
      if type(v) == 'table' and type(d[k]) == 'table' then
        local t = {}
        for k2, v2 in pairs(v) do t[k2] = d[k][k2] ~= nil and d[k][k2] or v2 end
        data[k] = t
      elseif d[k] ~= nil then data[k] = d[k] else data[k] = v end
    end
  end
  return data
end

local function clamp01(x) return math.max(0, math.min(1, x)) end

local function hashStr(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

local function odoKm(car) return tonumber(car.odometerKm) or tonumber((car.wear or {}).odometerKm) or tonumber(car.km) or 0 end

-- Startwerte für ein Auto ohne Wartungsdaten: frisch (start = 1) oder gebraucht (aus Zustand und Name, fest je Auto)
function M.init(car, start)
  if not car then return end
  local s = M.settings()
  local km = odoKm(car)
  car.maint = {}
  for i, item in ipairs(M.items) do
    local level = start
    if not level then
      local range = s.usedStart or defaults.usedStart
      local integ = tonumber((car.wear or {}).integrity) or 0.85
      local r = (hashStr(tostring(car.name or car.model) .. item .. tostring(car.plate)) % 1000) / 1000
      level = range[1] + (range[2] - range[1]) * (0.5 * r + 0.5 * clamp01((integ - 0.6) / 0.4))
    end
    car.maint[item] = km - (1 - clamp01(level)) * (s.intervalKm[item] or 1000)
  end
end

-- Auto ohne Laufleistung (z. B. Pink-Slip-Gewinn): Grundzustand neu, damit condition.lua die km mitzählt
function M.ensure(car)
  if not car then return end
  if not car.wear and not car.parts then
    car.wear = { odometerKm = tonumber(car.km) or 0, integrity = 1, visual = 1 }
    car.wearFrom = car.wearFrom or 'maint'
  end
  if not car.maint then M.init(car, nil) end
end

-- Neue Reifen über den Shop: Reifen-Teile mit kleiner Laufleistung zählen als frisch
local function tireDriven(car, driven)
  for id, p in pairs(car.parts or {}) do
    if tostring(id):lower():find('tire', 1, true) and tonumber(p.o) then
      driven = math.min(driven, p.o / 1000)
    end
  end
  return driven
end

-- Wartungswert 0..1
function M.level(car, item)
  if not car or not car.maint or not car.maint[item] then return 1 end
  local s = M.settings()
  local driven = math.max(0, odoKm(car) - car.maint[item])
  if item == 'tires' then driven = tireDriven(car, driven) end
  return clamp01(1 - driven / (s.intervalKm[item] or 1000))
end

-- Stärke der Wirkung 0..1 (0 über effectBelow, 1 bei 0 %)
local function strength(level)
  local below = M.settings().effectBelow or 0.5
  if below <= 0 then return 0 end
  return clamp01((below - level) / below)
end

-- Faktoren fürs Auto: Motorreibung, Kühler, Reifengrip
function M.factors(car)
  local s = M.settings()
  if not s.enabled or not car or not car.maint then return 1, 1, 1 end
  local e = s.effect
  local oil = 1 + (e.oilFriction or 0) * strength(M.level(car, 'oil'))
  local cool = 1 - (e.coolantRadiator or 0) * strength(M.level(car, 'coolant'))
  local grip = 1 - (e.tiresGrip or 0) * strength(M.level(car, 'tires'))
  return oil, cool, grip
end

-- Lua-Code für das Fahrzeug (wird von condition.lua nach dem Zustand mitgeschickt und nach Reset/Service).
-- Reibung: Basiswert merken, damit mehrfaches Anwenden nicht aufaddiert. Reifen: absolut aus den jbeam-Werten.
function M.vehicleLua(car, radInteg, cooling)
  local oil, cool, grip = M.factors(car)
  return string.format([[
    pcall(function()
      local oilMul, coolMul, gripMul, radInteg, cooling, odo = %f, %f, %f, %f, %f, %f
      hbMaint = hbMaint or {}
      for _, e in ipairs(powertrain.getDevicesByCategory('engine') or {}) do
        local key = tostring(e.name or 'engine')
        local cur = e.damageFrictionCoef
        if cur then
          local st = hbMaint[key]
          local base = (st and st.set == cur) and st.base or cur
          e.damageFrictionCoef = base * oilMul
          hbMaint[key] = { base = base, set = e.damageFrictionCoef }
        end
        if radInteg >= 0 and e.thermals and e.thermals.setPartConditionRadiator then
          pcall(e.thermals.setPartConditionRadiator, odo, (1 - (1 - radInteg) * cooling) * coolMul, 1)
        end
      end
      local tiresOk = false
      if obj.setNodeFrictionSlidingCoefs and v.data.wheels and v.data.nodes then
        for _, w in pairs(v.data.wheels) do
          for _, nid in ipairs(w.treadNodes or w.nodes or {}) do
            local n = v.data.nodes[nid]
            if n then
              local f = n.frictionCoef or 1
              local sl = n.slidingFrictionCoef or f
              obj:setNodeFrictionSlidingCoefs(nid, f * gripMul, sl * gripMul)
              tiresOk = true
            end
          end
        end
      end
      if not hbMaintReported then
        hbMaintReported = true
        obj:queueGameEngineLua('if extensions.hashiriyaBattle_maintenance then extensions.hashiriyaBattle_maintenance.onVehicleReport(' .. tostring(tiresOk) .. ') end')
      end
    end)
  ]], oil, cool, grip, radInteg or -1, cooling or 0.4, odoKm(car) * 1000)
end

function M.onVehicleReport(tiresOk)
  log('I', logTag, 'Wartung im Auto angewendet, Reifengrip ' .. (tiresOk and 'aktiv' or 'nicht verfügbar (BeamNG-Funktion fehlt)'))
end

local function activeCar()
  local save = core().save
  return save and save.cars and save.cars[save.activeCar or 1] or nil
end

-- Wirkung jetzt neu setzen (nach Service oder Reset), Kühler mit dem Zustand aus condition.lua
function M.applyNow()
  local c = core()
  local car = activeCar()
  local veh = c and c.getPlayerVehicle()
  if not car or not veh or veh:getJBeamFilename() ~= car.model then return end
  local cond = extensions.hashiriyaBattle_condition
  local rad, cooling = -1, 0.4
  if cond and cond.radiatorInfo then rad, cooling = cond.radiatorInfo(car) end
  veh:queueLuaCommand(M.vehicleLua(car, rad, cooling))
end

-- Preise je Posten (Reifen: fester Satzpreis oder Anteil am Wagenwert, der größere Wert)
function M.price(car, item)
  local s = M.settings()
  local p = tonumber(s.priceYen[item]) or 0
  if item == 'tires' and car and (s.tiresValueShare or 0) > 0 then
    -- BeamNG-Wert der Config (nicht der Kaufpreis: Rivalen-Autos kosten 5- bis 10-fach)
    local okV, value = pcall(function() return extensions.hashiriyaBattle_dealer.baseValue(car) end)
    if okV and value and value * s.tiresValueShare > p then p = math.floor(value * s.tiresValueShare / 100 + 0.5) * 100 end
  end
  return math.floor(p)
end

function M.service(item)
  local c = core()
  local save = c.save
  local car = activeCar()
  if not save or not car then return end
  M.ensure(car)
  local list = item == 'all' and M.items or { item }
  local cost, done = 0, {}
  for _, it in ipairs(list) do
    if car.maint[it] and M.level(car, it) < 0.995 then
      cost = cost + M.price(car, it)
      table.insert(done, it)
    end
  end
  if #done == 0 then return end
  if save.money < cost then c.msg(c.t('msg.noMoney')) return end
  save.money = save.money - cost
  local km = odoKm(car)
  car.maintWarned = car.maintWarned or {}
  local names = {}
  for _, it in ipairs(done) do
    car.maint[it] = km
    car.maintWarned[it] = nil
    table.insert(names, c.t('maint.' .. it))
  end
  pcall(function() extensions.hashiriyaBattle_progress.bump(save, 'services') end)
  c.writeSave()
  M.applyNow()
  c.msg(c.t('msg.serviced', table.concat(names, ', '), c.economy().formatYen(cost)), 5)
  c.sound('buy')
  log('I', logTag, string.format('Service %s für %d Yen', table.concat(done, '+'), cost))
end

function M.getUiState()
  local c = core()
  local car = activeCar()
  if not M.settings().enabled or not car then return nil end
  M.ensure(car)
  local st = { items = {}, total = 0 }
  local total = 0
  local warnBelow = M.settings().warnBelow or 0.2
  for _, it in ipairs(M.items) do
    local lvl = M.level(car, it)
    local need = lvl < 0.995
    local price = M.price(car, it)
    if need then total = total + price end
    table.insert(st.items, { id = it, name = c.t('maint.' .. it), pct = math.floor(lvl * 100 + 0.5),
      warn = lvl < warnBelow, need = need, price = c.economy().formatYen(price),
      affordable = c.save.money >= price, effect = strength(lvl) > 0 })
  end
  st.total = total > 0 and c.economy().formatYen(total) or nil
  st.canAll = total > 0 and c.save.money >= total
  return st
end

-- Warnung unterwegs, wenn ein Wert unter warnBelow fällt (einmal je Service)
local function checkWarn(car)
  local c = core()
  local s = M.settings()
  car.maintWarned = car.maintWarned or {}
  for _, it in ipairs(M.items) do
    if not car.maintWarned[it] and M.level(car, it) < (s.warnBelow or 0.2) then
      car.maintWarned[it] = true
      c.msg(c.t('msg.maintWarn', c.t('maint.' .. it)), 6)
      log('I', logTag, 'Wartung fällig: ' .. it)
    end
  end
end

function M.onVehicleResetted(vehId)
  local c = core()
  if not c or not c.active then return end
  local veh = c.getPlayerVehicle()
  if veh and veh:getID() == vehId then resetTimer = 0.5; resetVeh = vehId end
end

function M.onUpdate(dtReal)
  local c = core()
  if not c or not c.active or not c.save or not M.settings().enabled then return end
  if resetTimer then
    resetTimer = resetTimer - dtReal
    if resetTimer <= 0 then
      resetTimer = nil
      local veh = c.getPlayerVehicle()
      if veh and veh:getID() == resetVeh then M.applyNow() end
    end
  end
  pollTimer = pollTimer - dtReal
  if pollTimer > 0 then return end
  pollTimer = 15
  local car = activeCar()
  if not car then return end
  if not car.maint then M.ensure(car) return end
  -- Wirkung wächst mit den km: alle 15 s neu setzen, wenn sie sich spürbar geändert hat
  local oil, cool, grip = M.factors(car)
  local key = string.format('%.2f/%.2f/%.2f', oil, cool, grip)
  if key ~= lastApplied then
    lastApplied = key
    M.applyNow()
  end
  checkWarn(car)
end

return M
