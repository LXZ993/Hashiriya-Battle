-- Hashiriya Battle: Pink Slip (Alpha 0.5).
-- Manche Rivalen an den PAs fahren um die Fahrzeugpapiere. Gewinnst du, steht sein Auto in deiner Garage.
-- Verlierst du, nimmt er dein Auto mit und fährt es ab jetzt selbst, bis du ihn schlägst und es zurückholst.
-- Einstellungen: rivals.json settings.pinkSlip. Pro Rivale: "pinkSlip": true (immer) oder false (nie).
-- Spielstand: save.pinkHeld[rivalId] = dein Auto (wie in save.cars), save.pinkWon[rivalId] = Anzahl gewonnener Autos.
local M = {}

local logTag = 'hashiriya.pinkslip'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local function core() return extensions.hashiriyaBattle_core end
local function rivals() return extensions.hashiriyaBattle_rivals end
local function progress() return extensions.hashiriyaBattle_progress end

local defaults = { enabled = true, minRank = 3, share = 0.35, requireSpareCar = true, money = false, wanderers = true, leaders = true }
local pendingHome = nil -- nach verlorenem Pink Slip: sobald das Battle vorbei ist, mit dem nächsten Auto in die Garage

function M.settings()
  local d = rivals().getData()
  local p = d and d.settings and d.settings.pinkSlip or {}
  return setmetatable({}, { __index = function(_, k) if p[k] ~= nil then return p[k] end return defaults[k] end })
end

local function hashStr(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

local function baseId(rival) return rival and (rival.baseId or rival.id) end

function M.heldBy(rival, save)
  save = save or core().save
  return save and save.pinkHeld and save.pinkHeld[baseId(rival)] or nil
end

-- Fährt dieser Rivale grundsätzlich um Autos? (Bosse nie)
function M.isPinkRival(rival)
  if not rival or rival.boss then return false end
  if M.heldBy(rival) then return true end
  if rival.pinkSlip == true then return true end
  if rival.pinkSlip == false then return false end
  local s = M.settings()
  if rival.wanderer and not s.wanderers then return false end
  if rival.leader and not s.leaders then return false end
  return (hashStr(tostring(baseId(rival))) % 1000) / 1000 < (s.share or 0)
end

-- Darfst du jetzt gegen ihn um Autos fahren? Rückgabe: ok, Grund (Sprachschlüssel) wenn nicht
function M.canOffer(rival, save)
  save = save or core().save
  local s = M.settings()
  if not s.enabled or not save or not M.isPinkRival(rival) then return false, nil end
  if M.heldBy(rival, save) then return true end -- dein Auto zurückholen geht immer
  if progress().rankIndex(save) < (s.minRank or 0) then return false, 'talk.pinkNeedRank' end
  if s.requireSpareCar and #(save.cars or {}) < 2 then return false, 'talk.pinkNeedCar' end
  return true
end

-- Name fürs gewonnene Auto: "<Fahrzeug> von <Rivale>"
local function carName(rival)
  return core().t('pink.carName', rivals().vehicleName(rival.model), rival.name)
end

-- Ergebnis eines Battles (von core.onBattleResult). Rückgabe: true, wenn es ein Pink Slip war.
function M.onResult(rival, won)
  local c = core()
  local save = c.save
  if not save or not rival then return false end
  local id = baseId(rival)
  save.pinkHeld = save.pinkHeld or {}
  local held = save.pinkHeld[id]
  -- Hält er dein Auto, holst du es mit jedem Sieg gegen ihn zurück
  if won and held then
    save.pinkHeld[id] = nil
    held.pinkFrom = nil
    table.insert(save.cars, held)
    c.msg(c.t('msg.pinkBack', held.name or held.model, rival.name), 8)
    c.sound('talkHint')
    log('I', logTag, 'Auto zurückgewonnen von ' .. tostring(id) .. ': ' .. tostring(held.name))
    progress().bump(save, 'pinkBack')
    return rival.pinkSlip and true or false
  end
  if not rival.pinkSlip then return false end
  if won then
    local model, cfg = rivals().carFor(rival)
    local plates = extensions.hashiriyaBattle_plates
    local entry = {
      model = model, config = cfg, name = carName(rival),
      plate = (rival.plate and plates.normalize(rival.plate.text) and rival.plate.text) or plates.random(),
      plateDesign = rival.plate and rival.plate.design or plates.defaultDesign,
      km = 40000 + math.random(0, 80000), pinkFrom = id,
    }
    table.insert(save.cars, entry)
    save.pinkWon = save.pinkWon or {}
    save.pinkWon[id] = (save.pinkWon[id] or 0) + 1
    progress().bump(save, 'pinkWins')
    c.msg(c.t('msg.pinkWin', rival.name, entry.name), 8)
    c.sound('talkHint')
    log('I', logTag, 'Pink Slip gewonnen gegen ' .. tostring(id) .. ': ' .. tostring(model))
  else
    -- dein aktuelles Auto (mit allen Umbauten) geht an ihn
    local idx = save.activeCar or 1
    local car = save.cars[idx]
    if not car then return true end
    local okC, cfgNow = pcall(function() return extensions.hashiriyaBattle_shop.currentConfig() end)
    if okC and cfgNow then car.config = cfgNow end
    pcall(function() extensions.hashiriyaBattle_shop.cancelPreview(true) end)
    table.remove(save.cars, idx)
    car.pinkFrom = id
    save.pinkHeld[id] = car
    save.activeCar = 1
    progress().bump(save, 'pinkLosses')
    c.msg(c.t('msg.pinkLose', rival.name, car.name or car.model), 10)
    log('I', logTag, 'Pink Slip verloren an ' .. tostring(id) .. ': ' .. tostring(car.name))
    pendingHome = { t = 0 }
  end
  return true
end

-- Nach verlorenem Pink Slip: Ergebnis zeigen lassen, dann mit dem nächsten Auto zuhause in der Garage weiter
local function onUpdate(dtReal)
  if not pendingHome then return end
  local c = core()
  if not c or not c.active or not c.save then pendingHome = nil return end
  pendingHome.t = pendingHome.t + dtReal
  if extensions.hashiriyaBattle_battle.isBusy() and pendingHome.t < 20 then return end
  if pendingHome.t < 3 then return end
  pendingHome = nil
  if #c.save.cars == 0 then
    c.msg(c.t('msg.pinkNoCar'), 10)
    c.writeSave()
    return
  end
  pcall(function() extensions.hashiriyaBattle_rivals.despawnActive() end)
  c.spawnActiveCar()
  c.writeSave()
  c.msg(c.t('msg.pinkHome', c.save.cars[c.save.activeCar or 1].name or c.save.cars[c.save.activeCar or 1].model), 8)
end

M.onUpdate = onUpdate
return M
