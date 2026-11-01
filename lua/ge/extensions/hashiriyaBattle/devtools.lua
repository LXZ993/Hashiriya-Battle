-- Hashiriya Battle: Dev-Menü (Entwickler-Werkzeug, eigenes Fenster = UI-App HashiriyaDev).
-- Öffnen: Taste Shift+Ende oder Hashiriya-Menü > Werkzeuge > Dev-Menü.
-- Reiter: Spielstand (Rang, Ruf, Geld, Tag, Uhrzeit setzen), Rivalen (spawnen, besiegt an/aus), Orte (Positionen
-- merken, benennen, Typ setzen, hinteleportieren), Werkzeuge (Reparieren, Tanken, Exporte, Builder).
-- Orte stehen in settings/hashiriya_battle/dev_places.json (je Level). Die alten Einträge aus captured_positions.json
-- werden beim ersten Öffnen einmal übernommen; Orte aus der Kartendatei (maps/<level>.json) erscheinen mit in der
-- Liste und lassen sich umbenennen (nur der Anzeigename, die Kartendatei bleibt gleich).
-- Im Release (data/build.json release = true) ist alles aus; das Release-Zip enthält diese Datei nicht.
local M = {}

local logTag = 'hashiriya.dev'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

local saveDir = 'settings/hashiriya_battle/'
local placesPath = saveDir .. 'dev_places.json'
local legacyPath = saveDir .. 'captured_positions.json'
local up = vec3(0, 0, 1)

local isOpen = false
local tab = 'save'
local tickTimer = 0
local placesCache = nil -- Inhalt von dev_places.json
local rivalCache = nil

local function core() return extensions.hashiriyaBattle_core end
local function send(data) guihooks.trigger('HashiriyaDev', data) end

-- Ort-Typen (Reihenfolge = Auswahlliste im Fenster)
local placeTypes = {
  { id = 'garage', name = 'Garage / HQ' },
  { id = 'home', name = 'Zuhause' },
  { id = 'pa', name = 'Parkplatz (PA)' },
  { id = 'shop', name = 'Shop (allgemein)' },
  { id = 'shop_mech', name = 'Mechaniker' },
  { id = 'shop_paint', name = 'Lackierer' },
  { id = 'shop_body', name = 'Bodyshop' },
  { id = 'gas', name = 'Tankstelle' },
  { id = 'wanderer', name = 'Wanderer-Wartepunkt' },
  { id = 'police', name = 'Polizei / Messstelle' },
  { id = 'ramp_on', name = 'Auffahrt' },
  { id = 'ramp_off', name = 'Ausfahrt' },
  { id = 'mapchange', name = 'Map-Wechsel' },
  { id = 'spawn', name = 'Spawnpunkt' },
  { id = 'showroom', name = 'Showroom' },
  { id = 'other', name = 'Sonstiges' },
}
local typeName = {}
for _, t in ipairs(placeTypes) do typeName[t.id] = t.name end

function M.isAllowed()
  local c = core()
  return not (c and c.isRelease and c.isRelease())
end

local function msg(text, secs) if core() and core().msg then core().msg(text, secs or 3) end end
local function v3(t) return vec3(t[1], t[2], t[3]) end
local function arr(v) return { math.floor(v.x * 1000 + 0.5) / 1000, math.floor(v.y * 1000 + 0.5) / 1000, math.floor(v.z * 1000 + 0.5) / 1000 } end

-- Orte-Datei -------------------------------------------------------------------

local function levelKey() return core().levelName or 'unbekannt' end

local function loadPlaces()
  if placesCache then return placesCache end
  local d = jsonReadFile(placesPath)
  if type(d) ~= 'table' then d = {} end
  d._hinweis = 'Dev-Menü > Orte. Je Level: places = selbst gemerkte Orte (id, name, type, note, pos, dir, center = Mitte des Autos, onFoot = zu Fuß gemerkt). mapNames = eigene Namen für Orte aus der Kartendatei (maps/<level>.json). Typen: ' ..
    table.concat((function() local o = {} for _, t in ipairs(placeTypes) do table.insert(o, t.id) end return o end)(), ', ') .. '.'
  d.levels = d.levels or {}
  placesCache = d
  return d
end

local function savePlaces()
  if placesCache then jsonWriteFile(placesPath, placesCache, true) end
end

local function levelPlaces()
  local d = loadPlaces()
  local key = levelKey()
  d.levels[key] = d.levels[key] or { places = {}, mapNames = {}, nextId = 1 }
  local L = d.levels[key]
  L.places = L.places or {}
  L.mapNames = L.mapNames or {}
  L.nextId = L.nextId or (#L.places + 1)
  return L
end

local function newId(L)
  local id = 'p' .. L.nextId
  L.nextId = L.nextId + 1
  return id
end

-- Orte aus der Kartendatei (Garage, Shop, Zuhause, Tankstellen, PAs, Startpunkt, Showroom)
local mapTypeName = { garage = 'Garage (Bucht)', shop = 'Tuning-Shop (Bucht)', home = 'Zuhause', gas = 'Tankstelle' }
local function mapPlaces()
  local md = core().mapData or {}
  local out = {}
  local count = {}
  for _, a in ipairs(md.parkingAreas or {}) do
    if type(a.pos) == 'table' then
      count[a.type] = (count[a.type] or 0) + 1
      local name = a.name or mapTypeName[a.type] or a.id
      if a.type == 'gas' then name = 'Tankstelle ' .. count.gas end
      table.insert(out, { id = 'map:' .. a.id, name = name, type = a.type, pos = a.pos, dir = a.dir, map = true, mapId = a.id })
      if a.footPos and not a.footOnly then
        table.insert(out, { id = 'map:' .. a.id .. ':foot', name = name:gsub(' %(Bucht%)', '') .. ' (Eingang zu Fuß)', type = a.type,
          pos = a.footPos, dir = a.footDir or a.dir, onFoot = true, map = true, mapId = a.id .. ':foot' })
      end
    end
  end
  for i, n in ipairs(md.napSpots or {}) do
    if type(n.pos) == 'table' then
      table.insert(out, { id = 'map:nap' .. i, name = n.name or ('PA ' .. i), type = 'pa', pos = n.pos, map = true, mapId = 'nap' .. i })
    end
  end
  if md.playerSpawn and md.playerSpawn.pos then
    table.insert(out, { id = 'map:playerSpawn', name = 'Startpunkt zu Fuß', type = 'spawn', pos = md.playerSpawn.pos, dir = md.playerSpawn.dir, onFoot = true, map = true, mapId = 'playerSpawn' })
  end
  if md.showroom and md.showroom.pos then
    table.insert(out, { id = 'map:showroom', name = 'Showroom', type = 'showroom', pos = md.showroom.pos, dir = md.showroom.dir, map = true, mapId = 'showroom' })
  end
  return out
end

-- Alte Positionen (Menü "Position merken" bis Alpha 0.4) einmal übernehmen
local function importLegacy(L)
  if L.legacyImported then return end
  L.legacyImported = true
  local list = jsonReadFile(legacyPath)
  if type(list) ~= 'table' then return end
  local maps = mapPlaces()
  local n = 0
  for i, e in ipairs(list) do
    if type(e) == 'table' and type(e.pos) == 'table' and (e.level == nil or e.level == levelKey()) then
      local p = v3(e.center or e.pos)
      local near, best = nil, 15
      for _, m in ipairs(maps) do
        local d = (v3(m.pos) - p):length()
        if d < best then near, best = m, d end
      end
      table.insert(L.places, {
        id = newId(L),
        name = 'Alt ' .. i .. (near and (' (bei ' .. near.name .. ')') or ''),
        type = near and (typeName[near.type] and near.type or 'other') or 'other',
        note = 'aus captured_positions.json Nr. ' .. i,
        pos = e.pos, dir = e.dir, center = e.center, onFoot = e.onFoot or nil, legacy = i,
      })
      n = n + 1
    end
  end
  if n > 0 then log('I', logTag, 'Orte: ' .. n .. ' alte Positionen aus captured_positions.json übernommen') end
  savePlaces()
end

local function allPlaces()
  local L = levelPlaces()
  importLegacy(L)
  local out = {}
  for _, m in ipairs(mapPlaces()) do
    m.name = L.mapNames[m.mapId] or m.name
    m.typeName = typeName[m.type] or m.type
    table.insert(out, m)
  end
  for _, p in ipairs(L.places) do
    local e = {}
    for k, v in pairs(p) do e[k] = v end
    e.typeName = typeName[p.type] or p.type
    table.insert(out, e)
  end
  return out
end

local function findOwn(id)
  local L = levelPlaces()
  for i, p in ipairs(L.places) do
    if p.id == id then return p, i, L end
  end
  return nil, nil, L
end

-- Spieler / Kamera ---------------------------------------------------------------

local function playerObj()
  return getPlayerVehicle and getPlayerVehicle(0) or be:getPlayerVehicle(0)
end

local function isFreecam()
  local ok, name = pcall(function() return core_camera.getActiveCamName() end)
  return ok and name == 'free'
end

local function groundBelow(p)
  local ok, dist = pcall(function() return castRayStatic(p, vec3(0, 0, -1), 300) end)
  if ok and type(dist) == 'number' and dist < 300 then return p - vec3(0, 0, dist) end
  return nil
end

-- Wo steht man gerade? (Auto, zu Fuß oder Freecam)
local function currentSpot(useCam)
  local c = core()
  if useCam or isFreecam() then
    local okP, cp = pcall(core_camera.getPosition)
    local okF, cf = pcall(core_camera.getForward)
    if okP and cp then
      local g = groundBelow(vec3(cp))
      local d = okF and cf and vec3(cf.x, cf.y, 0) or vec3(0, 1, 0)
      if d:length() < 0.01 then d = vec3(0, 1, 0) end
      return { pos = g or vec3(cp), dir = d:normalized(), freecam = true, onFoot = true }
    end
  end
  local car = c.getPlayerVehicle()
  if car then
    local okC, center = pcall(function() return car:getSpawnWorldOOBB():getCenter() end)
    return { pos = car:getPosition(), dir = car:getDirectionVector(), center = okC and center or nil, car = car }
  end
  local walker = playerObj()
  if walker then
    local p = c.walkerPosition and c.walkerPosition(walker) or walker:getPosition()
    local d = walker:getDirectionVector()
    local okF, cf = pcall(core_camera.getForward)
    if okF and cf then d = vec3(cf.x, cf.y, 0) end
    if d:length() < 0.01 then d = vec3(0, 1, 0) end
    return { pos = p, dir = d:normalized(), onFoot = true }
  end
  return nil
end

local function playerInfo()
  local s = currentSpot(false)
  if not s then return nil end
  return { pos = arr(s.pos), onFoot = s.onFoot or false, freecam = s.freecam or false }
end

-- Teleport ---------------------------------------------------------------------------

local function teleportTo(pos, dir)
  local rot = quatFromDir((dir and v3(dir) or vec3(0, 1, 0)), up)
  local p = v3(pos) + vec3(0, 0, 0.3)
  if isFreecam() then
    pcall(function() core_camera.setPosition(0, p + vec3(0, 0, 3)) end)
  end
  local veh = playerObj()
  if not veh then return false end
  -- safeTeleport ohne Zurücksetzen (letzter Parameter false): Schaden bleibt wie er ist
  local ok = pcall(function() spawn.safeTeleport(veh, p, rot, nil, nil, nil, nil, false) end)
  if not ok then
    ok = pcall(function() veh:setPositionRotation(p.x, p.y, p.z, rot.x, rot.y, rot.z, rot.w) end)
  end
  return ok
end

-- Zustand fürs Fenster -------------------------------------------------------------

local function rivalList()
  if rivalCache then return rivalCache end
  local data = extensions.hashiriyaBattle_rivals.getData() or {}
  local teamName = {}
  for _, t in ipairs(data.teams or {}) do teamName[t.id] = t.name end
  rivalCache = {}
  for _, r in ipairs(data.rivals or {}) do
    local tag = r.boss and 'Boss' or r.wanderer and 'Wanderer' or teamName[r.team] or ''
    if r.leader then tag = tag .. ' (Leader)' end
    table.insert(rivalCache, { id = r.id, name = r.name, tag = tag })
  end
  return rivalCache
end

function M.resetCache() rivalCache = nil end

local function saveState()
  local c = core()
  local save = c.save
  if not save then return nil end
  local pr = extensions.hashiriyaBattle_progress
  local ranks = {}
  for i, r in ipairs((extensions.hashiriyaBattle_rivals.getData() or {}).ranks or {}) do
    table.insert(ranks, { idx = i - 1, name = pr.loc(r.name), rep = r.rep or 0, requiresFinal = r.requiresFinal or false })
  end
  local defeated = {}
  for id, v in pairs(save.defeated or {}) do if v then defeated[id] = true end end
  local shop = extensions.hashiriyaBattle_shop
  return {
    money = save.money or 0, moneyText = c.economy().formatYen(save.money or 0),
    rep = save.rep or 0, wins = save.wins or 0, losses = save.losses or 0, day = save.day or 1,
    rankIdx = pr.rankIndex(save), rankName = pr.rankName(save), finalBeaten = save.finalBeaten or false,
    hour = extensions.hashiriyaBattle_home.hour(), ranks = ranks, defeated = defeated,
    levels = shop.unlockedLevels and shop.unlockedLevels() or {},
  }
end

local function fullState()
  local c = core()
  return {
    open = isOpen, tab = tab, active = c.active or false, level = c.levelName,
    save = c.active and saveState() or nil,
    places = allPlaces(), types = placeTypes,
    rivals = c.active and rivalList() or {},
    player = playerInfo(), hour = extensions.hashiriyaBattle_home.hour(),
  }
end

function M.refresh()
  if isOpen then send(fullState()) end
end

-- Öffnen / Schließen -------------------------------------------------------------------

function M.toggle()
  if not M.isAllowed() then return end
  if isOpen then M.close() else M.open() end
end

function M.open()
  if not M.isAllowed() then return end
  isOpen = true
  tickTimer = 0
  M.refresh()
end

function M.close()
  isOpen = false
  send({ open = false })
end

function M.isOpen() return isOpen end

-- Spielstand ändern ------------------------------------------------------------------------

-- Freischalt-Meldungen: was jetzt frei ist, gilt als gesehen; nach Herabsetzen kommt die Meldung beim Aufstieg wieder
local function syncUnlockSeen(save)
  local shop = extensions.hashiriyaBattle_shop
  if not shop.unlockedLevels then return end
  save.unlockSeen = {}
  for _, lv in ipairs(shop.unlockedLevels()) do save.unlockSeen[tostring(lv)] = true end
end

local function afterSaveChange(text)
  local c = core()
  c.writeSave()
  c.sendUiState()
  if text then msg(text, 3) end
end

local setters = {
  money = function(save, n) save.money = math.max(0, math.floor(n)) end,
  rep = function(save, n) save.rep = math.max(0, math.floor(n)) end,
  wins = function(save, n) save.wins = math.max(0, math.floor(n)) end,
  losses = function(save, n) save.losses = math.max(0, math.floor(n)) end,
  day = function(save, n) save.day = math.max(1, math.floor(n)) end,
}

local actions = {}

function actions.tab(a) tab = tostring(a.tab or 'save') end

function actions.setValue(a)
  local save = core().save
  local n = tonumber(a.value)
  local f = setters[a.field]
  if not (save and n and f) then return end
  f(save, n)
  if a.field == 'rep' then syncUnlockSeen(save) end
  afterSaveChange('Dev: ' .. a.field .. ' = ' .. tostring(save[a.field]))
end

function actions.addValue(a)
  local save = core().save
  local n = tonumber(a.value)
  local f = setters[a.field]
  if not (save and n and f) then return end
  f(save, (save[a.field] or 0) + n)
  if a.field == 'rep' then syncUnlockSeen(save) end
  afterSaveChange()
end

-- Rang setzen = Ruf auf die Schwelle des Rangs (letzter Rang setzt auch "Endboss besiegt")
function actions.setRank(a)
  local save = core().save
  local idx = tonumber(a.idx)
  local ranks = (extensions.hashiriyaBattle_rivals.getData() or {}).ranks or {}
  local r = idx and ranks[idx + 1]
  if not (save and r) then return end
  save.rep = r.rep or 0
  if r.requiresFinal then save.finalBeaten = true end
  syncUnlockSeen(save)
  afterSaveChange('Dev: Rang ' .. (idx + 1) .. ' ' .. extensions.hashiriyaBattle_progress.rankName(save))
end

function actions.setFinal(a)
  local save = core().save
  if not save then return end
  save.finalBeaten = a.on and true or nil
  syncUnlockSeen(save)
  afterSaveChange()
end

function actions.setHour(a)
  local h = tonumber(a.hour)
  if h then extensions.hashiriyaBattle_home.applyClock(h % 24) end
end

function actions.setDefeated(a)
  local save = core().save
  local r = extensions.hashiriyaBattle_rivals.findRival(a.id)
  if not (save and r) then return end
  save.defeated = save.defeated or {}
  if a.on then
    save.defeated[r.id] = true
    if r.final then save.finalBeaten = true end
  else
    save.defeated[r.id] = nil
    if save.defeatedNight then save.defeatedNight[r.id] = nil end
  end
  afterSaveChange('Dev: ' .. r.name .. (a.on and ' besiegt' or ' wieder offen'))
end

function actions.resetDefeated()
  local save = core().save
  if not save then return end
  save.defeated, save.defeatedNight = {}, {}
  afterSaveChange('Dev: alle Rivalen wieder offen')
end

function actions.resetUnlockSeen()
  local save = core().save
  if not save then return end
  save.unlockSeen = { ['1'] = true }
  afterSaveChange('Dev: Freischalt-Meldungen kommen wieder')
end

-- Orte -----------------------------------------------------------------------------------

function actions.capture(a)
  local s = currentSpot(a.useCam)
  if not s or s.pos:length() < 0.5 then msg(core().t('msg.posInvalid')) return end
  local L = levelPlaces()
  importLegacy(L)
  local t = typeName[a.type] and a.type or 'other'
  local id = newId(L)
  local name = tostring(a.name or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if name == '' then
    local n = 0
    for _, p in ipairs(L.places) do if p.type == t then n = n + 1 end end
    name = typeName[t] .. ' ' .. (n + 1)
  end
  table.insert(L.places, {
    id = id, name = name, type = t, note = (a.note and a.note ~= '') and tostring(a.note) or nil,
    pos = arr(s.pos), dir = arr(s.dir), center = s.center and arr(s.center) or nil,
    onFoot = s.onFoot or nil, freecam = s.freecam or nil, created = os.date('%Y-%m-%d %H:%M'),
  })
  savePlaces()
  log('I', logTag, string.format('Ort gemerkt: %s [%s] (%.1f / %.1f / %.1f)', name, t, s.pos.x, s.pos.y, s.pos.z))
  msg('Ort gemerkt: ' .. name, 3)
end

function actions.editPlace(a)
  if tostring(a.id):find('^map:') then
    local L = levelPlaces()
    local mapId = tostring(a.id):sub(5)
    local name = tostring(a.name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    L.mapNames[mapId] = name ~= '' and name or nil
    savePlaces()
    return
  end
  local p = findOwn(a.id)
  if not p then return end
  if a.name ~= nil then
    local name = tostring(a.name):gsub('^%s+', ''):gsub('%s+$', '')
    if name ~= '' then p.name = name end
  end
  if a.type ~= nil and typeName[a.type] then p.type = a.type end
  if a.note ~= nil then p.note = a.note ~= '' and tostring(a.note) or nil end
  savePlaces()
end

-- Ort an die aktuelle Stelle verschieben
function actions.movePlace(a)
  local p = findOwn(a.id)
  local s = currentSpot(a.useCam)
  if not (p and s) then return end
  p.pos, p.dir = arr(s.pos), arr(s.dir)
  p.center = s.center and arr(s.center) or nil
  p.onFoot, p.freecam = s.onFoot or nil, s.freecam or nil
  savePlaces()
  msg('Ort neu gesetzt: ' .. p.name, 3)
end

function actions.deletePlace(a)
  local p, i, L = findOwn(a.id)
  if not p then return end
  table.remove(L.places, i)
  savePlaces()
  msg('Ort gelöscht: ' .. p.name, 3)
end

function actions.teleport(a)
  for _, p in ipairs(allPlaces()) do
    if p.id == a.id then
      if teleportTo(p.pos, p.dir) then msg('Teleport: ' .. p.name, 2)
      else msg('Teleport fehlgeschlagen', 3) end
      return
    end
  end
end

-- Kommt aus der App: Aktion + Argumente als JSON-Text
function M.action(name, argText)
  if not M.isAllowed() then return end
  local a = {}
  if type(argText) == 'string' and argText ~= '' then
    local ok, d = pcall(jsonDecode, argText, 'hashiriyaDev')
    if ok and type(d) == 'table' then a = d end
  end
  local f = actions[name]
  if not f then log('W', logTag, 'Unbekannte Dev-Aktion: ' .. tostring(name)) return end
  log('I', logTag, 'Dev-Aktion: ' .. tostring(name) .. (argText and argText ~= '' and (' ' .. argText) or ''))
  local ok, err = pcall(f, a)
  if not ok then log('E', logTag, 'Dev-Aktion ' .. tostring(name) .. ': ' .. tostring(err)) end
  M.refresh()
end

-- "Position merken" aus dem alten Menüpunkt bzw. von anderen Stellen
function M.capture(name, placeType)
  if not M.isAllowed() then return end
  actions.capture({ name = name, type = placeType })
  M.refresh()
end

local function onUpdate(dtReal)
  if not isOpen then return end
  tickTimer = tickTimer - dtReal
  if tickTimer > 0 then return end
  tickTimer = 0.5
  local c = core()
  send({ tick = true, player = playerInfo(), hour = extensions.hashiriyaBattle_home.hour(), active = c.active or false,
    moneyText = c.active and c.save and c.economy().formatYen(c.save.money or 0) or nil })
end

local function onClientEndMission()
  placesCache = nil
  rivalCache = nil
  if isOpen then M.close() end
end

M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission

return M
