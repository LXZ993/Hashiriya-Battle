-- Hashiriya Battle: PA-Gespräche (Alpha 0.4).
-- An den Parkplätzen der Kartendatei (napSpots, z. B. Shibaura PA) stehen Fahrer neben ihren geparkten Autos.
-- Nachts mehr, tagsüber wenige. Zu Fuß hingehen, Taste "Reden" (Standard T): Sprechblase mit Name und Porträt.
-- Was sie sagen, hängt vom Fortschritt ab: Crew-Gerüchte ab dem passenden Rang, Leader-Gerüchte wenn die Crew fast
-- geschlagen ist, Hinweise auf Wanderer und Bosse (schaltet den Hinweis im Lexikon frei), wartende Rivalen, Smalltalk.
-- Texte und Einstellungen: data/chat.json (speakers, talk, pa). Figuren = BeamNG-Fußgänger (Einrad mit Figur),
-- Porträts: art/portraits/npc/<sprecher>_<n>.svg.
local M = {}

local logTag = 'hashiriya.talk'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local chatPath = '/lua/ge/extensions/hashiriyaBattle/data/chat.json'
local up = vec3(0, 0, 1)

local function core() return extensions.hashiriyaBattle_core end
local function home() return extensions.hashiriyaBattle_home end
local function rivals() return extensions.hashiriyaBattle_rivals end
local function progress() return extensions.hashiriyaBattle_progress end

local chat = nil        -- chat.json
local speakerById = {}
local crowds = {}       -- [paIndex] = { key, npcs = { {speaker, variant, carId, figId, pos, dir, lines, talked} } }
local nearest = nil     -- Fahrer, mit dem man gerade reden kann
local convo = nil       -- laufendes Gespräch { npc, lines, index }
local checkTimer = 0
local lookTimer = 0
local pendingFace = {}  -- [figId] = { dir, tries }: Blickrichtung nach dem Spawnen setzen

-- Einstellungen ---------------------------------------------------------------------

local defaults = {
  nightCount = { 3, 6 }, dayCount = { 1, 2 }, spawnDistance = 230, despawnDistance = 330, spotRadius = 70,
  talkDistance = 2.8, lookDistance = 9, importantChance = 0.6, secondLineChance = 0.35, rankSlack = 1,
  heardWeight = 0.15, portraitVariants = 3, excludeConfigs = { 'police', 'race' },
}

local function cfg()
  local p = chat and chat.pa or {}
  return setmetatable({}, { __index = function(_, k) if p[k] ~= nil then return p[k] end return defaults[k] end })
end

function M.loadData()
  chat = jsonReadFile(chatPath) or { speakers = {}, talk = {} }
  speakerById = {}
  for _, s in ipairs(chat.speakers or {}) do speakerById[s.id] = s end
end

local function loc(v) return progress().loc(v) end

-- Zufall mit festem Startwert: dieselbe PA zeigt in derselben Nacht dieselben Leute
local function seeded(seed)
  local x = math.floor(seed) % 2147483646 + 1
  return function()
    x = (x * 16807) % 2147483647
    return (x - 1) / 2147483646
  end
end

local function hashStr(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

local function pickWeighted(list, weightOf, rand)
  local total = 0
  for _, e in ipairs(list) do total = total + math.max(weightOf(e), 0) end
  if total <= 0 then return nil end
  local r = (rand or math.random)() * total
  for _, e in ipairs(list) do
    r = r - math.max(weightOf(e), 0)
    if r <= 0 then return e end
  end
  return list[#list]
end

-- PAs der Karte ---------------------------------------------------------------------

local function paList()
  local md = core().mapData
  return md and md.talkSpots or md and md.napSpots or {}
end

local function toVec(t) return vec3(t[1], t[2], t[3]) end

-- Zeitraum: Nacht n oder Tag n. Wechselt er, stellen sich andere Leute hin (aber nie vor deinen Augen).
local function periodKey()
  local h = home()
  if h.isNight() then return 'n' .. tostring(h.nightId()) end
  return 'd' .. tostring(h.getDay and h.getDay() or (core().save and core().save.day) or 1)
end

-- Freie Parkbuchten an der PA (aus den Parkplätzen der Map, wie beim BeamNG-Parkverkehr)
local function freeSpots(center, radius)
  local park = extensions.gameplay_parking
  if not park then
    extensions.load('gameplay_parking')
    park = extensions.gameplay_parking
  end
  if not park then return {} end
  if not extensions.gameplay_city then extensions.load('gameplay_city') end
  pcall(park.getParkingSpots) -- lädt die Sites der Map, falls noch nicht geschehen
  local ok, list = pcall(park.findParkingSpots, center, 0, radius)
  if not ok or type(list) ~= 'table' then return {} end
  local vehPos = {}
  for _, v in ipairs(getAllVehicles and getAllVehicles() or {}) do
    local okP, p = pcall(function() return v:getPosition() end)
    if okP and p then table.insert(vehPos, vec3(p)) end
  end
  local out = {}
  for _, e in ipairs(list) do
    local ps = e.ps
    if ps and ps.pos and not ps.vehicle then
      local free = true
      for _, p in ipairs(vehPos) do
        if (p - ps.pos):length() < 4 then free = false; break end
      end
      if free then table.insert(out, ps) end
    end
  end
  return out
end

-- Config fürs geparkte Auto: zufällig aus den Configs des Modells, ohne Polizei, Rennwagen usw.
local function pickConfig(model, match, rand)
  local ok, m = pcall(function() return core_vehicles.getModel(model) end)
  if not ok or not m or type(m.configs) ~= 'table' then return nil end
  local keys = {}
  for key in pairs(m.configs) do
    local k = tostring(key):lower()
    local good = true
    if match and match ~= '' then
      good = k:find(match:lower(), 1, true) ~= nil
    else
      for _, bad in ipairs(cfg().excludeConfigs or {}) do
        if k:find(tostring(bad):lower(), 1, true) then good = false; break end
      end
    end
    if good then table.insert(keys, key) end
  end
  if #keys == 0 then return nil end
  table.sort(keys)
  return keys[math.floor(rand() * #keys) + 1]
end

local function paintFromColor(c)
  c = type(c) == 'table' and c or { 0.6, 0.6, 0.6 }
  local ok, p = pcall(createVehiclePaint, { x = c[1] or 0.6, y = c[2] or 0.6, z = c[3] or 0.6, w = 1 })
  return ok and p or nil
end

local occupantFaces = nil
local function randomFace(rand)
  if occupantFaces == nil then
    local ok, mod = pcall(require, 'jbeam/sections/occupantFaces')
    occupantFaces = ok and mod or false
  end
  if not occupantFaces then return nil end
  local ok, opts = pcall(occupantFaces.getFaceOptions)
  if not ok or type(opts) ~= 'table' or #opts == 0 then return nil end
  return opts[math.floor(rand() * #opts) + 1].value
end

-- Blickrichtung der Figur: Die Figur dreht sich zur "Kamera" ihres Steuer-Controllers (playerController).
local function setFacing(figId, dir)
  local fig = be:getObjectByID(figId)
  if not fig or not dir then return false end
  local d = vec3(dir.x, dir.y, 0)
  if d:length() < 0.01 then return false end
  d = d:normalized()
  local q = quatFromDir(d, up)
  fig:queueLuaCommand(string.format(
    'if controller and controller.mainController and controller.mainController.setCameraControlData then controller.mainController.setCameraControlData({cameraRotation = quat(%f, %f, %f, %f)}) end',
    q.x, q.y, q.z, q.w))
  return true
end

local function deleteObj(id)
  local o = id and be:getObjectByID(id)
  if o then pcall(function() o:delete() end) end
end

local function despawnCrowd(i)
  local cr = crowds[i]
  if not cr then return end
  for _, n in ipairs(cr.npcs) do
    if convo and convo.npc == n then convo = nil end
    deleteObj(n.figId)
    deleteObj(n.carId)
  end
  crowds[i] = nil
  nearest = nil
  log('I', logTag, 'PA-Fahrer entfernt (' .. tostring(cr.name) .. ')')
end

function M.despawnAll()
  for i in pairs(crowds) do despawnCrowd(i) end
  crowds, nearest, convo = {}, nil, nil
end

-- Figur neben der Fahrertür (rechts, japanische Autos) oder frei auf dem Platz
local function spawnFigure(n, pos, dir, rand)
  local s = speakerById[n.speaker] or {}
  local config = { model = 'unicycle', format = 2, parts = { unicycle_meshes = 'unicycle_character' } }
  local face = randomFace(rand)
  if face then config.parts.skin_character_face = face end
  local okH, h = pcall(function() return be:getSurfaceHeightBelow(pos + vec3(0, 0, 2)) end)
  if okH and h and h > -1e6 and math.abs(h - pos.z) < 3 then pos = vec3(pos.x, pos.y, h) end
  local opts = { config = config, pos = pos + vec3(0, 0, 0.1), rot = quatFromDir(dir, up), autoEnterVehicle = false,
    removeTraffic = false, canSpawnAnotherVehicleCheck = false, paint = paintFromColor(s.color) }
  local ok, fig = pcall(core_vehicles.spawnNewVehicle, 'unicycle', opts)
  if not ok or not fig then
    log('W', logTag, 'Figur nicht gespawnt: ' .. tostring(fig))
    return nil
  end
  fig.playerUsable = false
  pendingFace[fig:getID()] = { dir = dir, tries = 6 }
  return fig:getID(), pos
end

local function spawnCar(model, config, ps, rand)
  local opts = { pos = ps.pos, rot = ps.rot, autoEnterVehicle = false, removeTraffic = false,
    canSpawnAnotherVehicleCheck = false, licenseText = extensions.hashiriyaBattle_plates.random(rand) }
  if config then opts.config = config end
  local ok, veh = pcall(core_vehicles.spawnNewVehicle, model, opts)
  if not ok or not veh then
    log('W', logTag, 'PA-Auto nicht gespawnt: ' .. tostring(model) .. ' ' .. tostring(config) .. ' ' .. tostring(veh))
    return nil
  end
  local id = veh:getID()
  veh.playerUsable = false -- nicht einsteigbar
  -- sauber in die Bucht stellen (wie der BeamNG-Parkverkehr), Motor aus, Bremse fest
  pcall(function()
    ps:moveResetVehicleTo(id, false, rand() < 0.3, nil, nil, true, false, nil, { skipVehicleIntersectionCheck = true })
  end)
  pcall(function() veh:queueLuaCommand('electrics.setIgnitionLevel(0)') end)
  core().freezeCar(veh, true)
  return id
end

local function spawnCrowd(i, pa)
  local key = periodKey()
  local save = core().save
  local rand = seeded(hashStr(tostring(save and save.dealerSeed or 1) .. '|' .. key .. '|' .. tostring(pa.name or i)))
  local c = cfg()
  local night = home().isNight()
  local range = night and c.nightCount or c.dayCount
  local count = math.floor(range[1] + rand() * (range[2] - range[1] + 1))
  local center = toVec(pa.pos)
  local spots = freeSpots(center, math.min(pa.radius or c.spotRadius, c.spotRadius))
  -- Buchten mischen (fest pro Nacht)
  for k = #spots, 2, -1 do
    local j = math.floor(rand() * k) + 1
    spots[k], spots[j] = spots[j], spots[k]
  end
  local cr = { key = key, name = pa.name, npcs = {} }
  crowds[i] = cr
  local used = {}
  local spotIdx = 1
  for _ = 1, count do
    local pool = {}
    for _, s in ipairs(chat.speakers or {}) do
      if not used[s.id] and (night and (s.night or 1) or (s.day or 1)) > 0 then table.insert(pool, s) end
    end
    local s = pickWeighted(pool, function(e) return night and (e.night or 1) or (e.day or 1) end, rand)
    if not s then break end
    used[s.id] = true
    local n = { speaker = s.id, variant = math.floor(rand() * (c.portraitVariants or 3)) + 1, heard = {} }
    local cars = s.cars or {}
    if #cars > 0 and spots[spotIdx] then
      local ps = spots[spotIdx]
      spotIdx = spotIdx + 1
      local car = cars[math.floor(rand() * #cars) + 1]
      local config = pickConfig(car.model, car.match, rand)
      if not config and car.match then config = pickConfig(car.model, nil, rand) end
      n.carId = spawnCar(car.model, config, ps, rand)
      if n.carId then
        local veh = be:getObjectByID(n.carId)
        local fwd = veh and veh:getDirectionVector() or (ps.rot * vec3(0, 1, 0))
        fwd = vec3(fwd.x, fwd.y, 0):normalized()
        local right = fwd:cross(up):normalized()
        local okB, ext = pcall(function() return veh.initialNodePosBB:getExtents() end)
        local half = (okB and ext and ext.x or 1.8) / 2
        local side = rand() < 0.75 and 1 or -1 -- meist an der Fahrerseite (Rechtslenker)
        local base = veh and veh:getPosition() or ps.pos
        local okC, ctr = pcall(function() return veh:getSpawnWorldOOBB():getCenter() end)
        if okC and ctr then base = vec3(ctr) end
        local pos = base + right * side * (half + 0.9) + fwd * (rand() * 1.2 - 0.3)
        -- schaut zur Seite vom Auto weg, leicht nach vorne (als würde er warten)
        local dir = (right * side + fwd * (rand() - 0.5)):normalized()
        n.figId, n.pos = spawnFigure(n, pos, dir, rand)
        n.dir = dir
      end
    end
    if not n.carId and (#cars == 0 or #spots == 0) then
      -- ohne Auto (z. B. Parkwächter): irgendwo am Rand der PA-Mitte
      local a = rand() * math.pi * 2
      local pos = center + vec3(math.cos(a), math.sin(a), 0) * (4 + rand() * 6)
      local dir = (center - pos):normalized()
      n.figId, n.pos = spawnFigure(n, pos, dir, rand)
      n.dir = dir
    end
    if n.figId then
      table.insert(cr.npcs, n)
    else
      deleteObj(n.carId)
    end
    -- einer pro Takt, damit das Spiel beim Vorbeifahren nicht ruckelt (läuft als Coroutine)
    local co, isMain = coroutine.running()
    if co and not isMain then coroutine.yield() end
    if crowds[i] ~= cr then return end
  end
  if #spots == 0 then log('W', logTag, 'Keine freien Parkbuchten an ' .. tostring(pa.name) .. ' gefunden (Map ohne Parkplatz-Daten?), Fahrer stehen ohne Auto') end
  log('I', logTag, string.format('PA-Fahrer an %s: %d (%s, %d freie Buchten)', tostring(pa.name), #cr.npcs, key, #spots))
end

-- Was gesagt wird --------------------------------------------------------------------

local function talkHeard(save)
  save.talk = save.talk or { heard = {}, count = 0 }
  save.talk.heard = save.talk.heard or {}
  return save.talk
end

local function teamById(id)
  for _, t in ipairs((rivals().getData() or {}).teams or {}) do if t.id == id then return t end end
end
local function rivalById(id)
  for _, r in ipairs((rivals().getData() or {}).rivals or {}) do if r.id == id then return r end end
end

local function teamState(teamId, save)
  local total, beaten, leader = 0, 0, nil
  for _, r in ipairs((rivals().getData() or {}).rivals or {}) do
    if r.team == teamId then
      if r.leader then leader = r
      else
        total = total + 1
        if save.defeated[r.id] then beaten = beaten + 1 end
      end
    end
  end
  return total, beaten, leader
end

-- Rivale für die Vorlage "{name} sucht dich": wer heute fahren kann; Revanchen und Leute, die dich geschlagen haben, zuerst
local function waitingRival(save, rand)
  local list = {}
  for _, r in ipairs((rivals().getData() or {}).rivals or {}) do
    if not r.wanderer and not r.boss and rivals().isEligible(r, save) then
      local last = (save.lastBattle or {})[r.id]
      local w = 1
      if last and not last.won then w = 4 elseif save.defeated[r.id] then w = 2 end
      table.insert(list, { r = r, w = w })
    end
  end
  local e = pickWeighted(list, function(x) return x.w end, rand)
  return e and e.r or nil
end

-- Kandidaten mit Gewicht. important = Gerücht/Hinweis, sonst Smalltalk/Tipp.
local function candidates(n, save, important)
  local c = cfg()
  local heard = talkHeard(save).heard
  local rank = progress().rankIndex(save)
  local out = {}
  local function add(t, w, extra)
    if heard[t.id] then w = w * (c.heardWeight or 0) end
    if n.heard[t.id] then w = 0 end
    if w > 0 then table.insert(out, { t = t, w = w, extra = extra }) end
  end
  for _, t in ipairs(chat.talk or {}) do
    local k = t.kind
    if not important and (k == 'small' or k == 'tip') and t.speaker == n.speaker then
      add(t, k == 'tip' and (rank <= 2 and 1.5 or 0.7) or 1)
    elseif important and k == 'crew' then
      local team = teamById(t.about)
      local _, _, leader = teamState(t.about, save)
      if team and rank >= (team.minRank or 0) - (c.rankSlack or 1) and not (leader and save.defeated[leader.id]) then
        add(t, t.speaker == n.speaker and 2 or 1)
      end
    elseif important and k == 'leader' then
      local total, beaten, leader = teamState(t.about, save)
      if leader and not save.defeated[leader.id] and total > 0 and beaten >= math.max(total - 2, 1) then
        add(t, (t.speaker == n.speaker and 2 or 1) * 2)
      end
    elseif important and (k == 'wanderer' or k == 'boss') then
      local r = rivalById(t.about)
      local need = r and r.conditions and r.conditions.minRank or 0
      if r and not save.defeated[r.id] and rank >= need - (c.rankSlack or 1) then
        local known = save.knownHints and save.knownHints[r.id]
        add(t, (t.speaker == n.speaker and 2 or 1) * (known and 0.3 or 1.5) * (k == 'boss' and 0.7 or 1))
      end
    elseif important and k == 'waiting' and t.speaker == n.speaker and home().isNight() then
      add(t, 1.5)
    end
  end
  return out
end

local function speakerName(n)
  local s = speakerById[n.speaker]
  return s and loc(s.name) or ''
end

local function portraitOf(n)
  local path = '/art/portraits/npc/' .. n.speaker .. '_' .. tostring(n.variant) .. '.svg'
  if FS:fileExists(path) then return path end
  path = '/art/portraits/npc/' .. n.speaker .. '_1.svg'
  return FS:fileExists(path) and path or nil
end

-- Zeilen für ein Gespräch zusammenstellen
local function buildLines(n, save)
  local c = cfg()
  local rand = math.random
  local lines = {}
  local function push(entry)
    local t = entry.t
    local text = loc(t.text)
    local about = nil
    if t.kind == 'waiting' then
      local r = waitingRival(save, rand)
      if not r then return false end
      text = text:gsub('{name}', r.name)
    elseif t.kind == 'wanderer' or t.kind == 'boss' then
      about = t.about
    end
    table.insert(lines, { id = t.id, kind = t.kind, text = text, hint = about })
    n.heard[t.id] = true
    return true
  end
  if n.talked then
    local again = {}
    for _, t in ipairs(chat.talk or {}) do
      if t.kind == 'again' and (t.speaker == '' or t.speaker == nil or t.speaker == n.speaker) then table.insert(again, t) end
    end
    local t = again[math.random(math.max(#again, 1))]
    if t then table.insert(lines, { id = t.id, kind = 'again', text = loc(t.text) }) end
    return lines
  end
  local imp = candidates(n, save, true)
  local small = candidates(n, save, false)
  local wantImportant = #imp > 0 and math.random() < (c.importantChance or 0.6)
  if wantImportant then
    -- manchmal erst ein Satz Smalltalk, dann das Gerücht
    if #small > 0 and math.random() < (c.secondLineChance or 0.35) then
      push(pickWeighted(small, function(e) return e.w end))
    end
    for _ = 1, 3 do
      local e = pickWeighted(imp, function(x) return x.w end)
      if e and push(e) then break end
    end
  end
  if #lines == 0 and #small > 0 then
    push(pickWeighted(small, function(e) return e.w end))
    if #imp > 0 and math.random() < (c.secondLineChance or 0.35) then
      local e = pickWeighted(imp, function(x) return x.w end)
      if e then push(e) end
    end
  end
  if #lines == 0 then
    -- nichts mehr Neues: irgendein Smalltalk dieser Figur, auch schon gehörter
    for _, t in ipairs(chat.talk or {}) do
      if t.kind == 'small' and t.speaker == n.speaker then table.insert(lines, { id = t.id, kind = 'small', text = loc(t.text) }); break end
    end
  end
  return lines
end

-- Gespräch --------------------------------------------------------------------------

local function showLine()
  if not convo then return end
  local line = convo.lines[convo.index]
  if not line then return end
  local save = core().save
  -- gehört: merken, Hinweis im Lexikon freischalten
  if save then
    local th = talkHeard(save)
    th.heard[line.id] = (th.heard[line.id] or 0) + 1
    if line.hint and not (save.knownHints and save.knownHints[line.hint]) then
      home().learnHint(line.hint)
      th.hints = (th.hints or 0) + 1
      convo.newHint = true
      core().msg(core().t('msg.talkHint'), 5)
      core().sound('talkHint')
    end
  end
end

function M.startTalk(n)
  local save = core().save
  if not save or not n then return end
  local lines = buildLines(n, save)
  if #lines == 0 then return end
  convo = { npc = n, lines = lines, index = 1 }
  local th = talkHeard(save)
  th.count = (th.count or 0) + 1
  core().sound('talk')
  showLine()
  -- Figur schaut dich an
  local wpos = core().getWalkerPos()
  if wpos and n.figId and n.pos then setFacing(n.figId, wpos - n.pos) end
  core().sendUiState()
end

function M.endTalk()
  if not convo then return end
  local n = convo.npc
  n.talked = true
  convo = nil
  core().writeSave()
  core().sendUiState()
end

-- Taste "Reden": ansprechen, nächster Satz, beenden
function M.interact()
  local c = core()
  if not c or not c.active then return end
  if convo then
    convo.index = convo.index + 1
    if convo.index > #convo.lines then M.endTalk() else
      c.sound('talk')
      showLine()
      c.sendUiState()
    end
    return
  end
  if nearest then M.startTalk(nearest) end
end

function M.isTalking() return convo ~= nil end

-- UI-Daten für die Sprechblase (HashiriyaTalk)
function M.getHudState()
  local c = core()
  if convo then
    local line = convo.lines[convo.index]
    if not line then return nil end
    local last = convo.index >= #convo.lines
    return {
      talk = { text = line.text, name = speakerName(convo.npc), portrait = portraitOf(convo.npc), side = 'left', kind = 'pa',
        tag = line.hint and 'hint' or 'npc', step = convo.index, steps = #convo.lines,
        key = M.keyName(), next = c.t(last and 'talk.end' or 'talk.next'), hint = line.hint and c.t('talk.hintLearned') or nil },
    }
  end
  if nearest then
    return { prompt = { name = speakerName(nearest), key = M.keyName(), text = c.t('talk.prompt'), again = nearest.talked or nil } }
  end
  return nil
end

-- Name der Taste fürs Reden (aus der Tastenbelegung)
local keyCache, keyCacheT = nil, -100
function M.keyName()
  if os.clock() - keyCacheT < 5 then return keyCache end
  keyCacheT = os.clock()
  keyCache = 'T'
  local ok, name = pcall(function() return extensions.hashiriyaBattle_career.keyFor('hashiriyaTalk') end)
  if ok and name then keyCache = name end
  return keyCache
end

-- Laufend ---------------------------------------------------------------------------

local function onUpdate(dtReal)
  local c = core()
  if not c or not c.active or not c.save then
    if next(crowds) then M.despawnAll() end
    return
  end
  if not chat then M.loadData() end

  -- Blickrichtung nachreichen (Controller ist erst nach dem Spawnen bereit)
  for id, p in pairs(pendingFace) do
    p.wait = (p.wait or 0.6) - dtReal
    if p.wait <= 0 then
      setFacing(id, p.dir)
      p.tries = p.tries - 1
      p.wait = 0.5
      if p.tries <= 0 then pendingFace[id] = nil end
    end
  end

  checkTimer = checkTimer - dtReal
  if checkTimer > 0 then return end
  checkTimer = 0.25
  local conf = cfg()
  local wpos = c.getWalkerPos()
  local veh = c.getPlayerVehicle()
  local ppos = wpos or (veh and veh:getPosition()) or nil
  if not ppos then return end
  local busy = extensions.hashiriyaBattle_battle.isBusy()

  -- Leute an den PAs auf- und abbauen
  for i, pa in ipairs(paList()) do
    local d = (ppos - toVec(pa.pos)):length()
    local cr = crowds[i]
    if cr and (d > conf.despawnDistance or (cr.key ~= periodKey() and d > conf.spawnDistance)) then
      despawnCrowd(i)
      cr = nil
    end
    if cr and cr.job then
      local ok, err = coroutine.resume(cr.job)
      if not ok then log('E', logTag, 'PA-Fahrer aufstellen fehlgeschlagen: ' .. tostring(err)) end
      if coroutine.status(cr.job) == 'dead' then cr.job = nil end
    elseif not cr and d < conf.spawnDistance and not busy then
      local job = coroutine.create(spawnCrowd)
      local ok, err = coroutine.resume(job, i, pa)
      if not ok then log('E', logTag, 'PA-Fahrer aufstellen fehlgeschlagen: ' .. tostring(err)) end
      if crowds[i] and coroutine.status(job) ~= 'dead' then crowds[i].job = job end
    end
  end

  -- Wer steht nah genug? Fahrer drehen sich zu dir, wenn du zu Fuß näher kommst.
  nearest = nil
  if wpos then
    local best = conf.talkDistance
    lookTimer = lookTimer - 0.25
    for _, cr in pairs(crowds) do
      for _, n in ipairs(cr.npcs) do
        local fig = n.figId and be:getObjectByID(n.figId)
        if fig then
          local okP, fp = pcall(function() return vec3(fig:getPositionXYZ()) end)
          if okP and fp then n.pos = fp end
          local d = (wpos - n.pos):length()
          if d < best then best, nearest = d, n end
          if lookTimer <= 0 and d < conf.lookDistance then setFacing(n.figId, wpos - n.pos)
          elseif lookTimer <= 0 and n.looking and d >= conf.lookDistance then setFacing(n.figId, n.dir) end
          if lookTimer <= 0 then n.looking = d < conf.lookDistance end
        end
      end
    end
    if lookTimer <= 0 then lookTimer = 0.75 end
  end
  -- Weggehen oder einsteigen beendet das Gespräch
  if convo then
    local n = convo.npc
    if not wpos or not n.pos or (wpos - n.pos):length() > conf.talkDistance + 2.5 then M.endTalk() end
  end
end

local function onClientEndMission() M.despawnAll() end
local function onExtensionUnloaded() M.despawnAll() end

-- Entwickler: Leute neu aufstellen
function M.respawn()
  M.loadData()
  M.despawnAll()
  checkTimer = 0
end

M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission
M.onExtensionUnloaded = onExtensionUnloaded

return M
