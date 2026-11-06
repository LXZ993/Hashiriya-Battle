-- Hashiriya Battle: Befreien (festgehangen an Leitplanken, Mauern, Objekten)
--
-- Auf der C1-Karte sind manche Leitplanken und Objekte nicht ganz fest: Auto oder Bob zu Fuß bleiben darin
-- hängen wie an einem Magneten. "Befreien" (Taste, Standard Shift+U, oder Kachel im Menü links) setzt den
-- Spieler ein Stück auf dem eigenen Weg zurück, dorthin, wo er vorher schon frei gefahren oder gelaufen ist.
--
-- Wie es funktioniert:
--   * Laufend werden die letzten Stellen gemerkt (alle sampleMeters ein Punkt, bis keepMeters Weg),
--     nur wenn das Auto aufrecht steht. Ein Sprung > jumpMeters (Abschleppen, Laden, Shop) löscht die Spur.
--   * Befreien setzt auf den Punkt, der backMeters[1] Meter (Weg) zurück liegt, mit der damaligen Richtung,
--     etwas angehoben und ohne Schwung. Schaden und Tank bleiben, es wird nichts repariert.
--   * Hängt man danach immer noch (nochmal gedrückt innerhalb von chainSeconds, kaum bewegt),
--     geht es weiter zurück: backMeters[2], [3] ...
--
-- Sperren gegen Ausnutzen: nicht im Battle (auch nicht Countdown/Ergebnis), nicht im Gespräch, nicht beim
-- Schlafen, nicht im Shop; nur langsam (maxSpeedKmh); nicht wenn das Auto auf dem Dach/der Seite liegt
-- (das ist ein Fall fürs Abschleppen); Wartezeit cooldownSeconds zwischen zwei Benutzungen.
-- Einstellungen: data/world.json "unstuck".
-- Hardcore (hardcore.json unstuckPerDay, unstuckFeeYen): nur so oft pro Spieltag und gegen Servicegebühr.
-- Ein weiterer Druck, weil man noch hängt (Kette), zählt nicht extra.
local M = {}

local logTag = 'hashiriya'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
local function core() return extensions.hashiriyaBattle_core end
local function home() return extensions.hashiriyaBattle_home end

local defaults = {
  enabled = true,
  backMeters = { 0.5, 1.5, 3, 6 }, -- Weg zurück: 1. Druck, 2. Druck (hängt immer noch) ...
  cooldownSeconds = 6,       -- Wartezeit zwischen zwei Benutzungen
  chainSeconds = 45,         -- innerhalb dieser Zeit (und kaum bewegt) zählt ein neuer Druck als "hängt immer noch"
  chainMoveMeters = 4,       -- so weit darf man sich seit dem letzten Befreien bewegt haben, damit es weiter zurück geht
  maxSpeedKmh = 15,          -- nur langsam (wer schneller fährt, hängt nicht fest)
  sampleMeters = 0.25,       -- Abstand der gemerkten Punkte
  keepMeters = 40,           -- so viel Weg wird gemerkt
  jumpMeters = 25,           -- größerer Sprung zwischen zwei Messungen = versetzt (Abschleppen, Laden), Spur neu
  liftMeters = 0.25,         -- beim Absetzen so viel höher (fällt sanft auf den Boden)
  footLiftMeters = 0.4,      -- zu Fuß
}

function M.cfg()
  local w = home() and home().world() or {}
  local s = type(w.unstuck) == 'table' and w.unstuck or {}
  local out = {}
  for k, v in pairs(defaults) do out[k] = s[k] ~= nil and s[k] or v end
  if type(out.backMeters) ~= 'table' or #out.backMeters == 0 then out.backMeters = defaults.backMeters end
  return out
end

-- Spur -------------------------------------------------------------------------

local trail = {}         -- { pos, dir, up, d } neueste zuletzt; d = Weg seit Spurbeginn (m)
local trailId = nil      -- Fahrzeug-ID, zu der die Spur gehört (Auto oder Einrad zu Fuß)
local trailOnFoot = nil
local walked = 0         -- Weg gesamt (m)
local lastPos = nil      -- letzte Messung (auch wenn kein Punkt gesetzt wurde)
local sampleTimer = 0
local cooldown = 0       -- s bis wieder erlaubt
local chain = nil        -- { step, t, pos } letzte Befreiung
local clock = 0

local function playerObj()
  return getPlayerVehicle and getPlayerVehicle(0) or be:getPlayerVehicle(0)
end

local function isFoot(veh) return veh and veh:getJBeamFilename() == 'unicycle' end

local function resetTrail(id, onFoot)
  trail, trailId, trailOnFoot, walked, lastPos = {}, id, onFoot, 0, nil
end

-- Aktuelle Stelle: Position, Richtung, Oben-Vektor
local function currentSpot(veh)
  if isFoot(veh) then
    local c = core()
    local p = c.walkerPosition and c.walkerPosition(veh) or veh:getPosition()
    local d = vec3(0, 1, 0)
    local okF, cf = pcall(core_camera.getForward)
    if okF and cf then d = vec3(cf.x, cf.y, 0) end
    if d:length() < 0.01 then d = vec3(0, 1, 0) end
    return vec3(p), d:normalized(), vec3(0, 0, 1), true
  end
  return vec3(veh:getPosition()), vec3(veh:getDirectionVector()), vec3(veh:getDirectionVectorUp()), false
end

local function record(veh)
  local id = veh:getID()
  local pos, dir, up, onFoot = currentSpot(veh)
  if id ~= trailId or onFoot ~= trailOnFoot then resetTrail(id, onFoot) end
  if lastPos and (pos - lastPos):length() > M.cfg().jumpMeters then
    resetTrail(id, onFoot) -- versetzt worden (Abschleppen, Laden, Teleport): alte Spur gilt nicht mehr
  end
  lastPos = pos
  -- nur aufrecht stehende Stellen merken (auf dem Dach/der Seite wäre ein schlechter Rücksetzpunkt)
  if not onFoot and up.z < 0.7 then return end
  local last = trail[#trail]
  local cfg = M.cfg()
  if last then
    local step = (pos - last.pos):length()
    if step < cfg.sampleMeters then return end
    walked = walked + step
  end
  table.insert(trail, { pos = pos, dir = dir, up = up, d = walked })
  -- alten Weg vergessen
  while #trail > 2 and walked - trail[1].d > cfg.keepMeters do table.remove(trail, 1) end
end

-- Hardcore: Zähler und Gebühr --------------------------------------------------

local function hc() return extensions.hashiriyaBattle_hardcore end

-- nil außerhalb von Hardcore, sonst { left, perDay, fee }
local function hcInfo()
  local h = hc()
  if not h or not h.on() then return nil end
  local perDay = math.floor(tonumber(h.cfg().unstuckPerDay) or 0)
  local fee = h.price(tonumber(h.cfg().unstuckFeeYen) or 0)
  local c = core()
  local day = home() and home().getDay and home().getDay() or (c.save.day or 1)
  local u = c.save.hcUnstuck
  local used = (type(u) == 'table' and u.day == day) and (u.n or 0) or 0
  return { left = perDay > 0 and math.max(0, perDay - used) or nil, perDay = perDay, fee = fee, day = day, used = used }
end

local function chainActive(pos)
  local cfg = M.cfg()
  return chain and clock - chain.t <= cfg.chainSeconds and pos and (pos - chain.pos):length() <= cfg.chainMoveMeters
end

-- Darf man gerade? -------------------------------------------------------------

local function speedKmh(veh)
  local ok, v = pcall(function() return veh:getVelocity():length() end)
  return ok and v and v * 3.6 or 0
end

-- nil = erlaubt, sonst Grund (Sprachschlüssel)
local function blockReason(veh)
  local c = core()
  local cfg = M.cfg()
  if not cfg.enabled then return 'unstuck.reason.off' end
  if not c.active or not c.save then return 'unstuck.reason.off' end
  if not veh then return 'unstuck.reason.off' end
  local okB, busy = pcall(function() return extensions.hashiriyaBattle_battle.isBusy() end)
  if okB and busy then return 'unstuck.reason.battle' end
  local okT, talking = pcall(function() return extensions.hashiriyaBattle_talk.isTalking() end)
  if okT and talking then return 'unstuck.reason.talk' end
  local okR, resting = pcall(function() return home().isResting() end)
  if okR and resting then return 'unstuck.reason.off' end
  local okS, shop = pcall(function() return extensions.hashiriyaBattle_parking.isFootShop() end)
  if okS and shop then return 'unstuck.reason.shop' end
  if not isFoot(veh) then
    if speedKmh(veh) > cfg.maxSpeedKmh then return 'unstuck.reason.moving' end
    local okU, up = pcall(function() return veh:getDirectionVectorUp() end)
    if okU and up and up.z < 0.5 then return 'unstuck.reason.flipped' end
  end
  if cooldown > 0 then return 'unstuck.reason.cooldown' end
  local h = hcInfo()
  if h then
    local okP, pos = pcall(function() return (currentSpot(veh)) end)
    if not chainActive(okP and pos or nil) then
      if h.left and h.left <= 0 then return 'unstuck.reason.hcLimit' end
      if h.fee > 0 and (c.save.money or 0) < h.fee then return 'unstuck.reason.hcMoney' end
    end
  end
  return nil
end

-- Ziel suchen ------------------------------------------------------------------

-- Punkt auf der Spur, der mindestens back Meter Weg hinter der aktuellen Stelle liegt
local function targetFor(back, pos)
  if #trail == 0 then return nil end
  -- die aktuelle Stelle zählt als Wegende (falls seit dem letzten Punkt noch ein Stück dazukam)
  local tip = trail[#trail]
  local extra = (pos - tip.pos):length()
  local want = walked + extra - back
  for i = #trail, 1, -1 do
    local p = trail[i]
    if p.d <= want and (pos - p.pos):length() >= math.min(back, 0.3) then return p, i end
  end
  return trail[1], 1 -- Spur ist kürzer: so weit zurück wie möglich
end

local function place(veh, pos, dir, up, onFoot)
  local cfg = M.cfg()
  local p = pos + vec3(0, 0, onFoot and cfg.footLiftMeters or cfg.liftMeters)
  local rot = quatFromDir(dir, onFoot and vec3(0, 0, 1) or up)
  -- safeTeleport ohne Zurücksetzen (letzter Parameter false): Schaden und Tank bleiben
  local ok = pcall(function() spawn.safeTeleport(veh, p, rot, nil, nil, nil, nil, false) end)
  if not ok then
    ok = pcall(function() veh:setPositionRotation(p.x, p.y, p.z, rot.x, rot.y, rot.z, rot.w) end)
  end
  if ok and not onFoot then
    -- Schwung weg, sonst rutscht das Auto gleich wieder in die Leitplanke
    pcall(function() veh:applyClusterVelocityScaleAdd(veh:getRefNodeId(), 0, 0, 0, 0) end)
  end
  return ok
end

-- Befreien ---------------------------------------------------------------------

function M.unstuck()
  local c = core()
  local veh = playerObj()
  local reason = blockReason(veh)
  if reason then
    if reason == 'unstuck.reason.cooldown' then
      c.msg(c.t('msg.unstuck.wait', math.ceil(cooldown)), 2)
    elseif reason ~= 'unstuck.reason.off' then
      c.msg(c.t(reason, reason == 'unstuck.reason.hcLimit' and (hcInfo() or {}).perDay or M.cfg().maxSpeedKmh), 3)
    end
    return false
  end
  local cfg = M.cfg()
  local pos, dir, up, onFoot = currentSpot(veh)
  if veh:getID() ~= trailId or onFoot ~= trailOnFoot then resetTrail(veh:getID(), onFoot) end
  -- hängt immer noch? dann weiter zurück
  local step = 1
  local chained = chainActive(pos)
  if chained then
    step = math.min(chain.step + 1, #cfg.backMeters)
  end
  local back = tonumber(cfg.backMeters[step]) or 0.5
  local target, idx = targetFor(back, pos)
  local ok
  if target then
    ok = place(veh, target.pos, onFoot and dir or target.dir, target.up, onFoot)
    -- Spur hinter dem Ziel verwerfen (sonst landet der nächste Druck wieder vorne in der Leitplanke)
    for i = #trail, idx + 1, -1 do table.remove(trail, i) end
    walked = target.d
  else
    -- keine Spur (gerade erst gespawnt): ein Stück gegen die Blickrichtung und etwas hoch
    local d = vec3(dir.x, dir.y, 0)
    if d:length() < 0.01 then d = vec3(0, 1, 0) end
    ok = place(veh, pos - d:normalized() * back, dir, up, onFoot)
  end
  lastPos = nil
  if not ok then
    log('W', logTag, 'Befreien: Versetzen fehlgeschlagen')
    c.msg(c.t('msg.unstuck.failed'), 3)
    return false
  end
  cooldown = cfg.cooldownSeconds
  -- Position kommt nach dem Versetzen erst im nächsten Frame an: Ziel merken
  chain = { step = step, t = clock, pos = target and target.pos or pos }
  if c.save then pcall(function() extensions.hashiriyaBattle_progress.bump(c.save, 'unstucks') end) end
  log('I', logTag, string.format('Befreien: %s, Stufe %d, %.1f m zurück (Spur %d Punkte)', onFoot and 'zu Fuß' or 'Auto', step, back, #trail))
  local h = not chained and hcInfo() or nil
  if h then
    -- Hardcore: Servicegebühr abziehen und Benutzung zählen
    c.save.money = (c.save.money or 0) - h.fee
    c.save.hcUnstuck = { day = h.day, n = h.used + 1 }
    c.writeSave()
    c.msg(c.t('msg.unstuck.hcPaid', c.economy().formatYen(h.fee), h.left and (h.left - 1) or 0, h.perDay), 5)
  else
    c.msg(c.t(step > 1 and 'msg.unstuck.further' or 'msg.unstuck.done'), 2)
  end
  pcall(function() c.sound('click') end)
  return true
end

-- Für die Kachel im Menü links
function M.getUiState()
  local c = core()
  local veh = playerObj()
  if not M.cfg().enabled or not veh then return nil end
  local reason = blockReason(veh)
  local okK, key = pcall(extensions.hashiriyaBattle_career.keyFor, 'hashiriyaUnstuck')
  local text
  if reason == 'unstuck.reason.cooldown' then text = c.t('msg.unstuck.wait', math.ceil(cooldown))
  elseif reason and reason ~= 'unstuck.reason.off' then text = c.t(reason, reason == 'unstuck.reason.hcLimit' and (hcInfo() or {}).perDay or M.cfg().maxSpeedKmh) end
  local h = hcInfo()
  if h and not text then text = c.t('menu.unstuckHc', h.left or 0, h.perDay, c.economy().formatYen(h.fee)) end
  return { can = reason == nil, reason = text, key = okK and key or nil }
end

-- Hooks --------------------------------------------------------------------------

local function onUpdate(dtReal)
  clock = clock + (dtReal or 0)
  if cooldown > 0 then cooldown = math.max(0, cooldown - dtReal) end
  local c = core()
  if not c or not c.active then return end
  sampleTimer = sampleTimer - dtReal
  if sampleTimer > 0 then return end
  sampleTimer = 0.1
  local veh = playerObj()
  if veh then pcall(record, veh) end
end

local function onClientEndMission()
  resetTrail(nil, nil)
  chain, cooldown = nil, 0
end

M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission

return M
