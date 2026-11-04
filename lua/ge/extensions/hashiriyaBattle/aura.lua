-- Hashiriya Battle: Aura = farbiges Licht um das Auto (wie in TXR, vorerst als Licht, Effekte wie Gewitter kommen nach 1.0)
--
-- Zwei Arten, beide aus Punktlichtern des Spiels, die jedem Auto jeden Frame folgen:
--   Boden-Aura   weicher Schein in der Aura-Farbe unter und neben dem Auto (Rivalen: nur nachts)
--   Battle-Aura  heller, pulsiert, mit Leuchtsaum (vier kleine Lichter an den Ecken der Karosserie);
--                wird schwächer, je weniger SP der Fahrer noch hat
--
-- Rivalen: Farbe der Crew (rivals.json teams[].color), Leader mit goldenem Saum, Wanderer und Bosse
-- ihre eigene Farbe aus data/aura.json "colors" (erzeugt von tools/logos/aura_colors.py).
--
-- Spieler: Auren gibt es nur von geschlagenen Gegnern (Trophäenwand, Reiter „Auren“):
--   c:<crew>   Crew-Aura, frei nach dem Sieg gegen irgendein Mitglied der Crew
--   l:<crew>   Leader-Aura (Crew-Farbe + goldener Saum), frei nach dem Sieg gegen den Leader
--   <id>       Aura eines Wanderers oder Bosses, frei nach dem Sieg gegen ihn
-- Gespeichert: save.aura = { id = ..., mode = 'always'|'battle'|'off', level = 1..3 } (pro Spielstand).
-- Freigeschaltet wird nichts extra gespeichert, alles ergibt sich aus save.defeated.
local M = {}

local logTag = 'hashiriyaBattle.aura'
local function log(level, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, logTag, text) else _G.log(level, logTag, text) end end
local function core() return extensions.hashiriyaBattle_core end
local function rivals() return extensions.hashiriyaBattle_rivals end
local function loc(v) return extensions.hashiriyaBattle_progress.loc(v) end

local data = nil
local lights = {}      -- [Schlüssel] = { obj = Licht, col = '...' }
local used = {}        -- in diesem Frame benutzte Schlüssel
local clock = 0
local failed = false   -- Licht konnte nicht erzeugt werden: nicht jeden Frame neu versuchen
local nameSeq = 0

local function cfg()
  if not data then
    data = jsonReadFile('/lua/ge/extensions/hashiriyaBattle/data/aura.json') or {}
  end
  return data
end
function M.reload() data = nil; failed = false; M.clear() end

-- Vorschau ohne Karriere (Gegner-Garage, garagetool.lua): Aura am Spielerauto, egal ob Nacht oder Battle.
-- p = { color = '#rrggbb', rim = '#rrggbb' oder nil, ground = bool, battle = bool, sp = 0..1, level = 1..3,
--       boost = Faktor nur für die Vorschau (hell beleuchtete Halle) } oder nil = aus
local preview = nil
function M.setPreview(p)
  preview = p
  failed = false
  if not p then M.clear() end
end
function M.getPreview() return preview end

-- Farbe -> Licht-Farbe (0..1). Blasse Farben werden für das Licht kräftiger gemacht.
local function lightColor(hex)
  hex = tostring(hex or ''):gsub('#', '')
  if #hex ~= 6 then hex = 'ff6600' end
  local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
  local mx = math.max(r, g, b, 0.001)
  r, g, b = r / mx, g / mx, b / mx
  -- Sättigung anheben (Grau bleibt weißlich)
  local mn = math.min(r, g, b)
  if mn < 0.95 then
    local k = 1.35
    r, g, b = math.max(0, 1 - (1 - r) * k), math.max(0, 1 - (1 - g) * k), math.max(0, 1 - (1 - b) * k)
  end
  return { r, g, b }
end

-- Licht-Felder wie im Spiel (util/photomodeFlash.lua, core/cameraModes/relative.lua):
-- erst als Eigenschaft, dann zur Sicherheit über setField; Farbe als Text "r g b 1", Helligkeit = intensity (Lumen)
local function setField(obj, name, value, isNumber)
  if isNumber then
    local n = tonumber(value)
    if not n then return end
    pcall(function() obj[name] = n end)
    pcall(function() obj:setField(name, 0, tostring(n)) end)
  else
    pcall(function() obj:setField(name, 0, tostring(value)) end)
  end
end

local function makeLight()
  nameSeq = nameSeq + 1
  local ok, obj = pcall(function()
    local o = createObject('PointLight')
    o.canSave = false
    return o
  end)
  if not ok or not obj then
    if not failed then log('W', 'Punktlicht nicht verfügbar: ' .. tostring(obj)) end
    failed = true
    return nil
  end
  setField(obj, 'castShadows', 'false')
  setField(obj, 'useColorTemperature', 'false')
  pcall(function() obj:registerObject('hashiriyaAura_' .. nameSeq) end)
  return obj
end

-- Ein Licht setzen (wird nur angelegt, wenn es noch keins unter dem Schlüssel gibt)
local function put(key, pos, col, radius, intensity)
  if failed then return end
  used[key] = true
  local l = lights[key]
  if not l then
    local obj = makeLight()
    if not obj then return end
    l = { obj = obj }
    lights[key] = l
    setField(obj, 'isEnabled', 'true')
  end
  local obj = l.obj
  pcall(function() obj:setPosition(pos) end)
  local changed = false
  local cKey = string.format('%.3f %.3f %.3f 1', col[1], col[2], col[3])
  if l.col ~= cKey then l.col = cKey; setField(obj, 'color', cKey); changed = true end
  if l.radius ~= radius then l.radius = radius; setField(obj, 'radius', radius, true); changed = true end
  local b = math.floor(intensity + 0.5)
  if l.intensity ~= b then l.intensity = b; setField(obj, 'intensity', b, true); changed = true end
  if changed then pcall(function() obj:postApply() end) end
end

local function dropUnused()
  for key, l in pairs(lights) do
    if not used[key] then
      pcall(function() l.obj:delete() end)
      lights[key] = nil
    end
  end
end

function M.clear()
  for _, l in pairs(lights) do pcall(function() l.obj:delete() end) end
  lights = {}
end

-- Mitte und Ausrichtung des Autos
local function frame(veh)
  local pos = veh:getPosition()
  local ok, center = pcall(function() return veh:getSpawnWorldOOBB():getCenter() end)
  if ok and center then pos = vec3(center) end
  local fwd = vec3(veh:getDirectionVector())
  local up = vec3(veh:getDirectionVectorUp())
  fwd:normalize(); up:normalize()
  local side = fwd:cross(up); side:normalize()
  return pos, fwd, up, side
end

-- spec: { color = {r,g,b}, level = Faktor, ground = bool, battle = bool, sp = 0..1, rimColor = {r,g,b} }
local function drawAura(key, veh, spec)
  local c = cfg()
  local pos, fwd, up, side = frame(veh)
  local g = c.ground or {}
  local base = pos - up * (0.6 - (g.height or 0.35))
  if spec.ground or spec.battle then
    local radius, bright = g.radius or 3.6, (g.intensity or 1200) * spec.level
    if spec.battle then
      local bt = c.battle or {}
      local spF = (bt.minSpFactor or 0.25) + (1 - (bt.minSpFactor or 0.25)) * math.max(0, math.min(1, spec.sp or 1))
      local pulse = 1 - (bt.pulseDepth or 0.35) * (0.5 + 0.5 * math.sin(clock * (bt.pulseSpeed or 2.2) * 2 * math.pi / 2))
      radius = bt.radius or 4.8
      bright = (bt.intensity or 2600) * spec.battleLevel * spF * pulse
    end
    local spread = g.spread or 1.3
    put(key .. ':f', base + fwd * spread, spec.color, radius, bright)
    put(key .. ':r', base - fwd * spread, spec.color, radius, bright)
  end
  local rim = c.rim or {}
  if spec.battle and rim.enabled ~= false then
    local h = pos - up * 0.6 + up * (rim.height or 0.75)
    local s, l = rim.side or 1.05, rim.length or 2.0
    local bt = c.battle or {}
    local spF = (bt.minSpFactor or 0.25) + (1 - (bt.minSpFactor or 0.25)) * math.max(0, math.min(1, spec.sp or 1))
    local pulse = 0.75 + 0.25 * math.sin(clock * (bt.pulseSpeed or 2.2) * math.pi + 1.3)
    local col = spec.rimColor or spec.color
    local b = (rim.intensity or 900) * spec.battleLevel * spF * pulse
    put(key .. ':fl', h + fwd * l + side * s, col, rim.radius or 1.7, b)
    put(key .. ':fr', h + fwd * l - side * s, col, rim.radius or 1.7, b)
    put(key .. ':rl', h - fwd * l + side * s, col, rim.radius or 1.7, b)
    put(key .. ':rr', h - fwd * l - side * s, col, rim.radius or 1.7, b)
  end
end

-- Farben ---------------------------------------------------------------------------------------
local function teamOf(id)
  local d = rivals() and rivals().getData and rivals().getData() or {}
  for _, t in ipairs(d.teams or {}) do if t.id == id then return t end end
end

-- Aura-Farbe (Hex) eines Rivalen; Leader bekommen zusätzlich den goldenen Saum
function M.colorOf(rival)
  if not rival then return nil end
  local c = cfg()
  local id = rival.baseId or rival.id
  if rival.aura then return rival.aura end
  if c.colors and c.colors[id] then return c.colors[id] end
  if rival.team then
    local t = teamOf(rival.team)
    if t and t.color then return t.color end
  end
  return c.defaultColor or '#ff6600'
end

local function levelOf(i)
  local lv = (cfg().levels or {})[i or 2] or { ground = 0.9, battle = 1.4 }
  return lv
end

-- Sammlung -----------------------------------------------------------------------------------------
-- Alle Auren in Lexikon-Reihenfolge: pro Crew Crew-Aura und Leader-Aura, dann Wanderer, dann Bosse
function M.entries(save)
  local d = rivals() and rivals().getData and rivals().getData() or {}
  local defeated = save and save.defeated or {}
  local c = cfg()
  local list = {}
  for _, t in ipairs(d.teams or {}) do
    local anyMember, leader = false, nil
    for _, r in ipairs(d.rivals or {}) do
      if r.team == t.id then
        if defeated[r.id] then anyMember = true end
        if r.leader then leader = r end
      end
    end
    table.insert(list, { id = 'c:' .. t.id, kind = 'crew', name = loc(t.name), color = t.color or c.defaultColor,
      unlocked = anyMember, team = t.id, logo = rivals().teamLogo(t.id, false, true) })
    if leader then
      table.insert(list, { id = 'l:' .. t.id, kind = 'leader', name = loc(t.name), color = t.color or c.defaultColor,
        rim = c.leaderRimColor, unlocked = defeated[leader.id] and true or false, team = t.id,
        source = leader, logo = rivals().teamLogo(t.id, true, true) })
    end
  end
  for _, kind in ipairs({ 'wanderer', 'boss' }) do
    for _, r in ipairs(d.rivals or {}) do
      if (kind == 'boss' and r.boss) or (kind == 'wanderer' and r.wanderer and not r.boss) then
        table.insert(list, { id = r.id, kind = kind, name = r.name, nick = loc(r.nick), color = M.colorOf(r),
          unlocked = defeated[r.id] and true or false, source = r, logo = rivals().logoOf(r) })
      end
    end
  end
  return list
end

local function find(save, id)
  if not id then return nil end
  for _, e in ipairs(M.entries(save)) do if e.id == id then return e end end
end

local function playerSettings(save)
  save.aura = type(save.aura) == 'table' and save.aura or {}
  local a = save.aura
  if a.mode ~= 'always' and a.mode ~= 'battle' and a.mode ~= 'off' then a.mode = 'always' end
  a.level = math.max(1, math.min(3, tonumber(a.level) or 2))
  return a
end

-- Aktive Aura des Spielers (nil = keine, oder nicht mehr freigeschaltet)
local playerCache = { t = -1 }
local function playerAura(save)
  if playerCache.t == clock and playerCache.save == save then return playerCache.e end
  local a = playerSettings(save)
  local e = a.id and find(save, a.id) or nil
  if e and not e.unlocked then e = nil end
  playerCache = { t = clock, save = save, e = e }
  return e
end

-- Bekannte Auren (für die Meldung „Neue Aura“): beim ersten Mal still alle schon freien eintragen
local function initSeen(save)
  if type(save.auraSeen) == 'table' then return end
  save.auraSeen = {}
  for _, e in ipairs(M.entries(save)) do if e.unlocked then save.auraSeen[e.id] = true end end
end

-- Nach einem Sieg (core.onBattleResult): Name der neuen Aura, falls dieser Sieg eine freigeschaltet hat
function M.newlyUnlocked(rival)
  local save = core().save
  if not save or not rival then return nil end
  initSeen(save)
  local ids = {}
  if rival.wanderer or rival.boss then table.insert(ids, rival.baseId or rival.id)
  elseif rival.team then
    table.insert(ids, 'c:' .. rival.team)
    if rival.leader then table.insert(ids, 'l:' .. rival.team) end
  end
  local names = {}
  for _, id in ipairs(ids) do
    local e = find(save, id)
    if e and e.unlocked and not save.auraSeen[id] then
      save.auraSeen[id] = true
      table.insert(names, e.kind == 'leader' and core().t('aura.leader', e.name) or e.name)
    end
  end
  playerCache.t = -1
  return #names > 0 and table.concat(names, ', ') or nil
end

-- Menü: Wahl, Modus, Stärke
function M.choose(id)
  local save = core().save
  if not save then return end
  local a = playerSettings(save)
  if not id or id == '' or id == 'none' then a.id = nil
  else
    local e = find(save, id)
    if e and e.unlocked then a.id = id end
  end
  playerCache.t = -1
  core().writeSave()
end

function M.setMode(mode)
  local save = core().save
  if not save then return end
  local a = playerSettings(save)
  if mode == 'always' or mode == 'battle' or mode == 'off' then a.mode = mode end
  core().writeSave()
end

function M.setLevel(level)
  local save = core().save
  if not save then return end
  local a = playerSettings(save)
  a.level = math.max(1, math.min(3, tonumber(level) or 2))
  core().writeSave()
end

function M.getUiState()
  local save = core().save
  if not save then return nil end
  local a = playerSettings(save)
  local t = function(k, ...) return core().t(k, ...) end
  local groups = {
    { key = 'crew', name = t('aura.g.crew'), list = {} },
    { key = 'wanderer', name = t('logos.g.wanderer'), list = {} },
    { key = 'boss', name = t('logos.g.boss'), list = {} },
  }
  local byKey = { crew = groups[1], leader = groups[1], wanderer = groups[2], boss = groups[3] }
  local have, total, cur = 0, 0, nil
  for _, e in ipairs(M.entries(save)) do
    total = total + 1
    if e.unlocked then have = have + 1 end
    local hidden = not e.unlocked and (e.kind == 'wanderer' or e.kind == 'boss')
    local g = byKey[e.kind]
    local item = {
      id = e.id, kind = e.kind, unlocked = e.unlocked, selected = a.id == e.id,
      -- Farbe erst nach dem Sieg sichtbar (vorher grau), Wanderer/Bosse auch ohne Namen
      color = e.unlocked and e.color or nil, rim = e.unlocked and e.rim or nil,
      name = hidden and '???' or (e.kind == 'leader' and t('aura.leader', e.name) or e.name),
      logo = (not hidden) and e.logo or nil,
      hint = (not e.unlocked) and (e.kind == 'crew' and t('aura.hint.crew', e.name)
        or e.kind == 'leader' and t('aura.hint.leader', e.name) or t('aura.hint.' .. e.kind)) or nil,
    }
    if item.selected and e.unlocked then cur = item end
    table.insert(g.list, item)
    if e.unlocked then g.have = (g.have or 0) + 1 end
  end
  for _, g in ipairs(groups) do g.have = g.have or 0; g.total = #g.list end
  return {
    have = have, total = total, groups = groups,
    current = cur and cur.id or nil, currentName = cur and cur.name or t('aura.none'),
    currentColor = cur and cur.color or nil,
    mode = a.mode, level = a.level,
  }
end

-- Jeden Frame ----------------------------------------------------------------------------------------
local function update(dt)
  local c = cfg()
  if c.enabled == false or failed then
    if next(lights) then M.clear() end
    return
  end
  clock = clock + (dt or 0)
  used = {}
  if preview then
    local veh = getPlayerVehicle and getPlayerVehicle(0)
    if veh then
      local lv = levelOf(preview.level or 2)
      local boost = tonumber(preview.boost) or 1
      drawAura('preview', veh, {
        color = lightColor(preview.color), level = (lv.ground or 0.9) * boost, battleLevel = (lv.battle or 1.4) * boost,
        ground = preview.ground and true or false, battle = preview.battle and true or false, sp = preview.sp or 1,
        rimColor = preview.rim and lightColor(preview.rim) or nil,
      })
    end
    dropUnused()
    return
  end
  local cr = core()
  if not cr or not cr.active or not cr.save then dropUnused(); return end
  local save = cr.save
  initSeen(save)
  local player = cr.getPlayerVehicle()
  local night = true
  if extensions.hashiriyaBattle_home then night = extensions.hashiriyaBattle_home.isNight() and true or false end
  local bi = extensions.hashiriyaBattle_battle and extensions.hashiriyaBattle_battle.auraInfo and extensions.hashiriyaBattle_battle.auraInfo() or nil
  local inBattle = bi and (bi.state == 'battle' or bi.state == 'countdown') or false

  -- Rivalen
  local rc = c.rivals or {}
  local rLevel = levelOf(c.rivalLevel or 2)
  local ppos = player and player:getPosition() or nil
  for _, e in ipairs(rivals() and rivals().getOnRoad() or {}) do
    local veh = e.vehId and be:getObjectByID(e.vehId)
    if veh and e.rival then
      local near = not ppos or (veh:getPosition() - ppos):length() < (rc.maxDistance or 220)
      local fighting = inBattle and bi.rival == e.rival
      local ground = rc.ground ~= false and (night or rc.groundOnlyNight == false)
      if near and (ground or (fighting and rc.battle ~= false)) then
        drawAura('r' .. tostring(e.vehId), veh, {
          color = lightColor(M.colorOf(e.rival)), level = rLevel.ground or 0.9, battleLevel = rLevel.battle or 1.4,
          ground = ground, battle = fighting and rc.battle ~= false, sp = fighting and bi.rivalSp or 1,
          rimColor = e.rival.leader and lightColor(c.leaderRimColor or '#ffd257') or nil,
        })
      end
    end
  end

  -- Spieler
  if player then
    local a = playerSettings(save)
    local pe = a.mode ~= 'off' and playerAura(save) or nil
    if pe then
      local lv = levelOf(a.level)
      local ground = a.mode == 'always' and night
      local fighting = inBattle
      if ground or fighting then
        drawAura('p', player, {
          color = lightColor(pe.color), level = lv.ground or 0.9, battleLevel = lv.battle or 1.4,
          ground = ground, battle = fighting, sp = fighting and bi.playerSp or 1,
          rimColor = pe.rim and lightColor(pe.rim) or nil,
        })
      end
    end
  end
  dropUnused()
end

function M.onPreRender(dt)
  local ok, err = pcall(update, dt)
  if not ok then
    log('E', 'Aura: ' .. tostring(err))
    failed = true
    M.clear()
  end
end

function M.onClientEndMission() M.clear() end
function M.onExtensionUnloaded() M.clear() end

return M
