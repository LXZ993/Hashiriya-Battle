if SEED then math.randomseed(SEED) end
-- Offline-Test für lua/vehicle/extensions/hashiriyaDriver.lua (ohne BeamNG)
-- Start: python3 tools/driver-sim/run.py [szenario]
-- Baut eine Teststrecke (Straßennetz wie mapmgr), simuliert ein einfaches Fahrzeugmodell und Verkehr
-- und prüft: bleibt der Fahrer auf der Straße, fährt er in Verkehr, wie schnell ist er.

local SCEN = SCENARIO or 'highway'

-- vec3 ---------------------------------------------------------------------------------
local V = {}
V.__index = V
function vec3(x, y, z)
  if type(x) == 'table' then return setmetatable({ x = x.x, y = x.y, z = x.z }, V) end
  return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V)
end
V.__add = function(a, b) return vec3(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__mul = function(a, b)
  if type(a) == 'number' then return vec3(b.x * a, b.y * a, b.z * a) end
  return vec3(a.x * b, a.y * b, a.z * b)
end
function V:set(x, y, z)
  if type(x) == 'table' then self.x, self.y, self.z = x.x, x.y, x.z else self.x, self.y, self.z = x, y, z end
end
function V:dot(b) return self.x * b.x + self.y * b.y + self.z * b.z end
function V:length() return math.sqrt(self:dot(self)) end
function V:normalize() local l = self:length() if l > 1e-12 then self.x, self.y, self.z = self.x / l, self.y / l, self.z / l end end
function V:normalized() local c = vec3(self) c:normalize() return c end
function V:distance(b) return (self - b):length() end
function V:squaredDistance(b) local d = self - b return d:dot(d) end
function V:setCross(a, b) self.x, self.y, self.z = a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x end
function V:xnormOnLine(a, b)
  local ab = b - a
  return (self - a):dot(ab) / math.max(ab:dot(ab), 1e-30)
end

table.clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end
function nop() end
function tableSizeC(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
function log(l, tag, msg) print('[' .. l .. '] ' .. tag .. ': ' .. msg) end
function color(r, g, b, a) return { r, g, b, a } end
objectId = 1

-- Strecke ---------------------------------------------------------------------------------
-- Knoten alle 15 m; Abschnitte: gerade / Bogen. Breite über radius (halbe Breite).
local positions, radius, graph = {}, {}, {}
local nodeCount = 0
local function addNode(p, r)
  nodeCount = nodeCount + 1
  positions[nodeCount] = p
  radius[nodeCount] = r
  graph[nodeCount] = graph[nodeCount] or {}
  return nodeCount
end
local function link(a, b, oneWay, lanes)
  local e = { inNode = a, outNode = b, oneWay = oneWay, lanes = lanes, drivability = 1, len = positions[a]:distance(positions[b]) }
  graph[a][b] = e
  graph[b][a] = e
end

local function buildTrack(pieces, halfWidth, oneWay, lanes, start, heading)
  local pos = start or vec3(0, 0, 0)
  local h = heading or math.pi / 2 -- Richtung (Winkel), pi/2 = +y
  local prev = addNode(vec3(pos), halfWidth)
  local first = prev
  for _, pc in ipairs(pieces) do
    local len, rad = pc[1], pc[2] -- rad: Kurvenradius, + = rechts, nil = gerade
    local steps = math.max(1, math.floor(len / 15))
    for i = 1, steps do
      local ds = len / steps
      if rad then
        h = h - ds / rad
      end
      pos = pos + vec3(math.cos(h) * ds, math.sin(h) * ds, 0)
      local n = addNode(vec3(pos), halfWidth)
      link(prev, n, oneWay, lanes)
      prev = n
    end
  end
  return first, prev
end

local tracks = {
  -- Stadtautobahn: 3 Spuren eine Richtung, Kurven 150 m / 90 m, S-Kurve
  highway = { pieces = { { 300 }, { 235, 150 }, { 200 }, { 140, -90 }, { 120, 90 }, { 400 }, { 300, 200 }, { 600 } }, half = 5.6, oneWay = true, lanes = '+++' },
  -- Touge: eine Spur je Richtung, enge Kehren
  touge = { pieces = { { 150 }, { 90, 40 }, { 60 }, { 110, -35 }, { 80 }, { 70, 30 }, { 50, -45 }, { 200 } }, half = 3.6, oneWay = false, lanes = '-+' },
}
local T = tracks[SCEN] or tracks.highway
local firstNode, lastNode = buildTrack(T.pieces, T.half, T.oneWay, T.lanes)

-- Mittellinie zum Prüfen (dicht abgetastet)
local center = {}
do
  for i = firstNode, lastNode - 1 do
    local a, b = positions[i], positions[i + 1]
    for k = 0, 9 do center[#center + 1] = a + (b - a) * (k / 10) end
  end
end
local function nearestCenter(p)
  local best, bi = math.huge, 1
  for i = 1, #center, 1 do
    local d = (center[i].x - p.x) ^ 2 + (center[i].y - p.y) ^ 2
    if d < best then best, bi = d, i end
  end
  local a = center[bi]
  local b = center[math.min(bi + 1, #center)]
  if bi == #center then a, b = center[bi - 1], center[bi] end
  local t = b - a t.z = 0 t:normalize()
  local rightV = vec3(t.y, -t.x, 0)
  return (p - a):dot(rightV), bi / #center, t
end

-- mapmgr -----------------------------------------------------------------------------------
local mapDataObj = { graph = graph, positions = positions, radius = radius }
function mapDataObj:getEdgePositions(a, b) return positions[a], positions[b] end
function mapDataObj:getEdgeRadii(a, b) return radius[a], radius[b] end

local objects = {}
mapmgr = {
  mapData = mapDataObj,
  objects = objects,
  rules = { rightHandDrive = true },
  getObjects = function(_) return objects end,
  requestMap = nop,
}
local function closest(pos)
  local best, ba, bb = math.huge, nil, nil
  for a, nb in pairs(graph) do
    for b in pairs(nb) do
      if a < b then
        local pa, pb = positions[a], positions[b]
        local xn = math.min(math.max(pos:xnormOnLine(pa, pb), 0), 1)
        local q = pa + (pb - pa) * xn
        local d = q:squaredDistance(pos)
        if d < best then best, ba, bb = d, a, b end
      end
    end
  end
  return ba, bb, math.sqrt(best)
end
mapmgr.findClosestRoad = closest
mapmgr.findBestRoad = function(pos, dir) return closest(pos) end

-- Fahrzeug (Ego) --------------------------------------------------------------------------
local car = { pos = vec3(0, 5, 0), h = math.pi / 2, v = 22, steer = 0, len = 4.5, wid = 1.9, wb = 2.6 }
if SCEN == 'touge' then car.pos = vec3(1.8, 5, 0) car.v = 15 end
local inputs = { steering = 0, throttle = 0, brake = 0, parkingbrake = 0 }
input = { event = function(name, val) inputs[name] = val end }
wheels = { wheels = {} }
controller = { mainController = { setGearboxMode = nop } }
electrics = { values = { gearboxMode = 'arcade' } }

local function dirV() return vec3(math.cos(car.h), math.sin(car.h), 0) end
local function frontPos() return car.pos + dirV() * (car.len * 0.5) end

obj = {
  getFrontPositionXYZ = function(_) local f = frontPos() return f.x, f.y, f.z end,
  getDirectionVectorXYZ = function(_) local d = dirV() return d.x, d.y, d.z end,
  getDirectionVectorUpXYZ = function(_) return 0, 0, 1 end,
  getSmoothRefVelocityXYZ = function(_) local d = dirV() return d.x * car.v, d.y * car.v, 0 end,
  getStaticFrictionCoef = function(_) return 1.05 end,
  getInitialWidth = function(_) return car.wid end,
  getInitialLength = function(_) return car.len end,
  getObjectCenterPosition = function(_, id) return vec3(objects[id].pos) end,
  getObjectInitialLength = function(_, id) return objects[id].len end,
  getObjectInitialWidth = function(_, id) return objects[id].wid end,
  queueGameEngineLua = function(_, s) print('GE: ' .. s) end,
  debugDrawProxy = { drawSphere = nop },
}

-- Verkehr: fährt auf festen Querlagen mit konstantem Tempo
local traffic = {}
local function addTraffic(id, sFrac, lat, speed, laneChangeAt, newLat)
  traffic[#traffic + 1] = { id = id, idx = math.floor(sFrac * #center), lat = lat, speed = speed, lca = laneChangeAt, newLat = newLat, len = 4.6, wid = 1.85 }
end
if SCEN == 'highway' then
  -- Spuren bei -3.7 / 0 / +3.7
  addTraffic(2, 0.04, 0, 16)
  addTraffic(3, 0.07, -3.7, 17)
  addTraffic(4, 0.10, 3.7, 15)
  addTraffic(5, 0.13, 0, 15)
  addTraffic(6, 0.13, -3.7, 16) -- zwei nebeneinander: Lücke nur rechts
  addTraffic(7, 0.22, 0, 18, 0.24, 3.7) -- wechselt die Spur
  addTraffic(8, 0.30, -3.7, 14)
  addTraffic(9, 0.30, 0, 14)
  addTraffic(10, 0.30, 3.7, 14) -- Wand aus drei Autos
  addTraffic(11, 0.45, 0, 20)
  addTraffic(12, 0.55, 3.7, 17)
  addTraffic(13, 0.60, -3.7, 18)
  addTraffic(14, 0.70, 0, 19)
elseif SCEN == 'touge' then
  addTraffic(2, 0.15, 1.8, 11)
  addTraffic(3, 0.35, -1.8, -12) -- Gegenverkehr
  addTraffic(4, 0.55, 1.8, 10)
  addTraffic(5, 0.65, -1.8, -12)
end

local function trafficPos(t)
  local i = math.min(math.max(math.floor(t.idx), 1), #center - 1)
  local a, b = center[i], center[i + 1]
  local frac = t.idx - math.floor(t.idx)
  local p = a + (b - a) * frac
  local tt = b - a tt.z = 0 tt:normalize()
  local r = vec3(tt.y, -tt.x, 0)
  return p + r * t.lat, tt
end
local segLen = 1.5 -- center: Knoten alle ~15 m / 10
local function updateTraffic(dt)
  for _, t in ipairs(traffic) do
    t.idx = t.idx + t.speed * dt / segLen
    local frac = t.idx / #center
    if t.lca and frac > t.lca then
      local d = t.newLat - t.lat
      t.lat = t.lat + math.max(-1.2 * dt, math.min(1.2 * dt, d))
    end
    local p, tt = trafficPos(t)
    objects[t.id] = objects[t.id] or { pos = vec3(), vel = vec3(), dirVec = vec3() }
    local o = objects[t.id]
    o.pos = p
    o.vel = tt * t.speed
    o.len, o.wid = t.len, t.wid
  end
end

-- Laden und fahren -----------------------------------------------------------------------
local D = dofile(DRIVER_PATH)
updateTraffic(0)
local sp = { skill = SKILL or 0.6, courage = COURAGE or 0.7, targetId = -1 }
for k, v in pairs(EXTRA or {}) do sp[k] = v end
D.start(sp)

local dt = 1 / 60
local t = 0
local maxLat, minClear, contacts = 0, math.huge, 0
local touching = {}
local speeds = {}
local finished = false
local log2 = {}
while t < 120 do
  updateTraffic(dt)
  D.updateGFX(dt)
  -- Fahrzeugmodell (Fahrrad), Grip begrenzt Querbeschleunigung
  local maxAngle = MAXANGLE or 0.55
  local delta = inputs.steering * maxAngle
  local mu = 1.05 * 9.81
  local yawRate = car.v * math.tan(delta) / car.wb
  local aLat = math.abs(yawRate * car.v)
  if aLat > mu then yawRate = yawRate * mu / aLat end -- Untersteuern
  car.h = car.h - yawRate * dt -- positive Lenkung = rechts
  local acc = inputs.throttle * (car.v < 30 and 5 or 3) - inputs.brake * 9.8 - 0.0004 * car.v * car.v - 0.3
  if inputs.throttle == 0 and inputs.brake == 0 then acc = acc - 0.9 end -- Motorbremse
  car.v = math.max(0, car.v + acc * dt)
  car.pos = car.pos + dirV() * (car.v * dt)
  t = t + dt

  local lat, frac = nearestCenter(car.pos)
  do
    local pl = D._internal.getPlan()
    if pl and pl.n > 3 then
      local fp = frontPos()
      local bd, bk = math.huge, 1
      for k = 1, math.min(pl.n, 20) do
        local d = (pl.px[k] - fp.x) ^ 2 + (pl.py[k] - fp.y) ^ 2
        if d < bd then bd, bk = d, k end
      end
      local k2 = math.min(bk + 1, pl.n)
      if k2 == bk then bk = bk - 1 end
      local ax, ay = pl.px[bk], pl.py[bk]
      local bx, by = pl.px[k2], pl.py[k2]
      local tx, ty = bx - ax, by - ay
      local l = math.sqrt(tx * tx + ty * ty)
      bd = l > 1e-6 and (((fp.x - ax) * ty - (fp.y - ay) * tx) / l) ^ 2 or bd
      trackSq = (trackSq or 0) + bd
      trackN = (trackN or 0) + 1
      trackMax = math.max(trackMax or 0, math.sqrt(bd))
    end
  end
  local edge = T.half - car.wid * 0.5
  if math.abs(lat) > edge and math.abs(lat) - edge > maxLat then maxLat = math.abs(lat) - edge; maxLatT = t end
  -- Kontakt mit Verkehr (Rechtecke grob als Längs/Quer-Abstand)
  for _, tr in ipairs(traffic) do
    local o = objects[tr.id]
    local d = o.pos - car.pos
    local fwd = dirV()
    local along = math.abs(d:dot(fwd))
    local side = math.abs(d:dot(vec3(fwd.y, -fwd.x, 0)))
    local clearL = along - (tr.len + car.len) * 0.5
    local clearS = side - (tr.wid + car.wid) * 0.5
    if clearL < 0 and clearS < minClear then minClear = clearS; minClearT = t; minClearId = tr.id end
    if clearL < 0 and clearS < 0 then
      if not touching[tr.id] then contacts = contacts + 1 touching[tr.id] = true
        log2[#log2 + 1] = string.format('KONTAKT t=%.1f mit %d (v=%.0f km/h)', t, tr.id, car.v * 3.6) end
    else
      touching[tr.id] = nil
    end
  end
  if TRACE_FROM and t >= TRACE_FROM and t <= TRACE_TO and math.floor(t * 4) ~= math.floor((t - dt) * 4) then
    local pl = D._internal.getPlan()
    if pl then
      local parts = {}
      for _, ob in ipairs(pl.obstacles) do
        parts[#parts + 1] = string.format('#%d s=%.0f d=%.1f side=%s tM=%s', ob.id, ob.s, ob.d, tostring(ob.side), ob.tMeet and string.format('%.1f', ob.tMeet) or '-')
      end
      local caps = {}
      for _, c in ipairs(pl.followCaps or {}) do caps[#caps + 1] = string.format('%.0fm:%.0f', c.s, c.v * 3.6) end
      print(string.format('TRACE front=%.2f hdg=%.1f p3sim=%.2f t=%.2f v=%.0f lat=%.2f off3=%.2f lo3=%.2f hi3=%.2f ttc=%.2f caps[%s] %s', (nearestCenter(frontPos())), (function() local _, _, tt = nearestCenter(car.pos) local d = dirV() return math.deg(math.asin(d.x * tt.y - d.y * tt.x)) end)(), (nearestCenter(vec3(pl.px[3], pl.py[3], 0))), t, car.v * 3.6, (nearestCenter(car.pos)), pl.off[3], pl.lo[3], pl.hi[3], pl.ttc, table.concat(caps, ' '), table.concat(parts, ' | ')))
    end
  end
  if math.floor(t * 2) ~= math.floor((t - dt) * 2) then
    speeds[#speeds + 1] = string.format('t=%5.1f s=%3.0f%% v=%5.1f km/h lat=%5.2f steer=%5.2f thr=%.2f brk=%.2f', t, frac * 100, car.v * 3.6, lat, inputs.steering, inputs.throttle, inputs.brake)
  end
  if frac > 0.985 then finished = true break end
end

for _, s in ipairs(speeds) do print(s) end
for _, s in ipairs(log2) do print(s) end
print(string.format('  Spurtreue: mittlere Abweichung von der Linie %.2f m, max %.2f m', math.sqrt((trackSq or 0) / math.max(trackN or 1, 1)), trackMax or 0))
print(string.format('  Rand bei t=%s, engster Abstand bei t=%s zu #%s', tostring(maxLatT), tostring(minClearT), tostring(minClearId)))
print(string.format('ERGEBNIS %s: Zeit %.1f s, Ziel %s, max. über Rand %.2f m, Kontakte %d, engster Seitenabstand %.2f m',
  SCEN, t, finished and 'erreicht' or 'NICHT erreicht', maxLat, contacts, minClear))
