-- Hashiriya Battle: Tuning-Shop und Garagen-PC (HashiNet Teile-Terminal)
-- Welche Teile es gibt, kommt zur Laufzeit aus BeamNG: jeder Slot des Spielerautos mit Auswahl wird eine
-- Zeile im Katalog. data/tuning.json ordnet die Slots Kategorien zu (Lua-Muster auf den Slot-Namen) und legt
-- fest, welche Stufe (LV1-3) ein Teil bekommt und ab welchem Rang eine Stufe gekauft werden darf.
-- Gekaufte Teile bleiben im Besitz (car.owned); Serienteile (car.stock) sind ebenfalls Besitz.
-- Felgen werden ohne Reifen verkauft: passende eigene Reifen werden aufgezogen, sonst bleibt der Reifen-Slot leer.
-- Die Oberfläche ist die UI-App HashiriyaTerminal im eigenen Layout "hashiriyaShop".
local M = {}

local logTag = 'hashiriya'
-- Meldungen gehen ins BeamNG-Log und zusätzlich in settings/hashiriya_battle/logs/hashiriya.log (logger.lua)
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
local rulesPath = '/lua/ge/extensions/hashiriyaBattle/data/tuning.json'

local rules = nil
local catalog = nil        -- { vehId, rows = { ... }, bySlot = { [slot] = row } }
local catVersion = 0       -- steigt bei jeder Änderung; die UI holt den Katalog dann neu
local retryTimer = 0
local warnedNoConfig = false

-- Terminal-Zustand
local terminal = nil       -- nil | 'shop' | 'garage'
local termCat = 'engine'
local view = 'part'        -- 'part' = Kamera folgt dem Teil unter der Maus, 'car' = ganzes Auto
local xray = false         -- Rest des Autos durchsichtig
local camYaw = nil         -- Drehung der Vorschau-Kamera (Grad), nil = BeamNG-Standard
local camTimer = 0

local function core() return extensions.hashiriyaBattle_core end
local function bump() catVersion = catVersion + 1 end

function M.loadData()
  rules = jsonReadFile(rulesPath) or { tiers = {}, categories = {}, levelWords = {}, exclude = {}, overrides = {} }
  catalog = nil
  bump()
end

local function activeCar()
  local save = core().save
  return save and save.cars[save.activeCar or 1] or nil
end

-- Hilfen -----------------------------------------------------------------------

local function tokens(str)
  local out = {}
  for w in tostring(str or ''):lower():gmatch('[%w]+') do out[w] = true end
  return out
end

local function lastSegment(key)
  return (key:gsub('/+$', ''):match('([^/]+)$')) or key
end

-- Anzeigename aus den jbeam-Infos (Markenteile haben {txt=..., ctx={brand1=...}}).
local function niceName(desc, partName)
  if type(desc) == 'string' and desc ~= '' then return desc end
  if type(desc) == 'table' then
    local txt = tostring(desc.txt or desc[1] or '')
    txt = txt:match('([^%.]+)$') or txt
    local brand = desc.ctx and desc.ctx.brand1
    if brand then txt = txt:gsub('BRAND', (tostring(brand):match('([^%.]+)$') or brand)) end
    if txt ~= '' then return txt end
  end
  return partName
end

local function anyMatch(str, list)
  for _, pat in ipairs(list or {}) do
    if str:find(pat) then return true end
  end
  return false
end

local function slotExcluded(slot) return anyMatch(slot, rules.slotExclude) end

-- Slots, die nie im Katalog auftauchen (auch nicht unter "Alle Teile")
local function slotHidden(slot)
  return slot:find('licenseplate') ~= nil or slot:find('skin') ~= nil
end

-- Kategorie eines Slots: erste Kategorie, deren Muster passt; Rest = 'other'.
local function categoryOf(slot)
  if slot == 'paint_design' then return 'paint', nil end
  local s = slot:lower()
  local fallback = nil
  for _, c in ipairs(rules.categories or {}) do
    if c.id == 'other' then fallback = c
    elseif c.match and anyMatch(s, c.match) then return c.id, c end
  end
  return 'other', fallback
end

local function partLevel(partName, display, defaultLevel)
  local o = rules.overrides and rules.overrides[partName]
  if o ~= nil then return o end
  local tk = tokens(partName) -- Teilename in Wörter zerlegen (Trenner: _ . Leerzeichen)
  for w in pairs(tokens(display)) do tk[w] = true end
  for _, ex in ipairs(rules.exclude or {}) do
    if tk[ex:lower()] then return 0 end
  end
  for lv = 3, 1, -1 do
    for _, w in ipairs((rules.levelWords or {})[tostring(lv)] or {}) do
      if tk[w:lower()] then return lv end
    end
  end
  return defaultLevel or 1
end

-- Stufen verteilen (levelSpread in tuning.json): Die Wörter geben nur die Klasse 1-3. Innerhalb eines Slots
-- werden die Teile nach Klasse und Preis sortiert und gleichmäßig auf LV1..levels verteilt (billig früh, teuer spät).
-- bands begrenzt jede Klasse auf einen Bereich, damit z. B. Rennteile (Klasse 3) nie vor LV4 kommen.
-- Erwartet die Liste schon nach Klasse, dann Preis sortiert. Ohne levelSpread bleibt Stufe = Klasse.
local function spreadLevels(options)
  local sp = rules.levelSpread
  if type(sp) ~= 'table' or #options == 0 then return end
  local levels = tonumber(sp.levels) or 6
  local bands = sp.bands or {}
  local k = #options
  for i, o in ipairs(options) do
    local band = bands[tostring(o.level)] or { 1, levels }
    local lo, hi = tonumber(band[1]) or 1, tonumber(band[2]) or levels
    local lv = (k > 1) and math.ceil((i - 0.5) / k * levels) or lo
    o.cls = o.level
    o.level = math.min(math.max(lv, lo), hi)
  end
  -- nach der neuen Stufe sortieren, innerhalb der Stufe nach Preis
  table.sort(options, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return a.price < b.price
  end)
end

local function tierInfo(level)
  for _, t in ipairs(rules.tiers or {}) do
    if t.level == level then return t end
  end
  return { level = level, unlock = {} }
end

local function rankName(index)
  local pr = extensions.hashiriyaBattle_progress
  local r = (extensions.hashiriyaBattle_rivals.getData().ranks or {})[index + 1]
  return r and pr.loc(r.name) or tostring(index + 1)
end

-- Stufe freigeschaltet? Zweiter Wert = Text, was fehlt (Rang oder Siege)
local function isUnlocked(level)
  local c = core()
  local unlock = tierInfo(level).unlock
  if unlock.minRank then
    local pr = extensions.hashiriyaBattle_progress
    if pr.rankIndex(c.save) < unlock.minRank then
      return false, c.t('shop.needRank', rankName(unlock.minRank))
    end
  end
  local need = unlock.minWins or 0
  if (c.save.wins or 0) < need then return false, c.t('shop.needWins', need) end
  return true, nil
end

-- "LV1 ab Nachtgast · LV2 ab ... " für die Statuszeile
-- "Nächste Stufe: LV3 ab Kurvenkünstler" für die Statuszeile (nur die nächste gesperrte Stufe)
local function unlockText()
  local c = core()
  for _, t in ipairs(rules.tiers or {}) do
    local u = t.unlock or {}
    if not (c.save and isUnlocked(t.level)) then
      if u.minRank and u.minRank > 0 then return c.t('term.unlockRank', t.level, rankName(u.minRank))
      elseif u.minWins and u.minWins > 0 then return c.t('term.unlockWins', t.level, u.minWins) end
    end
  end
  return ''
end

local function yen(usd) return core().economy().usdToPrice(usd or 0) end

-- Zollgröße aus dem Teilenamen ("steelwheel_11a_13x7_F" -> 13")
local function sizeOf(part, name)
  local z = tostring(part):match('_(%d%d)x[%d%.]+') or tostring(name or ''):match('(%d%d)x[%d%.]+') or tostring(name or ''):match('(%d%d)"')
  return z and (z .. '"') or nil
end

-- Katalog aus den Teilen des aktuellen Autos aufbauen ----------------------------

local function currentConfig(vehId)
  -- vehId: anderes Auto als das Spielerauto (z. B. das geparkte Auto, während man zu Fuß ist)
  local ok, vd = pcall(function()
    if vehId then return core_vehicle_manager.getVehicleData(vehId) end
    return core_vehicle_manager.getPlayerVehicleData()
  end)
  if not ok or not vd then return nil end
  local cfg = vd.config or {}
  -- Ab 0.40 gibt es nur noch den Teilebaum (partsTree); BeamNG macht daraus selbst eine flache
  -- Slot -> Teil-Liste (bei doppelten Slot-Namen ist der Schlüssel der volle Pfad).
  local parts = cfg.parts
  if type(parts) ~= 'table' and cfg.partsTree and core_vehicle_partmgmt and core_vehicle_partmgmt.partsTreeToPartsMap then
    local okMap, map = pcall(core_vehicle_partmgmt.partsTreeToPartsMap, cfg.partsTree)
    if okMap then parts = map end
  end
  if type(parts) ~= 'table' then
    if not warnedNoConfig then
      warnedNoConfig = true
      log('W', logTag, 'Shop: Teileliste des Autos nicht lesbar (weder parts noch partsTree)')
    end
    return nil
  end
  local out = { parts = {}, vars = {}, paints = (deepcopy and cfg.paints) and deepcopy(cfg.paints) or cfg.paints }
  for k, v in pairs(parts) do out.parts[k] = v end
  for k, v in pairs(cfg.vars or {}) do out.vars[k] = v end
  return out, vd
end
M.currentConfig = function() return currentConfig() end

local function jbeamIO() return rawget(_G, 'jbeamIO') or require('jbeam/io') end

-- Kind-Slots eines Teils (slots2: name, allowTypes, default, description)
local function childSlots(ioCtx, partName)
  if not ioCtx or not partName or partName == '' then return {} end
  local ok, part = pcall(jbeamIO().getPart, ioCtx, partName)
  if not ok or type(part) ~= 'table' then return {} end
  return part.slots2 or part.slots or {}
end

-- Reifen-Slot(s) einer Felge, z. B. { "tire_F_15x7" }
local function tireSlotsOf(ioCtx, rimPart)
  local out = {}
  for _, s in ipairs(childSlots(ioCtx, rimPart)) do
    local t = type(s.allowTypes) == 'table' and s.allowTypes[1] or s.name or s.type
    if type(t) == 'string' and t:find('^tire_') then table.insert(out, { slot = s.name or t, type = t }) end
  end
  return out
end

-- Teil im Besitz? Gekauft oder Serie (auch ausgebaute Serienteile, z. B. die alten Reifen)
local function ownsPart(car, part)
  if not part or part == '' then return true end
  if car.owned and car.owned[part] then return true end
  for _, v in pairs(car.stock or {}) do
    if v == part then return true end
  end
  return false
end

-- Slot -> Anzeigename: eigene Übersetzung (shop.slot.<slot ohne Modell>), sonst jbeam-Beschreibung
local function slotLabel(car, slot, desc)
  local c = core()
  local s = slot
  if car and s:sub(1, #car.model + 1) == car.model .. '_' then s = s:sub(#car.model + 2) end
  local keys = { s, (s:gsub('_%d+x[%d%.]+$', '')), (s:gsub('_[%d%.]+$', '')), (s:gsub('_[%w%.]+$', '')) }
  for _, k in ipairs(keys) do
    local str = c.strings and c.strings['shop.slot.' .. k]
    if str then return str end
  end
  if type(desc) == 'string' and desc ~= '' then return desc end
  s = s:gsub('_', ' ')
  return (s:gsub('^%l', string.upper))
end

local function buildCatalog(vehOverride)
  local c = core()
  local veh = vehOverride or c.getPlayerVehicle()
  local car = activeCar()
  if not veh or not car then return nil end
  local cfg, vd = currentConfig(vehOverride and veh:getID() or nil)
  if not cfg then return nil end
  if not vd.ioCtx then
    log('W', logTag, 'Shop: kein ioCtx in den Fahrzeugdaten')
    return nil
  end
  local io = jbeamIO()
  -- 0.40: getAvailableParts liefert nur noch Beschreibungen; die Slot-Zuordnung kommt aus
  -- getAvailableSlotNameMap, Preis und englischer Name aus dem Teil selbst (getPart).
  local okMap, slotMap = pcall(io.getAvailableSlotNameMap, vd.ioCtx)
  local okDesc, descs = pcall(io.getAvailableParts, vd.ioCtx)
  if not okMap or type(slotMap) ~= 'table' then
    log('E', logTag, 'Shop: Slot-Liste nicht lesbar: ' .. tostring(slotMap))
    return nil
  end
  if not okDesc or type(descs) ~= 'table' then descs = {} end

  local partCache = {}
  local function partInfo(name)
    if partCache[name] == nil then
      local info = { value = 0 }
      local ok, part = pcall(io.getPart, vd.ioCtx, name)
      if ok and type(part) == 'table' and type(part.information) == 'table' then
        info.value = tonumber(part.information.value) or 0
        info.name = part.information.name
      end
      local d = descs[name]
      info.display = niceName(d and d.description or info.name, name)
      partCache[name] = info
    end
    return partCache[name]
  end

  -- Slot-Beschreibungen und Eltern-Teil aus den verbauten Teilen (slots2)
  local slotDesc, slotParent = {}, {}
  local installed = {}
  for _, p in pairs(cfg.parts) do if p ~= '' then installed[p] = true end end
  local okMain, mainPart = pcall(io.getMainPartName, vd.ioCtx)
  if okMain and mainPart then installed[mainPart] = true end
  for p in pairs(installed) do
    for _, s in ipairs(childSlots(vd.ioCtx, p)) do
      local name = s.name or s.type
      if name then
        slotDesc[name] = slotDesc[name] or s.description
        slotParent[name] = slotParent[name] or p
      end
    end
  end

  -- Serienteile einmalig merken (neue Slots, z. B. Reifen einer neuen Felge, bekommen kein "Serie")
  car.stock = car.stock or {}
  car.owned = car.owned or {}
  if not car.stockInit then
    for key, part in pairs(cfg.parts) do
      local slot = lastSegment(key)
      if car.stock[slot] == nil and not car.owned[part] then car.stock[slot] = part end
    end
    car.stockInit = true
  end

  local catDefs = {}
  for _, cd in ipairs(rules.categories or {}) do catDefs[cd.id] = cd end
  local cat = { vehId = veh:getID(), rows = {}, bySlot = {} }
  for key, part in pairs(cfg.parts) do
    local slot = lastSegment(key)
    local names = slotMap[slot]
    if names and not slotHidden(slot) then
      local catId, cd = categoryOf(slot)
      local excluded = slotExcluded(slot) and catId ~= 'paint'
      local defaultLevel = (cd and cd.defaultLevel) or 1
      local stockPart = car.stock[slot]
      local options = {}
      for _, n in ipairs(names) do
        if n ~= stockPart then
          local info = partInfo(n)
          local lv = partLevel(n, tostring(info.name or '') .. ' ' .. info.display, defaultLevel)
          if lv > 0 or n == part or car.owned[n] then
            local minPrice = catId == 'paint' and (rules.liveryMinPriceYen or 0) or 0
            table.insert(options, { part = n, name = info.display, level = math.max(lv, 1), price = math.max(yen(info.value), minPrice),
              size = (catId == 'wheels') and sizeOf(n, info.display) or nil })
          end
        end
      end
      local emptyOk = part == '' or stockPart == ''
      if #options > 0 or (stockPart ~= nil and stockPart ~= part) then
        table.sort(options, function(a, b)
          if a.level ~= b.level then return a.level < b.level end
          return a.price < b.price
        end)
        spreadLevels(options)
        local parentInfo = slotParent[slot] and partInfo(slotParent[slot])
        local row = {
          id = key, slot = slot, cat = excluded and nil or catId, inAll = true,
          name = slotLabel(car, slot, slotDesc[slot]),
          path = parentInfo and parentInfo.display or '',
          stockPart = stockPart, stockName = (stockPart and stockPart ~= '') and partInfo(stockPart).display or nil,
          emptyOk = emptyOk, options = options,
          hint = (catId == 'engineSwap' and 'term.hint.swap') or (slot:find('^wheel_') and 'term.hint.rim') or nil,
        }
        cat.bySlot[slot] = row
        table.insert(cat.rows, row)
      end
    end
  end
  -- feste Reihenfolge: Kategorie (wie in tuning.json), dann Name
  local order = {}
  for i, cd in ipairs(rules.categories or {}) do order[cd.id] = i end
  table.sort(cat.rows, function(a, b)
    local oa, ob = order[a.cat or 'all'] or 99, order[b.cat or 'all'] or 99
    if oa ~= ob then return oa < ob end
    if a.name ~= b.name then return a.name < b.name end
    return a.slot < b.slot
  end)
  cat.partInfo = partInfo
  cat.ioCtx = vd.ioCtx
  cat.slotMap = slotMap
  log('I', logTag, string.format('Shop: %d Slots mit Teilen für %s', #cat.rows, tostring(car.model)))
  return cat
end

local pruneCart -- weiter unten

local function getCatalog()
  local veh = core().getPlayerVehicle()
  if not veh then return nil end
  if catalog and catalog.vehId == veh:getID() then return catalog end
  if retryTimer > 0 then return nil end
  retryTimer = 1
  local ok, res = pcall(buildCatalog)
  if not ok then log('E', logTag, 'Shop: ' .. tostring(res)) end
  catalog = ok and res or nil
  if catalog then
    pcall(pruneCart)
    bump()
  end
  return catalog
end
-- Lackierer: Werkslacke des Modells ---------------------------------------------

local function cleanPaint(p)
  local bc = p.baseColor or {}
  return {
    baseColor = { bc[1] or bc.r or 0.5, bc[2] or bc.g or 0.5, bc[3] or bc.b or 0.5, bc[4] or bc.a or 1.2 },
    metallic = p.metallic or 0, roughness = p.roughness or 0.5,
    clearcoat = p.clearcoat or 1, clearcoatRoughness = p.clearcoatRoughness or 0.05,
  }
end

local function factoryPaints(model)
  local list, seen = {}, {}
  local okM, m = pcall(core_vehicles.getModel, model)
  local md = okM and m and m.model or {}
  local vp = rawget(_G, 'core_vehiclePaints')
  for _, colId in ipairs(md.paintCollections or {}) do
    local okC, col = pcall(function() return vp and vp.getPaintCollectionById(colId) end)
    if okC and col then
      for _, pid in ipairs(col.paints or {}) do
        local okP, paint = pcall(vp.getPaintById, pid)
        if okP and type(paint) == 'table' and not seen[pid] then
          seen[pid] = true
          table.insert(list, { id = tostring(pid), name = paint.name or tostring(pid), paint = cleanPaint(paint) })
        end
      end
    end
  end
  for name, paint in pairs(type(md.paints) == 'table' and md.paints or {}) do
    if not seen[name] and type(paint) == 'table' then
      seen[name] = true
      table.insert(list, { id = tostring(name), name = tostring(name), paint = cleanPaint(paint) })
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

local paintCache = {}
local function paintsFor(model)
  if not paintCache[model] then
    local ok, res = pcall(factoryPaints, model)
    paintCache[model] = ok and res or {}
    if not ok then log('W', logTag, 'Shop: Werkslacke nicht lesbar: ' .. tostring(res)) end
  end
  return paintCache[model]
end

M.factoryPaints = function(model) return paintsFor(model) end

function M.paintSwatch(p)
  local bc = p and p.baseColor or {}
  local function ch(i) return math.floor(clamp(tonumber(bc[i]) or 0.5, 0, 1) * 255) end
  return string.format('rgb(%d,%d,%d)', ch(1), ch(2), ch(3))
end

local function findPaint(model, paintId)
  for _, p in ipairs(paintsFor(model)) do
    if p.id == paintId then return p end
  end
end
-- Lackschicht 1-3 (BeamNG: Haupt-, Zweit-, Drittfarbe; je nach Auto und Livery sichtbar)
local paintSlot = 1
local settleLivePaint
function M.setPaintSlot(n)
  if settleLivePaint then settleLivePaint() end
  paintSlot = clamp(math.floor(tonumber(n) or 1), 1, 3)
end

local function paintIdOf(car, slot)
  if car.paintIds and car.paintIds[slot] ~= nil then return car.paintIds[slot] end
  if slot == 1 then return car.paintId end
end

-- Lack in eine Schicht schreiben; fehlende Schichten davor mit Schicht 1 auffüllen.
local function setPaintAt(cfg, slot, paint)
  cfg.paints = type(cfg.paints) == 'table' and cfg.paints or {}
  for i = 1, slot - 1 do
    if cfg.paints[i] == nil then cfg.paints[i] = deepcopy and deepcopy(cfg.paints[1] or paint) or (cfg.paints[1] or paint) end
  end
  cfg.paints[slot] = paint
end

local function storePaintId(car, slot, id)
  car.paintIds = car.paintIds or {}
  car.paintIds[slot] = id
  if slot == 1 then car.paintId = id end
end

-- Einbauen, Warenkorb, Kaufen ------------------------------------------------------
-- Ein Klick auf ein fremdes Teil (oder einen Lack) legt es in den Warenkorb und baut es probeweise ein.
-- Alles im Warenkorb ist gleichzeitig verbaut; an der Kasse wird der Gesamtbetrag bezahlt.
-- Eigene Teile (gekauft oder Serie) kommen kostenlos in den Warenkorb, solange er nicht leer ist (sie können
-- von Teilen im Warenkorb abhängen, z. B. eigene Reifen auf einer neuen Felge). Bei leerem Warenkorb wird ein
-- eigenes Teil sofort eingebaut. "Teile direkt montieren" aus: Gekauftes kommt ins Lager, das Auto bleibt wie vorher.

local cart = nil -- { original = cfg vor dem Warenkorb, items = { { key, kind, slot, id, name, level, price, free, extra, paintSlot, paint } } }
local mountParts = true

local function copyConfig(cfg)
  local out = { parts = {}, vars = {}, paints = deepcopy and deepcopy(cfg.paints) or cfg.paints }
  for k, v in pairs(cfg.parts or {}) do out.parts[k] = v end
  for k, v in pairs(cfg.vars or {}) do out.vars[k] = v end
  return out
end

-- Ausgangszustand für Änderungen am Besitz: bei vollem Warenkorb das Auto ohne die Warenkorb-Teile.
local function baseConfig()
  if cart then return copyConfig(cart.original) end
  return currentConfig()
end

local focusSlotName = nil   -- Slot, dessen Teil gerade in der Vorschau gezeigt wird
local refocusTimer = 0

local function respawn(cfg)
  local car = activeCar()
  catalog = nil
  retryTimer = 2 -- Katalog erst neu aufbauen, wenn das Auto neu gespawnt ist
  bump()
  extensions.hashiriyaBattle_fuel.keepAfterRespawn()
  core_vehicles.replaceVehicle(car.model, { config = cfg })
  extensions.hashiriyaBattle_parking.refreshShopCamera(0.8)
  camTimer = 0.9
  if focusSlotName then refocusTimer = 1.4 end -- nach dem Respawn das Teil wieder zeigen
end

-- Teil in einen Slot setzen; gibt es den Slot in der flachen Liste noch nicht (z. B. Reifen einer neuen
-- Felge), wird er angelegt. Zweiter Rückgabewert: Slot war schon vorhanden.
local function setPart(cfg, slot, part)
  local found = false
  for key in pairs(cfg.parts) do
    if lastSegment(key) == slot then cfg.parts[key] = part; found = true end
  end
  if not found then cfg.parts[slot] = part end
  return true, found
end

local function slotValue(cfg, slot)
  for key, v in pairs(cfg and cfg.parts or {}) do
    if lastSegment(key) == slot then return v end
  end
  return nil
end

-- Felge ohne Reifen: Reifen-Slot(s) der neuen Felge mit einem eigenen passenden Reifen belegen, sonst leer.
local function rimExtras(rimPart)
  if rules.tireWithRim then return nil end
  local car = activeCar()
  local cat = getCatalog()
  if not cat or not rimPart or rimPart == '' then return nil end
  local extra = nil
  for _, ts in ipairs(tireSlotsOf(cat.ioCtx, rimPart)) do
    local choice = ''
    for _, n in ipairs(cat.slotMap[ts.type] or {}) do
      if ownsPart(car, n) then choice = n; break end
    end
    extra = extra or {}
    extra[ts.slot] = choice
  end
  return extra
end

local function applyItem(cfg, it)
  if it.kind == 'part' then
    setPart(cfg, it.slot, it.id)
    for s, p in pairs(it.extra or {}) do setPart(cfg, s, p) end
  end
end

-- Lack ohne Neuladen des Autos (wie das BeamNG-Lackmenü): Farben live setzen und in die
-- Fahrzeug-Config schreiben, damit sie beim nächsten Respawn und in currentConfig() erhalten bleiben.
function M.applyPaintsLive(paints)
  local veh = core().getPlayerVehicle()
  local vm = rawget(_G, 'core_vehicle_manager')
  if not veh or not vm or not vm.liveUpdateVehicleColors or type(paints) ~= 'table' then return false end
  local ok = pcall(function()
    local vd = vm.getPlayerVehicleData()
    if not vd or not vd.config then error('keine Fahrzeugdaten') end
    vd.config.paints = deepcopy and deepcopy(paints) or paints
    for i = 1, 3 do
      if paints[i] then vm.liveUpdateVehicleColors(veh:getID(), veh, i, paints[i]) end
    end
    veh:setField('partConfig', '', serialize(vd.config))
  end)
  return ok
end

-- Nur der Lack ändert sich: live färben. Lief vorher eine Teile-Vorschau, muss das Auto neu gespawnt werden.
local function applyPaintCfg(cfg, wasPartPreview)
  if wasPartPreview or not M.applyPaintsLive(cfg.paints) then respawn(cfg) end
end

-- Live-Vorschau der eigenen Farbe: jede Regler-Bewegung färbt das Auto sofort um, ohne Warenkorb.
-- livePaint.orig = Lack vor der ersten Regler-Bewegung. Vor jeder anderen Aktion (Warenkorb, Kasse,
-- Kategorie- oder Schichtwechsel, Terminal schließen) wird er wiederhergestellt.
local livePaint = nil

settleLivePaint = function()
  if not livePaint then return end
  local orig = livePaint.orig
  livePaint = nil
  M.applyPaintsLive(orig)
end
M.settleLivePaint = settleLivePaint

function M.previewPaintLive(arg)
  if terminal ~= 'shop' or termCat ~= 'paint' then return end
  local v = {}
  for n in tostring(arg or ''):gmatch('[^,]+') do table.insert(v, clamp(tonumber(n) or 0, 0, 1)) end
  if #v ~= 7 then return end
  local veh = core().getPlayerVehicle()
  local vm = rawget(_G, 'core_vehicle_manager')
  if not veh or not vm or not vm.liveUpdateVehicleColors then return end
  if not livePaint then
    local cfg = currentConfig()
    if not cfg then return end
    livePaint = { orig = deepcopy and deepcopy(cfg.paints or {}) or (cfg.paints or {}) }
  end
  local paint = { baseColor = { v[1], v[2], v[3], 1.2 }, metallic = v[4], roughness = v[5], clearcoat = v[6], clearcoatRoughness = v[7] }
  pcall(vm.liveUpdateVehicleColors, veh:getID(), veh, paintSlot, paint)
end

function M.hasPreview() return cart ~= nil end

local function cartIndex(key)
  if not cart then return nil end
  for i, it in ipairs(cart.items) do if it.key == key then return i, it end end
end

local function cartHas(key, id)
  local _, it = cartIndex(key)
  return it ~= nil and it.id == id
end

local function buildCart()
  local cfg = copyConfig(cart.original)
  for _, it in ipairs(cart.items) do
    if it.kind == 'part' then applyItem(cfg, it) else setPaintAt(cfg, it.paintSlot, it.paint) end
  end
  return cfg
end

-- Auto auf den Stand des Warenkorbs bringen (Teile: neu spawnen, nur Lack: live färben)
local function applyCart(partsChanged)
  if not cart then return end
  local cfg
  if #cart.items == 0 then
    cfg = cart.original
    cart = nil
  else
    cfg = buildCart()
  end
  bump()
  if partsChanged then respawn(cfg) else applyPaintCfg(cfg, false) end
end

-- Teile im Warenkorb, deren Slot es am neu gespawnten Auto nicht mehr gibt (z. B. nach Motor-Swap
-- zurück), fliegen raus. Wird nach jedem Katalog-Neuaufbau aufgerufen.
pruneCart = function()
  if not cart then return end
  local cur = currentConfig()
  if not cur then return end
  local have = {}
  for key in pairs(cur.parts) do have[lastSegment(key)] = true end
  local removed = false
  for i = #cart.items, 1, -1 do
    local it = cart.items[i]
    if it.kind == 'part' and not have[it.slot] then
      table.remove(cart.items, i)
      removed = true
    end
  end
  if removed then
    log('I', logTag, 'Shop: Warenkorb bereinigt (Slots gibt es nicht mehr)')
    if #cart.items == 0 then cart = nil end
  end
end

-- Fahrzeugwerte -------------------------------------------------------------------
-- Fahrzeugwerte (Leistung, Drehmoment, Gewicht, Bremsen) vom Auto abfragen; Antwort über onStats
local carStats = nil      -- aktuelle Werte des Autos (mit Warenkorb-Teilen)
local baseStats = nil     -- Werte vor dem Warenkorb
local statsTimer = 0

local function requestStats()
  local veh = core().getPlayerVehicle()
  if not veh then return end
  veh:queueLuaCommand([[
    local kw, nm = 0, 0
    local ok = pcall(function()
      local eng = powertrain.getDevicesByCategory('engine')[1]
      if eng then kw = eng.maxPower or 0; nm = eng.maxTorque or 0 end -- kw-Variable enthält PS
    end)
    local kg = 0
    pcall(function() for _, n in pairs(v.data.nodes) do kg = kg + (n.nodeWeight or 0) end end)
    local brake = 0
    pcall(function() for _, w in pairs(wheels.wheels) do brake = brake + (w.brakeTorque or 0) end end)
    obj:queueGameEngineLua(string.format('if extensions.hashiriyaBattle_shop then extensions.hashiriyaBattle_shop.onStats(%f,%f,%f,%f) end', kw, nm, kg, brake))
  ]])
end

function M.onStats(kw, nm, kg, brake)
  -- combustionEngine.maxPower ist in PS (metrisch), maxTorque in Nm
  local ps
  ps, nm, kg, brake = tonumber(kw) or 0, tonumber(nm) or 0, tonumber(kg) or 0, tonumber(brake) or 0
  if kg <= 0 then return end
  carStats = { ps = ps, nm = nm, kg = kg, brake = brake, pw = ps > 0 and kg / ps or nil }
  if not cart then baseStats = nil end
end

local function statsUi()
  if not carStats then requestStats(); return nil end
  local c = core()
  local defs = {
    { k = 'ps', label = 'shop.stat.power', fmt = '%d PS', better = 1 },
    { k = 'nm', label = 'shop.stat.torque', fmt = '%d Nm', better = 1 },
    { k = 'kg', label = 'shop.stat.weight', fmt = '%d kg', better = -1 },
    { k = 'pw', label = 'shop.stat.ratio', fmt = '%.2f kg/PS', better = -1 },
    { k = 'brake', label = 'shop.stat.brake', fmt = '%d Nm', better = 1 },
  }
  local rows = {}
  for _, d in ipairs(defs) do
    local v = carStats[d.k]
    if v and v > 0 then
      local r = { label = c.t(d.label), value = string.format(d.fmt, d.k == 'pw' and v or math.floor(v + 0.5)) }
      local b = baseStats and baseStats[d.k]
      if b and math.abs(v - b) > (d.k == 'pw' and 0.005 or 0.5) then
        local diff = v - b
        r.delta = (diff > 0 and '+' or '') .. string.format(d.k == 'pw' and '%.2f' or '%d', d.k == 'pw' and diff or math.floor(diff + (diff > 0 and 0.5 or -0.5)))
        r.good = diff * d.better > 0
      end
      table.insert(rows, r)
    end
  end
  return rows
end
M.requestStats = requestStats

local function ensureCart()
  if cart then return true end
  local cfg = currentConfig()
  if not cfg then return false end
  cart = { original = copyConfig(cfg), items = {} }
  baseStats = carStats and deepcopy and deepcopy(carStats) or carStats
  return true
end

local function putInCart(item)
  local i = cartIndex(item.key)
  if i then cart.items[i] = item else table.insert(cart.items, item) end
end

function M.removeFromCart(key)
  settleLivePaint()
  local i, it = cartIndex(key)
  if not i then return end
  table.remove(cart.items, i)
  applyCart(it.kind == 'part')
end

function M.cancelPreview(silent)
  settleLivePaint()
  if not cart then return end
  local hadParts = false
  for _, it in ipairs(cart.items) do if it.kind == 'part' then hadParts = true end end
  local original = cart.original
  cart = nil
  bump()
  if hadParts then respawn(original) else applyPaintCfg(original, false) end
  if not silent then core().msg(core().t('msg.previewReverted')) end
end

-- Eigenes Teil fest einbauen (Serie oder gekauft, also kostenlos). Felgen bekommen passende eigene Reifen.
local function install(slot, part, label)
  local c = core()
  local car = activeCar()
  local cfg = baseConfig()
  if not cfg then
    c.msg(c.t('msg.partFailed'))
    return
  end
  setPart(cfg, slot, part)
  if slot:find('^wheel_') then
    for s, p in pairs(rimExtras(part) or {}) do setPart(cfg, s, p) end
  end
  car.config = cfg
  respawn(cfg)
  c.writeSave()
  if part == '' then c.msg(c.t('msg.partRemoved', label)) else c.msg(c.t('msg.partInstalled', label, c.t('shop.free'))) end
  log('I', logTag, string.format('Shop: %s -> %s (Besitz)', slot, part))
end

-- Option eines Slots suchen; Serie und "Nicht verbaut" sind eigene Optionen
local function findOption(slot, part)
  local cat = getCatalog()
  local row = cat and cat.bySlot[slot]
  if not row then return nil end
  if part == row.stockPart then
    return { part = part, name = part == '' and core().t('shop.notInstalled') or (row.stockName or part), level = 0, price = 0, stock = true }, row
  end
  if part == '' and row.emptyOk then
    return { part = '', name = core().t('shop.notInstalled'), level = 0, price = 0 }, row
  end
  for _, o in ipairs(row.options) do
    if o.part == part then return o, row end
  end
  return nil, row
end

-- Kennzeichen-Design (Plates Pack) ins Auto setzen; der Rest der Config bleibt
function M.setPlateDesign(design)
  local car = activeCar()
  local cfg = baseConfig()
  if not car or not cfg then return end
  cfg = extensions.hashiriyaBattle_plates.applyToConfig(cfg, design)
  car.config = cfg
  if cart then cart.original = copyConfig(cfg); applyCart(true) else respawn(cfg) end
end

-- Garagen-PC: nur eigene Teile, kostenlos umbauen
function M.buy(slot, part, garageOnly)
  settleLivePaint()
  local car = activeCar()
  local option, row = findOption(slot, part)
  if not option then return end
  if option.stock or part == '' or ownsPart(car, part) then return install(slot, part, option.name or row.name) end
  if not garageOnly then return M.select(slot, part) end
end

-- Shop: Klick auf eine Option legt sie in den Warenkorb (ersetzt ein anderes Teil im selben Slot).
function M.select(slot, part)
  settleLivePaint()
  local c = core()
  local car = activeCar()
  local option, row = findOption(slot, part)
  if not option then return end
  -- Klick auf das Teil, das vor dem Warenkorb verbaut war: Warenkorb-Eintrag zurücknehmen
  if cart and cartIndex('part:' .. slot) and slotValue(cart.original, slot) == part then
    return M.removeFromCart('part:' .. slot)
  end
  local free = option.stock or part == '' or ownsPart(car, part)
  if free and not cart then return install(slot, part, option.name) end
  if not ensureCart() then
    c.msg(c.t('msg.partFailed'))
    return
  end
  local extra = slot:find('^wheel_') and rimExtras(part) or nil
  putInCart({ key = 'part:' .. slot, kind = 'part', slot = slot, slotName = row.name, id = part, name = option.name,
    level = free and 0 or option.level, price = free and 0 or option.price, free = free, extra = extra })
  applyCart(true)
end

function M.selectPaint(paintId)
  settleLivePaint()
  local c = core()
  local car = activeCar()
  local entry = findPaint(car.model, paintId)
  if not entry then return end
  if car.ownedPaints and car.ownedPaints[paintId] then
    local cfg = baseConfig()
    if not cfg then
      c.msg(c.t('msg.partFailed'))
      return
    end
    setPaintAt(cfg, paintSlot, entry.paint)
    storePaintId(car, paintSlot, paintId)
    car.config = cfg
    if cart then
      cart.original = copyConfig(cfg)
      local i = cartIndex('paint:' .. paintSlot)
      if i then table.remove(cart.items, i) end
      applyCart(false)
    else
      applyPaintCfg(cfg, false)
    end
    c.writeSave()
    c.msg(c.t('msg.partInstalled', entry.name, c.t('shop.free')))
    return
  end
  if not ensureCart() then
    c.msg(c.t('msg.partFailed'))
    return
  end
  putInCart({ key = 'paint:' .. paintSlot, kind = 'paint', id = paintId, paintSlot = paintSlot, paint = entry.paint,
    name = entry.name, slotName = c.t('shop.paintSlot', paintSlot), level = 0, price = rules.paintPriceYen or 29800 })
  applyCart(false)
end

-- Eigene Farbe: arg = "r,g,b,metallic,rauheit,klarlack,klarlackRauheit" (alles 0..1).
-- Wird immer neu bezahlt (neue Lackierung).
function M.selectCustomPaint(arg)
  settleLivePaint()
  local c = core()
  local v = {}
  for n in tostring(arg or ''):gmatch('[^,]+') do table.insert(v, clamp(tonumber(n) or 0, 0, 1)) end
  if #v ~= 7 then return end
  if not ensureCart() then
    c.msg(c.t('msg.partFailed'))
    return
  end
  putInCart({ key = 'paint:' .. paintSlot, kind = 'paint', id = 'custom', paintSlot = paintSlot,
    paint = { baseColor = { v[1], v[2], v[3], 1.2 }, metallic = v[4], roughness = v[5], clearcoat = v[6], clearcoatRoughness = v[7] },
    name = c.t('shop.customName'), slotName = c.t('shop.paintSlot', paintSlot), level = 0, price = rules.customPaintPriceYen or 98000 })
  applyCart(false)
end

local function cartTotal()
  local total = 0
  for _, it in ipairs(cart and cart.items or {}) do total = total + it.price end
  return total
end

-- Kasse: alles im Warenkorb auf einmal bezahlen. Mit "Teile direkt montieren" bleibt alles verbaut,
-- sonst wandern die gekauften Teile ins Lager und das Auto wird wie vorher (nur neuer Lack bleibt drauf).
function M.confirmPreview()
  settleLivePaint()
  local c = core()
  local car = activeCar()
  if not cart or #cart.items == 0 then return end
  for _, it in ipairs(cart.items) do
    if not it.free and it.level > 0 and not isUnlocked(it.level) then
      c.msg(c.t('msg.partLocked'))
      return
    end
  end
  local total = cartTotal()
  if c.save.money < total then
    c.msg(c.t('msg.noMoney'))
    return
  end
  local live = currentConfig() or buildCart()
  local origVals = {}
  for _, v in pairs(cart.original.parts) do origVals[v] = true end
  c.save.money = c.save.money - total
  car.owned = car.owned or {}
  local bought = 0
  for _, it in ipairs(cart.items) do
    if not it.free then
      bought = bought + 1
      extensions.hashiriyaBattle_progress.bump(c.save, it.kind == 'paint' and 'paintsBought' or 'partsBought')
    end
    if it.kind == 'paint' then
      car.ownedPaints = car.ownedPaints or {}
      if it.id ~= 'custom' then car.ownedPaints[it.id] = true end
      storePaintId(car, it.paintSlot or 1, it.id)
    elseif it.id ~= '' then
      car.owned[it.id] = true
    end
  end
  local n = #cart.items
  if mountParts then
    -- Teile, die mit einem gekauften Teil kamen (z. B. Anbauteile eines neuen Motors), gehören dir auch
    for _, v in pairs(live.parts) do
      if v ~= '' and not origVals[v] then car.owned[v] = true end
    end
    car.config = live
    cart = nil
    bump()
    c.msg(c.t('msg.cartBought', n, c.economy().formatYen(total)))
  else
    local cfg = copyConfig(cart.original)
    local hadParts = false
    for _, it in ipairs(cart.items) do
      if it.kind == 'paint' then setPaintAt(cfg, it.paintSlot, it.paint) else hadParts = true end
    end
    cart = nil
    car.config = cfg
    bump()
    if hadParts then respawn(cfg) else applyPaintCfg(cfg, false) end
    c.msg(c.t('msg.cartStored', n, c.economy().formatYen(total)))
  end
  c.writeSave()
  log('I', logTag, string.format('Shop: %d Teile gekauft (%d Yen), montiert: %s', bought, total, tostring(mountParts)))
end

local function previewState()
  if not cart or #cart.items == 0 then return nil end
  local c = core()
  local eco = c.economy()
  local st = { items = {}, locked = false }
  for _, it in ipairs(cart.items) do
    local unlocked, need = true, nil
    if it.level > 0 and not it.free then unlocked, need = isUnlocked(it.level) end
    if not unlocked then st.locked = true end
    table.insert(st.items, { key = it.key, slot = it.slot, slotName = it.slotName, name = it.name, level = it.level, kind = it.kind,
      free = it.free, price = it.free and c.t('shop.free') or eco.formatYen(it.price), locked = not unlocked, lockText = not unlocked and need or nil })
  end
  local total = cartTotal()
  st.total = eco.formatYen(total)
  st.count = #cart.items
  st.affordable = c.save.money >= total
  st.after = eco.formatYen(c.save.money - total)
  return st
end
local function paintRow()
  local c = core()
  local car = activeCar()
  local eco = c.economy()
  local r = { slot = '__paint', kind = 'paint', name = c.t('shop.item.paint'), current = c.t('shop.stock'), currentLevel = 0, options = {} }
  local curId = paintIdOf(car, paintSlot)
  if curId == 'custom' then r.current = c.t('shop.customPaint') end
  r.custom = { price = eco.formatYen(rules.customPaintPriceYen or 98000) }
  -- Auswahl der Lackschicht mit der aktuellen Farbe jeder Schicht
  r.paintSlot = paintSlot
  r.paintSlots = {}
  local cur = currentConfig()
  local paints = cur and type(cur.paints) == 'table' and cur.paints or {}
  for i = 1, 3 do
    local p = paints[i] or paints[1]
    local bc = p and (p.baseColor or {}) or {}
    local function ch(k, n) return math.floor(clamp(tonumber(bc[k] or bc[n]) or 0.5, 0, 1) * 255) end
    table.insert(r.paintSlots, { id = i, name = c.t('shop.paintSlot', i), swatch = string.format('rgb(%d,%d,%d)', ch(1, 'r'), ch(2, 'g'), ch(3, 'b')) })
  end
  for _, p in ipairs(paintsFor(car.model)) do
    local owned = car.ownedPaints and car.ownedPaints[p.id]
    local price = rules.paintPriceYen or 29800
    local bc = p.paint.baseColor
    local installed = curId == p.id
    if installed then r.current = p.name end
    table.insert(r.options, {
      part = p.id, name = p.name, level = 0, installed = installed,
      previewing = cartHas('paint:' .. paintSlot, p.id),
      swatch = string.format('rgb(%d,%d,%d)', math.floor(clamp(bc[1], 0, 1) * 255), math.floor(clamp(bc[2], 0, 1) * 255), math.floor(clamp(bc[3], 0, 1) * 255)),
      price = owned and c.t('shop.owned') or eco.formatYen(price),
      affordable = owned or c.save.money >= price,
    })
  end
  return r
end

-- Live-Vorschau: Kamera und Teile-Ansicht ---------------------------------------------
-- Die 3D-Szene ist in der Mitte des Terminals zu sehen (die UI-App lässt dort ein Fenster frei).
-- 'car' = Orbit-Kamera aufs ganze Auto, 'part' = BeamNG-Teilekamera (partFocusCamera) auf das Teil unter der
-- Maus. Röntgen = Rest des Autos durchsichtig (wie im BeamNG-Teilemenü).

local function findPartPath(slot)
  local vd = select(2, currentConfig())
  local tree = vd and vd.config and vd.config.partsTree
  if type(tree) ~= 'table' then return nil end
  local found, parentPath = nil, nil
  local function walk(node, parent)
    if found then return end
    if node.id == slot or (type(node.path) == 'string' and lastSegment(node.path) == slot) then
      if node.chosenPartName and node.chosenPartName ~= '' and node.partPath then found = node.partPath
      else parentPath = parent and parent.partPath end
      if found or parentPath then return end
    end
    for _, child in pairs(node.children or {}) do
      if type(child) == 'table' then walk(child, node) end
    end
  end
  walk(tree, nil)
  return found or parentPath
end

-- Alle verbauten Teile (für "alles sichtbar, Kamera trotzdem aufs Teil")
local function allPartPaths()
  local vd = select(2, currentConfig())
  local tree = vd and vd.config and vd.config.partsTree
  local set = {}
  local function walk(node)
    if node.partPath and node.chosenPartName and node.chosenPartName ~= '' then set[node.partPath] = true end
    for _, child in pairs(node.children or {}) do
      if type(child) == 'table' then walk(child) end
    end
  end
  if type(tree) == 'table' then walk(tree) end
  return set
end

function M.applyPreviewCamera()
  if not terminal then return end
  local veh = core().getPlayerVehicle()
  if not veh then return end
  local vid = veh:getID()
  local pv = rules.preview or {}
  pcall(function() core_camera.setByName(0, 'orbit') end)
  if pv.distance then pcall(core_camera.setDistance, vid, pv.distance) end
  if camYaw then pcall(core_camera.setRotation, vid, vec3(camYaw, pv.pitch or -10, 0)) end
end

local function clearPartView()
  local veh = core().getPlayerVehicle()
  local pm = rawget(_G, 'core_vehicle_partmgmt')
  if not pm or not veh then return end
  pcall(pm.showHighlightedParts, veh:getID(), {})
  pcall(pm.releasePartFocusCamera)
end

local function applyFocus()
  local veh = core().getPlayerVehicle()
  local pm = rawget(_G, 'core_vehicle_partmgmt')
  if not veh or not pm then return end
  local path = view == 'part' and focusSlotName and findPartPath(focusSlotName)
  if not path then
    clearPartView()
    M.applyPreviewCamera()
    return
  end
  local camSet = { [path] = true }
  local sel = xray and camSet or allPartPaths()
  pcall(pm.selectParts, sel, veh:getID(), camSet, { focusOffsetUp = (rules.preview or {}).focusOffsetUp or 0.1 })
end

function M.focusSlot(slot)
  focusSlotName = (slot and slot ~= '' and slot ~= '__paint') and slot or nil
  refocusTimer = 0
  applyFocus()
end

-- Beim Wegfahren / Menü schließen: alles sichtbar, Kamera zurück.
function M.releaseFocus()
  focusSlotName = nil
  refocusTimer = 0
  clearPartView()
  -- Shop zu Fuß: wieder die Eingangskamera
  extensions.hashiriyaBattle_parking.refreshShopCamera()
end

function M.setView(v)
  view = (v == 'car') and 'car' or 'part'
  applyFocus()
end

function M.toggleXray()
  xray = not xray
  if view ~= 'part' then view = 'part' end
  applyFocus()
end

function M.rotate(dir)
  local pv = rules.preview or {}
  camYaw = ((camYaw or 0) + (pv.yawStep or 45) * ((tonumber(dir) or 1) < 0 and -1 or 1)) % 360
  view = 'car'
  clearPartView()
  M.applyPreviewCamera()
end

function M.toggleMount()
  mountParts = not mountParts
  local c = core()
  if c.save then
    c.save.settings = c.save.settings or {}
    c.save.settings.mountParts = mountParts
    c.writeSave()
  end
end

function M.loadSettings(save)
  mountParts = not (save and save.settings and save.settings.mountParts == false)
end

-- Terminal öffnen/schließen (Shop zu Fuß am Eingang oder Garagen-PC)
function M.openTerminal(mode)
  if terminal == mode then return end
  terminal = mode
  view, xray, camYaw = 'part', false, nil
  focusSlotName = nil
  camTimer = 0.6
  bump()
  core().setTerminalLayout(true)
  log('I', logTag, 'Teile-Terminal geöffnet: ' .. tostring(mode))
end

function M.closeTerminal()
  if not terminal then return end
  settleLivePaint()
  terminal = nil
  M.releaseFocus()
  core().setTerminalLayout(false)
end

function M.isTerminalOpen() return terminal ~= nil end
function M.terminalMode() return terminal end

function M.setCategory(id)
  termCat = tostring(id or 'engine')
  if termCat ~= 'paint' then settleLivePaint() end
end

function M.setTab(tab) M.setCategory(tab) end

-- Katalog für die UI (per Hook 'HashiriyaCatalog', nur auf Anfrage) ----------------------

local function catalogPayload(cat)
  local c = core()
  local car = activeCar()
  local eco = c.economy()
  local live = currentConfig()
  local inCart = {}
  for _, it in ipairs(cart and cart.items or {}) do
    if it.kind == 'part' then inCart[it.slot] = it.id end
  end
  local rows = {}
  for _, row in ipairs(cat.rows) do
    local cur = slotValue(live, row.slot)
    local before = cart and slotValue(cart.original, row.slot)
    if before == nil then before = cur end
    local r = { id = row.id, slot = row.slot, cat = row.cat, inAll = row.inAll, name = row.name, path = row.path,
      hint = row.hint and c.t(row.hint) or nil, current = c.t('shop.notInstalled'), currentLevel = 0, options = {} }
    local function add(o)
      o.installed = (before == o.part) and inCart[row.slot] == nil
      o.previewing = inCart[row.slot] ~= nil and inCart[row.slot] == o.part
      if cur == o.part then r.current, r.currentLevel, r.curSize = o.name, o.level, o.size end
      table.insert(r.options, o)
    end
    if row.stockPart ~= nil then
      add({ part = row.stockPart, name = c.t('shop.stock') .. ' · ' .. (row.stockName or c.t('shop.notInstalled')), level = 0,
        price = c.t('shop.free'), priceRaw = 0, owned = true, stock = true, free = true })
    end
    if row.emptyOk and row.stockPart ~= '' then
      add({ part = '', name = c.t('shop.notInstalled'), level = -1, price = c.t('shop.free'), priceRaw = 0, owned = true, free = true })
    end
    local sizes, seen = {}, {}
    for _, o in ipairs(row.options) do
      local owned = ownsPart(car, o.part)
      local unlocked, need = true, nil
      if not owned then unlocked, need = isUnlocked(o.level) end
      add({ part = o.part, name = o.name, level = o.level, size = o.size,
        price = owned and c.t('shop.owned') or eco.formatYen(o.price), priceRaw = owned and 0 or o.price,
        owned = owned, free = owned, locked = not unlocked, lockText = need })
      if o.size and not seen[o.size] then seen[o.size] = true; table.insert(sizes, o.size) end
    end
    table.sort(sizes, function(a, b) return (tonumber(a:match('%d+')) or 0) < (tonumber(b:match('%d+')) or 0) end)
    if #sizes > 1 then r.sizes = sizes end
    table.insert(rows, r)
  end
  local cats = {}
  for _, cd in ipairs(rules.categories or {}) do
    table.insert(cats, { id = cd.id, group = cd.group or 'more', name = c.t('term.cat.' .. cd.id) })
  end
  return { version = catVersion, rows = rows, categories = cats }
end

function M.sendCatalog()
  local cat = getCatalog()
  if not cat then return end
  local ok, payload = pcall(catalogPayload, cat)
  if not ok then
    log('E', logTag, 'Shop: Katalog für die UI: ' .. tostring(payload))
    return
  end
  guihooks.trigger('HashiriyaCatalog', payload)
end

-- Kleiner Zustand fürs Terminal (kommt mit jedem HashiriyaState)
function M.terminalState()
  if not terminal then return nil end
  local c = core()
  local car = activeCar()
  local eco = c.economy()
  local cat = getCatalog()
  local home = extensions.hashiriyaBattle_home
  local st = {
    mode = terminal,
    title = c.t(terminal == 'garage' and 'term.titleGarage' or 'term.titleShop'),
    carName = car and car.name or '',
    money = eco.formatYen(c.save.money),
    moneyRaw = c.save.money,
    clock = home.dayText(),
    stats = statsUi(),
    cart = terminal == 'shop' and previewState() or nil,
    mount = mountParts,
    view = view,
    xray = xray,
    cat = termCat,
    catVersion = cat and catVersion or -1,
    loading = cat == nil,
    unlockText = unlockText(),
  }
  if terminal == 'shop' and termCat == 'paint' then st.paint = paintRow() end
  return st
end

-- Alte Menü-Schnittstelle (Garagen-Reiter "Teile" öffnet jetzt den Garagen-PC)
function M.getUiState() return nil end

-- Freischalt-Meldung (UI-App HashiriyaUnlock) ---------------------------------------
-- Sobald eine Teile-Stufe (tiers in tuning.json) freigeschaltet ist, kommt einmal pro Spielstand eine Meldung:
-- welche Stufe, wodurch (Rang oder Siege) und wie viele neue Teile es fürs aktive Auto pro Kategorie gibt.
-- Gemerkt in save.unlockSeen ("1" = true ...). Alte Spielstände ohne Liste: was schon frei ist, gilt als gesehen.
-- Gezeigt wird erst, wenn kein Battle läuft, das Terminal zu ist und kein Karriere-Fenster offen ist.
local un = { save = nil, checkTimer = 0, calm = 0, current = nil, timer = 0 }

local function noticeCfg()
  local n = (rules and rules.unlockNotice) or {}
  return { enabled = n.enabled ~= false, seconds = tonumber(n.seconds) or 9, delay = tonumber(n.delay) or 3, maxCategories = tonumber(n.maxCategories) or 5 }
end

-- Neue Teile der Stufe fürs aktive Auto, nach Kategorie gezählt (nil, wenn kein Katalog da ist)
local function newPartsOf(level)
  local ok, cat = pcall(getCatalog)
  if not (ok and cat) then
    -- zu Fuß (oder Katalog gerade gesperrt): direkt vom aktiven Auto bauen, nicht als Shop-Katalog merken.
    -- Zu Fuß ist das Spielerfahrzeug der Fußgänger; das geparkte Auto merkt sich core.carVehId.
    local veh = core().getPlayerVehicle()
    if not veh then
      local id = core().carVehId
      veh = id and be:getObjectByID(id) or nil
    end
    if veh then ok, cat = pcall(buildCatalog, veh) end
  end
  if not ok or not cat then return nil end
  local c = core()
  local counts, total = {}, 0
  for _, row in ipairs(cat.rows) do
    if row.cat and row.cat ~= 'all' then
      for _, o in ipairs(row.options) do
        if o.level == level then
          counts[row.cat] = (counts[row.cat] or 0) + 1
          total = total + 1
        end
      end
    end
  end
  local list = {}
  for _, cd in ipairs(rules.categories or {}) do
    if counts[cd.id] then table.insert(list, { id = cd.id, name = c.t('term.cat.' .. cd.id), count = counts[cd.id], group = cd.group }) end
  end
  table.sort(list, function(a, b) return a.count > b.count end)
  local max, more = noticeCfg().maxCategories, 0
  while #list > max do more = more + table.remove(list).count end
  return { total = total, cats = list, more = more }
end

local function unlockedLevels()
  local out = {}
  if not (rules and core().save) then return out end
  for _, t in ipairs(rules.tiers or {}) do
    if isUnlocked(t.level) then table.insert(out, t.level) end
  end
  return out
end
M.unlockedLevels = unlockedLevels

local function showUnlock(level)
  local c = core()
  local u = tierInfo(level).unlock or {}
  local car = activeCar()
  local n = { level = level, key = tostring(level) .. '|' .. os.time() }
  if u.minRank and u.minRank > 0 then n.reason = c.t('unlock.byRank', rankName(u.minRank))
  elseif u.minWins and u.minWins > 0 then n.reason = c.t('unlock.byWins', u.minWins) end
  local parts = newPartsOf(level)
  if parts and parts.total > 0 then
    n.carName = car and car.name or ''
    n.total = parts.total
    n.cats = parts.cats
    n.more = parts.more
  end
  un.current = n
  un.timer = noticeCfg().seconds
  c.sound('unlock')
  log('I', logTag, string.format('Freischaltung: LV%d (%s neue Teile fürs aktive Auto)', level, tostring(parts and parts.total or '?')))
end

local function updateUnlocks(dtReal)
  local c = core()
  local save = c.save
  if un.current then
    un.timer = un.timer - dtReal
    if un.timer <= 0 then un.current = nil end
  end
  if not (c.active and save and rules) then un.calm = 0 return end
  -- neuer/geladener Spielstand: ohne Liste zählt alles schon Freie als gesehen (keine Meldungsflut)
  if un.save ~= save then
    un.save, un.current = save, nil
    if not save.unlockSeen then
      save.unlockSeen = {}
      for _, lv in ipairs(unlockedLevels()) do save.unlockSeen[tostring(lv)] = true end
    end
  end
  -- erst nach einer ruhigen Pause (Sieg-Spruch und Rang-Meldung sind dann durch)
  local bh = extensions.hashiriyaBattle_battle.getHudState()
  local career = extensions.hashiriyaBattle_career
  local calm = not terminal and not (bh and bh.state ~= 'idle') and not (career and career.isOpen())
  un.calm = calm and (un.calm + dtReal) or 0
  un.checkTimer = un.checkTimer - dtReal
  if un.checkTimer > 0 or un.current then return end
  un.checkTimer = 1
  local cfg = noticeCfg()
  for _, lv in ipairs(unlockedLevels()) do
    if not save.unlockSeen[tostring(lv)] then
      if not cfg.enabled then
        save.unlockSeen[tostring(lv)] = true
      elseif un.calm >= cfg.delay then
        save.unlockSeen[tostring(lv)] = true
        showUnlock(lv)
      end
      return -- eine Stufe nach der anderen
    end
  end
end

-- Zustand für die UI-App (kommt mit HashiriyaState als st.unlock)
function M.unlockHud()
  local n = un.current
  if not n then return nil end
  return { level = n.level, key = n.key, reason = n.reason, carName = n.carName, total = n.total, cats = n.cats, more = n.more,
    left = math.max(un.timer, 0), seconds = noticeCfg().seconds }
end

-- Entwickler-Werkzeug: Meldung für eine Stufe sofort zeigen (ohne etwas freizuschalten)
function M.devShowUnlock(level)
  showUnlock(tonumber(level) or 2)
end

local function onUpdate(dtReal)
  local okU, errU = pcall(updateUnlocks, dtReal)
  if not okU and not un.warned then un.warned = true log('E', logTag, 'Freischalt-Meldung: ' .. tostring(errU)) end
  if retryTimer > 0 then retryTimer = retryTimer - dtReal end
  -- im Shop/in der Garage die Fahrzeugwerte regelmäßig auffrischen (nach jedem Respawn neu)
  local p = extensions.hashiriyaBattle_parking
  local area = p and p.isArrived() and p.getCurrent()
  if area and (area.type == 'shop' or area.type == 'garage') then
    statsTimer = statsTimer - dtReal
    if statsTimer <= 0 then statsTimer = 1.5; requestStats() end
  else
    carStats, baseStats = nil, nil
    if terminal then M.closeTerminal() end
  end
  if camTimer > 0 then
    camTimer = camTimer - dtReal
    if camTimer <= 0 and not (focusSlotName and view == 'part') then M.applyPreviewCamera() end
  end
  if refocusTimer > 0 then
    refocusTimer = refocusTimer - dtReal
    if refocusTimer <= 0 and focusSlotName then applyFocus() end
  end
end

local function onExtensionLoaded()
  M.loadData()
end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate

return M
