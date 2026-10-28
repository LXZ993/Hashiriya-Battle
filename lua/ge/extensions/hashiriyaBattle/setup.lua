-- Hashiriya Battle: Fahrzeug-Setup in der Garage (Ladedruck, Fahrwerk, Sturz, Übersetzung ...)
-- Die Einstellwerte sind die jbeam-Variablen der verbauten Teile (dieselben wie im BeamNG-Tuning-Menü).
-- Änderungen werden erst gesammelt und mit apply() auf einmal übernommen (Auto wird neu gespawnt).
local M = {}

local logTag = 'hashiriya'

local pending = {}      -- [name] = Rohwert, noch nicht übernommen
local openCat = nil

local function core() return extensions.hashiriyaBattle_core end

local function activeCar()
  local save = core().save
  return save and save.cars[save.activeCar or 1] or nil
end

local function vehicleData()
  local ok, vd = pcall(function() return core_vehicle_manager.getPlayerVehicleData() end)
  if ok then return vd end
end

-- Liste der einstellbaren Variablen (vdata.variables ist je nach Version Map oder Liste).
local function variables()
  local vd = vehicleData()
  local src = vd and vd.vdata and vd.vdata.variables
  if type(src) ~= 'table' then return {}, {} end
  local current = vd.config and vd.config.vars or {}
  local list = {}
  for k, v in pairs(src) do
    if type(v) == 'table' then
      local name = v.name or k
      local min, max = tonumber(v.min), tonumber(v.max)
      if type(name) == 'string' and min and max and min ~= max and not v.hideInUI and (v.type == nil or v.type == 'range') then
        table.insert(list, {
          name = name, title = v.title or name, unit = v.unit or '', category = v.category or 'Other', subCategory = v.subCategory,
          min = min, max = max, default = tonumber(v.default) or min,
          val = tonumber(current[name]) or tonumber(v.val) or tonumber(v.default) or min,
          minDis = tonumber(v.minDis), maxDis = tonumber(v.maxDis), stepDis = tonumber(v.stepDis), step = tonumber(v.step),
        })
      end
    end
  end
  table.sort(list, function(a, b)
    if a.category ~= b.category then return a.category < b.category end
    return tostring(a.title) < tostring(b.title)
  end)
  return list, current
end

local function toDisplay(v, raw)
  if v.minDis and v.maxDis and v.max ~= v.min then
    return v.minDis + (raw - v.min) / (v.max - v.min) * (v.maxDis - v.minDis)
  end
  return raw
end

-- Schrittweite in Rohwerten (stepDis ist in Anzeigeeinheiten angegeben).
local function rawStep(v)
  if v.stepDis and v.stepDis > 0 then
    if v.minDis and v.maxDis and v.maxDis ~= v.minDis then
      return v.stepDis * (v.max - v.min) / (v.maxDis - v.minDis)
    end
    return v.stepDis
  end
  if v.step and v.step > 0 then return v.step end
  return (v.max - v.min) / 50
end

local function fmt(v, raw)
  local d = toDisplay(v, raw)
  if math.abs(d) < 1e-9 then d = 0 end -- kein "-0"
  local step = v.stepDis or 0.01
  local decimals = step >= 1 and 0 or (step >= 0.1 and 1 or (step >= 0.01 and 2 or 3))
  local s = string.format('%.' .. decimals .. 'f', d)
  if v.unit ~= '' then s = s .. ' ' .. v.unit end
  return s
end

function M.adjust(name, dir)
  for _, v in ipairs((variables())) do
    if v.name == name then
      local raw = pending[name] or v.val
      raw = clamp(raw + rawStep(v) * (dir < 0 and -1 or 1), math.min(v.min, v.max), math.max(v.min, v.max))
      if math.abs(raw - v.val) < 1e-6 then pending[name] = nil else pending[name] = raw end
      return
    end
  end
end

function M.resetDefaults()
  for _, v in ipairs((variables())) do
    if math.abs(v.default - v.val) > 1e-6 then pending[v.name] = v.default else pending[v.name] = nil end
  end
end

function M.discard() pending = {} end

function M.hasPending() return next(pending) ~= nil end

function M.toggleCategory(cat) openCat = (openCat == cat) and nil or cat end

function M.apply()
  local c = core()
  local car = activeCar()
  if not car or not M.hasPending() then return end
  local cfg = extensions.hashiriyaBattle_shop.currentConfig()
  if not cfg then
    c.msg(c.t('msg.partFailed'))
    return
  end
  for name, raw in pairs(pending) do cfg.vars[name] = raw end
  pending = {}
  car.config = cfg
  core_vehicles.replaceVehicle(car.model, { config = cfg })
  c.writeSave()
  c.msg(c.t('msg.setupApplied'))
  log('I', logTag, 'Setup übernommen')
end

function M.getUiState()
  local list = variables()
  local cats, byCat = {}, {}
  for _, v in ipairs(list) do
    if not byCat[v.category] then
      byCat[v.category] = { id = v.category, name = v.category, rows = {}, changed = 0 }
      table.insert(cats, byCat[v.category])
    end
    local raw = pending[v.name] or v.val
    local cat = byCat[v.category]
    table.insert(cat.rows, {
      name = v.name, title = v.title, value = fmt(v, raw), changed = pending[v.name] ~= nil,
      atMin = raw <= math.min(v.min, v.max) + 1e-6, atMax = raw >= math.max(v.min, v.max) - 1e-6,
    })
    if pending[v.name] ~= nil then cat.changed = cat.changed + 1 end
  end
  if openCat == nil and cats[1] then openCat = cats[1].id end
  return { cats = cats, open = openCat, pending = M.hasPending() }
end

-- Beim Verlassen der Garage verfallen nicht übernommene Änderungen.
function M.onParkingLeft() pending = {} end

return M
