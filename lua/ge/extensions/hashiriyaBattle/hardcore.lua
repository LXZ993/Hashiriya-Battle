-- Hashiriya Battle: Hardcore-Modus
-- Wird beim Anlegen eines neuen Spielstands gewählt (career.lua, letzter Schritt) und steht dann fest im
-- Spielstand (save.hardcore = true). Alle Regeln stehen in data/hardcore.json und wirken nur auf
-- Hardcore-Spielstände. Die einzelnen Systeme fragen hier nach:
--   Kaltstart            BeamNG-Einstellung startThermalsPreHeated aus, solange ein Hardcore-Spielstand läuft
--   Wartung              maintenance.lua (Intervall, Wirkung)
--   Tank                 condition.lua (Starttank), fuel.lua (Mehrverbrauch)
--   Preise / Preisgeld   parking, shop, maintenance, fuel, dealer, police, core (Kennzeichen, Siege)
--   Pink Slip Pflicht    talk.lua
--   Game Over            core.lua (Spielstand löschen nach dem Game-Over-Bildschirm)
--   Polizei / Verkehr    police.lua (mehr Laserkontrollen), core.lua (mehr Verkehr)
--   Speichern / Ironman  savepoint.lua, battle.lua, core.lua
--   HUD                  rivals.lua (Minimap), core.lua (Radar)
--   Reisen               travel.lua (keine Schnellreise zu PAs/Garage)
local M = {}

local logTag = 'hashiriya.hardcore'
local function log(level, tag, text) local L = rawget(_G, 'hashiriyaBattle_logger') if L then L.log(level, tag, text) else _G.log(level, tag, text) end end
local function core() return extensions.hashiriyaBattle_core end
local dataPath = '/lua/ge/extensions/hashiriyaBattle/data/hardcore.json'
local thermalsState = 'settings/hashiriya_battle/hardcore_thermals.json'

local defaults = {
  enabled = true,
  coldStart = true, maintIntervalFactor = 0.5, maintEffectFactor = 1.6, startFuel = 0.12, fuelUseFactor = 1.5,
  priceFactor = 1.5, rewardFactor = 0.75, pinkSlipForced = true, gameOverDeletesSave = true,
  laserExtra = 2, trafficFactor = 1.3, noPaTravel = true,
  saveOnlyHome = true, towFineFactor = 2, ironman = true,
  hideRivalMarks = true,
}

local data = nil
function M.cfg()
  if not data then
    local d = jsonReadFile(dataPath) or {}
    data = {}
    for k, v in pairs(defaults) do if d[k] ~= nil then data[k] = d[k] else data[k] = v end end
  end
  return data
end

-- Läuft gerade ein Hardcore-Spielstand? (save optional, sonst der laufende)
function M.on(save)
  if not M.cfg().enabled then return false end
  if not save then
    local c = core()
    save = c and c.save
  end
  return save ~= nil and save.hardcore == true
end

-- Einzelne Regel an? (Schalter aus hardcore.json, nur im Hardcore-Spielstand)
function M.rule(key, save)
  return M.on(save) and M.cfg()[key] == true
end

-- Zahlenwert einer Regel; außerhalb von Hardcore der neutrale Wert (Standard 1)
function M.num(key, neutral)
  neutral = neutral == nil and 1 or neutral
  if not M.on() then return neutral end
  return tonumber(M.cfg()[key]) or neutral
end

-- Preis in Yen mit Hardcore-Aufschlag (auf 10 Yen gerundet)
function M.price(yen)
  yen = tonumber(yen) or 0
  local f = M.num('priceFactor')
  if f == 1 or yen <= 0 then return yen end
  return math.floor(yen * f / 10 + 0.5) * 10
end

-- Kaltstart -------------------------------------------------------------------------
-- BeamNG liest startThermalsPreHeated beim Spawnen eines Autos (combustionEngineThermals.lua).
-- Wir merken uns Alex' eigenen Wert in einer Datei, damit er auch nach einem Absturz zurückkommt.

local function getSetting()
  local ok, v = pcall(function() return settings.getValue('startThermalsPreHeated') end)
  if ok then return v end
  return nil
end

local function setSetting(v)
  local ok, err = pcall(function() settings.setValue('startThermalsPreHeated', v) end)
  if not ok then log('W', logTag, 'startThermalsPreHeated setzen fehlgeschlagen: ' .. tostring(err)) end
  return ok
end

local function restoreThermals()
  local st = FS:fileExists(thermalsState) and jsonReadFile(thermalsState) or nil
  if type(st) ~= 'table' or not st.changed then return end
  local orig = st.original
  if orig == nil then orig = true end
  if setSetting(orig) then
    log('I', logTag, 'Kaltstart aus, startThermalsPreHeated wieder ' .. tostring(orig))
    pcall(function() FS:removeFile(thermalsState) end)
  end
end

local function applyThermals()
  if not M.rule('coldStart') then
    restoreThermals()
    return
  end
  local st = FS:fileExists(thermalsState) and jsonReadFile(thermalsState) or nil
  if type(st) ~= 'table' or not st.changed then
    local orig = getSetting()
    jsonWriteFile(thermalsState, { changed = true, original = orig == nil and true or orig }, true)
  end
  if setSetting(false) then log('I', logTag, 'Kaltstart an (startThermalsPreHeated = false)') end
end

-- Spielstand geladen oder neu angelegt (vor dem Spawn des Autos aufrufen)
function M.onSaveLoaded()
  applyThermals()
  if M.on() then log('I', logTag, 'Hardcore-Spielstand aktiv') end
end

-- Spielstand beendet: BeamNG-Einstellung zurück
function M.onStop()
  restoreThermals()
end

-- Mehrverbrauch Sprit ------------------------------------------------------------------
-- fuel.lua meldet jede Tankabfrage (ca. 1 s). Ist der Tank seit der letzten Abfrage gesunken,
-- ziehen wir den Anteil (fuelUseFactor - 1) davon zusätzlich ab.
local lastFuel = nil -- { id, liters }
function M.extraFuel(vehId, remaining)
  local f = M.num('fuelUseFactor')
  remaining = tonumber(remaining)
  if f <= 1 or not remaining then lastFuel = nil return nil end
  local prev = lastFuel
  lastFuel = { id = vehId, liters = remaining }
  if not prev or prev.id ~= vehId then return nil end
  local used = prev.liters - remaining
  -- nur normaler Verbrauch (kein Tanken, kein Reisen, kein Respawn)
  if used <= 0 or used > 0.5 then return nil end
  local want = math.max(0, remaining - used * (f - 1))
  lastFuel.liters = want
  return want
end
function M.resetFuel() lastFuel = nil end

-- Ironman: Battle läuft -> beim nächsten Laden verloren ---------------------------------
function M.battleStarted(rival)
  if not M.rule('ironman') or not rival then return end
  local c = core()
  c.save.hcBattle = { id = rival.id, name = rival.name }
  c.writeSave()
end

function M.battleEnded()
  local c = core()
  if c and c.save then c.save.hcBattle = nil end
end

-- Beim Laden: offenes Battle zählt als Niederlage
function M.checkForfeit()
  local c = core()
  local save = c.save
  if not save or not save.hcBattle then return end
  local b = save.hcBattle
  save.hcBattle = nil
  if not M.rule('ironman') then return end
  save.losses = (save.losses or 0) + 1
  save.lastLossDay = save.day or 1
  pcall(function() extensions.hashiriyaBattle_style.resetStreak('loss') end)
  c.writeSave()
  c.msg(c.t('hardcore.forfeit', tostring(b.name or b.id)), 10)
  log('I', logTag, 'Ironman: Battle gegen ' .. tostring(b.id) .. ' abgebrochen = Niederlage')
end

-- Game Over: Spielstand löschen ---------------------------------------------------------
-- Gibt true zurück, wenn gelöscht wurde.
function M.wipeAfterGameOver()
  local c = core()
  local save = c.save
  if not save or not save.gameOver or not M.rule('gameOverDeletesSave', save) then return false end
  local slot = c.currentSlot()
  pcall(c.stopGame)
  c.save = nil
  local ok = c.deleteSlot(slot)
  log('I', logTag, 'Game Over im Hardcore: Spielstand-Platz ' .. tostring(slot) .. (ok and ' gelöscht' or ' NICHT gelöscht'))
  return ok
end

-- Reload (Dev-Menü / Handbuch: Datei geändert)
function M.reload() data = nil end

function M.onExtensionLoaded()
  -- nach einem Absturz mitten im Hardcore-Spielstand: BeamNG-Einstellung zurück
  restoreThermals()
end

return M
