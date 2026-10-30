-- Hashiriya Battle: japanische Kennzeichen (Agent's Japanese Plates Pack)
-- Text: genau 9 Zeichen, 4 oben (mit "/"), 5 unten, z. B. "330/12-34", "12//12-34", "330/.. .7".
-- Design: Teil im Slot licenseplate_design_2_1, z. B. am5jp_shinagawa_standard.
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end

M.slot = 'licenseplate_design_2_1'
M.regions = { 'shinagawa', 'sapporo', 'toyota', 'shizuoka', 'himeji', 'kochi', 'kumamoto', 'kagoshima', 'okinawa' }
M.types = { 'standard', 'kei', 'commercial', 'keicommercial' }
-- Sonderkennzeichen der Mod gibt es nur in einer Region; Okinawa hat nur das US-Air-Force-Kennzeichen
M.specialTypes = {
  shinagawa = { 'temporary', 'glow', 'olympic', 'olympiccommercial' },
  okinawa = { 'airforce' },
}
M.onlySpecial = { okinawa = true }
M.defaultDesign = 'am5jp_shinagawa_standard'

-- Erlaubte Arten einer Region (Reihenfolge wie in der Auswahl)
function M.typesFor(region)
  local out = {}
  if not M.onlySpecial[region] then
    for _, k in ipairs(M.types) do table.insert(out, k) end
  end
  for _, k in ipairs(M.specialTypes[region] or {}) do table.insert(out, k) end
  return out
end

function M.design(region, kind)
  return 'am5jp_' .. (region or 'shinagawa') .. '_' .. (kind or 'standard')
end

function M.splitDesign(design)
  local region, kind = tostring(design or ''):match('^am5jp_([a-z]+)_([a-z]+)$')
  return region or 'shinagawa', kind or 'standard'
end

function M.validDesign(design)
  local region, kind = tostring(design or ''):match('^am5jp_([a-z]+)_([a-z]+)$')
  if not region then return false end
  local okR = false
  for _, r in ipairs(M.regions) do if r == region then okR = true end end
  if not okR then return false end
  for _, k in ipairs(M.typesFor(region)) do if k == kind then return true end end
  return false
end

-- Region oder Art geändert: passt die Art nicht zur Region, nimmt sie die erste erlaubte (Okinawa -> Air Force,
-- zurück von einem Sonderkennzeichen -> Privat)
function M.fitDesign(region, kind)
  local allowed = M.typesFor(region)
  for _, k in ipairs(allowed) do if k == kind then return M.design(region, kind) end end
  return M.design(region, allowed[1] or 'standard')
end

-- Untere Zeile aus einer Zahl 1-9999: "12-34", kleine Nummern mit Punkten ("・・・7" = ".. .7", "・123" = ".1 23")
local function bottomFromNumber(n)
  n = math.floor(tonumber(n) or 0)
  if n < 1 or n > 9999 then return nil end
  local digits = string.format('%4d', n):gsub(' ', '.')
  if n >= 1000 then return digits:sub(1, 2) .. '-' .. digits:sub(3, 4) end
  return digits:sub(1, 2) .. ' ' .. digits:sub(3, 4)
end

-- Eingabe prüfen und ins Plates-Pack-Format bringen. Rückgabe: Text oder nil
-- Erlaubt: "330/12-34" (fertig), "330 1234", "330 7", "3301234", "12 1234"
function M.normalize(text)
  text = tostring(text or ''):gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
  if text == '' then return nil end
  -- schon im fertigen Format?
  if #text == 9 and text:match('^[%dXx&][%dXx&][%dXx&/]/[%d%.Xx&][%d%.Xx&][%- ][%d%.Xx&][%d%.Xx&]$') then return text end
  local top, bottom = text:match('^([%dXx]+)[/ ]+(.+)$')
  if not top then
    local digits = text:gsub('[^%d]', '')
    if #digits >= 5 and #digits <= 7 then top, bottom = digits:sub(1, #digits - 4), digits:sub(-4) end
  end
  if not top or #top < 2 or #top > 3 then return nil end
  local b = bottom:gsub('%s', '')
  local out
  if b:match('^%d%d%-%d%d$') then out = b
  elseif b:match('^%d+$') then out = bottomFromNumber(b)
  elseif #bottom == 5 and bottom:match('^[%d%.][%d%.][%- ][%d%.][%d%.]$') then out = bottom end
  if not out then return nil end
  return (#top == 3 and (top .. '/') or (top .. '//')) .. out
end

-- Zufallskennzeichen: Klassennummer 300-399 oder 500-599, meist vierstellig, manchmal kleine Wunschnummer
function M.random(rand)
  rand = rand or math.random
  local top = (rand() < 0.6 and 300 or 500) + math.floor(rand() * 100)
  local n
  if rand() < 0.2 then
    local picks = { 1, 3, 7, 8, 11, 22, 33, 55, 77, 88, 99, 123, 555, 777, 888 }
    n = picks[math.floor(rand() * #picks) + 1]
  else
    n = 1000 + math.floor(rand() * 9000)
  end
  return string.format('%03d/', top) .. bottomFromNumber(n)
end

-- Design in eine Config schreiben. config = .pc-Pfad oder Tabelle {parts, vars, paints}; Rückgabe: Tabelle (oder das Original, wenn nicht lesbar)
function M.applyToConfig(config, design)
  design = M.validDesign(design) and design or M.defaultDesign
  local cfg = config
  if type(config) == 'string' and config ~= '' then
    local pc = jsonReadFile(config:sub(1, 1) == '/' and config or ('/' .. config))
    if not pc or type(pc.parts) ~= 'table' then
      log('W', logTag, 'Kennzeichen: Config nicht lesbar: ' .. config)
      return config
    end
    cfg = { parts = {}, vars = {}, paints = pc.paints }
    for k, v in pairs(pc.parts) do cfg.parts[k] = v end
    for k, v in pairs(pc.vars or {}) do cfg.vars[k] = v end
  end
  if type(cfg) ~= 'table' then return config end
  cfg.parts = cfg.parts or {}
  local set = false
  for k in pairs(cfg.parts) do
    if type(k) == 'string' and (k == M.slot or k:match('/' .. M.slot .. '/?$')) then cfg.parts[k] = design; set = true end
  end
  if not set then cfg.parts[M.slot] = design end
  return cfg
end

-- Für die UI: Regionen und Arten mit Anzeigenamen. types = Arten der Region `region` (ohne: alle);
-- byRegion = erlaubte Art-IDs je Region (Garage blättert damit im Browser)
function M.uiOptions(t, region)
  local regions, kinds, byRegion, names = {}, {}, {}, {}
  for _, r in ipairs(M.regions) do
    table.insert(regions, { id = r, name = t('plate.region.' .. r) })
    byRegion[r] = M.typesFor(r)
  end
  local list = region and M.typesFor(region) or nil
  if not list then
    list = {}
    for _, k in ipairs(M.types) do table.insert(list, k) end
    for _, r in ipairs(M.regions) do for _, k in ipairs(M.specialTypes[r] or {}) do table.insert(list, k) end end
  end
  for _, k in ipairs(list) do table.insert(kinds, { id = k, name = t('plate.type.' .. k) }) end
  for _, r in ipairs(M.regions) do for _, k in ipairs(byRegion[r]) do names[k] = t('plate.type.' .. k) end end
  return { regions = regions, types = kinds, byRegion = byRegion, typeNames = names }
end

return M
