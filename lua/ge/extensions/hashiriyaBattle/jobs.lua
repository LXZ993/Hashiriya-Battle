-- Hashiriya Battle: Nebenjobs am Tag und bezahlte Tipps (Alpha 0.7).
-- Am Jobbrett (Garage oder Zuhause, nur tagsüber) gibt es jeden Tag ein paar Aufträge:
--   courier = Kurierfahrt zu einem Ziel mit Zeitlimit, Schaden am Auto kürzt den Lohn
--   express = wie Kurier, aber knapper und besser bezahlt
--   fragile = zerbrechliche Ladung: mehr Geld, Schaden kostet dreifach, zu viel Schaden = Auftrag geplatzt
--   photo   = Fotojob: zu Fuß an einer PA sein, solange das Zeitfenster offen ist
-- Dazu Tipps: Hinweise zu Wanderern und Bossen kaufen (wie aus den PA-Gesprächen, landen im Rivalen-Lexikon).
-- Ziele: Parkplätze und PAs der Kartendatei, dazu "jobSpots" (Liste { name, pos }) in maps/<level>.json.
-- Einstellungen und Ladungen: data/jobs.json. Spielstand: save.jobs = { day, offers, done, earned, count }.
local M = {}

local logTag = 'hashiriya.jobs'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local jobsPath = '/lua/ge/extensions/hashiriyaBattle/data/jobs.json'

local function core() return extensions.hashiriyaBattle_core end
local function home() return extensions.hashiriyaBattle_home end
local function progress() return extensions.hashiriyaBattle_progress end
local function parking() return extensions.hashiriyaBattle_parking end

local data = nil
local active = nil   -- laufender Auftrag { offer, left, startDamage, early, stage = 'pickup'|'deliver' }
local timer = 0
local updateMarkers -- weiter unten (Markierungen und Navi-Route)

local defaults = {
  enabled = true, offersPerDay = 4, maxPerDay = 4, minDistance = 800, arriveRadius = 25, arriveKmh = 8,
  rankBonus = 0.08, photoRadius = 60, photoWindowHours = 2, failMoney = 0,
  pickup = true, pickupMaxDistance = 2500, photoSpotRadius = 7, photoStopKmh = 2, markers = true, navRoute = true,
  tipPriceWanderer = 250000, tipPriceBoss = 750000, tipRankFactor = 0.1,
}
local typeDefaults = {
  courier = { payBase = 8000, payPerKm = 2500, secondsPerKm = 75, minSeconds = 150, damageFactor = 1, weight = 3 },
  express = { payBase = 12000, payPerKm = 3800, secondsPerKm = 52, minSeconds = 110, damageFactor = 1, weight = 2 },
  fragile = { payBase = 15000, payPerKm = 3200, secondsPerKm = 95, minSeconds = 180, damageFactor = 3, failDamageYen = 40000, weight = 2 },
  photo = { payBase = 22000, weight = 1 },
}

local speakerNames = {} -- Auftraggeber: Namen der Sprecher aus chat.json

function M.loadData()
  local chat = jsonReadFile('/lua/ge/extensions/hashiriyaBattle/data/chat.json') or {}
  speakerNames = {}
  for _, sp in ipairs(chat.speakers or {}) do speakerNames[sp.id] = sp.name end
  data = jsonReadFile(jobsPath) or {}
  data.settings = data.settings or {}
  data.types = data.types or {}
  data.cargo = data.cargo or {}
end

local function cfg()
  if not data then M.loadData() end
  local s = data.settings
  return setmetatable({}, { __index = function(_, k) if s[k] ~= nil then return s[k] end return defaults[k] end })
end

local function typeCfg(kind)
  if not data then M.loadData() end
  local t = data.types[kind] or {}
  local d = typeDefaults[kind] or {}
  return setmetatable({}, { __index = function(_, k) if t[k] ~= nil then return t[k] end return d[k] end })
end

local function loc(v) return progress().loc(v) end
local function toVec(t) return vec3(t[1], t[2], t[3]) end

local function hashStr(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

local function seeded(seed)
  local x = seed % 2147483647
  if x <= 0 then x = x + 2147483646 end
  return function(a, b)
    x = (x * 16807) % 2147483647
    local f = (x - 1) / 2147483646
    if not a then return f end
    return a + math.floor(f * (b - a + 1))
  end
end

-- Ziele der Karte ---------------------------------------------------------------------

local function spots()
  local c = core()
  local md = c.mapData or {}
  local out = {}
  for _, a in ipairs(md.parkingAreas or {}) do
    if type(a.pos) == 'table' and a.type ~= 'home' and a.type ~= 'garage' and not a.footOnly then
      table.insert(out, { name = c.t('pa.' .. a.type), pos = a.pos, kind = a.type })
    end
  end
  for _, n in ipairs(md.napSpots or {}) do
    if type(n.pos) == 'table' then table.insert(out, { name = n.name, pos = n.pos, kind = 'pa' }) end
  end
  for _, j in ipairs(md.jobSpots or {}) do
    if type(j.pos) == 'table' then table.insert(out, { name = loc(j.name) ~= '' and loc(j.name) or 'Ziel', pos = j.pos, kind = 'job' }) end
  end
  return out
end

local function playerPos()
  local c = core()
  local veh = c.getPlayerVehicle()
  if veh then return veh:getPosition() end
  return c.getWalkerPos()
end

-- Spielstand --------------------------------------------------------------------------

local function state(save)
  save = save or core().save
  save.jobs = save.jobs or {}
  local j = save.jobs
  j.done = j.done or {}
  j.count = j.count or 0
  j.earned = j.earned or 0
  return j
end

local function rankFactor(save)
  return 1 + (progress().rankIndex(save) or 0) * cfg().rankBonus
end

local function round100(v) return math.floor(v / 100 + 0.5) * 100 end

-- Aufträge des Tages (fest pro Tag und Spielstand, damit Neuladen nichts ändert)
local function buildOffers(save)
  local j = state(save)
  local day = save.day or 1
  if j.day == day and j.offers then return j.offers end
  j.day, j.offers, j.done = day, {}, {}
  local rand = seeded(hashStr(tostring(save.dealerSeed or 1) .. ':jobs:' .. day))
  local from = parking().find('garage')
  local origin = from and toVec(from.pos) or playerPos()
  local list = spots()
  if not origin or #list == 0 then return j.offers end
  local far = {}
  for _, s in ipairs(list) do
    local d = (toVec(s.pos) - origin):length()
    if d >= cfg().minDistance then table.insert(far, { spot = s, dist = d }) end
  end
  local paSpots = {}
  -- Foto-Spots (Dev-Menü / photoSpots): dort wird das Auto abgestellt. Ohne eigene Spots: die PAs.
  for _, e in ipairs(core().spots('photo')) do
    table.insert(paSpots, { name = loc(e.name) ~= '' and loc(e.name) or 'Foto-Spot', pos = e.pos, dir = e.dir, photoSpot = true })
  end
  if #paSpots == 0 then
    for _, s in ipairs(list) do if s.kind == 'pa' then table.insert(paSpots, s) end end
  end
  local kinds = {}
  for _, k in ipairs({ 'courier', 'express', 'fragile', 'photo' }) do
    for _ = 1, math.max(0, tonumber(typeCfg(k).weight) or 0) do table.insert(kinds, k) end
  end
  local h = home().hour() or 8
  for i = 1, cfg().offersPerDay do
    local kind = kinds[rand(1, math.max(#kinds, 1))]
    if kind == 'photo' and #paSpots == 0 then kind = 'courier' end
    if kind ~= 'photo' and #far == 0 then kind = 'photo' end
    local t = typeCfg(kind)
    local o = { id = 'j' .. day .. '_' .. i, kind = kind }
    if kind == 'photo' then
      local s = paSpots[rand(1, #paSpots)]
      local w = cfg().photoWindowHours
      -- Fenster tagsüber, frühestens eine Stunde nach jetzt
      local start = math.min(18 - w, math.max(math.floor(h) + 1, 7 + rand(0, 8)))
      o.target = { name = s.name, pos = s.pos, dir = s.dir, photoSpot = s.photoSpot or nil }
      o.window = { start, start + w }
      o.pay = round100(t.payBase * rankFactor(save) * (0.85 + rand() * 0.3))
      local subj = data.photoSubjects or {}
      o.cargo = #subj > 0 and subj[rand(1, #subj)] or nil
    else
      local f = far[rand(1, #far)]
      local km = f.dist / 1000
      o.target = { name = f.spot.name, pos = f.spot.pos }
      -- Ware erst abholen (Abholpunkt näher an der Garage), dann zum Ziel
      if cfg().pickup then
        local cands = {}
        local tpos = toVec(f.spot.pos)
        for _, s2 in ipairs(list) do
          local sp = toVec(s2.pos)
          if s2 ~= f.spot and (sp - origin):length() <= cfg().pickupMaxDistance and (sp - tpos):length() >= cfg().minDistance then
            table.insert(cands, s2)
          end
        end
        if #cands > 0 then
          local pk = cands[rand(1, #cands)]
          o.pickup = { name = pk.name, pos = pk.pos }
          km = (toVec(pk.pos) - tpos):length() / 1000
        end
      end
      o.km = math.floor(km * 10 + 0.5) / 10
      o.seconds = math.max(t.minSeconds, math.floor(km * t.secondsPerKm / 5 + 0.5) * 5)
      o.pay = round100((t.payBase + t.payPerKm * km) * rankFactor(save) * (0.9 + rand() * 0.2))
      local pool = data.cargo[kind] or data.cargo.courier or {}
      o.cargo = #pool > 0 and pool[rand(1, #pool)] or nil
    end
    o.speaker = t.speaker or (kind == 'photo' and 'photo' or (kind == 'fragile' and 'trucker' or 'courier'))
    table.insert(j.offers, o)
  end
  return j.offers
end

-- Annehmen, abbrechen, abschließen ------------------------------------------------------

local function damageYen()
  local ok, v = pcall(function() return parking().repairCost() end)
  return ok and v or 0
end

function M.isActive() return active ~= nil end

function M.canWork()
  local c = core()
  local save = c.save
  if not save or not cfg().enabled then return false, nil end
  if home().isNight() then return false, 'jobs.notNight' end
  if active then return false, 'jobs.busy' end
  if state(save).count >= cfg().maxPerDay and state(save).countDay == save.day then return false, 'jobs.dayFull' end
  return true
end

function M.accept(id)
  local c = core()
  local save = c.save
  if not save then return end
  local ok, reason = M.canWork()
  if not ok then if reason then c.msg(c.t(reason), 4) end return end
  local j = state(save)
  for _, o in ipairs(buildOffers(save)) do
    if o.id == id and not j.done[o.id] then
      if o.kind == 'photo' and (home().hour() or 0) >= o.window[2] then c.msg(c.t('jobs.photoMissed'), 4) return end
      active = { offer = o, left = o.seconds, startDamage = damageYen(), stage = o.pickup and 'pickup' or 'deliver' }
      j.done[o.id] = 'active'
      c.sound('challenge')
      local what = loc(o.cargo and o.cargo.title or '') ~= '' and loc(o.cargo.title) or c.t('jobs.type.' .. o.kind)
      if o.pickup then c.msg(c.t('jobs.acceptedPickup', what, o.pickup.name), 6)
      else c.msg(c.t('jobs.accepted', what, o.target.name), 6) end
      updateMarkers()
      log('I', logTag, 'Auftrag angenommen: ' .. o.id .. ' ' .. o.kind .. ' -> ' .. tostring(o.target.name))
      c.writeSave()
      return
    end
  end
end

local function finish(success, pay, reasonKey)
  local c = core()
  local save = c.save
  local o = active.offer
  local j = state(save)
  active = nil
  j.done[o.id] = success and 'ok' or 'fail'
  if j.countDay ~= save.day then j.countDay, j.count = save.day, 0 end
  j.count = j.count + 1
  if success then
    save.money = save.money + pay
    j.earned = j.earned + pay
    progress().bump(save, 'jobsDone')
    c.msg(c.t(reasonKey or 'jobs.done', c.economy().formatYen(pay)), 7)
    c.sound('levelUp')
  else
    progress().bump(save, 'jobsFailed')
    c.msg(c.t(reasonKey or 'jobs.failed'), 7)
  end
  log('I', logTag, 'Auftrag ' .. o.id .. (success and (' erledigt, ' .. tostring(pay) .. ' Yen') or (' geplatzt: ' .. tostring(reasonKey))))
  c.writeSave()
  pcall(function() extensions.hashiriyaBattle_story.onEvent('job', { job = o.kind, success = success }) end)
end

function M.cancel()
  if not active then return end
  finish(false, 0, 'jobs.cancelled')
end

-- Tipps ---------------------------------------------------------------------------------

-- Tipps nur zu Gegnern, die man vom Fortschritt her schon fordern könnte (Rang, Teams, Kapitel ...).
-- Uhrzeit, Auto und Teile zählen nicht: genau das verrät ja der Tipp.
local progressKeys = { minRank = true, minWins = true, minDay = true, speedTraps = true, beatenTeam = true,
  beatenTeams = true, beatenRivals = true, requires = true, storyChapter = true }
local function reachable(r, save)
  local cond = {}
  for k, v in pairs(r.conditions or {}) do if progressKeys[k] then cond[k] = v end end
  local rv = extensions.hashiriyaBattle_rivals
  local ok, met = pcall(rv.conditionsMet, cond, save)
  return ok and met
end

-- Preis steigt mit dem Rang (tipRankFactor pro Rangstufe)
local function tipPrice(r, save)
  local base = r.boss and cfg().tipPriceBoss or cfg().tipPriceWanderer
  local rank = 0
  pcall(function() rank = progress().rankIndex(save) end)
  return math.floor(base * (1 + (cfg().tipRankFactor or 0) * rank) / 1000 + 0.5) * 1000
end

local function tipList(save)
  local rv = extensions.hashiriyaBattle_rivals
  local out = {}
  for _, r in ipairs((rv.getData() or {}).rivals or {}) do
    if (r.wanderer or r.boss) and r.hint and not (save.defeated or {})[r.id] and reachable(r, save) then
      local known = save.knownHints and save.knownHints[r.id]
      table.insert(out, { id = r.id, boss = r.boss or false, known = known or false,
        price = tipPrice(r, save), name = r.name, hint = loc(r.hint), text = known and loc(r.hint) or nil })
    end
  end
  table.sort(out, function(a, b) if a.known ~= b.known then return not a.known end if a.boss ~= b.boss then return not a.boss end return a.id < b.id end)
  return out
end

function M.buyTip(id)
  local c = core()
  local save = c.save
  if not save then return end
  for _, t in ipairs(tipList(save)) do
    if t.id == id and not t.known then
      if save.money < t.price then c.msg(c.t('msg.noMoney'), 3) return end
      save.money = save.money - t.price
      home().learnHint(id)
      progress().bump(save, 'tipsBought')
      local st = extensions.hashiriyaBattle_story
      if st and st.phoneMessage then
        st.phoneMessage('tip_' .. id, 'genzo', { c.t('jobs.tipPhone1', t.name or ''), t.hint or '' })
      end
      c.msg(c.t('msg.talkHint'), 5)
      c.writeSave()
      return
    end
  end
end

-- UI ------------------------------------------------------------------------------------

local function fmtTime(s)
  s = math.max(0, math.floor(s))
  return string.format('%d:%02d', math.floor(s / 60), s % 60)
end

function M.getUiState()
  local c = core()
  local save = c.save
  if not save then return nil end
  if not data then M.loadData() end
  local eco = c.economy()
  local ok, reason = M.canWork()
  local st = { can = ok, reason = reason and c.t(reason) or nil, offers = {}, tips = {}, earned = eco.formatYen(state(save).earned) }
  local j = state(save)
  if not home().isNight() then
    for _, o in ipairs(buildOffers(save)) do
      local e = {
        id = o.id, kind = o.kind, kindText = c.t('jobs.type.' .. o.kind), pay = eco.formatYen(o.pay), target = o.target.name,
        title = o.cargo and loc(o.cargo.title) or c.t('jobs.type.' .. o.kind), text = o.cargo and loc(o.cargo.text) or nil,
        state = j.done[o.id], client = nil,
      }
      if o.kind == 'photo' and not e.state and (home().hour() or 0) >= o.window[2] then e.state = 'missed' end
      if o.kind == 'photo' then
        e.info = c.t(o.target.photoSpot and 'jobs.windowSpot' or 'jobs.window', string.format('%02d:00', o.window[1]), string.format('%02d:00', o.window[2]))
      elseif o.pickup then e.info = c.t('jobs.limitPickup', o.pickup.name, fmtTime(o.seconds), tostring(o.km))
      else e.info = c.t('jobs.limit', fmtTime(o.seconds), tostring(o.km)) end
      e.client = speakerNames[o.speaker] and loc(speakerNames[o.speaker]) or nil
      table.insert(st.offers, e)
    end
  end
  for _, t in ipairs(tipList(save)) do
    table.insert(st.tips, { id = t.id, label = c.t(t.boss and 'jobs.tipBoss' or 'jobs.tipWanderer'), price = eco.formatYen(t.price),
      known = t.known, text = t.text, afford = save.money >= t.price })
  end
  if active then st.active = M.getHudState() end
  return st
end

-- HUD-Zeile (Status-App) während eines Auftrags
function M.getHudState()
  if not active then return nil end
  local c = core()
  local o = active.offer
  local pos = playerPos()
  local goal = (active.stage == 'pickup' and o.pickup) or o.target
  local hud = { kind = o.kind, title = c.t('jobs.type.' .. o.kind), target = goal.name }
  if active.stage == 'pickup' and o.pickup then hud.title = c.t('jobs.pickupHud') hud.pickup = true end
  if pos then
    local to = toVec(goal.pos) - pos
    local d = to:length()
    hud.distText = d < 1000 and string.format('%d m', math.floor(d)) or string.format('%.1f km', d / 1000)
    local veh = c.getPlayerVehicle()
    if veh then
      local fwd = veh:getDirectionVector()
      hud.angle = math.floor(math.deg(math.atan2(fwd.x * to.y - fwd.y * to.x, fwd.x * to.x + fwd.y * to.y)) * -1 + 0.5)
    end
  end
  if o.kind == 'photo' then
    hud.timeText = string.format('%02d-%02d h', o.window[1], o.window[2])
    hud.early = active.early or nil
  elseif active.stage == 'pickup' then
    hud.timeText = fmtTime(active.left)
  else
    hud.timeText = fmtTime(active.left)
    hud.warn = active.left < 30 or nil
    local dmg = math.max(0, damageYen() - active.startDamage)
    if dmg > 0 then hud.damage = c.economy().formatYen(dmg * (typeCfg(o.kind).damageFactor or 1)) end
  end
  return hud
end

-- Laufend -------------------------------------------------------------------------------

-- Markierungen in der Welt (wie die Parkplätze) und Navi-Route zum aktuellen Ziel
local shownGoal = nil
local function clearRoute()
  pcall(function() if core_groundMarkers then core_groundMarkers.setPath(nil) end end)
end

local function setRoute(pos)
  if not cfg().navRoute then return end
  local ok = pcall(function() core_groundMarkers.setPath(toVec(pos)) end)
  if not ok then log('W', logTag, 'Navi-Route zum Auftrag konnte nicht gesetzt werden') end
end

updateMarkers = function()
  local goal, kind = nil, 'job'
  if active then
    local o = active.offer
    goal = (active.stage == 'pickup' and o.pickup) or o.target
    if o.kind == 'photo' then kind = 'photo' end
  end
  local key = goal and (tostring(active.offer.id) .. ':' .. tostring(active.stage)) or nil
  if key == shownGoal then return end
  shownGoal = key
  local pk = parking()
  if pk and pk.setExtraMarkers then
    pcall(pk.setExtraMarkers, (goal and cfg().markers) and { { id = 'job', type = kind, pos = goal.pos, dir = goal.dir } } or {})
  end
  clearRoute()
  if goal then setRoute(goal.pos) end
end
M.updateMarkers = updateMarkers

local function stoppedNear(veh, pos, radius, kmh)
  if not veh then return false end
  local d = (veh:getPosition() - toVec(pos)):length()
  return d < radius and veh:getVelocity():length() * 3.6 < kmh
end

local function photoTaken(c, o)
  c.sound('photo')
  pcall(function() guihooks.trigger('HashiriyaFlash', { kind = 'photo' }) end)
  finish(true, o.pay, 'jobs.photoDone')
end

local function onUpdate(dtReal, dtSim)
  local c = core()
  if not c or not c.active or not c.save then
    if active or shownGoal then active = nil updateMarkers() end
    return
  end
  if not active then
    if shownGoal then updateMarkers() end
    return
  end
  local o = active.offer
  local t = typeCfg(o.kind)
  if o.kind ~= 'photo' and active.stage == 'deliver' then
    if not extensions.hashiriyaBattle_home.isResting() then active.left = active.left - (dtSim or dtReal or 0) end
    if active.left <= 0 then finish(false, 0, 'jobs.late') updateMarkers() return end
  end
  timer = timer - (dtReal or 0)
  if timer > 0 then return end
  timer = 0.5
  local ok, err = pcall(function()
    updateMarkers()
    local veh = c.getPlayerVehicle()
    if o.kind == 'photo' then
      local h = home().hour() or 0
      if h >= o.window[2] then finish(false, 0, 'jobs.photoMissed') return end
      local there
      if o.target.photoSpot then
        -- eigener Foto-Spot: Auto genau dort abstellen (Fahrer darf drin bleiben oder aussteigen)
        there = stoppedNear(veh, o.target.pos, cfg().photoSpotRadius, cfg().photoStopKmh)
        if not there and not veh then
          local okL, last = pcall(function() return c.carVehId and be:getObjectByID(c.carVehId) end)
          there = okL and last and stoppedNear(last, o.target.pos, cfg().photoSpotRadius, cfg().photoStopKmh) or false
        end
      else
        local w = c.getWalkerPos()
        there = (w and (w - toVec(o.target.pos)):length() < cfg().photoRadius) or stoppedNear(veh, o.target.pos, cfg().photoRadius, cfg().photoStopKmh)
      end
      if there then
        if h >= o.window[1] then photoTaken(c, o)
        elseif not active.early then active.early = true c.msg(c.t('jobs.photoEarly', string.format('%02d:00', o.window[1])), 5) end
      end
      return
    end
    if not veh then return end
    if active.stage == 'pickup' then
      if stoppedNear(veh, o.pickup.pos, cfg().arriveRadius, cfg().arriveKmh) then
        active.stage = 'deliver'
        active.left = o.seconds
        active.startDamage = damageYen()
        c.sound('jobPickup')
        c.msg(c.t('jobs.pickedUp', o.target.name, fmtTime(o.seconds)), 6)
        log('I', logTag, 'Ware abgeholt: ' .. o.id)
        updateMarkers()
      end
      return
    end
    local dmg = math.max(0, damageYen() - active.startDamage) * (t.damageFactor or 1)
    if t.failDamageYen and dmg >= t.failDamageYen then finish(false, 0, 'jobs.broken') return end
    if stoppedNear(veh, o.target.pos, cfg().arriveRadius, cfg().arriveKmh) then
      local pay = math.max(0, round100(o.pay - dmg))
      finish(true, pay, dmg > 0 and 'jobs.doneDamage' or 'jobs.done')
    end
  end)
  if not ok then log('E', logTag, 'Auftrag: ' .. tostring(err)) end
  if not active then updateMarkers() end
end

function M.reset() active = nil updateMarkers() end

M.onUpdate = onUpdate
M.onClientEndMission = function() active = nil shownGoal = nil clearRoute() end

return M
