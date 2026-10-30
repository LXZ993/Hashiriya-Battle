-- Hashiriya Battle: Brücke zum eigenen Gegner-Fahrer (lua/vehicle/extensions/hashiriyaDriver.lua)
-- Leitet aus rivals.json die Fahrer-Werte ab (Können, Mut, Aggression, Nerven, Fairness),
-- startet und stoppt den Fahrer im Gegnerauto und schickt ihm den Rennstand.
local M = {}

local logTag = 'hashiriya'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/driver.json'
local data = nil
local failed = {}   -- vehId -> Grund, wenn der Fahrer dort aufgegeben hat
local running = {}  -- vehId -> true
local sendTimer = 0

local function clamp(x, a, b) return math.min(math.max(x, a), b) end

function M.loadData()
  data = jsonReadFile(dataPath) or {}
  return data
end

local function settings()
  if not data then M.loadData() end
  return data
end

-- fester Zufall pro Rivale (immer gleich für dieselbe ID), -1..1
local function jitter(id, salt)
  local h = 0
  local s = tostring(id) .. (salt or '')
  for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
  return (h % 2001) / 1000 - 1
end

local function maxTeamRank()
  local r = extensions.hashiriyaBattle_rivals
  local d = r and r.getData and r.getData() or {}
  local m = 1
  for _, t in ipairs(d.teams or {}) do m = math.max(m, t.minRank or 0) end
  return m, d.teams or {}
end

-- Fahrer-Werte eines Rivalen. Reihenfolge: Grundwert nach Stufe -> driver.json "tiers" -> rivals.json "driver"
function M.profile(rival)
  local st = settings()
  local tiers = st.tiers or {}
  local id = rival.id or rival.name or '?'
  local aggr = rival.aggression or 0.6
  local tier = rival.boss and 'boss' or (rival.leader and 'leader' or (rival.wanderer and 'wanderer' or 'rival'))
  local skill
  if tier == 'boss' then
    skill = 0.95
  elseif tier == 'wanderer' then
    skill = 0.8 + 0.1 * jitter(id, 's')
  else
    -- Crews: je höher der Rang der Crew, desto besser die Fahrer
    local maxRank, teams = maxTeamRank()
    local rank = 0
    for _, t in ipairs(teams) do if t.id == rival.team then rank = t.minRank or 0 end end
    skill = 0.3 + 0.45 * (rank / maxRank) + 0.05 * jitter(id, 's')
    if tier == 'leader' then skill = skill + 0.15 end
  end
  if rival.rematch then skill = skill + 0.05 end
  local p = {
    skill = skill,
    courage = aggr,
    aggression = aggr,
    nerves = skill * 0.8 + 0.15 * jitter(id, 'n'),
    fairness = 0.8,
    boss = rival.boss and true or false,
  }
  -- Stufenwerte aus driver.json (z. B. alle Bosse etwas mutiger)
  local t = tiers[tier]
  if type(t) == 'table' then
    for k, v in pairs(t) do if type(v) == 'number' then p[k] = (p[k] or 0) + v end end
  end
  -- Feste Werte pro Rivale aus rivals.json ("driver": { "fairness": 0.2, ... })
  if type(rival.driver) == 'table' then
    for k, v in pairs(rival.driver) do p[k] = v end
  end
  for _, k in ipairs({ 'skill', 'courage', 'aggression', 'nerves', 'fairness' }) do p[k] = clamp(p[k], 0, 1) end
  return p
end

local function luaTable(t)
  local parts = {}
  for k, v in pairs(t) do
    if type(v) == 'number' then parts[#parts + 1] = string.format('%s=%.4f', k, v)
    elseif type(v) == 'boolean' then parts[#parts + 1] = k .. '=' .. tostring(v)
    elseif type(v) == 'string' then parts[#parts + 1] = string.format('%s=%q', k, v) end
  end
  return '{' .. table.concat(parts, ',') .. '}'
end

function M.enabled()
  return settings().enabled ~= false
end

function M.hasFailed(vehId) return failed[vehId] ~= nil end

-- Fahrer im Gegnerauto starten (BeamNG-KI aus)
function M.start(veh, rival, playerId)
  local id = veh:getID()
  failed[id] = nil
  local p = M.profile(rival)
  p.targetId = playerId or -1
  -- Feineinstellungen aus driver.json (gleiche Namen wie defaults im Fahrer)
  for k, v in pairs(settings().params or {}) do p[k] = v end
  if settings().debug then p.debug = true end
  veh:queueLuaCommand("ai.setMode('disabled') extensions.load('hashiriyaDriver') if hashiriyaDriver then hashiriyaDriver.start(" .. luaTable(p) .. ") end")
  running[id] = true
  sendTimer = 0
  log('I', logTag, string.format('Eigener Fahrer für %s: Können %.2f, Mut %.2f, Aggression %.2f, Nerven %.2f, Fairness %.2f',
    tostring(rival.id), p.skill, p.courage, p.aggression, p.nerves, p.fairness))
end

-- Rennstand schicken (2x pro Sekunde): gap > 0 = Rivale vorne, SP-Anteile 0..1
function M.update(dt, veh, gap, rivalSp, playerSp)
  if not running[veh:getID()] then return end
  sendTimer = sendTimer - dt
  if sendTimer > 0 then return end
  sendTimer = 0.5
  veh:queueLuaCommand(string.format('if hashiriyaDriver then hashiriyaDriver.setRace({gap=%.1f,ownSp=%.3f,otherSp=%.3f}) end', gap, rivalSp, playerSp))
end

function M.stop(veh)
  if not veh then return end
  local id = veh:getID()
  if not running[id] then return end
  running[id] = nil
  veh:queueLuaCommand('if hashiriyaDriver then hashiriyaDriver.stop() end')
end

function M.isRunning(vehId) return running[vehId] == true end

-- Meldung aus dem Fahrzeug: Fahrer gibt auf (z. B. keine Straßendaten) -> Battle nimmt die alte KI
local function onHashiriyaDriverFailed(vehId, reason)
  failed[vehId] = reason or '?'
  running[vehId] = nil
  log('W', logTag, 'Eigener Fahrer aufgegeben (' .. tostring(vehId) .. '): ' .. tostring(reason) .. ' -> BeamNG-KI übernimmt')
end

M.onHashiriyaDriverFailed = onHashiriyaDriverFailed

return M
