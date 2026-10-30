-- Hashiriya Battle: Zuhause (zu Fuß), Spieltage und Uhr
-- Zuhause: speichern, schlafen (bis zum nächsten Abend, neuer Tag), Rivalen-Lexikon, Reisen (später).
-- Ein Spieltag endet um Mitternacht oder beim Schlafen; der Autohändler hat jeden Tag neue Angebote.
-- Die Uhr läuft mit data/world.json (dayLengthMinutes echte Minuten pro Spieltag).
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
local worldPath = '/lua/ge/extensions/hashiriyaBattle/data/world.json'
local world = nil
local lastTime = nil       -- Tageszeit beim letzten Update (für den Tageswechsel um Mitternacht)
local clockCheck = 0

local function core() return extensions.hashiriyaBattle_core end

function M.world()
  world = world or jsonReadFile(worldPath) or {}
  world.dayLengthMinutes = world.dayLengthMinutes or 24
  world.nightFrom = world.nightFrom or 20
  world.nightTo = world.nightTo or 6
  world.startHour = world.startHour or 20
  world.wakeHour = world.wakeHour or 20
  return world
end

-- BeamNG-Tageszeit: 0 = 12 Uhr mittags, 0.5 = Mitternacht
local function timeOfDay()
  local ok, tod = pcall(function() return core_environment.getTimeOfDay() end)
  return ok and tod and tonumber(tod.time) or nil
end

local function hourOf(t) return (t * 24 + 12) % 24 end

function M.hour()
  local t = timeOfDay()
  return t and hourOf(t) or nil
end

function M.isNight()
  local h = M.hour()
  if not h then return true end
  local w = M.world()
  return h >= w.nightFrom or h < w.nightTo
end

-- Nummer der aktuellen Nacht: Abend und folgender Morgen gehören zusammen (der Tag zählt um Mitternacht hoch)
function M.nightId()
  local h = M.hour() or 0
  local day = M.getDay()
  return h < 12 and day - 1 or day
end

-- Uhr stellen und laufen lassen (ein Spieltag = dayLengthMinutes echte Minuten)
function M.applyClock(hour)
  local w = M.world()
  local ok, err = pcall(function()
    local tod = core_environment.getTimeOfDay()
    if hour then tod.time = ((hour - 12) / 24) % 1 end
    tod.play = true
    tod.dayLength = w.dayLengthMinutes * 60
    tod.dayScale = 1
    tod.nightScale = 1
    -- setTimeOfDay tut nichts, solange Umgebungsänderungen gesperrt sind
    if core_environment.canChange and not core_environment.canChange() and core_environment.enableChanges then core_environment.enableChanges(true) end
    core_environment.setTimeOfDay(tod)
  end)
  if not ok then log('W', logTag, 'Uhr stellen fehlgeschlagen: ' .. tostring(err)) end
  -- Tempo direkt am TimeOfDay-Objekt (dayScale/nightScale setzt core_environment nicht; 0 hält die Uhr an)
  pcall(function()
    for _, name in ipairs(scenetree.findClassObjects('TimeOfDay') or {}) do
      local obj = scenetree.findObject(name)
      if obj then
        obj.dayScale = 1
        obj.nightScale = 1
        obj.dayLength = w.dayLengthMinutes * 60
        obj:setField('play', 0, 'true')
      end
    end
  end)
  lastTime = timeOfDay()
end

function M.getDay()
  local save = core().save
  return save and (save.day or 1) or 1
end

-- Uhrzeit, Datum und Wochentag fürs HUD (Tag 1 = startDate aus data/world.json)
function M.clockInfo()
  local c = core()
  local t = timeOfDay()
  if not t then return nil end
  local h = hourOf(t)
  local out = { time = string.format('%02d:%02d', math.floor(h), math.floor((h % 1) * 60)), day = M.getDay(), night = M.isNight() }
  local y, m, d = tostring(M.world().startDate or '2026-04-03'):match('(%d+)-(%d+)-(%d+)')
  if y and rawget(_G, 'os') and os.time and os.date then
    local ok, stamp = pcall(os.time, { year = tonumber(y), month = tonumber(m), day = tonumber(d) + M.getDay() - 1, hour = 12 })
    if ok and stamp then
      local wd = tonumber(os.date('%w', stamp)) or 0
      out.weekday = c.t('wd.' .. wd)
      out.date = os.date('%d.%m.%Y', stamp)
      if c.lang == 'en' then out.date = os.date('%Y-%m-%d', stamp) end
    end
  end
  return out
end

function M.dayText()
  local t = timeOfDay()
  local clock = t and string.format('%02d:%02d', math.floor(hourOf(t)), math.floor((hourOf(t) % 1) * 60)) or ''
  return core().t('home.day', M.getDay()) .. (clock ~= '' and (' · ' .. clock) or '')
end

local function newDay()
  local save = core().save
  if not save then return end
  save.day = (save.day or 1) + 1
  log('I', logTag, 'Neuer Tag: ' .. save.day)
end

-- Schlafen zu Hause: tagsüber bis zum Abend (wakeHour), nachts ab sleepFrom bis zum Morgen (nightWakeHour).
-- Zwischen nightFrom und sleepFrom (20 bis 22 Uhr) geht es nicht, dann ist Battle-Zeit.
function M.sleepInfo()
  local w = M.world()
  local h = M.hour() or 0
  local from, nightFrom = w.sleepFrom or 22, w.nightFrom or 20
  local morning = w.nightWakeHour or 6
  if h >= nightFrom and h < from then return { can = false, wake = from, reason = 'early' } end
  if h >= from or h < morning then return { can = true, wake = morning, newDay = h >= from } end
  return { can = true, wake = w.wakeHour or 20, newDay = false }
end

-- Ruhephase (Schlafen/Nickerchen): Bildschirm wird schwarz, die Uhr läuft im Zeitraffer bis zur Aufwachzeit,
-- dann wird es wieder hell. Dauer: world.json restSeconds { nap, home }. Währenddessen sind Menü-Aktionen gesperrt.
local rest = nil
local restFade = 1 -- Sekunden für Ab- und Aufblenden

function M.isResting() return rest ~= nil end

local function fadeScreen() return rawget(_G, 'ui_fadeScreen') or extensions.ui_fadeScreen end

local function freezePlayer(on)
  local veh = core().getPlayerVehicle()
  if veh then veh:queueLuaCommand('controller.setFreeze(' .. (on and 1 or 0) .. ')') end
end

local function startRest(kind, fromHour, toHour, isNewDay, doneMsg)
  local secs = M.world().restSeconds or {}
  rest = { kind = kind, from = fromHour, to = toHour, newDay = isNewDay, msg = doneMsg,
           black = math.max(1, tonumber(secs[kind]) or (kind == 'home' and 20 or 10)), t = 0 }
  pcall(extensions.hashiriyaBattle_rivals.despawnActive)
  if kind == 'nap' then freezePlayer(true) end
  local fs = fadeScreen()
  if fs and fs.start then pcall(fs.start, restFade) end
  log('I', logTag, string.format('Ruhephase %s: %.2f -> %.2f Uhr (%d s schwarz)', kind, fromHour, toHour % 24, rest.black))
end

local function finishRest()
  local r = rest
  rest = nil
  M.applyClock(r.to % 24)
  if r.newDay then newDay() end
  local c = core()
  c.writeSave()
  if r.kind == 'nap' then freezePlayer(false) end
  local fs = fadeScreen()
  if fs and fs.stop then pcall(fs.stop, restFade) end
  if r.msg then c.msg(r.msg(), 5) end
end

-- Zeitraffer: erst abblenden, dann die Uhr bis zur Aufwachzeit drehen (weich ein- und auslaufend)
local function updateRest(dtReal)
  rest.t = rest.t + (dtReal or 0)
  local p = math.min(1, math.max(0, (rest.t - restFade) / rest.black))
  local e = p * p * (3 - 2 * p)
  if p > 0 then M.applyClock((rest.from + (rest.to - rest.from) * e) % 24) end
  if p >= 1 then finishRest() end
end

function M.sleep()
  local c = core()
  if not c.save or rest then return end
  local info = M.sleepInfo()
  if not info.can then
    c.msg(c.t('msg.sleepEarly', string.format('%02d:00', info.wake)), 4)
    return
  end
  local h = M.hour() or 0
  local to = info.wake
  if to <= h then to = to + 24 end
  startRest('home', h, to, info.newDay, function() return c.t('msg.slept', M.getDay()) end)
end

-- Nickerchen im Auto auf einem Parkplatz (napSpots der Kartendatei, sonst an jedem Parkplatz): 0,5 bis 2 h
local napMaxSpeed = 1

local function napSpotNear(pos)
  local md = core().mapData or {}
  for _, sp in ipairs(md.napSpots or {}) do
    if (pos - vec3(sp.pos[1], sp.pos[2], sp.pos[3])):length() <= (sp.radius or 60) then return sp end
  end
  for _, a in ipairs(md.parkingAreas or {}) do
    if not a.footOnly and (pos - vec3(a.pos[1], a.pos[2], a.pos[3])):length() <= 40 then return a end
  end
  return nil
end

function M.napInfo()
  local c = core()
  local veh = c.getPlayerVehicle()
  if not veh or not c.save then return nil end
  local reason = nil
  if not napSpotNear(veh:getPosition()) then reason = 'notHere'
  elseif extensions.hashiriyaBattle_battle.isBusy() then reason = 'battle'
  elseif veh:getVelocity():length() > napMaxSpeed then reason = 'moving' end
  return { can = reason == nil, reason = reason }
end

function M.nap()
  local c = core()
  if rest then return end
  local info = M.napInfo()
  if not info then return end
  if info.reason then
    c.msg(c.t('msg.nap.' .. info.reason), 3)
    return
  end
  local range = M.world().napHours or { 0.5, 2 }
  local dur = range[1] + math.random() * (range[2] - range[1])
  dur = math.floor(dur * 4 + 0.5) / 4 -- auf Viertelstunden
  local h = M.hour() or 0
  local hh, mm = math.floor(dur), math.floor((dur % 1) * 60 + 0.5)
  startRest('nap', h, h + dur, h + dur >= 24, function()
    return c.t('msg.napped', mm > 0 and string.format('%d:%02d', hh, mm) or tostring(hh))
  end)
end

-- Merkliste: bis zu 5 Rivalen aus dem Lexikon, die man suchen oder schlagen will (HUD zeigt sie an)
local watchMax = 5

function M.watchList()
  local save = core().save
  if not save then return {} end
  save.watch = save.watch or {}
  return save.watch
end

function M.isWatched(id)
  for _, w in ipairs(M.watchList()) do if w == id then return true end end
  return false
end

function M.toggleWatch(id)
  local c = core()
  local list = M.watchList()
  for i, w in ipairs(list) do
    if w == id then table.remove(list, i); return end
  end
  if #list >= watchMax then
    c.msg(c.t('msg.watchFull', watchMax))
    return
  end
  table.insert(list, id)
end

function M.unwatch(id)
  local list = M.watchList()
  for i, w in ipairs(list) do if w == id then table.remove(list, i); return true end end
  return false
end

-- Hinweis zu einem Wanderer/Boss: erst sichtbar, wenn man davon gehört hat (save.knownHints, später durch PA-Gespräche)
local function hintText(r, save)
  local pr = extensions.hashiriyaBattle_progress
  if save and save.knownHints and save.knownHints[r.id] then return pr.loc(r.hint) end
  return core().t('home.hintUnknown')
end
M.hintText = hintText

function M.learnHint(id)
  local save = core().save
  if not save or not id then return end
  save.knownHints = save.knownHints or {}
  save.knownHints[id] = true
end

-- Für das HUD: Name (oder Hinweis, solange unbekannt), Farbe nach Art
function M.watchHud()
  local list = M.watchList()
  if #list == 0 then return nil end
  local rv = extensions.hashiriyaBattle_rivals
  local pr = extensions.hashiriyaBattle_progress
  local save = core().save
  local byId = {}
  for _, r in ipairs((rv.getData() or {}).rivals or {}) do byId[r.id] = r end
  local onRoad = {}
  for _, e in ipairs(rv.getOnRoad()) do onRoad[e.data.id] = true end
  local out = {}
  for _, id in ipairs(list) do
    local r = byId[id]
    if r then
      local beaten = save.defeated and save.defeated[id]
      local hidden = (r.wanderer or r.boss) and not beaten
      table.insert(out, { id = id, name = hidden and '???' or r.name, kind = rv.markerKind(r), near = onRoad[id] or false,
        hint = hidden and hintText(r, save) or nil })
    end
  end
  return out
end

-- Rivalen-Lexikon: nach Teams sortiert; Wanderer und Bosse erst nach dem Sieg mit Namen, vorher nur ein Hinweis
local function lexicon()
  local c = core()
  local save = c.save
  local rv = extensions.hashiriyaBattle_rivals
  local pr = extensions.hashiriyaBattle_progress
  local data = rv and rv.getData and rv.getData() or {}
  local groups = {}
  local byTeam = {}
  for _, tm in ipairs(data.teams or {}) do
    local g = { name = tm.name, jp = tm.jp, color = tm.color, desc = pr.loc(tm.desc), list = {},
      locked = pr.rankIndex(save) < (tm.minRank or 0) }
    if g.locked then g.lockText = c.t('home.needRank', pr.loc((data.ranks or {})[(tm.minRank or 0) + 1] and data.ranks[(tm.minRank or 0) + 1].name)) end
    byTeam[tm.id] = g
    table.insert(groups, g)
  end
  local wanderers = { name = c.t('home.wanderer'), color = '#cfd8dc', list = {} }
  local bosses = { name = c.t('home.bosses'), color = '#ff5a36', list = {} }
  for _, r in ipairs(data.rivals or {}) do
    local beaten = save and save.defeated and save.defeated[r.id] or false
    local hidden = (r.wanderer or r.boss) and not beaten
    local e = {
      name = hidden and '???' or r.name,
      nick = hidden and '' or pr.loc(r.nick),
      car = hidden and '???' or (rv.vehicleName and rv.vehicleName(r.model) or r.model),
      desc = hidden and hintText(r, save) or pr.loc(r.desc),
      quote = (not hidden and r.lines) and pr.loc(r.lines.challenge) or nil,
      leader = r.leader or false, boss = r.boss or false,
      beaten = beaten,
      id = r.id, watched = M.isWatched(r.id),
    }
    if r.leader and not beaten and rv.leaderStatus then
      local ls = rv.leaderStatus(r, save)
      if ls then e.status = c.t('home.leader.' .. ls) end
    end
    local g = (r.boss and bosses) or (r.wanderer and wanderers) or byTeam[r.team]
    if g then table.insert(g.list, e) end
  end
  table.insert(groups, wanderers)
  table.insert(groups, bosses)
  for _, g in ipairs(groups) do
    local n = 0
    for _, e in ipairs(g.list) do if e.beaten then n = n + 1 end end
    g.count = n .. ' / ' .. #g.list
  end
  return groups
end

function M.getUiState(tab)
  local st = { tab = tab or 'main', day = M.getDay() }
  local si = M.sleepInfo()
  st.sleep = { can = si.can, wake = string.format('%02d:00', si.wake) }
  if st.tab == 'lexicon' then
    st.lexicon = lexicon()
    st.watchCount = #M.watchList()
    st.watchMax = watchMax
  end
  return st
end

-- Release-Build: Uhrzeit-Sprünge von außen (Time & Weather) rückgängig machen
local function timeLocked(c)
  return c.active and c.save and c.buildData and c.buildData.release == true and c.buildData.lockTime ~= false
end

local stallTime, stallSim = nil, 0 -- erkennt eine stehende Uhr

local function onUpdate(dtReal, dtSim)
  if rest then
    local ok, err = pcall(updateRest, dtReal)
    if not ok then
      log('E', logTag, 'Ruhephase abgebrochen: ' .. tostring(err))
      rest = nil
      freezePlayer(false)
      local fs = fadeScreen()
      if fs and fs.stop then pcall(fs.stop, restFade) end
    end
    return
  end
  local t = timeOfDay()
  if not t then return end
  local c = core()
  if lastTime and timeLocked(c) then
    local expected = (dtSim or dtReal or 0) / (M.world().dayLengthMinutes * 60)
    local diff = ((t - lastTime - expected + 0.5) % 1) - 0.5
    if math.abs(diff) > 0.005 then -- mehr als ~7 Spielminuten daneben
      log('I', logTag, 'Uhrzeit wurde verstellt, setze zurück')
      M.applyClock(hourOf((lastTime + expected) % 1))
      return
    end
  end
  -- Mitternacht überschritten (kleiner Sprung, nicht durch Schlafen oder Zeit-Einstellung)
  if lastTime and lastTime < 0.5 and t >= 0.5 and t - lastTime < 0.05 and c.active then newDay() end
  lastTime = t
  if not c.active or not c.save then return end
  stallSim = stallSim + (dtSim or 0)
  -- Uhr gelegentlich prüfen (falls sie über die BeamNG-Umgebung angehalten oder verstellt wurde)
  clockCheck = clockCheck - (dtReal or 0)
  if clockCheck <= 0 then
    clockCheck = 5
    local ok, tod = pcall(function() return core_environment.getTimeOfDay() end)
    if ok and tod and (not tod.play or math.abs((tod.dayLength or 0) - M.world().dayLengthMinutes * 60) > 1) then M.applyClock() end
    -- Uhr steht trotzdem (z. B. Zeitskala 0 im Time-&-Weather-Menü): neu anstoßen
    if stallSim > 4 and stallTime and t then
      local moved = (t - stallTime) % 1
      local expected = stallSim / (M.world().dayLengthMinutes * 60)
      if moved < expected * 0.25 then
        log('I', logTag, 'Uhr steht, starte sie neu')
        M.applyClock()
      end
    end
    stallTime, stallSim = t, 0
    if M.isNight() then extensions.hashiriyaBattle_progress.onNight(M.nightId()) end
  end
end

M.onUpdate = onUpdate

return M
