-- Hashiriya Battle: Rivalen laden, spawnen und im Verkehr fahren lassen
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/rivals.json'

-- Mehrere Rivalen fahren gleichzeitig im Verkehr (settings.maxOnRoad). Wer hinter einem Rivalen die Lichthupe gibt,
-- fordert genau diesen heraus. Nach dem Battle fährt der Rivale weiter (geschlagen = Revanche möglich).
local spawnMin, spawnMax = 400, 650 -- m vor dem Spieler (außer Sichtweite)
local behindMin, behindMax = 200, 400 -- m hinter dem Spieler
local stuckSeconds = 8       -- so lange fast stehen = hängt fest
local despawnDistance = 1100 -- m Abstand, ab dem ein Rivale verschwindet
local spawnCooldown = 20     -- s zwischen automatischen Spawns
local minSpawnSpeed = 40 / 3.6 -- Spieler muss mind. 40 km/h fahren

local data = nil
local onRoad = {}   -- { data = rivalData, vehId = id, spawnDir = vec3, spawnPos = vec3, age = s }
local engaged = nil -- Eintrag aus onRoad, gegen den gerade das Battle läuft
local cooldown = 10

local function core() return extensions.hashiriyaBattle_core end

-- Stufen (wie die Rückkampf-Versionen in TXR 2025): "stages" beim Rivalen in rivals.json.
-- Jede Stufe wird ein eigener Gegner <id>_s2, <id>_s3 ..., der erst kommt, wenn die Stufe davor geschlagen ist
-- und das Kapitel "chapter" (story.json) erreicht ist. Alle anderen Felder der Stufe ersetzen die der Stufe davor
-- (config, model, nick, desc, lines, auraOn, aura, auraLevel, wanderer, boss, team ...; false bei team/leader = weg).
-- Stärke relativ zur Stufe davor: spFactor (1.25), aggressionBonus (0.1), rewardFactor (1.5), repFactor (1.5).
local stageSpecial = { chapter = true, spFactor = true, aggressionBonus = true, rewardFactor = true, repFactor = true,
  conditions = true, _info = true }
local stageClearable = { team = true, leader = true, boss = true, wanderer = true, hint = true, aura = true }
local function expandStages(d)
  local out = {}
  for _, r in ipairs(d.rivals or {}) do
    table.insert(out, r)
    if type(r.stages) == 'table' then
      local prev = r
      for i, st in ipairs(r.stages) do
        if type(st) == 'table' then
          local n = i + 1
          local e = {}
          for k, v in pairs(prev) do e[k] = v end
          e.stages = nil
          -- Stufen gehören nicht mehr zur Crew (sonst zählen sie für den Leader mit); ohne Rolle werden sie Wanderer
          e.stageTeam = prev.team or prev.stageTeam
          e.team, e.leader = nil, nil
          e.hint = nil -- der Tipp der Stufe davor passt nicht mehr; eigener Tipp über "hint" in der Stufe
          e.id = r.id .. '_s' .. n
          e.baseId = r.id
          e.stageOf = r.id
          e.stage = n
          e.stagePrev = prev.id
          e.stageChapter = st.chapter
          e.stageOwnConfig = st.config ~= nil or prev.stageOwnConfig or nil
          e.maxSp = math.floor((tonumber(prev.maxSp) or 1000) * (tonumber(st.spFactor) or 1.25))
          e.aggression = math.min(1, (tonumber(prev.aggression) or 0.5) + (tonumber(st.aggressionBonus) or 0.1))
          e.cruiseKmh = (tonumber(prev.cruiseKmh) or 100) + 5
          local rf = tonumber(st.rewardFactor) or 1.5
          e.rewardUsd = math.floor((tonumber(prev.rewardUsd) or 1000) * rf)
          if tonumber(prev.rewardYen) then e.rewardYen = math.floor(tonumber(prev.rewardYen) * rf) end
          e.rep = math.floor((tonumber(prev.rep) or 30) * (tonumber(st.repFactor) or 1.5))
          for k, v in pairs(st) do
            if not stageSpecial[k] then
              if v == false and stageClearable[k] then e[k] = nil else e[k] = v end
            end
          end
          if not e.boss and not e.team then e.wanderer = true end
          -- Bedingungen: wie die Stufe davor (Uhrzeit, Auto ...), dazu Sieg über die Stufe davor und das Kapitel
          local c = {}
          for k, v in pairs(type(prev.conditions) == 'table' and prev.conditions or {}) do c[k] = v end
          for k, v in pairs(type(st.conditions) == 'table' and st.conditions or {}) do c[k] = v end
          c.beatenRivals = { prev.id }
          c.beatenTeam, c.beatenTeams = nil, nil
          c.storyChapter = st.chapter
          e.conditions = c
          table.insert(out, e)
          prev = e
        end
      end
    end
  end
  d.rivals = out
end
M._expandStages = expandStages -- für Tests

function M.loadData()
  data = jsonReadFile(dataPath) or { rivals = {}, teams = {} }
  local ok, err = pcall(expandStages, data)
  if not ok then log('E', logTag, 'Stufen: ' .. tostring(err)) end
end

function M.getData()
  if not data then M.loadData() end
  return data
end

-- "Marke Modell" für die Anzeige
function M.vehicleName(model)
  local ok, info = pcall(core_vehicles.getModel, model)
  if ok and info and info.model then
    local m = info.model
    return ((m.Brand and m.Brand ~= '') and (m.Brand .. ' ') or '') .. (m.Name or model)
  end
  return model
end

local setCruise -- weiter unten
local function entryVeh(e) return e and be:getObjectByID(e.vehId) or nil end

-- Nächster Rivale zum Spieler (für die Anzeige), bzw. der aus dem laufenden Battle
local function nearest()
  local player = core().getPlayerVehicle()
  if not player then return onRoad[1] end
  local best, bestD = nil, math.huge
  for _, e in ipairs(onRoad) do
    local veh = entryVeh(e)
    if veh then
      local d = (veh:getPosition() - player:getPosition()):length()
      if d < bestD then best, bestD = e, d end
    end
  end
  return best
end

function M.getActiveRival()
  return engaged or nearest()
end

function M.getRivalVehicle()
  return entryVeh(engaged or nearest())
end

function M.getOnRoad() return onRoad end

-- Battle beginnt gegen diesen Rivalen / ist vorbei
function M.engage(e) engaged = e end
function M.disengage(cooldown)
  local e = engaged
  engaged = nil
  local veh = entryVeh(e)
  if veh then
    -- weiterfahren, aber erst nach einer Pause wieder herausforderbar
    e.cooldown = cooldown or (data and data.settings and data.settings.rechallengeSeconds) or 60
    M.resume(e)
  end
end

-- Wer darf als Nächstes erscheinen? -----------------------------------------
-- Teams ab einem Rang, pro Nacht nur ein paar Mitglieder je Team, der Leader erst in einer späteren Nacht.
-- Wanderer und Bosse haben eigene Bedingungen (Rang, Siege, Spieltag, Uhrzeit, Auto, Tuningteil, besiegte Teams).

local function progress() return extensions.hashiriyaBattle_progress end
local function home() return extensions.hashiriyaBattle_home end

local function settings() return data.settings or {} end
function M.getSettings() return data and data.settings or {} end

local function teamById(id)
  for _, t in ipairs(data.teams or {}) do if t.id == id then return t end end
end

-- Kennzeichen (Agent's Japanese Plates Pack) und fester Lack ----------------------
-- plate.design ist ein Teil im Slot licenseplate_design_2_1 und muss in die Config; der Text kommt per licenseText.
-- paint gilt nur, wenn die Config keine Livery (paint_design) hat.
local pcCache = {}
local function readPc(path)
  if pcCache[path] == nil then pcCache[path] = jsonReadFile('/' .. tostring(path):gsub('^/', '')) or false end
  return pcCache[path] or nil
end

-- Gegner-Garage (garagetool.lua): nach dem Speichern einer Config den Zwischenspeicher leeren
function M.clearPcCache() pcCache = {} end

local function hasLivery(parts)
  for slot, part in pairs(parts or {}) do
    if type(slot) == 'string' and slot:match('paint_design$') and type(part) == 'string' and part ~= '' then return true end
  end
  return false
end

local function rivalPaint(p)
  if type(p) ~= 'table' or type(p.color) ~= 'table' then return nil end
  return {
    baseColor = { p.color[1] or 0.5, p.color[2] or 0.5, p.color[3] or 0.5, 1.2 },
    metallic = p.metallic or 0, roughness = p.roughness or 0.5, clearcoat = 1, clearcoatRoughness = 0.05,
  }
end

-- Lack aus der info_<config>.json neben der .pc (defaultMultiPaintSetup paint1..3), so wie BeamNG ihn beim
-- Speichern einer eigenen Config ablegt. Wird gebraucht, weil wir mit einer Config-Tabelle spawnen.
local function infoPaints(path)
  local dir, name = tostring(path):match('^(.*)/([^/]+)%.pc$')
  if not dir then return nil end
  local info = readPc(dir .. '/info_' .. name .. '.json')
  local setup = type(info) == 'table' and info.defaultMultiPaintSetup
  if type(setup) ~= 'table' or type(setup.paint1) ~= 'table' then return nil end
  local function one(p)
    if type(p) ~= 'table' or type(p.baseColor) ~= 'table' then return nil end
    return { baseColor = p.baseColor, metallic = p.metallic or 0, roughness = p.roughness or 0.5,
      clearcoat = p.clearcoat or 0, clearcoatRoughness = p.clearcoatRoughness or 0 }
  end
  local p1 = one(setup.paint1)
  if not p1 then return nil end
  return { p1, one(setup.paint2) or p1, one(setup.paint3) or p1 }
end

M.infoPaints = infoPaints

-- Config fürs Spawnen: Pfad, oder Tabelle mit Kennzeichen-Design und Lack. Zweiter Wert = Lacke {1,2,3} (oder nil)
local function spawnSetup(rival)
  local path = rival.config ~= '' and rival.config or nil
  local design = rival.plate and rival.plate.design
  local paint = rivalPaint(rival.paint)
  if not path or (not design and not paint) then return path, nil end
  local pc = readPc(path)
  if not pc or type(pc.parts) ~= 'table' then return path, nil end
  if paint and hasLivery(pc.parts) then paint = nil end
  local cfg = { parts = {}, vars = {}, paints = pc.paints }
  local paints = nil
  if paint then paints = { paint, paint, paint }
  elseif not pc.paints then paints = infoPaints(path); cfg.paints = paints end
  for k, v in pairs(pc.parts) do cfg.parts[k] = v end
  for k, v in pairs(pc.vars or {}) do cfg.vars[k] = v end
  if design then
    local set = false
    for k in pairs(cfg.parts) do
      if type(k) == 'string' and k:match('licenseplate_design_2_1$') then cfg.parts[k] = design; set = true end
    end
    if not set then cfg.parts.licenseplate_design_2_1 = design end
  end
  if paint then cfg.paints = paints end
  return cfg, paints
end

M.spawnSetup = spawnSetup

local function leaderOf(teamId)
  for _, r in ipairs(data.rivals) do if r.team == teamId and r.leader then return r end end
end

local function teamBeaten(teamId, save)
  local l = leaderOf(teamId)
  return l and save.defeated[l.id] or false
end

local function teamMembersDefeated(teamId, save, beforeNight)
  for _, r in ipairs(data.rivals) do
    if r.team == teamId and not r.leader then
      if not save.defeated[r.id] then return false end
      if beforeNight and (save.defeatedNight or {})[r.id] == beforeNight then return false end
    end
  end
  return true
end

local function membersBeatenTonight(teamId, save, night)
  local n = 0
  for _, r in ipairs(data.rivals) do
    if r.team == teamId and not r.leader and (save.defeatedNight or {})[r.id] == night then n = n + 1 end
  end
  return n
end

-- Leader: "appear": "sameNight" (kommt noch in derselben Nacht) oder "nextNight"; ohne Angabe gilt settings.leaderNotSameNight
local function leaderWaitsNight(rival)
  if rival.appear == 'sameNight' then return false end
  if rival.appear == 'nextNight' then return true end
  return settings().leaderNotSameNight ~= false
end

local function inHours(h, from, to)
  if from <= to then return h >= from and h < to end
  return h >= from or h < to
end

local function playerHasPart(word)
  local ok, cfg = pcall(function() return extensions.hashiriyaBattle_shop.currentConfig() end)
  if not ok or type(cfg) ~= 'table' then return false end
  word = word:lower()
  for slot, part in pairs(cfg.parts or {}) do
    if type(part) == 'string' and part ~= '' and (part:lower():find(word, 1, true)) then return true end
  end
  return false
end

local function playerModel()
  local veh = core().getPlayerVehicle()
  return veh and veh:getJBeamFilename() or nil
end

-- Erweiterte Bedingungen (04.11.2026) -------------------------------------------
local function playerConfig()
  local ok, cfg = pcall(function() return extensions.hashiriyaBattle_shop.currentConfig() end)
  if ok and type(cfg) == 'table' then return cfg end
end

local function anyPart(cfg, words)
  for _, part in pairs(cfg and cfg.parts or {}) do
    if type(part) == 'string' and part ~= '' then
      local p = part:lower()
      for _, w in ipairs(words) do if p:find(w, 1, true) then return true end end
    end
  end
  return false
end

-- Saugmotor: kein Turbo und kein Kompressor verbaut
local function isNaturallyAspirated()
  local cfg = playerConfig()
  if not cfg then return false end
  return not anyPart(cfg, { 'turbo', 'supercharger', 'twincharger', 'roots', 'centrifugal' })
end

-- Schalter: Getriebe-Teil enthält manual/sequential (keine Automatik, DCT oder CVT)
local function hasManualGearbox()
  local cfg = playerConfig()
  if not cfg then return false end
  for slot, part in pairs(cfg.parts or {}) do
    if type(slot) == 'string' and slot:lower():find('transmission', 1, true) and type(part) == 'string' and part ~= '' then
      local p = part:lower()
      if p:find('manual', 1, true) or p:find('sequential', 1, true) then return true end
    end
  end
  return false
end

-- Lackfarbe in grobe Farbnamen: red, orange, yellow, green, blue, purple, pink, white, silver, grey, black
local function colorName(col)
  if type(col) ~= 'table' then return nil end
  local r, g, b = tonumber(col[1] or col.r) or 0, tonumber(col[2] or col.g) or 0, tonumber(col[3] or col.b) or 0
  if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local sat = mx > 0 and (mx - mn) / mx or 0
  if sat < 0.18 then
    if mx > 0.85 then return 'white' elseif mx > 0.55 then return 'silver' elseif mx > 0.2 then return 'grey' else return 'black' end
  end
  local h
  if mx == r then h = ((g - b) / (mx - mn)) % 6 elseif mx == g then h = (b - r) / (mx - mn) + 2 else h = (r - g) / (mx - mn) + 4 end
  h = h * 60
  if h < 15 or h >= 340 then return 'red' elseif h < 45 then return 'orange' elseif h < 70 then return 'yellow'
  elseif h < 170 then return 'green' elseif h < 255 then return 'blue' elseif h < 300 then return 'purple' else return 'pink' end
end

local function playerPaintName()
  local cfg = playerConfig()
  local p = cfg and type(cfg.paints) == 'table' and cfg.paints[1]
  return p and colorName(p.baseColor) or nil
end
M.colorName = colorName

local function activeCarEntry(save)
  return save and save.cars and save.cars[save.activeCar or 1] or nil
end

-- Kilometerstand des aktiven Autos (höchster Teile-Kilometerstand, sonst Kaufzustand)
local function carOdometerKm(save)
  local car = activeCarEntry(save)
  if not car then return 0 end
  local best = 0
  for _, p in pairs(car.parts or {}) do
    if type(p) == 'table' and tonumber(p.o) then best = math.max(best, tonumber(p.o) / 1000) end
  end
  if best <= 0 and car.wear then best = tonumber(car.wear.odometerKm) or 0 end
  return best
end

local function statsOf(save) return save.stats or {} end

-- Werte des Autos (PS, kg) kommen asynchron aus dem Fahrzeug; fehlen sie, wird nachgefragt und die Bedingung gilt noch nicht
local function carStat(key)
  local shop = extensions.hashiriyaBattle_shop
  local st = shop and shop.getCarStats and shop.getCarStats()
  if not st then
    local now = os.clock()
    if shop and shop.requestStats and now - (M._statsAsked or -10) > 5 then M._statsAsked = now; pcall(shop.requestStats) end
    return nil
  end
  return st[key]
end

local function extraConditionsMet(c, save)
  local st = statsOf(save)
  if c.minStreak and (save.streak or 0) < c.minStreak then return false end
  if c.minMoney and (save.money or 0) < c.minMoney then return false end
  if c.minCars and #(save.cars or {}) < c.minCars then return false end
  if c.maxLosses and (save.losses or 0) > c.maxLosses then return false end
  if c.naOnly and not isNaturallyAspirated() then return false end
  if c.forcedInduction and isNaturallyAspirated() then return false end
  if c.manual and not hasManualGearbox() then return false end
  if c.noPart and playerHasPart(c.noPart) then return false end
  if c.paintColor then
    local want = type(c.paintColor) == 'table' and c.paintColor or { c.paintColor }
    local have, ok = playerPaintName(), false
    for _, w in ipairs(want) do if have == w then ok = true end end
    if not ok then return false end
  end
  if c.plateContains then
    local car = activeCarEntry(save)
    local plate = car and tostring(car.plate or '') or ''
    if not plate:find(tostring(c.plateContains), 1, true) then return false end
  end
  if c.minPower or c.maxPower then
    local ps = carStat('ps')
    if not ps then return false end
    if c.minPower and ps < c.minPower then return false end
    if c.maxPower and ps > c.maxPower then return false end
  end
  if c.minWeight or c.maxWeight then
    local kg = carStat('kg')
    if not kg then return false end
    if c.minWeight and kg < c.minWeight then return false end
    if c.maxWeight and kg > c.maxWeight then return false end
  end
  -- Antrieb: "FWD", "RWD" oder "AWD" (auch als Liste), gemessen im Auto
  if c.drive then
    local d = carStat('drive')
    if not d then return false end
    local list = type(c.drive) == 'table' and c.drive or { c.drive }
    local ok = false
    for _, w in ipairs(list) do if tostring(w):upper() == d then ok = true end end
    if not ok then return false end
  end
  if c.minOdometerKm and carOdometerKm(save) < c.minOdometerKm then return false end
  if c.maxOdometerKm and carOdometerKm(save) > c.maxOdometerKm then return false end
  if c.minTopSpeed and (st.topKmh or 0) < c.minTopSpeed then return false end
  if c.weekday then
    -- Spieltag 1 = Montag; weekday 1-7 (Mo-So) oder Liste
    local wd = ((save.day or 1) - 1) % 7 + 1
    local list = type(c.weekday) == 'table' and c.weekday or { c.weekday }
    local ok = false
    for _, d in ipairs(list) do if tonumber(d) == wd then ok = true end end
    if not ok then return false end
  end
  if c.nickname then
    local ok, nick = pcall(progress().nicknameId, save)
    if not ok or nick ~= c.nickname then return false end
  end
  if c.playerLogo and save.playerLogo ~= c.playerLogo then return false end
  -- Tage ohne Niederlage (ohne Niederlage seit Spielbeginn zählt ab Tag 1)
  if c.minDaysNoLoss and ((save.day or 1) - (save.lastLossDay or 0)) < c.minDaysNoLoss then return false end
  -- Auto fast unbeschädigt: Reparaturpreis höchstens so viel Yen
  if c.maxDamageYen then
    local okP, cost = pcall(function() return extensions.hashiriyaBattle_parking.repairCost() end)
    if not okP or (tonumber(cost) or 0) > c.maxDamageYen then return false end
  end
  -- PA besucht (zu Fuß, Name enthält den Text) bzw. Mindestanzahl besuchter PAs
  if c.visitedPa then
    local list = type(c.visitedPa) == 'table' and c.visitedPa or { c.visitedPa }
    for _, want in ipairs(list) do
      local found = false
      for name in pairs(save.paVisited or {}) do if tostring(name):lower():find(tostring(want):lower(), 1, true) then found = true end end
      if not found then return false end
    end
  end
  if c.minPaVisited then
    local n = 0
    for _ in pairs(save.paVisited or {}) do n = n + 1 end
    if n < c.minPaVisited then return false end
  end
  -- beliebige Statistik: "stat": {"key": "pinkWins", "min": 3} oder Liste davon
  if c.stat then
    local list = c.stat.key and { c.stat } or c.stat
    for _, s in ipairs(list) do
      local v = tonumber(st[s.key]) or 0
      if s.min and v < s.min then return false end
      if s.max and v > s.max then return false end
    end
  end
  return true
end

local function conditionsMet(c, save)
  if not c then return true end
  local rank = progress().rankIndex(save)
  if c.minRank and rank < c.minRank then return false end
  if c.minWins and (save.wins or 0) < c.minWins then return false end
  if c.minDay and (save.day or 1) < c.minDay then return false end
  local hours = c.hours or c.timeWindow
  if hours then
    local h = home().hour()
    if h and not inHours(h, hours[1], hours[2]) then return false end
  end
  if c.playerModel and playerModel() ~= c.playerModel then return false end
  if c.playerPart and not playerHasPart(c.playerPart) then return false end
  if c.speedTraps then
    local n, total = progress().speedTrapCount(save)
    local need = c.speedTraps == 'all' and total or tonumber(c.speedTraps)
    if not need or n < need then return false end
  end
  if c.beatenTeam and not teamBeaten(c.beatenTeam, save) then return false end
  for _, id in ipairs(c.beatenTeams or {}) do if not teamBeaten(id, save) then return false end end
  for _, id in ipairs(c.beatenRivals or c.requires or {}) do if not save.defeated[id] then return false end end
  if not extraConditionsMet(c, save) then return false end
  -- Story (Alpha 0.6): erst ab diesem Kapitel (ID aus story.json)
  if c.storyChapter then
    local st = extensions.hashiriyaBattle_story
    if st and not st.reached(c.storyChapter, save) then return false end
  end
  return true
end
M.conditionsMet = conditionsMet
M.teamBeaten = teamBeaten

local function isOnRoad(id)
  for _, e in ipairs(onRoad) do if e.data.id == id then return true end end
  return false
end
M.isOnRoad = isOnRoad

-- Rivalen, die gerade an einer PA stehen (talk.lua), tauchen nicht gleichzeitig auf der Straße auf
local reserved = {}
function M.setReserved(id, on) if id then reserved[id] = on and true or nil end end
function M.isReserved(id) return id and reserved[id] or false end

-- Auto eines Rivalen: sein eigenes, oder dein Auto, wenn er es dir im Pink Slip abgenommen hat.
-- Rückgabe: model, config (Pfad oder Tabelle), paints, Kennzeichen-Text
function M.carFor(rival)
  local save = core().save
  local held = save and save.pinkHeld and save.pinkHeld[rival.baseId or rival.id]
  if held and held.model then return held.model, held.config, nil, held.plate end
  local cfgOut, paints = spawnSetup(rival)
  return rival.model, cfgOut, paints, rival.plate and rival.plate.text
end

local function isEligible(rival, save)
  local set = settings()
  if isOnRoad(rival.id) or reserved[rival.id] then return false end
  -- Geschlagene Rivalen kommen als Revanche wieder (stärker, weniger Belohnung)
  if save.defeated[rival.id] and not (set.rematch and set.rematch.enabled) then return false end
  local night = home().nightId()
  -- jeder Rivale nur einmal pro Nacht; nach einer Niederlage eine Nacht Pause
  local last = (save.lastBattle or {})[rival.id]
  if last then
    if set.rivalOncePerNight ~= false and last.night == night then return false end
    if not last.won and night - last.night <= (set.lostRivalCooldownNights or 0) and last.night ~= night then return false end
  end
  if save.defeated[rival.id] then return true end
  if rival.team then
    local team = teamById(rival.team)
    if team and progress().rankIndex(save) < (team.minRank or 0) then return false end
    if rival.leader then
      if not teamMembersDefeated(rival.team, save, leaderWaitsNight(rival) and night or nil) then return false end
    elseif membersBeatenTonight(rival.team, save, night) >= (set.teamMembersPerNight or 99) then
      return false
    end
  end
  return conditionsMet(rival.conditions, save)
end

-- Für die PA-Gespräche: könnte dieser Rivale gerade auftauchen?
function M.isEligible(rival, save)
  save = save or core().save
  if not save or not rival then return false end
  local ok, res = pcall(isEligible, rival, save)
  return ok and res or false
end

-- Wie viele Battles diese Nacht noch gehen
function M.battlesLeftTonight()
  local save = core().save
  local max = settings().maxBattlesPerNight
  if not save or not max then return nil end
  local nb = save.nightBattles
  local used = (nb and nb.night == home().nightId()) and nb.count or 0
  return math.max(0, max - used)
end

-- Revanche: Kopie des Rivalen mit mehr Biss; Belohnung und Ruf fallen kleiner aus
local function rematchOf(r, save)
  local rm = settings().rematch or {}
  local n = ((save.rematchWins or {})[r.id] or 0)
  local copy = {}
  for k, v in pairs(r) do copy[k] = v end
  copy.rematch = true
  copy.aggression = math.min(1, (r.aggression or 0.5) + (rm.aggressionBonus or 0.08) * (1 + math.min(n, 3) * 0.5))
  copy.maxSp = math.floor((r.maxSp or 1000) * (rm.spFactor or 1.1) * (1 + math.min(n, 3) * 0.05))
  copy.cruiseKmh = (r.cruiseKmh or 100) + 5
  copy.rewardUsd = math.floor((r.rewardUsd or 1000) * (rm.rewardFactor or 0.4))
  if tonumber(r.rewardYen) then copy.rewardYen = math.floor(tonumber(r.rewardYen) * (rm.rewardFactor or 0.4)) end
  copy.rep = math.floor((r.rep or 30) * (rm.repFactor or 0.25))
  return copy
end

-- Daten fürs Battle: ein schon geschlagener Rivale auf der Straße kämpft als Revanche
function M.challengeData(e)
  local save = core().save
  if save and save.defeated[e.data.id] and not e.data.rematch then e.data = rematchOf(e.data, save) end
  return e.data
end

-- Stufen: Genzō meldet per Handy, wenn eine neue Stufe da ist (Stufe davor geschlagen, Kapitel erreicht). Einmal pro Stufe.
local function announceStages(save)
  local st = extensions.hashiriyaBattle_story
  if not st or not st.phoneMessage then return end
  save.stageAnnounced = save.stageAnnounced or {}
  for _, r in ipairs(data.rivals) do
    if r.stageOf and not save.stageAnnounced[r.id] and not save.defeated[r.id] and save.defeated[r.stagePrev]
      and (not r.stageChapter or (st.reached and st.reached(r.stageChapter, save))) then
      save.stageAnnounced[r.id] = true
      local pr = progress()
      local text = r.announce and pr.loc(r.announce) or ''
      if text == '' then text = core().t('msg.stageReturn', r.name) end
      pcall(st.phoneMessage, 'stage_' .. r.id, r.announceSpeaker or 'genzo', { text })
    end
  end
end
M.announceStages = announceStages

local function pickRival(save)
  pcall(announceStages, save)
  -- Gibt es neue Gegner, kommt meist einer davon (rematch.weight = Anteil der Revanchen); sonst eine Revanche
  -- Ein Leader, dessen Mitglieder alle geschlagen sind, kommt bevorzugt (settings.leaderChance)
  local fresh, beaten, leaders = {}, {}, {}
  for _, r in ipairs(data.rivals) do
    if isEligible(r, save) then
      table.insert(save.defeated[r.id] and beaten or fresh, r)
      if r.leader and not save.defeated[r.id] then table.insert(leaders, r) end
    end
  end
  if #leaders > 0 and math.random() < (settings().leaderChance or 0.7) then return leaders[math.random(#leaders)] end
  local rw = (settings().rematch or {}).weight or 0.25
  if #fresh > 0 and (#beaten == 0 or math.random() >= rw) then return fresh[math.random(#fresh)] end
  if #beaten > 0 then return rematchOf(beaten[math.random(#beaten)], save) end
  return nil
end

-- Spawnen -----------------------------------------------------------------------

-- Fahrtrichtung auf Einbahn-Kanten. Auf C1 passte inNode -> outNode nicht immer zur echten Fahrtrichtung,
-- deshalb lernen wir sie vom Verkehr: Wie fahren die KI-Autos auf Einbahn-Kanten? (+1 = inNode -> outNode)
local oneWaySign, oneWayVotes = nil, { plus = 0, minus = 0 }
local calibTimer = 0

local function isRivalVeh(id)
  for _, e in ipairs(onRoad) do if e.vehId == id then return true end end
  return false
end

-- Kanten im KI-Straßennetz können einseitig gespeichert sein (nur nodes[a].links[b], nicht nodes[b].links[a]),
-- daher immer in beide Richtungen nachsehen (wie map.lua selbst).
local function edgeOf(nodes, a, b)
  local na, nb = nodes[a], nodes[b]
  return (na and na.links and na.links[b]) or (nb and nb.links and nb.links[a]) or nil
end

-- Nachbarn eines Knotens, auch über einseitig gespeicherte Kanten (Rückwärts-Index, einmal pro Straßennetz)
local reverseLinks, reverseFor = nil, nil
local function neighbors(nodes, id)
  if reverseFor ~= nodes then
    reverseLinks, reverseFor = {}, nodes
    for a, n in pairs(nodes) do
      for b in pairs(n.links or {}) do
        reverseLinks[b] = reverseLinks[b] or {}
        reverseLinks[b][a] = true
      end
    end
  end
  local out = {}
  for b in pairs((nodes[id] and nodes[id].links) or {}) do out[b] = true end
  for a in pairs(reverseLinks[id] or {}) do out[a] = true end
  return out
end

local relaxOneWay = false -- Dev-Spawn: zur Not ohne Einbahn-Regeln

local function calibrateOneWay(player)
  local nodes = map.getMap().nodes
  if not nodes then return end
  local pid = player and player:getID()
  for i = 0, be:getObjectCount() - 1 do
    local o = be:getObject(i)
    if o and o:getID() ~= pid and not isRivalVeh(o:getID()) then
      local vel = o:getVelocity()
      if vel and vel:length() > 8 then
        local p = o:getPosition()
        local n1, n2, dist = map.findClosestRoad(p)
        local l = n1 and n2 and edgeOf(nodes, n1, n2)
        if l and dist and dist < 5 and l.oneWay and l.inNode and l.outNode and nodes[l.inNode] and nodes[l.outNode] then
          local d = (nodes[l.outNode].pos - nodes[l.inNode].pos):normalized():dot(vel:normalized())
          if d > 0.7 then oneWayVotes.plus = oneWayVotes.plus + 1 elseif d < -0.7 then oneWayVotes.minus = oneWayVotes.minus + 1 end
        end
      end
    end
  end
  local total = oneWayVotes.plus + oneWayVotes.minus
  if total >= 6 then
    local sign = oneWayVotes.plus >= oneWayVotes.minus and 1 or -1
    if sign ~= oneWaySign then
      log('I', logTag, string.format('Einbahn-Richtung vom Verkehr gelernt: %s (%d / %d)', sign > 0 and 'inNode->outNode' or 'outNode->inNode', oneWayVotes.plus, oneWayVotes.minus))
    end
    oneWaySign = sign
    -- weiter lernen, aber alte Stimmen langsam vergessen
    if total > 60 then oneWayVotes.plus, oneWayVotes.minus = oneWayVotes.plus * 0.5, oneWayVotes.minus * 0.5 end
  end
end

-- Darf man von `from` nach `to` fahren? nil = Richtung noch unbekannt (Einbahn, aber noch nichts gelernt)
local function linkAllowed(nodes, from, to)
  local l = edgeOf(nodes, from, to)
  if not l then return false, nil end
  if relaxOneWay or not (l.oneWay and l.inNode and l.outNode) then return true, l end
  if not oneWaySign then return nil, l end
  local forward = (l.inNode == from) == (oneWaySign > 0)
  return forward, l
end

-- Suche über die nächste Straße am Zielpunkt (Rückfall, falls das Straßennetz unterwegs endet).
-- Einbahn-Kanten in Gegenrichtung (= Gegenfahrbahn) werden abgelehnt.
local function closestRoadSpawn(pos, dir, distance)
  local target = pos + dir * distance
  local n1, n2, roadDist = map.findClosestRoad(target)
  if not n1 or not n2 then return nil, 'keine Straße am Ziel' end
  local nodes = map.getMap().nodes
  if not nodes[n1] or not nodes[n2] then return nil, 'Knoten fehlt' end
  local p1, p2 = nodes[n1].pos, nodes[n2].pos
  local seg = p2 - p1
  local segLen2 = seg:squaredLength()
  if segLen2 < 0.01 then return nil, 'Kante zu kurz' end
  local t = clamp((target - p1):dot(seg) / segLen2, 0, 1)
  -- Abstand zum nächsten Punkt auf der Kante (nicht zum Knoten: Kanten können lang sein)
  local onRoadPos = p1 + seg * t
  if (roadDist and roadDist > 25) or math.abs(onRoadPos.z - target.z) > 12 then
    return nil, string.format('Ziel neben der Straße (%.0f m)', roadDist or -1)
  end
  local a, b = n1, n2
  if seg:dot(dir) < 0 then a, b = n2, n1 end
  local ok = linkAllowed(nodes, a, b)
  if ok == nil then return nil, 'Einbahn-Richtung noch unbekannt' end
  if not ok then return nil, 'Gegenfahrbahn' end
  return p1 + seg * t + vec3(0, 0, 0.5), (nodes[b].pos - nodes[a].pos):normalized()
end

-- Läuft das Straßennetz entlang, in erlaubter Fahrtrichtung. Endet eine Straße (nicht verbundene Straßenstücke),
-- wird ein paar Meter weiter geradeaus die nächste passende Kante gesucht.
local function walkRoad(nodes, pos, dir, distance)
  local n1, n2 = map.findClosestRoad(pos)
  if not n1 or not n2 or not nodes[n1] or not nodes[n2] then return nil, 'Spieler nicht auf Straße' end
  local back = distance < 0
  local travel = back and dir * -1 or dir
  local prev, cur = n1, n2
  if (nodes[cur].pos - nodes[prev].pos):dot(travel) < 0 then prev, cur = cur, prev end
  local function allowed(from, to)
    if back then return linkAllowed(nodes, to, from) end
    return linkAllowed(nodes, from, to)
  end
  local okStart = allowed(prev, cur)
  if okStart == nil then return nil, 'Einbahn-Richtung noch unbekannt' end
  if not okStart then return nil, 'Spieler auf Gegenfahrbahn' end
  local remaining = math.abs(distance) - (nodes[cur].pos - pos):length()
  local heading = (nodes[cur].pos - nodes[prev].pos):normalized()
  local bridges, walked = 0, 0
  for _ = 1, 800 do
    local best, bestScore
    for nid in pairs(neighbors(nodes, cur)) do
      if nid ~= prev and nodes[nid] then
        local ok, l = allowed(cur, nid)
        if ok then
          local d = nodes[nid].pos - nodes[cur].pos
          local len = d:length()
          if len > 0.1 then
            local align = (d / len):dot(heading)
            if align > 0 then
              -- geradeaus bevorzugen, breitere Hauptstraße vor Ausfahrt
              local score = align + ((l and l.drivability) or 1) * 0.1 + math.min(nodes[nid].radius or 0, 10) * 0.02
              if not bestScore or score > bestScore then best, bestScore = nid, score end
            end
          end
        end
      end
    end
    if not best then
      -- Lücke überbrücken: nächste Kante kurz voraus, die in dieselbe Richtung läuft
      local bridged = false
      if bridges < 20 then
        local probe = nodes[cur].pos + heading * 6
        local a, b, dist = map.findClosestRoad(probe)
        if a and b and dist and dist < 4 and nodes[a] and nodes[b] and a ~= cur and b ~= cur then
          local e = nodes[b].pos - nodes[a].pos
          if e:dot(heading) < 0 then a, b, e = b, a, e * -1 end
          if e:length() > 0.1 and e:normalized():dot(heading) > 0.8 and allowed(a, b) then
            bridges = bridges + 1
            remaining = remaining - (nodes[a].pos - nodes[cur].pos):length()
            prev, cur = cur, a
            bridged = true
          end
        end
      end
      if not bridged then return nil, string.format('Straßennetz endet nach %d m', math.floor(walked)) end
    else
      local seg = nodes[best].pos - nodes[cur].pos
      local len = seg:length()
      if remaining <= len then
        local t = math.max(remaining, 0) / len
        local fwd = seg:normalized()
        if back then fwd = fwd * -1 end
        return nodes[cur].pos + seg * t + vec3(0, 0, 0.5), fwd
      end
      remaining = remaining - len
      walked = walked + len
      heading = seg:normalized()
      prev, cur = cur, best
    end
  end
  return nil, 'zu viele Knoten'
end

-- Sucht einen Spawnpunkt `distance` m vor (negativ: hinter) dem Spieler auf seiner Fahrbahn.
-- Zuerst das Straßennetz entlang, sonst die nächste Straße am Ziel (beides nur in erlaubter Fahrtrichtung).
local function findRoadSpawn(pos, dir, distance)
  local nodes = map.getMap().nodes
  local p, d, why1
  if nodes then
    p, d = walkRoad(nodes, pos, dir, distance)
    if p then return p, d end
    why1 = d
  end
  p, d = closestRoadSpawn(pos, dir, distance)
  if p then return p, d end
  return nil, string.format('Netz: %s / Ziel: %s', tostring(why1), tostring(d))
end

M.findRoadSpawn = findRoadSpawn -- auch für die Polizei (police.lua)

-- Kein anderes Fahrzeug (Verkehr) in der Nähe des Spawnpunkts?
local function spawnFree(pos, radius)
  local ok, free = pcall(function()
    for i = 0, be:getObjectCount() - 1 do
      local o = be:getObject(i)
      if o and (o:getPosition() - pos):length() < radius then return false end
    end
    return true
  end)
  if not ok then return true end
  return free
end

M.spawnFree = spawnFree

-- Abstand zum nächsten Fahrzeug vor einem Punkt in Fahrtrichtung (für das Losrollen)
local function gapAhead(veh, dir, range)
  local best = range
  local p = veh:getPosition()
  for i = 0, be:getObjectCount() - 1 do
    local o = be:getObject(i)
    if o and o:getID() ~= veh:getID() then
      local d = o:getPosition() - p
      local along = d:dot(dir)
      if along > 0 and along < best and (d - dir * along):length() < 4 then best = along end
    end
  end
  return best
end

local function setRotation(veh, pos, dir)
  local rot = quatFromDir(dir, vec3(0, 0, 1))
  if spawn and spawn.safeTeleport then
    spawn.safeTeleport(veh, pos, rot)
  else
    veh:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
  end
end

-- Reisetempo im Verkehr: vorsichtig (niedrige Aggression), Autos ausweichen, in der Spur bleiben.
-- Die Battle-Aggression aus rivals.json gilt erst im Battle.
local cruiseAggression = 0.3

function setCruise(veh, rival)
  local speed = (rival.cruiseKmh or 100) / 3.6
  veh:queueLuaCommand(string.format(
    "ai.setMode('traffic') ai.setAggressionMode('off') ai.setAvoidCars('on') ai.setSpeedMode('limit') ai.setSpeed(%f) ai.setAggression(%f) ai.driveInLane('on')",
    speed, cruiseAggression))
end
M.setCruise = setCruise

-- Begleiter (crew.lua, Alpha 0.9.3): fahren im Konvoi hinter ihrem Leader/Boss her ('follow' auf den Vordermann).
-- Wer in der Kette geschlagen wurde (leftGroup) oder dessen Vordermann fehlt, fährt normal im Verkehr.
local function crew() return extensions.hashiriyaBattle_crew end

function M.resume(e)
  local veh = entryVeh(e)
  if not veh then return end
  -- Vordermann: der Begleiter vor ihm, außer der fährt gerade selbst ein Battle oder ist raus; dann der Leader
  local f = e.followEntry
  if f and (f == engaged or f.leftGroup or not entryVeh(f)) then f = e.escortOf end
  local ahead = e.escortOf and not e.leftGroup and entryVeh(f) or nil
  local cc = crew() and crew().cfg('escorts')
  if ahead and cc and cc.ai == 'follow' then
    local lead = e.escortOf.data
    local speed = ((lead.cruiseKmh or 100) + (cc.followExtraKmh or 10)) / 3.6
    veh:queueLuaCommand(string.format(
      "ai.setMode('follow') ai.setTargetObjectID(%d) ai.setAggressionMode('off') ai.setAvoidCars('on') ai.setSpeedMode('limit') ai.setSpeed(%f) ai.setAggression(%f) ai.driveInLane('on')",
      ahead:getID(), speed, cruiseAggression))
  else
    setCruise(veh, e.data)
  end
end

-- Alle Fahrzeuge einer Gruppe (Leader zuerst, dann die Begleiter von vorne nach hinten)
function M.groupMembers(group)
  local out = {}
  if not group then return out end
  if group.leader then out[1] = group.leader end
  for _, e in ipairs(group.escorts or {}) do out[#out + 1] = e end
  return out
end

-- Kette gerissen oder vorbei: alle wieder zusammen (geschlagene Begleiter fahren wieder mit), mit Pause
function M.regroup(group, cooldown)
  for _, e in ipairs(M.groupMembers(group)) do
    e.leftGroup = nil
    if cooldown then e.cooldown = math.max(e.cooldown or 0, cooldown) end
    if e ~= engaged then M.resume(e) end
  end
end

-- Hängt sich ans Ende: Begleiter-Autos direkt hinter dem Leader spawnen (gleiche Spur, spacing m Abstand)
local spawnCar -- weiter unten
local function spawnEscorts(entry, rival, dist, player, save)
  local c = crew()
  if not c then return end
  local list = c.escortsFor(rival, save, function(r) return not isOnRoad(r.id) and not reserved[r.id] end)
  if #list == 0 then return end
  local cc = c.cfg('escorts')
  local group = { leader = entry, escorts = {} }
  entry.group = group
  local prev = entry
  for i, r in ipairs(list) do
    local d = dist - (cc.spacing or 20) * i
    local pos, dir = findRoadSpawn(player:getPosition(), player:getDirectionVector(), d)
    if pos and spawnFree(pos, 6) then
      local veh = spawnCar(r, pos, dir)
      if veh then
        local e = { data = r, vehId = veh:getID(), spawnDir = dir, spawnPos = pos, age = 0, rotChecked = false,
          group = group, escortOf = entry, followEntry = prev, escortIndex = i }
        table.insert(onRoad, e)
        table.insert(group.escorts, e)
        M.resume(e)
        prev = e
      end
    end
  end
  if #group.escorts == 0 then entry.group = nil; return end
  log('I', logTag, string.format('Begleiter für %s: %d', tostring(rival.id), #group.escorts))
  return #group.escorts
end

-- Auto eines Rivalen an pos/dir spawnen (eigene Config mit Kennzeichen und Lack, zur Not die Original-Config)
function spawnCar(rival, pos, dir)
  local model, cfg, paints, plateText = M.carFor(rival)
  local opts = { config = cfg, pos = pos, rot = quatFromDir(dir, vec3(0, 0, 1)), autoEnterVehicle = false, licenseText = plateText }
  if paints then opts.paint, opts.paint2, opts.paint3 = paints[1], paints[2], paints[3] end
  local okSpawn, veh = pcall(core_vehicles.spawnNewVehicle, model, opts)
  if (not okSpawn or not veh) and type(cfg) == 'table' then
    -- Ersatz: Original-Config ohne Kennzeichen-Design und Lack
    log('W', logTag, 'Rivale mit eigener Config nicht gespawnt, nehme Original: ' .. tostring(rival.id) .. ' ' .. tostring(veh))
    opts.config, opts.paint, opts.paint2, opts.paint3 = rival.config, nil, nil, nil
    okSpawn, veh = pcall(core_vehicles.spawnNewVehicle, model, opts)
  end
  if not okSpawn then veh = nil end
  if veh and plateText then pcall(core_vehicles.setPlateText, plateText, veh:getID()) end
  if not veh then log('E', logTag, 'Konnte Rivalen-Auto nicht spawnen: ' .. tostring(model)) end
  return veh
end

-- Dev-Tool: Rivale per ID oder (Teil vom) Namen finden
function M.findRival(q)
  if not data then M.loadData() end
  q = tostring(q or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
  if q == '' then return nil end
  for _, r in ipairs(data.rivals or {}) do if r.id:lower() == q then return r end end
  for _, r in ipairs(data.rivals or {}) do if r.name:lower() == q then return r end end
  for _, r in ipairs(data.rivals or {}) do
    if r.name:lower():find(q, 1, true) or r.id:lower():find(q, 1, true) then return r end
  end
  return nil
end

-- force = Test-Knopf (ohne Nacht/Limit/Parkplatz-Sperre); forced = bestimmter Rivale (Dev-Tool, ohne Bedingungen)
function M.spawnNext(force, forced)
  local save = core().save
  if not save then return end
  if not data then M.loadData() end
  local player = core().getPlayerVehicle()
  if not player then return end
  if #onRoad >= (settings().maxOnRoad or 4) and not force then return end

  -- Nicht in Parkplätzen spawnen (nur der Test-Knopf darf das)
  if not force and extensions.hashiriyaBattle_parking.getCurrent() then return end
  -- Battles nur nachts und (falls eingestellt) nur bis zum Limit pro Nacht
  if not force then
    if settings().nightOnly and not home().isNight() then return end
    local left = M.battlesLeftTonight()
    if left and left <= 0 then
      if not save.nightLimitShown or save.nightLimitShown ~= home().nightId() then
        save.nightLimitShown = home().nightId()
        core().msg(core().t('msg.nightDone'), 6)
      end
      return
    end
  end

  local rival = forced or pickRival(save)
  if forced and isOnRoad(forced.id) then
    core().msg(core().t('msg.devOnRoad', forced.name), 3)
    return
  end
  if not rival then
    if force then core().msg(core().t('msg.noRivals')) end
    return
  end

  -- vor oder hinter dem Spieler, in Fahrtrichtung: neue Gegner fast immer vorne, Revanchen öfter auch hinten
  local behindChance = rival.rematch and (settings().spawnBehindRematch or 0.25) or (settings().spawnBehindNew or 0.05)
  local behind = not force and math.random() < behindChance
  local pos, dir, dist, failWhy
  -- Rufen/Dev-Spawn: mehrere Abstände probieren, zur Not ohne Einbahn-Regeln
  local forceDists = { 160, 250, 350, 120, 500, -150 }
  local tries = force and #forceDists * 2 or 4
  for i = 1, tries do
    dist = behind and -(behindMin + math.random() * (behindMax - behindMin)) or (spawnMin + math.random() * (spawnMax - spawnMin))
    if force then
      dist = forceDists[(i - 1) % #forceDists + 1]
      relaxOneWay = i > #forceDists
    end
    pos, dir = findRoadSpawn(player:getPosition(), player:getDirectionVector(), dist)
    relaxOneWay = false
    if pos and force and i > #forceDists then log('W', logTag, 'Rivale ohne Einbahn-Prüfung gespawnt (Straßennetz unklar)') end
    if pos then
      if spawnFree(pos, 20) then break end
      failWhy = 'Verkehr am Spawnpunkt'
    else
      failWhy = dir
    end
    pos = nil
  end
  if not pos then
    log('I', logTag, 'Kein Rivalen-Spawnpunkt (' .. tostring(dist and math.floor(dist)) .. ' m): ' .. tostring(failWhy)
      .. ', Einbahn gelernt: ' .. tostring(oneWaySign) .. string.format(' (%d/%d)', oneWayVotes.plus, oneWayVotes.minus))
    if force then core().msg(core().t('msg.noRoad')) end
    return
  end

  local veh = spawnCar(rival, pos, dir)
  if not veh then return end

  local entry = { data = rival, vehId = veh:getID(), spawnDir = dir, spawnPos = pos, age = 0, rotChecked = false }
  table.insert(onRoad, entry)
  setCruise(veh, rival)
  -- Leader und Bosse bringen Begleiter mit (crew.lua, data/crewbattle.json)
  local escorts = nil
  if rival.leader or rival.boss or type(rival.escorts) == 'table' then
    local okE, n = pcall(spawnEscorts, entry, rival, dist, player, save)
    if okE then escorts = n else log('E', logTag, 'Begleiter: ' .. tostring(n)) end
  end
  if force or dist > 0 then
    local nick = progress().loc(rival.nick)
    core().msg(core().t('msg.rivalSpotted', rival.name .. (nick ~= '' and (' "' .. nick .. '"') or ''))
      .. (rival.leader and core().t('msg.leader') or '') .. (rival.wanderer and core().t('msg.wanderer') or '') .. (rival.boss and core().t('msg.boss') or '')
      .. (rival.stage and core().t('msg.stage', rival.stage) or '') .. (rival.rematch and core().t('msg.rematch') or '') .. (home().isWatched(rival.id) and core().t('msg.watched') or '')
      .. (escorts and core().t('msg.escorts', escorts) or ''))
  end
  log('I', logTag, 'Rivale gespawnt: ' .. rival.id .. string.format(' (%d m, %d unterwegs)', math.floor(dist), #onRoad))
  return entry
end

-- Logos (Team-Logos, Wanderer-Siegel, Boss-Embleme) ---------------------------------
-- Suche: eigener Pfad "logo" in rivals.json (Team oder Rivale), dann art/logos/<id>.png
-- (fertiges Bild, z. B. aus VectorCraft), dann art/logos/<id>.svg (Entwurf aus tools/logos).
-- Crews: <teamId>.* , Leader: <teamId>_leader.* (fehlt es, das normale Team-Logo).
-- Wanderer/Bosse: <rivalId>.* . Gefundenes bleibt gemerkt, Fehlendes wird nach 30 s neu gesucht.
local logoCache = {}
local function findLogo(key, custom)
  local hit = logoCache[key]
  if hit and hit.path then return hit.path end
  if hit and os.clock() - hit.t < 30 then return nil end
  local list = {}
  if type(custom) == 'string' and custom ~= '' then list[1] = '/' .. (custom:gsub('^/', '')) end
  list[#list + 1] = '/art/logos/' .. key .. '.png'
  list[#list + 1] = '/art/logos/' .. key .. '.svg'
  local found = nil
  for _, p in ipairs(list) do
    if FS:fileExists(p) then found = p; break end
  end
  logoCache[key] = { path = found, t = os.clock() }
  return found
end

-- icon = true: zuerst das Symbol ohne Schrift (<id>_icon.*) für HUD und Sprechblase, sonst das volle Logo
function M.teamLogo(teamId, leader, icon)
  if not teamId or not data then return nil end
  local team = teamById(teamId)
  local keys = {}
  if leader then
    if icon then keys[#keys + 1] = { teamId .. '_leader_icon' } end
    keys[#keys + 1] = { teamId .. '_leader', team and team.logoLeader }
  end
  if icon then keys[#keys + 1] = { teamId .. '_icon' } end
  keys[#keys + 1] = { teamId, team and team.logo }
  for _, k in ipairs(keys) do
    local p = findLogo(k[1], k[2])
    if p then return p end
  end
  return nil
end

function M.teamName(teamId)
  local t = data and teamById(teamId)
  return t and t.name or nil
end

-- Logo für einen Rivalen: Wanderer/Boss eigenes Siegel, sonst das Logo seiner Crew
function M.logoOf(rival, icon)
  if not rival then return nil end
  local id = rival.baseId or rival.id
  if rival.wanderer or rival.boss then return findLogo(id, rival.logo) end
  if rival.team then return M.teamLogo(rival.team, rival.leader, icon) end
  return nil
end

-- Ein schon vorhandenes Auto als Rivalen auf die Straße übernehmen (PA-Rivale, der selbst aus der PA gefahren ist).
-- Er fährt schon (KI läuft), also kein Anschieben und kein Umdrehen. Zählt nicht gegen maxOnRoad.
function M.adoptVehicle(rival, vehId)
  local veh = vehId and be:getObjectByID(vehId)
  if not veh or not rival or isOnRoad(rival.id) then return nil end
  local dir = veh:getDirectionVector()
  local entry = { data = rival, vehId = vehId, spawnDir = dir, spawnPos = vec3(veh:getPosition()), age = 0,
    rotChecked = true, launched = true, fromPa = true }
  table.insert(onRoad, entry)
  log('I', logTag, 'Rivale aus der PA auf der Straße: ' .. tostring(rival.id) .. string.format(' (%d unterwegs)', #onRoad))
  return entry
end

-- Farbklasse für Markierungen (Radar, HUD): Boss, Wanderer, Leader, Revanche, verloren, normal
function M.markerKind(rival)
  local save = core().save
  if not rival then return 'rival' end
  if rival.boss then return 'boss' end
  if save and save.defeated and save.defeated[rival.id] then return 'beaten' end
  local last = save and save.lastBattle and save.lastBattle[rival.id]
  if last and not last.won then return 'lost' end
  if rival.wanderer then return 'wanderer' end
  if rival.leader then return 'leader' end
  return 'rival'
end

-- Radar: Rivalen relativ zum Spieler (x rechts, y vorne, in Metern)
function M.radarInfo(range)
  local c = core()
  local player = c.getPlayerVehicle()
  if not player or #onRoad == 0 then return nil end
  local fwd = player:getDirectionVector(); fwd.z = 0
  if fwd:length() < 0.01 then return nil end
  fwd = fwd:normalized()
  local right = vec3(fwd.y, -fwd.x, 0)
  local list, near = {}, nil
  for _, e in ipairs(onRoad) do
    local veh = entryVeh(e)
    if veh then
      local d = veh:getPosition() - player:getPosition()
      local rdir = veh:getDirectionVector()
      local x, y = d:dot(right), d:dot(fwd)
      local dist = math.sqrt(x * x + y * y)
      local scale = math.min(1, range / math.max(dist, 1))
      local item = {
        kind = M.markerKind(e.data), name = e.data.name, engaged = e == engaged,
        x = x / range * scale, y = y / range * scale, edge = dist > range,
        heading = math.deg(math.atan2(rdir:dot(right), rdir:dot(fwd))),
        dist = dist < 1000 and string.format('%d m', math.floor(dist)) or string.format('%.1f km', dist / 1000),
        d = dist,
      }
      table.insert(list, item)
      if not near or dist < near.d then near = item end
    end
  end
  return { list = list, near = near }
end

local function despawn(e)
  local veh = entryVeh(e)
  if veh then veh:delete() end
  for i, x in ipairs(onRoad) do if x == e then table.remove(onRoad, i); break end end
  if engaged == e then engaged = nil end
  -- Konvoi: wer diesem Auto gefolgt ist, sucht sich einen neuen Vordermann (oder fährt normal weiter)
  if e.group then
    for _, m in ipairs(M.groupMembers(e.group)) do
      if m ~= e and (m.followEntry == e or m.escortOf == e) and m ~= engaged then
        if m.followEntry == e then m.followEntry = (e ~= e.group.leader) and e.followEntry or nil end
        if m.escortOf == e then m.leftGroup = true end
        M.resume(m)
      end
    end
  end
end

-- Rivale aus dem Battle (oder der nächste) verschwindet, z. B. beim Abschleppen
function M.despawnActive()
  local e = engaged or nearest()
  if e then despawn(e) end
  cooldown = spawnCooldown
end

function M.despawnAll()
  for i = #onRoad, 1, -1 do despawn(onRoad[i]) end
  onRoad, engaged = {}, nil
end

-- Minimap (unten links): Rivalen in denselben Farben wie im Radar oben rechts -----------
-- BeamNG zeichnet alle fremden Autos auf der Minimap gleich (gedämpftes Orange, Ebene 90).
-- Über den Hook onDrawOnMinimap(td) malen wir Rivalen eine Ebene höher (95) und etwas größer
-- darüber, damit ihr Pfeil die Farbe der Radar-Klasse bekommt (siehe M.markerKind).
-- Farben = CSS-Variablen --k-* in ui/modules/apps/HashiriyaStatus/app.js (beide Stellen gleich halten!)
local minimapKindColors = {
  rival    = { 255, 102,   0 }, -- #ff6600
  leader   = { 255, 210,  63 }, -- #ffd23f
  wanderer = { 185, 140, 255 }, -- #b98cff
  boss     = { 255,  59,  48 }, -- #ff3b30
  beaten   = { 158, 158, 158 }, -- #9e9e9e
  lost     = {  63, 169, 255 }, -- #3fa9ff
}
local minimapLayer = 95 -- über VEHICLES_USABLE (90), unter dem Spieler (100) und der Rand-Maske (110)
local mmPos, mmFwd = vec3(), vec3()

-- Eigener Pfeil (Spieler): weiß wie der Punkt in der Radar-Mitte (.hbt-radar-me), damit er sich
-- vom orangen Rivalen abhebt. BeamNG malt ihn in drawPlayer mit der Stilfarbe clrFocus (orange).
-- Wir hüllen drawPlayer ein und tauschen clrFocus nur für diesen einen Aufruf.
local minimapPlayerColor = { 244, 244, 244 } -- #f4f4f4
local playerColorObj = nil

local function wrapMinimapPlayer()
  local vehs = ui_apps_minimap_vehicles
  if not vehs or not vehs.drawPlayer or vehs.hbPlayerWrapped then return end
  local original = vehs.drawPlayer
  vehs.drawPlayer = function(...)
    local c = core()
    local utils = ui_apps_minimap_utils
    local style = c and c.active and utils and utils.getCurrentStyleColors and utils.getCurrentStyleColors()
    if type(style) ~= 'table' or not style.clrFocus then return original(...) end
    if not playerColorObj then
      playerColorObj = color(minimapPlayerColor[1], minimapPlayerColor[2], minimapPlayerColor[3], 255)
    end
    local keep = style.clrFocus
    style.clrFocus = playerColorObj
    local ok, res = pcall(original, ...)
    style.clrFocus = keep
    if not ok then error(res) end
    return res
  end
  vehs.hbPlayerWrapped = true
end

local function onDrawOnMinimap(td)
  if not td then return end
  local c = core()
  if not c or not c.active then return end
  wrapMinimapPlayer()
  if #onRoad == 0 then return end
  if extensions.hashiriyaBattle_hardcore.rule('hideRivalMarks') then return end -- Hardcore: keine Rivalen-Markierung
  local utils, minimap = ui_apps_minimap_utils, ui_apps_minimap_minimap
  if not utils or not minimap or not utils.getWorldToMapTransform then return end
  local scale = minimap.getScale and minimap.getScale()
  if not scale then return end
  local style = utils.getCurrentStyleColors and utils.getCurrentStyleColors() or utils.colors
  local bg = style and (style.navBg or style.navBgBlack)
  local dpi = (utils.dpi or 1) * (globalDpi or 1)
  local xx, xy, yx, yy, xo, yo = utils.getWorldToMapTransform()
  local pulse = math.sin(os.clock() * 8)
  for _, e in ipairs(onRoad) do
    local veh = entryVeh(e)
    if veh then
      local rgb = minimapKindColors[M.markerKind(e.data)] or minimapKindColors.rival
      mmPos:set(veh:getPositionXYZ())
      mmFwd:set(veh:getDirectionVectorXYZ()); mmFwd.z = 0
      if mmFwd:length() > 0.001 then
        mmFwd:normalize()
        -- Rivale im laufenden Battle pulsiert leicht (wie der Punkt im Radar)
        local size = (e == engaged) and (1.0 + 0.12 * pulse) or 0.95
        td:vehicleMarker(mmPos.x, mmPos.y, mmFwd.x, mmFwd.y, color(rgb[1], rgb[2], rgb[3], 255), bg,
          size, false, scale, dpi, xx, xy, yx, yy, xo, yo, minimapLayer)
      end
    end
  end
end

-- Update -------------------------------------------------------------------------

local function onUpdate(dtReal, dtSim)
  local c = core()
  if not c or not c.active or home().isResting() then return end
  local player = c.getPlayerVehicle()
  local busy = extensions.hashiriyaBattle_battle.isBusy()
  local night = not settings().nightOnly or home().isNight()

  for i = #onRoad, 1, -1 do
    local e = onRoad[i]
    e.age = e.age + dtSim
    if e.cooldown then e.cooldown = e.cooldown - dtSim; if e.cooldown <= 0 then e.cooldown = nil end end
    local veh = entryVeh(e)
    if not veh then
      table.remove(onRoad, i)
      if engaged == e then engaged = nil end
    else
      -- Falls das Auto falsch herum gespawnt ist, einmal umdrehen.
      if not e.rotChecked and e.age > 0.5 then
        e.rotChecked = true
        if veh:getDirectionVector():dot(e.spawnDir) < 0 then
          log('W', logTag, 'Rivale stand falsch herum, wird gedreht')
          setRotation(veh, e.spawnPos, e.spawnDir * -1)
          M.resume(e)
        end
      end
      -- Gleich nach dem Spawn mit Reisetempo losrollen lassen, statt aus dem Stand zu starten
      if not e.launched and e.age > 0.25 then
        e.launched = true
        -- nur so schnell, wie Platz nach vorne ist (sonst fährt er direkt ins nächste Verkehrsauto)
        local room = gapAhead(veh, e.spawnDir, 120)
        local launch = math.min((e.data.cruiseKmh or 100) / 3.6 * 0.8, room * 0.5)
        local v = e.spawnDir * launch
        local ok = pcall(function() veh:applyClusterVelocityScaleAdd(veh:getRefNodeId(), 0, v.x, v.y, v.z) end)
        if not ok then
          veh:queueLuaCommand(string.format('obj:applyClusterVelocityScaleAdd(obj:getRefNodeId(), 0, %f, %f, %f)', v.x, v.y, v.z))
        end
      end
      -- Licht: nachts an, außer der Rivale fährt als Markenzeichen ohne Licht (rivals.json: "lights": "off")
      e.lightTimer = (e.lightTimer or 0.3) - dtSim
      if e.lightTimer <= 0 then
        e.lightTimer = 5
        local want = (e.data.lights == 'off' or not home().isNight()) and 0 or 1
        if e.data.lights == 'on' then want = 1 end
        veh:queueLuaCommand(string.format('if (electrics.values.lights_state or 0) ~= %d then electrics.setLightsState(%d) end', want, want))
      end
      -- Hängt fest (steht oder fährt kaum, ohne Battle): erst neu anschieben, dann verschwinden lassen, wenn weit genug weg
      -- (nicht bei Crew-Blockern: die fährt gerade der eigene Fahrer, crew.lua)
      local drv = extensions.hashiriyaBattle_driver
      if e ~= engaged and e.launched and not (drv and drv.isRunning(e.vehId)) then
        if veh:getVelocity():length() < 3 then e.stuck = (e.stuck or 0) + dtSim else e.stuck = 0 end
        if e.stuck > stuckSeconds * 0.5 and not e.nudged then e.nudged = true; M.resume(e) end
        if e.stuck > stuckSeconds and player and (veh:getPosition() - player:getPosition()):length() > 120 then
          log('I', logTag, 'Rivale hing fest und wird entfernt: ' .. tostring(e.data.id))
          despawn(e)
          goto continue
        end
        if e.stuck == 0 then e.nudged = nil end
      end
      -- Zu weit weg (oder Tag geworden) und nicht im Battle: verschwinden lassen.
      if player and e ~= engaged then
        local far = (veh:getPosition() - player:getPosition()):length() > despawnDistance
        if far or (not night and not busy) then despawn(e) end
      end
    end
    ::continue::
  end

  calibTimer = calibTimer - dtSim
  if calibTimer <= 0 then
    calibTimer = 2
    pcall(calibrateOneWay, player)
  end

  cooldown = cooldown - dtSim
  if cooldown > 0 or busy then return end
  if player and player:getVelocity():length() > minSpawnSpeed then
    cooldown = spawnCooldown
    local ok, err = pcall(M.spawnNext, false)
    if not ok then log('E', logTag, 'Rivalen-Spawn fehlgeschlagen: ' .. tostring(err)) end
  end
end

local function onExtensionLoaded()
  M.loadData()
end

-- Leader-Status für Lexikon und Hinweis: 'members' (noch Mitglieder offen), 'nextNight' (letzte heute geschlagen), 'out' (unterwegs)
function M.leaderStatus(rival, save)
  save = save or core().save
  if not (rival and rival.leader and save) then return nil end
  if not teamMembersDefeated(rival.team, save) then return 'members' end
  if leaderWaitsNight(rival) and not teamMembersDefeated(rival.team, save, extensions.hashiriyaBattle_home.nightId()) then return 'nextNight' end
  return 'out'
end

function M.leaderOf(teamId) return leaderOf(teamId) end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate
M.onDrawOnMinimap = onDrawOnMinimap

return M
