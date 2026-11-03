-- Hashiriya Battle: Speichern am Standort (realistisches Speichern)
--
-- Wo man beim Laden startet, hängt davon ab, WIE gespeichert wurde (save.resume.kind):
--   home    zu Hause gespeichert oder geschlafen  -> Auto in der Garagenbucht, Spieler zu Fuß zu Hause
--   garage  Auto steht in der Garagenbucht         -> wie home
--   parked  Auto angehalten, Motor aus, gespeichert -> Auto genau dort (Position, Richtung), Motor aus
--   auto    nicht ordentlich geparkt (losgefahren, Spiel einfach beendet, Absturz)
--           -> world.json saving.unsavedExit: "tow" (abgeschleppt, Gebühr, Start zu Hause)
--              oder "resume" (am letzten Zwischenstand weiter, Auto steht dort mit Motor aus)
-- Fortschritt (Geld, Teile, Siege, Uhrzeit, Schaden, Tank) wird wie bisher laufend gespeichert und geht nie verloren.
-- Nur der Standort braucht ein ordentliches Parken. Wer mit laufendem Motor speichern will, bekommt einen Gag-Hinweis.
local M = {}

local logTag = 'hashiriya'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
local function core() return extensions.hashiriyaBattle_core end
local function home() return extensions.hashiriyaBattle_home end
local function parking() return extensions.hashiriyaBattle_parking end

local defaults = {
  unsavedExit = 'tow',     -- tow | resume
  snapshotSeconds = 30,    -- so oft merkt sich das Spiel den Standort, solange nicht ordentlich geparkt
  writeSeconds = 60,       -- so oft landet der Zwischenstand auf der Platte (Absturzschutz)
  leaveRadius = 20,        -- m: so weit darf sich das Auto vom Speicherort entfernen, bevor er nicht mehr gilt
  maxSpeedKmh = 2,         -- Speichern nur im Stand
  towFineYen = 20000,      -- Abschleppen nach unsauberem Beenden: Bußgeld zusätzlich zur normalen Abschleppgebühr
  gagSeconds = 14,         -- so lange bleibt der Motor-aus-Hinweis offen
}

function M.cfg()
  local w = home() and home().world() or {}
  local s = type(w.saving) == 'table' and w.saving or {}
  local out = {}
  for k, v in pairs(defaults) do out[k] = s[k] ~= nil and s[k] or v end
  return out
end

-- Fahrzeugzustand ------------------------------------------------------------

local lastCarId = nil       -- letztes Auto, in dem der Spieler saß (zu Fuß ist das Spielerfahrzeug das Einrad)
local engine = { id = nil, off = nil, t = 0 } -- Antwort des Fahrzeug-Lua: Motor aus?
local pollTimer = 0
local pendingMark = nil    -- s bis der Speicherort nach dem Laden gesetzt wird (Spawn abwarten)

local function carVeh()
  local c = core()
  local veh = c.getPlayerVehicle()
  if veh then lastCarId = veh:getID() return veh, false end
  local id = c.carVehId or lastCarId
  local v = id and be:getObjectByID(id)
  if v and v:getJBeamFilename() ~= 'unicycle' then return v, true end
  return nil, true
end

-- Vom Fahrzeug-Lua zurückgerufen. Motor gilt als aus bei Zündung aus/Zubehör oder Drehzahl ~0 (abgewürgt, E-Auto im Stand).
function M.onEngine(vehId, ignition, rpm)
  ignition, rpm = tonumber(ignition) or 0, tonumber(rpm) or 0
  engine.id, engine.off, engine.t = vehId, (ignition <= 1 or rpm < 150), 0
end

local function pollEngine(veh)
  veh:queueLuaCommand(string.format([[
    local v = electrics.values
    obj:queueGameEngineLua('hashiriyaBattle_savepoint.onEngine(%d,' .. tostring(tonumber(v.ignitionLevel) or 0) .. ',' .. tostring(tonumber(v.rpm) or 0) .. ')')
  ]], veh:getID()))
end

-- nil = noch keine Antwort (dann nicht blockieren)
local function engineOff(veh)
  if not veh or engine.id ~= veh:getID() or engine.t > 3 then return nil end
  return engine.off
end

local function v3(t) return vec3(t[1], t[2], t[3]) end
local function arr(v) return { v.x, v.y, v.z } end

local function transformOf(veh)
  local pos = veh:getPosition()
  local dir, up = veh:getDirectionVector(), veh:getDirectionVectorUp()
  return pos, quatFromDir(dir, up), up
end

-- Speicherort setzen ------------------------------------------------------------

-- kind: home | garage | parked | auto
function M.mark(kind)
  local c = core()
  if not c.save then return end
  local veh, onFoot = carVeh()
  local r = { kind = kind, level = c.levelName }
  local old = c.save.resume
  if not veh and kind == 'auto' and old and old.pos then
    r.pos, r.rot = old.pos, old.rot -- Auto schon weg (Spiel wird beendet): letzte bekannte Stelle behalten
  elseif veh then
    local pos, rot, up = transformOf(veh)
    -- auf dem Dach / auf der Seite: Position nicht übernehmen (beim Laden stünde man sonst kopfüber)
    if kind == 'auto' and up.z < 0.5 and c.save.resume and c.save.resume.pos then
      r.pos, r.rot = c.save.resume.pos, c.save.resume.rot
    else
      r.pos, r.rot = arr(pos), { rot.x, rot.y, rot.z, rot.w }
    end
  end
  if onFoot then
    local w = c.getWalkerPos and c.getWalkerPos()
    if w then r.footPos = arr(w) end
    local okC, camDir = pcall(function() return core_camera.getForward() end)
    if okC and camDir then local d = vec3(camDir); d.z = 0; if d:length() > 0.1 then r.footDir = arr(d:normalized()) end end
  end
  r.onFoot = onFoot or nil
  c.save.resume = r
end

-- Speicherort kurz verzögert setzen (Auto wurde gerade versetzt oder gespawnt)
function M.markSoon(kind, delay)
  local c = core()
  if not c.save then return end
  c.save.resume = { kind = kind, level = c.levelName }
  pendingMark = delay or 3
end

function M.kind()
  local c = core()
  return c.save and c.save.resume and c.save.resume.kind or nil
end

-- Kann man hier und jetzt am Standort speichern?
-- reason: battle | resting | moving | engine | noCar | nil (geht)
function M.saveInfo()
  local c = core()
  if not c.active or not c.save then return nil end
  if extensions.hashiriyaBattle_battle.isBusy() then return { can = false, reason = 'battle' } end
  if home().isResting() then return { can = false, reason = 'resting' } end
  local p = parking()
  local area = p.isArrived() and p.getCurrent() or nil
  if area and (area.type == 'home' or area.type == 'garage') then return { can = true, kind = area.type } end
  local veh = carVeh()
  if not veh then return { can = false, reason = 'noCar' } end
  if veh:getVelocity():length() * 3.6 > M.cfg().maxSpeedKmh then return { can = false, reason = 'moving' } end
  if engineOff(veh) == false then return { can = false, reason = 'engine', kind = 'parked' } end
  return { can = true, kind = 'parked' }
end

-- Gag-Hinweis ---------------------------------------------------------------------

local popup = nil -- { kind = 'engine' | 'towed' | 'resumed', title, text, hint, ok, t }
local gagCount = 0

local function gagLines(t)
  local out, i = {}, 1
  while true do
    local key = 'save.gag.' .. i
    local s = t(key)
    if not s or s == key then break end
    table.insert(out, s)
    i = i + 1
  end
  return out
end

local function showPopup(kind, title, text, hint, ok, ttl)
  popup = { kind = kind, title = title, text = text, hint = hint, ok = ok, ttl = ttl or M.cfg().gagSeconds }
  core().sendUiState()
end

local function showEngineGag()
  local c = core()
  local lines = gagLines(c.t)
  gagCount = gagCount + 1
  local text = lines[1] and lines[math.random(1, #lines)] or c.t('msg.save.engine')
  -- wer es mehrmals hintereinander probiert, bekommt einen Extra-Spruch
  if gagCount >= 3 then text = c.t('save.gag.repeat') end
  showPopup('engine', c.t('save.gag.title'), text, c.t('save.gag.hint'), c.t('save.gag.ok'))
  c.sound('denied')
end

function M.closePopup() popup = nil end

function M.getUiState()
  local c = core()
  local info = M.saveInfo()
  local st = {}
  if info then
    st.can = info.can
    st.kind = info.kind
    if info.reason then st.reason = c.t('save.reason.' .. info.reason) end
    st.label = info.kind == 'parked' and c.t('menu.saveHere') or c.t('menu.save')
  end
  if popup then st.popup = { kind = popup.kind, title = popup.title, text = popup.text, hint = popup.hint, ok = popup.ok } end
  local k = M.kind()
  if k == 'auto' and M.cfg().unsavedExit == 'resume' then k = 'autoResume' end
  st.where = k and c.t('save.where.' .. k) or nil
  st.unparked = (k == 'auto' or k == 'autoResume') or nil
  return st
end

-- Menü "Speichern" -------------------------------------------------------------------

function M.manualSave()
  local c = core()
  local info = M.saveInfo()
  if not info then return end
  if not info.can then
    if info.reason == 'engine' then showEngineGag()
    else c.msg(c.t('save.reason.' .. info.reason), 4) end
    return
  end
  gagCount = 0
  popup = nil
  M.mark(info.kind)
  c.writeSave()
  c.msg(c.t('msg.saved.' .. info.kind), 5)
  log('I', logTag, 'Am Standort gespeichert: ' .. tostring(info.kind))
end

-- Laufend: Zwischenstand und "losgefahren" erkennen ------------------------------------

local snapTimer, writeTimer, checkTimer = 0, 0, 0

local function cleanKind(k) return k == 'home' or k == 'garage' or k == 'parked' end

local function update(dtReal)
  local c = core()
  if popup then
    popup.ttl = popup.ttl - dtReal
    if popup.ttl <= 0 then popup = nil end
  end
  if not c.active or not c.save or c.save.gameOver then return end
  engine.t = engine.t + dtReal
  local veh = carVeh()
  pollTimer = pollTimer - dtReal
  if veh and pollTimer <= 0 then
    pollTimer = 0.5
    pcall(pollEngine, veh)
  end
  if home().isResting() then return end
  local cfg = M.cfg()
  checkTimer = checkTimer - dtReal
  if checkTimer <= 0 and not pendingMark then
    checkTimer = 1
    local r = c.save.resume
    if r and cleanKind(r.kind) and veh and not r.pos and not pendingMark then
      M.mark(r.kind)
    elseif r and cleanKind(r.kind) and veh and r.pos then
      if (veh:getPosition() - v3(r.pos)):length() > cfg.leaveRadius then
        log('I', logTag, 'Speicherort verlassen (' .. r.kind .. '), ab jetzt Zwischenstand')
        M.mark('auto')
        snapTimer = cfg.snapshotSeconds
      end
    elseif not r then
      M.mark('auto')
    end
  end
  if M.kind() ~= 'auto' then return end
  snapTimer = snapTimer - dtReal
  if snapTimer <= 0 then
    snapTimer = cfg.snapshotSeconds
    M.mark('auto')
  end
  writeTimer = writeTimer - dtReal
  if writeTimer <= 0 then
    writeTimer = cfg.writeSeconds
    c.writeSave()
  end
end
M.update = update

-- Beim Beenden (Hauptmenü, Spiel schließen): letzten Stand merken
function M.beforeStop()
  if M.kind() == 'auto' or M.kind() == nil then pcall(M.mark, 'auto') end
end

-- Laden ---------------------------------------------------------------------------------
-- Gibt zurück, wie continueCareer das Auto hinstellen soll:
--   { mode = 'garage' }                                  wie bisher (Garagenbucht, zu Fuß zu Hause)
--   { mode = 'spot', pos, rot, onFoot, footPos, footRot } an der gespeicherten Stelle
function M.planLoad(save)
  local r = save.resume
  local c = core()
  if not r or not r.kind or r.kind == 'home' or r.kind == 'garage' then return { mode = 'garage' } end
  if r.level and c.levelName and r.level ~= c.levelName then return { mode = 'garage' } end
  if not r.pos or not r.rot then return { mode = 'garage' } end
  local plan = { mode = 'spot', pos = v3(r.pos) + vec3(0, 0, 0.3), rot = quat(r.rot[1], r.rot[2], r.rot[3], r.rot[4]), onFoot = r.onFoot }
  if r.footPos then
    plan.footPos = v3(r.footPos) + vec3(0, 0, 0.2)
    local d = r.footDir and v3(r.footDir) or vec3(0, 1, 0)
    plan.footRot = quatFromDir(d, vec3(0, 0, 1))
  end
  if r.kind == 'parked' then return plan end
  -- nicht ordentlich geparkt
  if M.cfg().unsavedExit == 'resume' then
    plan.unsaved = 'resumed'
    return plan
  end
  -- abgeschleppt: Gebühr wie beim Abschleppen aus dem Menü plus Bußgeld
  local garage = parking().find('garage')
  local cost = 0
  if garage then
    local km = (v3(r.pos) - v3(garage.pos)):length() / 1000
    local fee = parking().towCost and parking().towCost(km) or math.floor((30000 + km * 2500) / 100) * 100
    cost = fee + (tonumber(M.cfg().towFineYen) or 0)
  end
  local paid = math.min(cost, math.max(0, save.money or 0))
  save.money = (save.money or 0) - paid
  extensions.hashiriyaBattle_progress.bump(save, 'tows')
  return { mode = 'garage', unsaved = 'towed', cost = cost, paid = paid }
end

-- nach dem Spawn: Hinweis zeigen, Speicherort setzen
function M.afterLoad(plan)
  local c = core()
  snapTimer, writeTimer, checkTimer = M.cfg().snapshotSeconds, M.cfg().writeSeconds, 2
  gagCount = 0
  if plan.unsaved == 'towed' then
    local eco = c.economy()
    showPopup('towed', c.t('save.towed.title'), c.t('save.towed.text', eco.formatYen(plan.paid or 0)),
      (plan.paid or 0) < (plan.cost or 0) and c.t('save.towed.short') or c.t('save.towed.hint'), c.t('save.ok'), 20)
    c.save.resume = { kind = 'home', level = c.levelName }
  elseif plan.unsaved == 'resumed' then
    showPopup('resumed', c.t('save.resumed.title'), c.t('save.resumed.text'), c.t('save.towed.hint'), c.t('save.ok'), 14)
    c.save.resume.kind = 'parked'
  end
  -- Position für "losgefahren?" erst nehmen, wenn das Auto steht (Spawn dauert einen Moment)
  pendingMark = 3
end

local function onUpdate(dtReal)
  if pendingMark then
    pendingMark = pendingMark - dtReal
    if pendingMark <= 0 then
      pendingMark = nil
      local c = core()
      local k = M.kind() or 'home'
      if c.active and c.save then
        M.mark(k == 'auto' and 'parked' or k)
        c.writeSave()
      end
    end
  end
  update(dtReal)
end

local function onClientEndMission()
  popup, pendingMark, lastCarId = nil, nil, nil
  engine = { id = nil, off = nil, t = 0 }
end

M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission

return M
