-- Hashiriya Battle: Trophäenwand = Logo-Sammlung (wie die Aufkleber in TXR) + Trophäen für Leader und Bosse
-- (Spitznamen stehen als dritter Reiter daneben, Logik in progress.lua)
--
-- Wer eine Crew (ihren Leader), einen Wanderer oder einen Boss besiegt, bekommt dessen Logo in die Sammlung.
-- Eins davon wählt der Spieler als sein eigenes Logo: es steht dann im Battle oben links in der SP-Anzeige
-- (statt dem Hashiriya-Zeichen 走) und auf der Karte oben im Menü.
--
-- Freigeschaltet wird nichts extra gespeichert: die Sammlung ergibt sich aus save.defeated (alte Spielstände
-- haben also sofort alle Logos der schon besiegten Gegner). Gespeichert wird nur die Wahl: save.playerLogo
-- (nil = Hashiriya-Zeichen). Jeder Spielstand (Platz 1-3) hat seine eigene Wahl.
--
-- Einträge:
--   default         Hashiriya-Zeichen 走, immer da
--   t_<crew>        Crew-Logo, frei sobald der Leader der Crew besiegt ist
--   w_<id> / b_<id> Siegel / Emblem des Wanderers / Bosses, frei nach dem Sieg
-- Bilddateien: wie überall art/logos/<id>.svg (oder .png, oder "logo" in rivals.json), siehe rivals.lua logoOf.
local M = {}

local function core() return extensions.hashiriyaBattle_core end
local function rivals() return extensions.hashiriyaBattle_rivals end
local function loc(v) return extensions.hashiriyaBattle_progress.loc(v) end

M.defaultMark = '/ui/ui-vue/mods/hashiriyaBattle/assets/icon.png'

local function leaderOf(data, teamId)
  for _, r in ipairs(data.rivals or {}) do if r.team == teamId and r.leader then return r end end
end

-- Alle sammelbaren Logos (ohne das Standard-Zeichen), in Lexikon-Reihenfolge: Crews, Wanderer, Bosse.
-- Kurz zwischengespeichert, weil das Menü den Zustand oft neu baut.
local cache = { t = -1, save = nil, list = nil }
local function build(save)
  local rv = rivals()
  local data = rv and rv.getData and rv.getData() or {}
  local defeated = save and save.defeated or {}
  local list = {}
  for _, tm in ipairs(data.teams or {}) do
    local leader = leaderOf(data, tm.id)
    if leader then
      table.insert(list, { id = tm.id, kind = 'crew', name = tm.name, jp = tm.jp, color = tm.color,
        unlocked = defeated[leader.id] and true or false, source = leader,
        logo = rv.teamLogo(tm.id), icon = rv.teamLogo(tm.id, false, true) })
    end
  end
  for _, kind in ipairs({ 'wanderer', 'boss' }) do
    for _, r in ipairs(data.rivals or {}) do
      if (kind == 'boss' and r.boss) or (kind == 'wanderer' and r.wanderer and not r.boss) then
        local p = rv.logoOf(r)
        if p then
          table.insert(list, { id = r.id, kind = kind, name = r.name, nick = loc(r.nick),
            unlocked = defeated[r.id] and true or false, source = r, logo = p, icon = p })
        end
      end
    end
  end
  return list
end

local function entries(save)
  local now = os.clock()
  if cache.list and cache.save == save and now - cache.t < 0.5 then return cache.list end
  cache.list, cache.save, cache.t = build(save), save, now
  return cache.list
end
function M.invalidate() cache.list = nil end
-- Für stickers.lua: dieselbe Liste wie in der Trophäenwand
function M.entries(save) return entries(save) end

local function find(save, id)
  if not id then return nil end
  for _, e in ipairs(entries(save)) do if e.id == id then return e end end
end

-- Bild für das eigene Logo im HUD (Symbol ohne Schrift, wenn es eins gibt)
function M.playerLogo(save)
  save = save or core().save
  local e = save and find(save, save.playerLogo)
  if e and e.unlocked then return e.icon or e.logo end
  return M.defaultMark
end

-- Logo wählen ('default' oder nil = Hashiriya-Zeichen). Nur freigeschaltete.
function M.choose(id)
  local c = core()
  local save = c.save
  if not save then return false end
  if id == nil or id == '' or id == 'default' then
    save.playerLogo = nil
  else
    local e = find(save, id)
    if not e or not e.unlocked then return false end
    save.playerLogo = id
  end
  c.writeSave()
  if c.sound then pcall(c.sound, 'click') end
  return true
end

-- Nach einem Sieg (von core.onBattleResult): Name des neuen Logos, falls dieser Sieg eins freigeschaltet hat
function M.newlyUnlocked(rival)
  if not rival then return nil end
  local save = core().save
  local id = rival.baseId or rival.id
  if rival.rematch then return nil end
  M.invalidate()
  if rival.wanderer or rival.boss then
    local e = find(save, id)
    return e and e.unlocked and e.name or nil
  end
  if rival.leader and rival.team then
    local e = find(save, rival.team)
    return e and e.unlocked and e.name or nil
  end
  return nil
end

-- Daten für den Menü-Bildschirm "Logo-Sammlung"
function M.getUiState()
  local c = core()
  local save = c.save
  if not save then return nil end
  local home = extensions.hashiriyaBattle_home
  local groups = {
    { key = 'crew', name = c.t('logos.g.crew'), list = {} },
    { key = 'wanderer', name = c.t('logos.g.wanderer'), list = {} },
    { key = 'boss', name = c.t('logos.g.boss'), list = {} },
  }
  local byKey = { crew = groups[1], wanderer = groups[2], boss = groups[3] }
  local have, total = 0, 0
  local current = save.playerLogo
  for _, e in ipairs(entries(save)) do
    total = total + 1
    if e.unlocked then have = have + 1 end
    local hidden = not e.unlocked and e.kind ~= 'crew'
    local hint
    if not e.unlocked then
      if e.kind == 'crew' then hint = c.t('logos.hint.crew', e.source.name)
      else hint = (home and home.hintText and home.hintText(e.source, save)) or c.t('logos.hint.' .. e.kind) end
    end
    local g = byKey[e.kind]
    table.insert(g.list, {
      id = e.id, unlocked = e.unlocked, selected = current == e.id,
      -- Crew-Logos sieht man schon vorher (Lexikon), Siegel und Embleme erst nach dem Sieg
      logo = (not hidden) and e.logo or nil,
      name = hidden and '???' or e.name, jp = e.jp, nick = (not hidden) and e.nick or nil,
      color = e.color, hint = hint,
    })
    if e.unlocked then g.have = (g.have or 0) + 1 end
  end
  for _, g in ipairs(groups) do g.have = g.have or 0; g.total = #g.list end
  local cur = current and find(save, current)
  if cur and not cur.unlocked then cur = nil end
  return {
    have = have, total = total,
    current = cur and cur.id or 'default',
    currentName = cur and cur.name or c.t('logos.default'),
    currentLogo = cur and cur.logo or M.defaultMark,
    defaultMark = M.defaultMark,
    groups = groups,
  }
end

-- Kurzinfo für die Kachel im Menü
function M.tileInfo()
  local save = core().save
  if not save then return nil end
  local have, total = 0, 0
  for _, e in ipairs(entries(save)) do
    total = total + 1
    if e.unlocked then have = have + 1 end
  end
  return { have = have, total = total, logo = M.playerLogo(save) }
end

-- Trophäen (Reiter "Trophäen" der Trophäenwand) ---------------------------------------
-- Jeder besiegte Crew-Leader gibt eine Wand-Plakette mit dem goldenen Leader-Logo, jeder Boss einen Pokal mit seinem
-- Emblem, der Endboss den großen Pokal. Die Bilder sind 2D: Grundbild aus art/trophies/ (plaque.svg, cup.svg, final.svg),
-- das Menü legt das Logo darauf und schreibt den Namen auf das Schild.
-- Frei ist eine Trophäe, sobald der Gegner in save.defeated steht (alte Spielstände haben ihre sofort).
-- Beim ersten Sieg merkt sich save.trophies[id] = { day, car, time } (Tag, dein Auto, Battle-Zeit) für die Infozeile.
M.trophyArt = { leader = '/art/trophies/plaque.svg', boss = '/art/trophies/cup.svg', final = '/art/trophies/final.svg' }

local function trophyList(save)
  local rv = rivals()
  local data = rv and rv.getData and rv.getData() or {}
  local defeated = save and save.defeated or {}
  local list = {}
  for _, tm in ipairs(data.teams or {}) do
    local leader = leaderOf(data, tm.id)
    if leader then
      table.insert(list, { id = leader.id, kind = 'leader', art = M.trophyArt.leader, name = tm.name, jp = tm.jp, color = tm.color,
        sub = leader.name, nick = loc(leader.nick), unlocked = defeated[leader.id] and true or false, source = leader,
        logo = rv.teamLogo(tm.id, true, true) or rv.teamLogo(tm.id) })
    end
  end
  for _, r in ipairs(data.rivals or {}) do
    if r.boss then
      local kind = r.final and 'final' or 'boss'
      table.insert(list, { id = r.id, kind = kind, art = M.trophyArt[kind], name = r.name, nick = loc(r.nick),
        unlocked = defeated[r.id] and true or false, source = r, logo = rv.logoOf(r) })
    end
  end
  return list
end

-- Nach einem Sieg (core.onBattleResult): Trophäe eintragen. Gibt den Namen zurück, wenn es eine neue ist.
function M.recordTrophy(rival, result)
  if not rival or rival.rematch or not (rival.leader or rival.boss) then return nil end
  local c = core()
  local save = c.save
  if not save then return nil end
  local id = rival.baseId or rival.id
  save.trophies = save.trophies or {}
  if save.trophies[id] then return nil end
  local car = save.cars and save.cars[save.activeCar or 1]
  save.trophies[id] = { day = save.day or 1, car = car and car.name or nil, time = result and result.time or nil }
  c.writeSave()
  if rival.leader and rival.team then return rivals().teamName(rival.team) or rival.name end
  return rival.name
end

local function fmtTime(t)
  if not t then return nil end
  return string.format('%d:%04.1f', math.floor(t / 60), t % 60)
end

function M.getTrophyUi()
  local c = core()
  local save = c.save
  if not save then return nil end
  local home = extensions.hashiriyaBattle_home
  local rec = save.trophies or {}
  local groups = {
    { key = 'leader', name = c.t('trophy.g.leader'), list = {}, have = 0 },
    { key = 'boss', name = c.t('trophy.g.boss'), list = {}, have = 0 },
  }
  local have, total = 0, 0
  for _, e in ipairs(trophyList(save)) do
    local g = e.kind == 'leader' and groups[1] or groups[2]
    total = total + 1
    if e.unlocked then have = have + 1; g.have = g.have + 1 end
    local hidden = not e.unlocked and e.kind ~= 'leader'
    local r = rec[e.id]
    local info
    if e.unlocked then
      local parts = {}
      if r and r.day then parts[#parts + 1] = c.t('trophy.day', r.day) end
      if r and r.car then parts[#parts + 1] = r.car end
      if r and r.time then parts[#parts + 1] = fmtTime(r.time) end
      info = #parts > 0 and table.concat(parts, ' · ') or c.t('trophy.old')
    end
    local hint
    if not e.unlocked then
      if e.kind == 'leader' then hint = c.t('trophy.hint.leader', e.source.name)
      else hint = (home and home.hintText and home.hintText(e.source, save)) or c.t('trophy.hint.boss') end
    end
    table.insert(g.list, {
      id = e.id, kind = e.kind, art = e.art, unlocked = e.unlocked,
      logo = (not hidden) and e.logo or nil,
      name = hidden and '???' or e.name, jp = e.jp, color = e.color,
      sub = (not hidden) and e.sub or nil, nick = (not hidden) and e.nick ~= '' and e.nick or nil,
      info = info, hint = hint,
      plate = (e.unlocked and r and r.day) and c.t('trophy.day', r.day) or nil,   -- Gravur auf dem Schild
    })
  end
  for _, g in ipairs(groups) do g.total = #g.list end
  return { have = have, total = total, groups = groups }
end

return M
