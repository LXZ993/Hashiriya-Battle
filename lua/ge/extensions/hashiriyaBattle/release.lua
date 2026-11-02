-- Hashiriya Battle: Release-Sperren (data/build.json "release": true)
-- Gleicht den Modus an die offizielle BeamNG-Karriere an (lua/ge/extensions/career/career.lua):
-- dieselben Tasten-Vorlagen über core_input_actionFilter, nur der Node Grabber bleibt.
-- Dazu: Fahrzeug-/Umgebungs-Tab und Freeroam-Knöpfe im ESC-Menü ausblenden, Schnellreise über die Karte sperren.
-- Läuft nur, solange die Karriere aktiv ist; beim Beenden wird alles zurückgesetzt.
local M = {}

local logTag = 'hashiriya'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
local function core() return extensions.hashiriyaBattle_core end

-- Wie career.lua: Vorlagen aus core_input_actionFilter, Node Grabber ausgenommen
local actionTemplates = { 'vehicleTeleporting', 'vehicleMenues', 'physicsControls', 'aiControls', 'vehicleSwitching', 'funStuff', 'editor', 'uiReloading' }
local nodeGrabberActions = { 'nodegrabberAction', 'nodegrabberGrab', 'nodegrabberRender', 'nodegrabberPadMode', 'nodegrabberStrength' }

-- ESC-Menü: Tabs und Knöpfe, die es in der offiziellen Karriere nicht gibt
local hiddenTabs = { vehicle = true, environment = true, multiplayer = true }
local hiddenRailActions = {
  ['home.repairHere'] = true, ['home.vehicleSelector'] = true, ['home.replay'] = true,
  ['home.changeLevel'] = true, ['home.splitScreen'] = true,
}
local blockedRoutePatterns = { '^pause%.vehicle', '^pause%.environment', '^pause%.multiplayer', '^pause%.freeroam', '^pause%.replay' }

local on = false
local blockedList = nil
local patched = {} -- [ext .. '.' .. fn] = original
local redirectPause = false
local patchTimer = 0

local function isBlockedRoute(name)
  for _, p in ipairs(blockedRoutePatterns) do
    if tostring(name or ''):find(p) then return true end
  end
  return false
end

local function buildBlockedList(af, bd)
  -- nodegrabberStrength bleibt nur gesperrt, wenn build.json es verlangt (feste Stärke)
  local whitelist = {}
  for _, a in ipairs(nodeGrabberActions) do whitelist[a] = true end
  for _, a in ipairs(bd.blockedActions or {}) do
    if a == 'nodegrabberStrength' then whitelist[a] = nil end
  end
  local list, seen = {}, {}
  local function add(a) if not seen[a] and not whitelist[a] then seen[a] = true table.insert(list, a) end end
  if af.createActionTemplate then
    for _, a in ipairs(af.createActionTemplate(actionTemplates) or {}) do add(a) end
  end
  for _, a in ipairs(bd.blockedActions or {}) do add(a) end
  return list
end

-- ESC-Menü filtern ------------------------------------------------------------

local function filterRail(rail)
  if type(rail) ~= 'table' then return rail end
  local out = {}
  for _, group in ipairs(rail) do
    if type(group) == 'table' and type(group.actions) == 'table' then
      local actions = {}
      for _, a in ipairs(group.actions) do
        if not (type(a) == 'table' and hiddenRailActions[a.id]) then table.insert(actions, a) end
      end
      if #actions > 0 then
        group.actions = actions
        table.insert(out, group)
      end
    else
      table.insert(out, group)
    end
  end
  return out
end

local function filterPauseData(data, routeName)
  local lm = type(data) == 'table' and data.layoutMenu
  if type(lm) ~= 'table' then return end
  local topbar = lm.topbar
  if type(topbar) == 'table' and type(topbar.tabs) == 'table' then
    local selected = topbar.tabs[(topbar.selectedTab or 0) + 1]
    local tabs = {}
    for _, tab in ipairs(topbar.tabs) do
      if not hiddenTabs[tab.tabId] then
        if tab.tabId == 'home' then
          tab.label = 'Hashiriya Battle'
          tab.icon = 'road'
        end
        table.insert(tabs, tab)
      end
    end
    topbar.tabs = tabs
    topbar.selectedTab = 0
    for i, tab in ipairs(tabs) do
      if tab == selected then topbar.selectedTab = i - 1 end
    end
  end
  if type(lm.content) == 'table' then lm.content.rail = filterRail(lm.content.rail) end
  if isBlockedRoute(routeName) then redirectPause = true end
end

local function pauseWrapper(orig)
  return function(context, toRoute, fromRoute, data)
    local r = orig(context, toRoute, fromRoute, data)
    if on then
      local ok, err = pcall(filterPauseData, data, toRoute and toRoute.name)
      if not ok then log('W', logTag, 'ESC-Menü filtern fehlgeschlagen: ' .. tostring(err)) end
    end
    return r
  end
end

local function quickTravelBlocked()
  return function()
    local c = core()
    if c then c.msg(c.t('msg.noQuickTravel'), 3) end
  end
end

local function vehicleSelectorBlocked()
  return function() return false end
end

-- Funktionen anderer Extensions ersetzen, sobald sie geladen sind (einige laden erst später, z. B. die große Karte)
local patches = {
  { ext = 'ui_pause_routeLifecycleCallbacks', fn = 'onPauseEnter', make = pauseWrapper },
  { ext = 'ui_pause_routeLifecycleCallbacks', fn = 'onPauseMount', make = pauseWrapper },
  { ext = 'freeroam_bigMapMode', fn = 'teleportToPoi', make = quickTravelBlocked, flag = 'blockBigMapTeleport' },
  { ext = 'ui_vehicleSelector_general', fn = 'openFromPause', make = vehicleSelectorBlocked },
}

local function applyPatches(want, bd)
  for _, p in ipairs(patches) do
    local key = p.ext .. '.' .. p.fn
    local mod = rawget(_G, p.ext)
    local enabled = want and not (p.flag and bd and bd[p.flag] == false)
    if mod and type(mod[p.fn]) == 'function' then
      if enabled and not patched[key] then
        patched[key] = { orig = mod[p.fn], mod = mod }
        mod[p.fn] = p.make(mod[p.fn])
      elseif not enabled and patched[key] then
        if patched[key].mod == mod then mod[p.fn] = patched[key].orig end
        patched[key] = nil
      end
    elseif patched[key] and patched[key].mod ~= mod then
      patched[key] = nil -- Extension wurde neu geladen
    end
  end
end

-- Ein/Aus -----------------------------------------------------------------------

local function setActionFilter(want, bd)
  local af = rawget(_G, 'core_input_actionFilter') or (extensions and extensions.core_input_actionFilter)
  if not af or not af.setGroup or not af.addAction then
    if want then log('W', logTag, 'core_input_actionFilter fehlt, Tasten-Sperren nicht aktiv') end
    return
  end
  local ok, err = pcall(function()
    if want then
      blockedList = buildBlockedList(af, bd)
      af.setGroup('hashiriyaBlocked', blockedList)
    end
    af.addAction(0, 'hashiriyaBlocked', want)
  end)
  log(ok and 'I' or 'W', logTag, 'Release-Sperren ' .. (want and ('an (' .. #(blockedList or {}) .. ' Tastenaktionen)') or 'aus') .. (ok and '' or (': ' .. tostring(err))))
  if want and bd.nodeGrabberStrength then
    pcall(function() be.nodeGrabber:setStrength(bd.nodeGrabberStrength) end)
  end
end

function M.update(dtReal, want, bd)
  bd = bd or {}
  if want ~= on then
    on = want
    setActionFilter(want, bd)
    applyPatches(want, bd)
    patchTimer = 0
    -- POI-Liste der großen Karte neu bauen lassen (core.onGetRawPoiListForLevel nimmt die Schnellreise raus)
    local rp = rawget(_G, 'gameplay_rawPois')
    if rp and rp.clear then pcall(rp.clear) end
    -- offenes Menü neu aufbauen, damit Tabs sofort stimmen
    local router = rawget(_G, 'ui_router')
    if want and router and router.getCurrent then
      local okR, route = pcall(router.getCurrent)
      if okR and type(route) == 'table' and tostring(route.name or route.routeName or ''):find('^pause') then redirectPause = true end
    end
  end
  if not on then return end
  patchTimer = patchTimer - (dtReal or 0)
  if patchTimer <= 0 then
    patchTimer = 1
    applyPatches(true, bd)
  end
  if redirectPause then
    redirectPause = false
    local router = rawget(_G, 'ui_router')
    if router and router.navigate then pcall(router.navigate, 'pause') end
  end
end

function M.isOn() return on end
function M.getBlockedActions() return blockedList or {} end

return M
