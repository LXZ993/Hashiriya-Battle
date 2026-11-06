-- Hashiriya Battle: Aura = farbiges Licht um das Auto (wie in TXR, vorerst als Licht, Effekte wie Gewitter kommen nach 1.0)
--
-- Sichtbar wird die Aura durch drei Bausteine, die jedem Auto jeden Frame folgen:
--   Hülle   leuchtende, additive Flammen-Hülle ums Auto (TSStatic art/shapes/hashiriya/aura_shell.dae,
--           Farbe pro Auto über instanceColor), pulsiert im Battle
--   Nebel   aufsteigender Leucht-Nebel (ParticleEmitterNode, ein Datablock pro Farbe aus aura.particleData.json)
--   Licht   Punktlichter, die Boden und Lack färben
-- Erzeugt werden Hülle, Texturen und Datablocks von tools/aura/build_aura_assets.py.
-- Zwei Arten:
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
function M.reload() data = nil; failed = false; M.clear(); if M.resetFx then M.resetFx() end end

-- Aura-Editor (Gegner-Garage): Werte live ändern, ohne aura.json zu schreiben (Speichern macht garagetool.lua)
function M.config() return cfg() end
function M.setValue(path, value)
  local c = cfg()
  local t, last = c, nil
  local keys = {}
  for k in tostring(path):gmatch('[^%.]+') do table.insert(keys, k) end
  if #keys == 0 then return false end
  for i = 1, #keys - 1 do
    local k = keys[i]
    if type(t[k]) ~= 'table' then t[k] = {} end
    t = t[k]
  end
  last = keys[#keys]
  t[last] = value
  return true
end

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

-- Hülle und Nebel ----------------------------------------------------------------------------------
local shells = {}      -- [Schlüssel] = { obj = TSStatic }
local hazes = {}       -- [Schlüssel] = { obj = ParticleEmitterNode, emitter = Name }
local dimCache = {}    -- [Fahrzeug-ID] = Maße
local assetsLoaded = false
local shellFailed, hazeFailed = false, false
local SHELL_SHAPE = 'art/shapes/hashiriya/aura_shell.dae'
local FX_DIR = '/settings/hashiriya_battle/aura_fx/'
local SMOKE = 'art/shapes/particles/particle_smoke_soft_01.dds' -- weiche Rauch-Textur des Spiels
local hazeBlocks = {}  -- [Name des Emitters] = true (geladen)

local function loadAssets()
  if assetsLoaded then return end
  assetsLoaded = true
  local ok, err = pcall(loadJsonMaterialsFile, 'art/shapes/hashiriya/aura.materials.json')
  if not ok then log('W', 'Aura: Material nicht geladen: ' .. tostring(err)) end
  hazeBlocks = {}
end

-- Nebel-Stufen: Stärke 1 = voll, kleiner = dünner (weniger Partikel, durchsichtiger). Mit sinkenden SP wird umgeschaltet.
local function hazeLevels()
  local l = (cfg().haze or {}).levels
  if type(l) ~= 'table' or #l == 0 then l = { 1, 0.6, 0.35, 0.15 } end
  return l
end

-- kurze Prüfsumme der Nebel-Werte: ändern sie sich (Aura-Editor), bekommen die Datablocks neue Namen
local function hazeHash(hz)
  local s = string.format('%.2f|%.2f|%.2f|%.2f|%.2f', hz.size or 1, hz.life or 1, hz.rise or 1, hz.alpha or 0.35, hz.rate or 1)
  local h = 0
  for k = 1, #s do h = (h * 31 + s:byte(k)) % 65521 end
  return string.format('%04x', h)
end

-- Datablocks für eine Farbe und Stufe zur Laufzeit anlegen (Datei im Benutzerordner, dann laden)
local function hazeEmitter(hex, lvl)
  loadAssets()
  hex = tostring(hex or ''):gsub('#', ''):lower()
  if #hex ~= 6 or not hex:match('^%x+$') then return nil end
  local hz = cfg().haze or {}
  local hash = hazeHash(hz)
  local en = 'HBAuraE_' .. hex .. '_' .. lvl .. '_' .. hash
  if hazeBlocks[en] then return en end
  local pn = 'HBAuraP_' .. hex .. '_' .. lvl .. '_' .. hash
  local exists = false
  pcall(function() exists = scenetree.findObject(en) ~= nil end)
  if not exists then
    local col = lightColor('#' .. hex)
    local k = hazeLevels()[lvl] or 1
    local a = (hz.alpha or 0.35) * math.min(1, k * 1.2)
    local sz = hz.size or 1
    local life = math.floor(1300 * (hz.life or 1))
    local r, g, b = col[1], col[2], col[3]
    local pdata = { [pn] = {
      name = pn, class = 'ParticleData', textureName = SMOKE, animTexName = SMOKE,
      colors = { { r, g, b, 0 }, { r, g, b, a }, { r, g, b, a * 0.5 }, { r, g, b, 0 } },
      sizes = { 0.4 * sz, 0.8 * sz, 1.2 * sz, 1.5 * sz }, times = { 0, 0.15, 0.6, 1 },
      lifetimeMS = life, lifetimeVarianceMS = math.floor(life * 0.3),
      gravityCoefficient = -0.12 * (hz.rise or 1), dragCoefficient = 2.0, inheritedVelFactor = 0.1,
      spinInitialMax = 360, spinRandomMin = -60, spinRandomMax = 60, spinSpeed = 0.2, useInvAlpha = false,
    } }
    local period = math.floor(45 / math.max(0.1, (hz.rate or 1) * math.max(0.1, k)))
    local edata = { [en] = {
      name = en, class = 'ParticleEmitterData', particles = pn, blendStyle = 'ADDITIVE',
      ejectionPeriodMS = math.max(10, period), periodVarianceMS = math.floor(math.max(10, period) / 3),
      ejectionVelocity = 0.35, velocityVariance = 0.25, ejectionOffset = 0.25,
      thetaMin = 0, thetaMax = 80, phiVariance = 360, alignDirection = { 0, 0, 1 },
      reverseOrder = true, softParticles = '0', useLighting = false,
    } }
    local base = FX_DIR .. hex .. '_' .. lvl .. '_' .. hash
    local ok, err = pcall(function()
      if not FS:directoryExists(FX_DIR) then FS:directoryCreate(FX_DIR, true) end
      jsonWriteFile(base .. '.particleData.json', pdata, false)
      jsonWriteFile(base .. '.emitterData.json', edata, false)
      loadJsonMaterialsFile(base .. '.particleData.json')
      loadJsonMaterialsFile(base .. '.emitterData.json')
    end)
    if not ok then
      log('W', 'Aura-Nebel: Datablock nicht angelegt: ' .. tostring(err))
      return nil
    end
  end
  hazeBlocks[en] = true
  return en
end

local usedFx = {}

-- Achsen-Winkel aus Vorwärts- und Hochrichtung (für das Feld 'rotation' = "x y z Grad")
local function axisAngle(fwd, up)
  local okQ, q = pcall(quatFromDir, fwd, up)
  if not okQ or not q then return '0 0 1 0' end
  local w = math.max(-1, math.min(1, q.w))
  local ang = 2 * math.acos(w)
  local sn = math.sqrt(math.max(0, 1 - w * w))
  if sn < 1e-4 then return '0 0 1 0' end
  return string.format('%.5f %.5f %.5f %.4f', q.x / sn, q.y / sn, q.z / sn, math.deg(ang))
end

local function putShell(key, pos, fwd, up, size, col, alpha)
  if shellFailed then return end
  usedFx['s' .. key] = true
  loadAssets()
  local s = shells[key]
  if not s then
    local ok, obj = pcall(function()
      local o = createObject('TSStatic')
      o:setField('shapeName', 0, SHELL_SHAPE)
      o:setField('collisionType', 0, 'None')
      o:setField('decalType', 0, 'None')
      o.useInstanceRenderData = true
      o:setField('instanceColor', 0, '1 1 1 0')
      o.canSave = false
      nameSeq = nameSeq + 1
      o:registerObject('hashiriyaAuraShell_' .. nameSeq)
      return o
    end)
    if not ok or not obj then
      log('W', 'Aura-Hülle nicht verfügbar: ' .. tostring(obj))
      shellFailed = true
      return
    end
    s = { obj = obj }
    shells[key] = s
  end
  local o = s.obj
  pcall(function()
    o:setPosition(pos)
    o:setField('rotation', 0, axisAngle(fwd, up))
    o:setScale(size)
    -- additiv: Helligkeit steckt in der Farbe (Alpha zählt nicht)
    local k = math.max(0, math.min(1, alpha))
    o:setField('instanceColor', 0, string.format('%.3f %.3f %.3f 1', col[1] * k, col[2] * k, col[3] * k))
    o:updateInstanceRenderData()
  end)
end

local function putHaze(key, pos, hex, lvl)
  if hazeFailed then return end
  local emitter = hazeEmitter(hex, lvl)
  if not emitter then return end
  usedFx['h' .. key] = true
  local h = hazes[key]
  if h and h.emitter ~= emitter then pcall(function() h.obj:delete() end); hazes[key] = nil; h = nil end
  if not h then
    local ok, obj = pcall(function()
      local o = createObject('ParticleEmitterNode')
      o:setField('emitter', 0, emitter)
      o:setField('dataBlock', 0, 'lightExampleEmitterNodeData1')
      o:setField('rotation', 0, '1 0 0 0')
      o.canSave = false
      nameSeq = nameSeq + 1
      o:registerObject('hashiriyaAuraHaze_' .. nameSeq)
      return o
    end)
    if not ok or not obj then
      log('W', 'Aura-Nebel nicht verfügbar: ' .. tostring(obj))
      hazeFailed = true
      return
    end
    h = { obj = obj, emitter = emitter }
    hazes[key] = h
  end
  pcall(function() h.obj:setPosition(pos) end)
end

local function dropUnusedFx()
  for key, s in pairs(shells) do
    if not usedFx['s' .. key] then pcall(function() s.obj:delete() end); shells[key] = nil end
  end
  for key, h in pairs(hazes) do
    if not usedFx['h' .. key] then pcall(function() h.obj:delete() end); hazes[key] = nil end
  end
  usedFx = {}
end

-- Datablocks und Hülle neu laden (aura.json neu laden, neues Level)
function M.resetFx() assetsLoaded, shellFailed, hazeFailed = false, false, false end

local function clearFx()
  for _, s in pairs(shells) do pcall(function() s.obj:delete() end) end
  for _, h in pairs(hazes) do pcall(function() h.obj:delete() end) end
  shells, hazes, usedFx = {}, {}, {}
  dimCache = {}
end

local function dropUnused()
  for key, l in pairs(lights) do
    if not used[key] then
      pcall(function() l.obj:delete() end)
      lights[key] = nil
    end
  end
  dropUnusedFx()
end

function M.clear()
  for _, l in pairs(lights) do pcall(function() l.obj:delete() end) end
  lights = {}
  clearFx()
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

-- Maße des Autos (Länge, Breite, Höhe in Metern), pro Auto gemerkt
local function dims(veh)
  local id = veh:getID()
  local d = dimCache[id]
  if d then return d end
  local l, w, h = 4.4, 1.8, 1.35
  local okE, e = pcall(function() return veh:getSpawnWorldOOBB():getHalfExtents() end)
  if okE and e then
    local t = { math.abs(e.x) * 2, math.abs(e.y) * 2, math.abs(e.z) * 2 }
    table.sort(t)
    if t[1] > 0.3 then l, w, h = t[3], t[2], t[1] end
  end
  d = { l = l, w = w, h = h }
  dimCache[id] = d
  log('I', string.format('Aura: Maße %s: %.2f x %.2f x %.2f m (OOBB %s)', tostring(id), l, w, h, okE and e and string.format('%.2f %.2f %.2f', e.x, e.y, e.z) or '-'))
  return d
end

-- Hülle und Nebel um das Auto
local function drawFx(key, veh, spec, pos, fwd, up, side)
  local c = cfg()
  local sc, hz = c.shell or {}, c.haze or {}
  local d = dims(veh)
  local ground = pos - up * (d.h * 0.5 + 0.05)
  local bt = c.battle or {}
  local spF = (bt.minSpFactor or 0.25) + (1 - (bt.minSpFactor or 0.25)) * math.max(0, math.min(1, spec.sp or 1))
  if sc.enabled ~= false then
    local alpha, hgt
    if spec.battle then
      local pulse = 1 - (sc.pulseDepth or 0.3) * (0.5 + 0.5 * math.sin(clock * (bt.pulseSpeed or 2.2) * math.pi))
      alpha = (sc.battle or 0.85) * (spec.battleLevel / 1.4) * spF * pulse
      hgt = d.h * (sc.battleHeight or 1.7)
    else
      alpha = (sc.ground or 0.4) * (spec.level / 0.9)
      hgt = d.h * (sc.height or 1.15)
    end
    local fl = sc.flicker or 0.12
    alpha = alpha * (1 - fl * (0.5 + 0.25 * math.sin(clock * 11.3) + 0.25 * math.sin(clock * 17.9 + 1.7)))
    local size = vec3(d.w * 0.5 * (sc.widthPad or 1.1) + 0.08, d.l * 0.5 * (sc.lengthPad or 1.0) + 0.08, hgt)
    putShell(key, ground, fwd, up, size, spec.color, alpha)
  end
  -- Stärke des Nebels: Stufe der Aura, im Battle mal SP; daraus die passende Nebel-Stufe
  local strength
  if spec.battle then strength = (spec.battleLevel / 1.4) * spF else strength = (spec.level / 0.9) * (hz.groundAmount or 0.6) end
  strength = strength * (hz.amount or 1)
  local lvl = nil
  local levels = hazeLevels()
  for li = 1, #levels do
    if strength >= levels[li] * 0.85 then lvl = li; break end
  end
  if not lvl and strength >= levels[#levels] * 0.4 then lvl = #levels end
  if hz.enabled ~= false and lvl and spec.hex and (spec.battle or hz.ground ~= false) then
    local n = spec.battle and (hz.battlePoints or 4) or (hz.groundPoints or 2)
    local fl, sw = d.l * 0.5 * 0.8, d.w * 0.5 * 0.9
    local pts
    if n >= 4 then
      pts = { fwd * fl + side * sw, fwd * fl - side * sw, fwd * (-fl) + side * sw, fwd * (-fl) - side * sw }
    else
      pts = { side * sw, side * (-sw) }
    end
    for i, off in ipairs(pts) do
      local hex = spec.hex
      if spec.rimHex and i > 2 then hex = spec.rimHex end
      putHaze(key .. ':' .. i, ground + off + up * 0.1, hex, lvl)
    end
  end
end

-- spec: { color = {r,g,b}, hex = '#rrggbb', level = Faktor, ground = bool, battle = bool, sp = 0..1,
--         rimColor = {r,g,b}, rimHex = '#rrggbb' }
local function drawAura(key, veh, spec)
  local c = cfg()
  local pos, fwd, up, side = frame(veh)
  if spec.ground or spec.battle then drawFx(key, veh, spec, pos, fwd, up, side) end
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
  if type(rival.aura) == 'string' and rival.aura ~= '' then return rival.aura end
  if c.colors and c.colors[id] then return c.colors[id] end
  local team = rival.team or rival.stageTeam -- Stufen ehemaliger Crew-Mitglieder: Farbe der alten Crew
  if team then
    local t = teamOf(team)
    if t and t.color then return t.color end
  end
  return c.defaultColor or '#ff6600'
end

-- Hat dieser Rivale eine Aura? Eigene Angabe in rivals.json ("auraOn": true/false) gewinnt,
-- sonst die Regel aus aura.json "who" (wie in TXR 2025 nur wenige: standardmäßig nur Bosse)
local function roleOf(rival)
  if rival.boss then return 'boss' end
  if rival.wanderer then return 'wanderer' end
  if rival.leader then return 'leader' end
  return 'member'
end
M.roleOf = roleOf

function M.defaultOn(rival)
  local who = cfg().who
  if type(who) ~= 'table' then return true end
  return who[roleOf(rival)] == true
end

function M.hasAura(rival)
  if not rival then return false end
  if rival.auraOn == true or rival.auraOn == false then return rival.auraOn end
  return M.defaultOn(rival)
end

-- Farbe ohne eigene Angabe beim Rivalen (Crew-, Siegel- oder Standardfarbe)
function M.defaultColorOf(rival)
  if not rival then return nil end
  local c = cfg()
  local id = rival.baseId or rival.id
  if c.colors and c.colors[id] then return c.colors[id] end
  local team = rival.team or rival.stageTeam -- Stufen ehemaliger Crew-Mitglieder: Farbe der alten Crew
  if team then
    local t = teamOf(team)
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
    -- Crew-Aura nur, wenn mindestens ein Mitglied (ohne Leader) eine Aura hat; frei nach dem Sieg gegen so eines
    local hasMember, anyMember, leader = false, false, nil
    for _, r in ipairs(d.rivals or {}) do
      if r.team == t.id then
        if r.leader then leader = r
        elseif M.hasAura(r) then
          hasMember = true
          if defeated[r.id] then anyMember = true end
        end
      end
    end
    if hasMember then
      table.insert(list, { id = 'c:' .. t.id, kind = 'crew', name = loc(t.name), color = t.color or c.defaultColor,
        unlocked = anyMember, team = t.id, logo = rivals().teamLogo(t.id, false, true) })
    end
    if leader and M.hasAura(leader) then
      table.insert(list, { id = 'l:' .. t.id, kind = 'leader', name = loc(t.name), color = M.colorOf(leader) or t.color or c.defaultColor,
        rim = c.leaderRimColor, unlocked = defeated[leader.id] and true or false, team = t.id,
        source = leader, logo = rivals().teamLogo(t.id, true, true) })
    end
  end
  for _, kind in ipairs({ 'wanderer', 'boss' }) do
    for _, r in ipairs(d.rivals or {}) do
      if ((kind == 'boss' and r.boss) or (kind == 'wanderer' and r.wanderer and not r.boss)) and M.hasAura(r) then
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
        color = lightColor(preview.color), hex = preview.color, rimHex = preview.rim, level = (lv.ground or 0.9) * boost, battleLevel = (lv.battle or 1.4) * boost,
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
    if veh and e.rival and M.hasAura(e.rival) then
      local near = not ppos or (veh:getPosition() - ppos):length() < (rc.maxDistance or 220)
      local fighting = inBattle and bi.rival == e.rival
      local ground = rc.ground ~= false and (night or rc.groundOnlyNight == false)
      if near and (ground or (fighting and rc.battle ~= false)) then
        local lv = e.rival.auraLevel and levelOf(math.max(1, math.min(3, tonumber(e.rival.auraLevel) or 2))) or rLevel
        drawAura('r' .. tostring(e.vehId), veh, {
          color = lightColor(M.colorOf(e.rival)), hex = M.colorOf(e.rival), rimHex = e.rival.leader and (c.leaderRimColor or '#ffd257') or nil, level = lv.ground or 0.9, battleLevel = lv.battle or 1.4,
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
          color = lightColor(pe.color), hex = pe.color, rimHex = pe.rim, level = lv.ground or 0.9, battleLevel = lv.battle or 1.4,
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

function M.onClientEndMission() M.clear(); M.resetFx() end
function M.onExtensionUnloaded() M.clear() end

return M
