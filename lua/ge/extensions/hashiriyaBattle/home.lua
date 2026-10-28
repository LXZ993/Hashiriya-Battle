-- Hashiriya Battle: Zuhause (zu Fuß) und Spieltage
-- Zuhause: speichern, schlafen (bis zum nächsten Abend, neuer Tag), Rivalen-Lexikon, Reisen (später).
-- Ein Spieltag endet um Mitternacht oder beim Schlafen; der Autohändler hat jeden Tag neue Angebote.
local M = {}

local logTag = 'hashiriya'
local wakeHour = 21        -- nach dem Schlafen: 21 Uhr, die Nacht beginnt
local lastTime = nil       -- Tageszeit beim letzten Update (für den Tageswechsel um Mitternacht)

local function core() return extensions.hashiriyaBattle_core end

-- BeamNG-Tageszeit: 0 = 12 Uhr mittags, 0.5 = Mitternacht
local function timeOfDay()
  local ok, tod = pcall(function() return core_environment.getTimeOfDay() end)
  return ok and tod and tonumber(tod.time) or nil
end

local function hourOf(t) return (t * 24 + 12) % 24 end

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
  local ok = pcall(function()
    local tod = core_environment.getTimeOfDay()
    tod.time = ((wakeHour - 12) / 24) % 1
    core_environment.setTimeOfDay(tod)
  end)
  if not ok then log('W', logTag, 'Tageszeit setzen fehlgeschlagen') end
  newDay()
  lastTime = timeOfDay()
  c.writeSave()
  c.msg(c.t('msg.slept', M.getDay()), 5)
end

-- Rivalen-Lexikon: besiegte Gegner mit Namen, Wanderer erst nach dem Sieg sichtbar
local function lexicon()
  local c = core()
  local save = c.save
  local list = {}
  local rv = extensions.hashiriyaBattle_rivals
  local data = rv and rv.getData and rv.getData() or {}
  local teams = {}
  for _, tm in ipairs(data.teams or {}) do teams[tm.id] = tm.name end
  for _, r in ipairs(data.rivals or {}) do
    local beaten = save and save.defeated and save.defeated[r.id] or false
    local hidden = r.wanderer and not beaten
    table.insert(list, {
      name = hidden and '???' or r.name,
      team = r.wanderer and c.t('home.wanderer') or (teams[r.team] or ''),
      car = hidden and '???' or (rv.vehicleName and rv.vehicleName(r.model) or r.model),
      leader = r.leader or false,
      beaten = beaten,
    })
  end
  return list
end

function M.getUiState(tab)
  local st = { tab = tab or 'main', day = M.getDay() }
  if st.tab == 'lexicon' then st.lexicon = lexicon() end
  return st
end

local function onUpdate()
  local t = timeOfDay()
  if not t then return end
  -- Mitternacht überschritten (kleiner Sprung, nicht durch Schlafen oder Zeit-Einstellung)
  if lastTime and lastTime < 0.5 and t >= 0.5 and t - lastTime < 0.05 and core().active then newDay() end
  lastTime = t
end

M.onUpdate = onUpdate

return M
