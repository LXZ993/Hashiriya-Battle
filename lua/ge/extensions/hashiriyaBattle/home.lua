-- Hashiriya Battle: Zuhause (zu Fuß), Spieltage und Uhr
-- Zuhause: speichern, schlafen (bis zum nächsten Abend, neuer Tag), Rivalen-Lexikon, Reisen (später).
-- Ein Spieltag endet um Mitternacht oder beim Schlafen; der Autohändler hat jeden Tag neue Angebote.
-- Die Uhr läuft mit data/world.json (dayLengthMinutes echte Minuten pro Spieltag).
local M = {}

local logTag = 'hashiriya'
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
    core_environment.setTimeOfDay(tod)
  end)
  if not ok then log('W', logTag, 'Uhr stellen fehlgeschlagen: ' .. tostring(err)) end
  lastTime = timeOfDay()
end

function M.getDay()
  local save = core().save
  return save and (save.day or 1) or 1
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

function M.sleep()
  local c = core()
  if not c.save then return end
  -- Schlafen geht nur bis zum nächsten Abend: wer abends schläft, überspringt die Nacht
  local h = M.hour() or 0
  M.applyClock(M.world().wakeHour)
  -- nur wenn der nächste Abend auf einem neuen Datum liegt (nach Mitternacht oder tagsüber bleibt es derselbe Tag)
  if h >= M.world().wakeHour then newDay() end
  c.writeSave()
  c.msg(c.t('msg.slept', M.getDay()), 5)
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
      desc = hidden and pr.loc(r.hint) or pr.loc(r.desc),
      leader = r.leader or false, boss = r.boss or false,
      beaten = beaten,
    }
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
  if st.tab == 'lexicon' then st.lexicon = lexicon() end
  return st
end

-- Release-Build: Uhrzeit-Sprünge von außen (Time & Weather) rückgängig machen
local function timeLocked(c)
  return c.active and c.save and c.buildData and c.buildData.release == true and c.buildData.lockTime ~= false
end

local function onUpdate(dtReal, dtSim)
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
  -- Uhr gelegentlich prüfen (falls sie über die BeamNG-Umgebung angehalten oder verstellt wurde)
  clockCheck = clockCheck - (dtReal or 0)
  if clockCheck <= 0 then
    clockCheck = 5
    local ok, tod = pcall(function() return core_environment.getTimeOfDay() end)
    if ok and tod and (not tod.play or math.abs((tod.dayLength or 0) - M.world().dayLengthMinutes * 60) > 1) then M.applyClock() end
    if M.isNight() then extensions.hashiriyaBattle_progress.onNight(M.nightId()) end
  end
end

M.onUpdate = onUpdate

return M
