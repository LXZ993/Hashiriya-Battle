-- Hashiriya Battle: Siegesserie und Fahrstil-Combo
-- Siegesserie: Battles hintereinander gewinnen erhöht Preisgeld und Ruf, bis man verliert oder in die Garage/nach Hause fährt.
-- Combo: knappe Manöver (Beinahe-Kontakt im Verkehr, knappes Überholen des Rivalen, Windschatten, Drift, Vollgas im Verkehr)
-- reihen sich aneinander und steigern den Multiplikator. Endet die Combo sauber, gibt es Yen und Ruf. Ein Unfall löscht sie.
local M = {}

local logTag = 'hashiriya'
local cfgData = nil

local combo = nil       -- { points, chain, timer, label, labelTimer, labelPts }
local banked = nil      -- { yen, rep, timer } letzte ausgezahlte Combo (für die Anzeige)
local tracks = {}       -- vehId -> { along, minLat, rel }
local slipTime, driftTime, speedTime = 0, 0, 0
local lastDamage = nil
local wasNight = nil

local function core() return extensions.hashiriyaBattle_core end
local function pr() return extensions.hashiriyaBattle_progress end

local function cfg()
  if not cfgData then cfgData = jsonReadFile('/lua/ge/extensions/hashiriyaBattle/data/style.json') or {} end
  return cfgData
end

-- Siegesserie -------------------------------------------------------------------

function M.streak()
  local save = core().save
  return save and (save.streak or 0) or 0
end

-- Multiplikatoren für den nächsten Sieg (Serie zählt diesen Sieg mit)
function M.streakFactors(streak)
  local s = cfg().streak or {}
  local n = math.max((streak or 1) - 1, 0)
  return math.min(1 + n * (s.moneyPerWin or 0.1), s.moneyMax or 2),
         math.min(1 + n * (s.repPerWin or 0.05), s.repMax or 1.5)
end

function M.onBattleWon()
  local c = core()
  c.save.streak = (c.save.streak or 0) + 1
  c.save.stats = c.save.stats or {}
  local st = c.save.stats
  st.bestStreak = math.max(st.bestStreak or 0, c.save.streak)
  return c.save.streak
end

function M.resetStreak(reason)
  local c = core()
  if not c.save or (c.save.streak or 0) == 0 then return end
  local n = c.save.streak
  c.save.streak = 0
  if n >= 2 and reason ~= 'loss' then c.msg(c.t('msg.streakEnd', n), 4) end
end

function M.onParkingArrived(area)
  local s = cfg().streak or {}
  if area and ((area.type == 'garage' and s.resetAtGarage ~= false) or (area.type == 'home' and s.resetAtHome ~= false)) then
    M.resetStreak('garage')
  end
end

function M.onDaybreak()
  if (cfg().streak or {}).resetAtDaybreak ~= false then M.resetStreak('day') end
end

-- Combo -------------------------------------------------------------------------

local function comboCfg() return cfg().combo or {} end
local function man(name) return (comboCfg().maneuvers or {})[name] or {} end

local function mult(chain)
  local cc = comboCfg()
  return math.min(1 + math.max(chain - 1, 0) * (cc.multPerChain or 0.25), cc.multMax or 4)
end

local function award(name, extra)
  local c = core()
  local pts = (man(name).points or 50) + (extra or 0)
  if not combo then combo = { points = 0, chain = 0 } end
  combo.chain = combo.chain + 1
  combo.points = combo.points + pts
  combo.timer = comboCfg().window or 4
  combo.label, combo.labelPts, combo.labelTimer = name, pts, 1.6
  pr().bump(c.save, 'maneuvers')
  if name == 'nearMiss' or name == 'razor' then pr().bump(c.save, 'nearMisses') end
  c.sound('combo')
end

local function bankCombo()
  local c = core()
  local cc = comboCfg()
  local total = math.floor(combo.points * mult(combo.chain) + 0.5)
  combo = nil
  if total <= 0 then return end
  c.sound('comboBank')
  local yen = math.floor(total * (cc.yenPerPoint or 8) / 10 + 0.5) * 10
  local rep = math.floor(total / (cc.pointsPerRep or 400))
  c.save.money = c.save.money + yen
  c.save.rep = (c.save.rep or 0) + rep
  local st = c.save.stats or {}
  c.save.stats = st
  st.bestCombo = math.max(st.bestCombo or 0, total)
  pr().bump(c.save, 'comboYen', yen)
  banked = { points = total, yen = c.economy().formatYen(yen), rep = rep, timer = 3 }
end

local function loseCombo()
  if not combo then return end
  local c = core()
  combo = nil
  banked = { lost = true, timer = 2.5 }
  c.msg(c.t('msg.comboLost'), 2)
end

local function kmh(v) return v:length() * 3.6 end

local function onUpdate(dtReal, dtSim)
  local c = core()
  if banked then banked.timer = banked.timer - dtReal; if banked.timer <= 0 then banked = nil end end
  if c.active and c.save then
    local night = extensions.hashiriyaBattle_home.isNight()
    if wasNight and not night then M.onDaybreak() end
    wasNight = night
  end
  local cc = comboCfg()
  local veh = c.active and c.save and cc.enabled ~= false and c.getPlayerVehicle()
  if not veh or (cc.nightOnly and not extensions.hashiriyaBattle_home.isNight()) or (dtSim or 0) <= 0 then
    if combo and not veh then combo = nil end
    tracks = {}
    return
  end
  local dt = dtSim
  local me = map.objects[veh:getID()]
  if not me or not me.pos or not me.vel then return end

  -- Unfall: Combo weg
  local dmg = me.damage or 0
  if lastDamage and dmg - lastDamage > (cc.crashDamage or 150) then loseCombo() end
  lastDamage = dmg

  if combo then
    combo.timer = combo.timer - dt
    if combo.labelTimer then combo.labelTimer = combo.labelTimer - dt end
    if combo.timer <= 0 then bankCombo() end
  end

  local speed = kmh(me.vel)
  local dir = me.dirVec and vec3(me.dirVec) or veh:getDirectionVector()
  dir.z = 0
  dir = dir:normalized()
  local rivalVeh = extensions.hashiriyaBattle_rivals.getRivalVehicle()
  local rivalId = rivalVeh and rivalVeh:getID()
  local fast = speed >= (cc.minSpeedKmh or 80)

  -- Drift: Winkel zwischen Fahrtrichtung und Bewegung
  local d = man('drift')
  local vflat = vec3(me.vel.x, me.vel.y, 0)
  if speed >= (d.minKmh or 60) and vflat:length() > 1 then
    local cosA = math.max(-1, math.min(1, vflat:normalized():dot(dir)))
    local ang = math.deg(math.acos(cosA))
    if ang >= (d.angle or 15) and ang < 100 then
      driftTime = driftTime + dt
      if driftTime >= (d.seconds or 1) then
        driftTime = 0
        award('drift', math.floor(ang))
      end
    else
      driftTime = 0
    end
  else
    driftTime = 0
  end

  -- andere Autos in der Nähe: Beinahe-Kontakt, Windschatten, Vollgas im Verkehr
  local slipNow, trafficNear = false, false
  local seen = {}
  local nm, rz, rp, sl, hs = man('nearMiss'), man('razor'), man('rivalPass'), man('slipstream'), man('highSpeed')
  for id, o in pairs(map.objects) do
    if id ~= veh:getID() and o.pos and o.vel then
      local rel = o.pos - me.pos
      local dist = rel:length()
      if dist < (hs.trafficRange or 60) then trafficNear = true end
      if dist < 30 then
        seen[id] = true
        local along = rel:dot(dir)
        local lat = math.sqrt(math.max(rel.x * rel.x + rel.y * rel.y - along * along, 0))
        local t = tracks[id]
        if not t then t = { along = along, minLat = 99 }; tracks[id] = t end
        if math.abs(along) < 6 then t.minLat = math.min(t.minLat, lat) end
        local relKmh = speed - kmh(o.vel)
        -- vorbeigefahren: war vor uns, jetzt neben/hinter uns
        if t.along > 0 and along <= 0 and fast then
          if id == rivalId then
            if t.minLat < (rp.lateral or 3.2) then award('rivalPass') end
          elseif kmh(o.vel) > 5 and relKmh >= (nm.minRelKmh or 20) then
            if t.minLat < (rz.lateral or 2.25) then award('razor')
            elseif t.minLat < (nm.lateral or 2.9) then award('nearMiss') end
          end
          t.minLat = 99
        end
        if along < -8 then t.minLat = 99 end
        t.along = along
        -- Windschatten: direkt hinter einem fahrenden Auto
        if along > 3 and along < (sl.maxGap or 15) and lat < (sl.lateral or 1.4) and speed >= (sl.minKmh or 120) then slipNow = true end
      end
    end
  end
  for id in pairs(tracks) do if not seen[id] then tracks[id] = nil end end

  if slipNow then
    slipTime = slipTime + dt
    if slipTime >= (sl.seconds or 2) then slipTime = 0; award('slipstream') end
  else
    slipTime = 0
  end

  if speed >= (hs.minKmh or 200) and trafficNear then
    speedTime = speedTime + dt
    if speedTime >= (hs.seconds or 3) then speedTime = 0; award('highSpeed') end
  else
    speedTime = 0
  end
end

function M.getHudState()
  local c = core()
  local out = { streak = M.streak() }
  if combo then
    local cc = comboCfg()
    out.combo = {
      points = combo.points, chain = combo.chain, mult = string.format('x%.2f', mult(combo.chain)):gsub('0$', ''),
      left = math.floor(math.max(combo.timer, 0) / (cc.window or 4) * 100),
      label = combo.labelTimer and combo.labelTimer > 0 and c.t('combo.' .. combo.label) or nil,
      labelPts = combo.labelPts,
    }
  end
  if banked then out.banked = banked end
  return out
end

function M.reset()
  combo, banked, tracks = nil, nil, {}
  slipTime, driftTime, speedTime, lastDamage = 0, 0, 0, nil
end

M.onUpdate = onUpdate

return M
