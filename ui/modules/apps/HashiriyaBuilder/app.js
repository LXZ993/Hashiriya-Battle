// Hashiriya Battle: Builder (Entwickler-Werkzeug) für Crews, Wanderer und Bosse.
// Öffnen: Hashiriya-Menü > Werkzeuge > Builder. Lua-Seite: lua/ge/extensions/hashiriyaBattle/builder.lua
// Die App bekommt rivals.json als Text (Hook 'HashiriyaBuilder'), bearbeitet ihn hier (JSON-Reihenfolge bleibt)
// und schickt den ganzen Text beim Speichern in Stücken zurück. Im Release-Build ist der Builder aus.
angular.module('beamng.apps')
.directive('hashiriyaBuilder', [function () {
  return {
    templateUrl: '/ui/modules/apps/HashiriyaBuilder/app.html',
    replace: true,
    link: function (scope, element) {
      'use strict'
      // Die App liegt im Layout über dem ganzen Bildschirm: geschlossen darf sie keine Klicks abfangen
      // (auch nicht ihr BeamNG-Rahmen), offen schon.
      function setClickable(on) {
        var el = element[0]
        for (var i = 0; i < 3 && el; i++) { el.style.pointerEvents = on ? 'auto' : 'none'; el = el.parentElement }
      }
      setClickable(false)

      var b = scope.b = {
        open: false, tab: 'crews', filter: '', data: null, configs: [], modelMap: {}, portraits: {}, plates: null,
        player: null, active: false, root: null, sel: null, form: null, snap: null, pending: null, status: null,
        armed: null, carName: '', addRival: '', busy: false
      }
      scope.roles = [
        { id: 'member', name: 'Crew-Mitglied' }, { id: 'leader', name: 'Crew-Leader' },
        { id: 'wanderer', name: 'Wanderer' }, { id: 'boss', name: 'Boss' }
      ]
      scope.driverKeys = [
        { id: 'skill', name: 'Können' }, { id: 'courage', name: 'Mut' }, { id: 'aggression', name: 'Aggression' },
        { id: 'nerves', name: 'Nerven' }, { id: 'fairness', name: 'Fairness' }
      ]
      scope.lineKeys = [
        { id: 'challenge', name: 'Herausforderung' }, { id: 'win', name: 'Rivale gewinnt' }, { id: 'lose', name: 'Rivale verliert' }
      ]
      // Auswahl-Listen für die eigenen Dropdowns (BeamNG öffnet keine HTML-<select>)
      scope.opts = {
        roles: [{ v: 'member', l: 'Crew-Mitglied' }, { v: 'leader', l: 'Crew-Leader' }, { v: 'wanderer', l: 'Wanderer' }, { v: 'boss', l: 'Boss' }],
        appear: [{ v: 'sameNight', l: 'in derselben Nacht wie das letzte Mitglied' }, { v: 'nextNight', l: 'erst in der nächsten Nacht' }],
        lights: [{ v: '', l: 'normal' }, { v: 'off', l: 'aus (Markenzeichen)' }, { v: 'on', l: 'immer an' }]
      }
      scope.teamOpts = function () { return teams().map(function (t) { return { v: t.id, l: t.name } }) }
      scope.modelOpts = function () { return b.configs.map(function (m) { return { v: m.id, l: m.name + ' (' + m.id + ')' } }) }
      scope.configOpts = function () {
        return scope.modelConfigs().map(function (c) {
          return { v: scope.configPath(c), l: c.name + (c.source && c.source !== 'BeamNG - Official' ? ' · ' + c.source : '') }
        })
      }
      scope.regionOpts = function () { return ((b.plates && b.plates.regions) || []).map(function (r) { return { v: r, l: r } }) }
      scope.plateTypeOpts = function () { return scope.plateTypes().map(function (t) { return { v: t, l: scope.typeNames[t] || t } }) }
      scope.rankOpts = function () { return scope.ranks().map(function (r, i) { return { v: String(i), l: scope.rankName(i) } }) }
      scope.typeNames = {
        standard: 'Privat', kei: 'Kei', commercial: 'Gewerbe', keicommercial: 'Kei-Gewerbe', temporary: 'Überführung',
        glow: 'Leuchtend', olympic: 'Olympia', olympiccommercial: 'Olympia Gewerbe', airforce: 'US Air Force'
      }

      // --- Hilfen ---------------------------------------------------------------
      function clone(o) { return o === undefined ? undefined : JSON.parse(JSON.stringify(o)) }
      function slug(s) {
        return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
          .replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'neu'
      }
      function txt(o, lang) { return o && typeof o === 'object' ? (o[lang] || '') : (lang === 'de' ? (o || '') : '') }
      function bi(o) { return { de: txt(o, 'de'), en: txt(o, 'en') } }
      function biOut(o) {
        if (!o || (!o.de && !o.en)) return undefined
        return { de: o.de || '', en: o.en || '' }
      }
      function num(v, def) { var n = parseFloat(v); return isNaN(n) ? def : n }
      function hexToRgb(h) {
        var m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(h || '')
        if (!m) return [0.5, 0.5, 0.5]
        return [1, 2, 3].map(function (i) { return Math.round(parseInt(m[i], 16) / 255 * 1000) / 1000 })
      }
      function rgbToHex(c) {
        if (!Array.isArray(c)) return '#808080'
        return '#' + c.slice(0, 3).map(function (v) {
          var x = Math.max(0, Math.min(255, Math.round((v || 0) * 255))).toString(16)
          return x.length < 2 ? '0' + x : x
        }).join('')
      }
      function lua(cmd) { bngApi.engineLua('if extensions.hashiriyaBattle_builder then extensions.hashiriyaBattle_builder.' + cmd + ' end') }
      // JS-Text als Lua-Stringliteral (eigene Escapes, damit kein \u im Text landet)
      function luaStr(s) {
        return '"' + s.replace(/[\\"\x00-\x1f\x7f]/g, function (c) {
          if (c === '\\') return '\\\\'
          if (c === '"') return '\\"'
          if (c === '\n') return '\\n'
          if (c === '\r') return '\\r'
          if (c === '\t') return '\\t'
          var d = String(c.charCodeAt(0))
          return '\\' + ('000' + d).slice(-3)
        }) + '"'
      }
      function sendText(what, text) {
        lua('chunkBegin()')
        var size = 16000, i = 0
        while (i < text.length) {
          var end = Math.min(i + size, text.length)
          var code = text.charCodeAt(end - 1)
          if (end < text.length && code >= 0xD800 && code <= 0xDBFF) end-- // Emoji nicht zerschneiden
          lua('chunk(' + luaStr(text.slice(i, end)) + ')')
          i = end
        }
        lua('chunkEnd("' + what + '")')
      }

      // --- Daten ----------------------------------------------------------------
      function rivals() { return (b.data && b.data.rivals) || [] }
      function teams() { return (b.data && b.data.teams) || [] }
      function teamById(id) { return teams().filter(function (t) { return t.id === id })[0] }
      function rivalById(id) { return rivals().filter(function (r) { return r.id === id })[0] }
      function roleOf(r) { return r.boss ? 'boss' : r.wanderer ? 'wanderer' : r.leader ? 'leader' : 'member' }
      scope.roleOf = roleOf
      scope.roleIsLeader = function (r) { return !!r.leader }
      scope.teams = teams
      scope.ranks = function () { return (b.data && b.data.ranks) || [] }
      scope.rankName = function (i) { var r = scope.ranks()[i]; return r ? (i + ' · ' + txt(r.name, 'de')) : String(i) }
      scope.teamMembers = function (teamId) {
        return rivals().filter(function (r) { return r.team === teamId && !r.wanderer && !r.boss })
          .sort(function (a, c) { return (c.leader ? 1 : 0) - (a.leader ? 1 : 0) })
      }
      function matches(r) {
        var q = (b.filter || '').toLowerCase()
        if (!q) return true
        return (r.name + ' ' + r.id + ' ' + (r.model || '') + ' ' + txt(r.nick, 'de')).toLowerCase().indexOf(q) >= 0
      }
      scope.listTeams = function () {
        var q = (b.filter || '').toLowerCase()
        return teams().filter(function (t) {
          if (!q) return true
          if ((t.name + ' ' + t.id + ' ' + (t.jp || '')).toLowerCase().indexOf(q) >= 0) return true
          return scope.teamMembers(t.id).some(matches)
        })
      }
      scope.listKind = function (kind) {
        return rivals().filter(function (r) { return roleOf(r) === kind && matches(r) })
      }
      scope.isSel = function (kind, id) { return b.sel && b.sel.kind === kind && b.sel.id === id }
      scope.portraitOf = function (id) { return b.portraits[id] || null }
      scope.modelName = function (id) { var m = b.modelMap[id]; return m ? m.name : id }
      scope.modelConfigs = function () { var m = b.form && b.modelMap[b.form.model]; return m ? m.configs : [] }

      // --- Formular Rivale --------------------------------------------------------
      function rivalForm(r, isNew) {
        var c = r.conditions || {}
        var hours = c.hours || c.timeWindow
        var plateRegion = 'shinagawa', plateType = 'standard'
        var m = /^am5jp_([a-z]+)_([a-z]+)$/.exec((r.plate && r.plate.design) || '')
        if (m) { plateRegion = m[1]; plateType = m[2] }
        var f = {
          type: 'rival', isNew: !!isNew, orig: clone(r), id: r.id || '', name: r.name || '', nick: bi(r.nick),
          role: roleOf(r), team: r.team || '', appear: r.appear || 'sameNight', final: !!r.final,
          model: r.model || '', config: r.config || '',
          aggression: num(r.aggression, 0.5), cruiseKmh: num(r.cruiseKmh, 100), maxSp: num(r.maxSp, 1000),
          rewardUsd: num(r.rewardUsd, 2000), rep: num(r.rep, 50), lights: r.lights || '',
          driverOn: !!r.driver, driver: {},
          cond: {
            minRank: c.minRank != null ? String(c.minRank) : '', minWins: c.minWins != null ? c.minWins : null,
            minDay: c.minDay != null ? c.minDay : null, hoursOn: !!hours,
            hFrom: hours ? hours[0] : 22, hTo: hours ? hours[1] : 4,
            speedTraps: c.speedTraps != null ? String(c.speedTraps) : '', playerModel: c.playerModel || '',
            playerPart: c.playerPart || '', beatenTeam: c.beatenTeam || '',
            beatenTeams: (c.beatenTeams || []).slice(), beatenRivals: (c.beatenRivals || []).slice()
          },
          plateText: (r.plate && r.plate.text) || '', plateRegion: plateRegion, plateType: plateType,
          paintOn: !!r.paint, paintHex: rgbToHex(r.paint && r.paint.color), paintName: (r.paint && r.paint.name) || '',
          metallic: num(r.paint && r.paint.metallic, 0.3), roughness: num(r.paint && r.paint.roughness, 0.3),
          lines: {}, desc: bi(r.desc), hint: bi(r.hint), portrait: r.portrait || ''
        }
        scope.driverKeys.forEach(function (k) { f.driver[k.id] = num(r.driver && r.driver[k.id], 0.5) })
        scope.lineKeys.forEach(function (k) { f.lines[k.id] = bi(r.lines && r.lines[k.id]) })
        return f
      }

      // Formular -> Eintrag. Unbekannte Felder (z. B. _platzhalter, community, credit) bleiben erhalten.
      var managed = ['id', 'name', 'nick', 'team', 'leader', 'appear', 'wanderer', 'boss', 'final', 'model', 'config',
        'aggression', 'cruiseKmh', 'maxSp', 'rewardUsd', 'rep', 'lights', 'driver', 'conditions', 'plate', 'paint',
        'portrait', 'lines', 'desc', 'hint']
      function formToRival(f) {
        var r = {}
        var c = {}
        if (f.cond.minRank !== '') c.minRank = parseInt(f.cond.minRank, 10)
        if (f.cond.minWins) c.minWins = parseInt(f.cond.minWins, 10)
        if (f.cond.minDay) c.minDay = parseInt(f.cond.minDay, 10)
        if (f.cond.speedTraps !== '') c.speedTraps = f.cond.speedTraps === 'all' ? 'all' : parseInt(f.cond.speedTraps, 10)
        if (f.cond.hoursOn) c.hours = [parseInt(f.cond.hFrom, 10) || 0, parseInt(f.cond.hTo, 10) || 0]
        if (f.cond.playerModel) c.playerModel = f.cond.playerModel
        if (f.cond.playerPart) c.playerPart = f.cond.playerPart
        if (f.cond.beatenTeam) c.beatenTeam = f.cond.beatenTeam
        if (f.cond.beatenTeams.length) c.beatenTeams = f.cond.beatenTeams.slice()
        if (f.cond.beatenRivals.length) c.beatenRivals = f.cond.beatenRivals.slice()
        var lines = {}, anyLine = false
        scope.lineKeys.forEach(function (k) { var v = biOut(f.lines[k.id]); if (v) { lines[k.id] = v; anyLine = true } })
        var vals = {
          id: f.id, name: f.name, nick: biOut(f.nick),
          team: (f.role === 'member' || f.role === 'leader') ? f.team : undefined,
          leader: f.role === 'leader' ? true : undefined,
          appear: f.role === 'leader' ? f.appear : undefined,
          wanderer: f.role === 'wanderer' ? true : undefined,
          boss: f.role === 'boss' ? true : undefined,
          final: f.role === 'boss' && f.final ? true : undefined,
          model: f.model, config: f.config,
          aggression: Math.round(num(f.aggression, 0.5) * 100) / 100, cruiseKmh: num(f.cruiseKmh, 100),
          maxSp: num(f.maxSp, 1000), rewardUsd: num(f.rewardUsd, 0), rep: num(f.rep, 0),
          lights: f.lights || undefined,
          driver: f.driverOn ? clone(f.driver) : undefined,
          conditions: Object.keys(c).length ? c : undefined,
          plate: f.plateText ? { text: f.plateText, design: 'am5jp_' + f.plateRegion + '_' + f.plateType } : undefined,
          paint: f.paintOn ? { name: f.paintName || 'custom', color: hexToRgb(f.paintHex), metallic: num(f.metallic, 0.3), roughness: num(f.roughness, 0.3) } : undefined,
          portrait: f.portrait || undefined,
          lines: anyLine ? lines : undefined, desc: biOut(f.desc),
          hint: (f.role === 'wanderer' || f.role === 'boss') ? biOut(f.hint) : undefined
        }
        if (f.orig && f.orig.paint && f.paintOn) {
          // Farbe unverändert: Originalwerte behalten (keine Rundungsänderung)
          if (rgbToHex(f.orig.paint.color) === f.paintHex) vals.paint.color = f.orig.paint.color
        }
        managed.forEach(function (k) { if (vals[k] !== undefined) r[k] = vals[k] })
        Object.keys(f.orig || {}).forEach(function (k) { if (managed.indexOf(k) < 0) r[k] = clone(f.orig[k]) })
        return r
      }

      // --- Formular Crew -------------------------------------------------------------
      function teamForm(t, isNew) {
        return { type: 'team', isNew: !!isNew, orig: clone(t), id: t.id || '', name: t.name || '', jp: t.jp || '',
          color: t.color || '#ff6600', minRank: String(t.minRank != null ? t.minRank : 0), desc: bi(t.desc) }
      }
      function formToTeam(f) {
        var t = { id: f.id, name: f.name, jp: f.jp, color: f.color, minRank: parseInt(f.minRank, 10) || 0 }
        var d = biOut(f.desc); if (d) t.desc = d
        Object.keys(f.orig || {}).forEach(function (k) { if (!(k in t) && ['desc'].indexOf(k) < 0) t[k] = clone(f.orig[k]) })
        return t
      }

      // --- Formular Einstellungen ----------------------------------------------------
      function settingsForm() { return { type: 'settings', isNew: false, settings: clone(b.data.settings || {}) } }
      scope.settingRows = function (obj) {
        return Object.keys(obj || {}).map(function (k) { return { key: k, type: typeof obj[k] } })
      }

      // --- Auswahl ---------------------------------------------------------------------
      function formJson() { return b.form ? JSON.stringify(b.form, function (k, v) { return k === 'orig' ? undefined : v }) : '' }
      scope.dirty = function () { return !!b.form && (b.form.isNew || formJson() !== b.snap) }
      function doSelect(target) {
        b.pending = null; b.armed = null
        b.sel = target
        if (!target) { b.form = null; b.snap = ''; return }
        if (target.kind === 'team') b.form = teamForm(target.newObj || teamById(target.id), !!target.newObj)
        else if (target.kind === 'settings') b.form = settingsForm()
        else b.form = rivalForm(target.newObj || rivalById(target.id), !!target.newObj)
        b.snap = formJson()
        validate()
      }
      scope.select = function (kind, id) {
        var target = { kind: kind, id: id }
        if (scope.dirty() && !scope.isSel(kind, id)) { b.pending = target; return }
        doSelect(target)
      }
      scope.discardPending = function () { doSelect(b.pending) }
      scope.keepEditing = function () { b.pending = null }
      scope.setTab = function (tab) {
        b.tab = tab
        if (tab === 'settings') scope.select('settings', 'settings')
      }

      function nextId(base) {
        var id = base, n = 2
        while (rivalById(id) || teamById(id)) { id = base + '_' + n; n++ }
        return id
      }
      scope.newTeam = function () {
        var t = { id: nextId('t_neu'), name: 'Neue Crew', jp: '', color: '#ff6600', minRank: 0, desc: { de: '', en: '' } }
        var target = { kind: 'team', id: t.id, newObj: t }
        if (scope.dirty()) { b.pending = target; return }
        doSelect(target)
      }
      scope.newRival = function (role, teamId) {
        var base = role === 'boss' ? 'b_neu' : role === 'wanderer' ? 'w_neu' : (teamId + (role === 'leader' ? '_leader' : '_neu'))
        var r = { id: nextId(base), name: '', model: '', config: '', aggression: 0.6, cruiseKmh: 110, maxSp: 1200,
          rewardUsd: 5000, rep: 80, plate: { text: '', design: 'am5jp_shinagawa_standard' } }
        if (role === 'member' || role === 'leader') r.team = teamId
        if (role === 'leader') { r.leader = true; r.appear = 'sameNight' }
        if (role === 'wanderer') { r.wanderer = true; r.conditions = { minRank: 2 } }
        if (role === 'boss') { r.boss = true; r.conditions = { minRank: 10, minDay: 10 } }
        var target = { kind: 'rival', id: r.id, newObj: r }
        if (scope.dirty()) { b.pending = target; return }
        doSelect(target)
      }
      // Neue ID aus dem Namen (nur solange der Eintrag neu ist)
      scope.nameChanged = function () {
        var f = b.form
        if (!f || !f.isNew || f.idTouched) return
        var base = f.type === 'team' ? 't_' + slug(f.name)
          : f.role === 'boss' ? 'b_' + slug(f.name) : f.role === 'wanderer' ? 'w_' + slug(f.name)
          : f.role === 'leader' ? f.team + '_leader' : null
        if (base) f.id = nextId(base)
        validate()
      }
      scope.roleChanged = function () {
        var f = b.form
        if ((f.role === 'member' || f.role === 'leader') && !f.team && teams()[0]) f.team = teams()[0].id
        scope.nameChanged()
      }
      scope.modelChanged = function () {
        var cfgs = scope.modelConfigs()
        var cur = b.form.config
        if (!cfgs.some(function (c) { return 'vehicles/' + b.form.model + '/' + c.key + '.pc' === cur })) {
          b.form.config = cfgs[0] ? 'vehicles/' + b.form.model + '/' + cfgs[0].key + '.pc' : ''
        }
        validate()
      }
      scope.configPath = function (c) { return 'vehicles/' + b.form.model + '/' + c.key + '.pc' }
      scope.regionChanged = function () {
        var allowed = (b.plates && b.plates.byRegion[b.form.plateRegion]) || ['standard']
        if (allowed.indexOf(b.form.plateType) < 0) b.form.plateType = allowed[0]
        validate()
      }
      scope.plateTypes = function () { return (b.plates && b.form && b.plates.byRegion[b.form.plateRegion]) || [] }
      scope.randomPlate = function () {
        var used = {}
        rivals().forEach(function (r) { if (r.plate) used[r.plate.text] = true })
        var text
        for (var i = 0; i < 50; i++) {
          var top = (Math.random() < 0.6 ? 300 : 500) + Math.floor(Math.random() * 100)
          var n = 1000 + Math.floor(Math.random() * 9000)
          text = top + '/' + String(n).slice(0, 2) + '-' + String(n).slice(2)
          if (!used[text]) break
        }
        b.form.plateText = text
        validate()
      }
      scope.addTo = function (list, value) {
        if (value && list.indexOf(value) < 0) list.push(value)
        b.addRival = ''
        validate()
      }
      scope.removeFrom = function (list, i) { list.splice(i, 1); validate() }
      scope.rivalChoices = function () {
        var q = (b.addRival || '').toLowerCase()
        if (q.length < 2) return []
        return rivals().filter(function (r) {
          return r.id !== b.form.id && (r.name + ' ' + r.id).toLowerCase().indexOf(q) >= 0
        }).slice(0, 12)
      }
      scope.rivalLabel = function (id) { var r = rivalById(id); return r ? r.name + ' (' + id + ')' : id + ' (fehlt!)' }
      scope.teamLabel = function (id) { var t = teamById(id); return t ? t.name : id + ' (fehlt!)' }

      // --- Prüfung ---------------------------------------------------------------------
      var plateRe = /^[\dXx&][\dXx&][\dXx&\/]\/[\d.Xx&][\d.Xx&][- ][\d.Xx&][\d.Xx&]$/
      // Rang, ab dem ein Rivale frühestens kommen kann (eigene + geerbte Bedingungen)
      function effRank(r, seen) {
        seen = seen || {}
        if (!r || seen[r.id]) return 0
        seen[r.id] = true
        var c = r.conditions || {}
        var best = c.minRank || 0
        var t = r.team && teamById(r.team)
        if (t) best = Math.max(best, t.minRank || 0)
        function teamRank(id) {
          var tt = teamById(id); if (!tt) return 0
          var m = tt.minRank || 0
          scope.teamMembers(id).forEach(function (x) { m = Math.max(m, effRank(x, seen)) })
          return m
        }
        if (c.beatenTeam) best = Math.max(best, teamRank(c.beatenTeam))
        ;(c.beatenTeams || []).forEach(function (id) { best = Math.max(best, teamRank(id)) })
        ;(c.beatenRivals || []).forEach(function (id) { best = Math.max(best, effRank(rivalById(id), seen)) })
        return best
      }
      function validate() {
        var f = b.form, err = [], warn = []
        if (!f) { b.issues = null; return }
        if (f.type === 'rival') {
          if (!/^[a-z0-9_]+$/.test(f.id)) err.push('ID nur aus a-z, 0-9 und _')
          if (f.isNew && (rivalById(f.id) || teamById(f.id))) err.push('ID ' + f.id + ' gibt es schon')
          if (!f.name.trim()) err.push('Name fehlt')
          if (!f.model) err.push('Auto (Modell) fehlt')
          if (!f.config) err.push('Config fehlt')
          else if (f.model && !b.modelMap[f.model]) warn.push('Modell ' + f.model + ' ist im Spiel gerade nicht installiert')
          else if (f.model && !scope.modelConfigs().some(function (c) { return scope.configPath(c) === f.config })) warn.push('Config-Datei nicht gefunden: ' + f.config)
          if ((f.role === 'member' || f.role === 'leader') && !teamById(f.team)) err.push('Crew fehlt')
          if (f.role === 'leader') {
            var other = rivals().filter(function (r) { return r.team === f.team && r.leader && r.id !== f.id })[0]
            if (other) err.push('Crew hat schon einen Leader: ' + other.name)
          }
          if (f.role === 'boss' && f.final) {
            var fin = rivals().filter(function (r) { return r.final && r.id !== f.id })[0]
            if (fin) warn.push('Es gibt schon einen finalen Boss: ' + fin.name)
          }
          if (!f.plateText) warn.push('Kein Kennzeichen')
          else if (!plateRe.test(f.plateText)) err.push('Kennzeichen-Format falsch (z. B. 330/12-34, 12//12-34, 330/.. .7)')
          else {
            var dup = rivals().filter(function (r) { return r.id !== f.id && r.plate && r.plate.text === f.plateText })[0]
            if (dup) warn.push('Kennzeichen hat schon ' + dup.name)
          }
          if (f.cond.hoursOn) {
            var h1 = parseInt(f.cond.hFrom, 10), h2 = parseInt(f.cond.hTo, 10)
            if (!(h1 >= 0 && h1 <= 23 && h2 >= 0 && h2 <= 24)) err.push('Uhrzeit von/bis: 0 bis 24')
          }
          if (f.cond.beatenTeam && !teamById(f.cond.beatenTeam)) err.push('Bedingung: Crew ' + f.cond.beatenTeam + ' fehlt')
          f.cond.beatenTeams.forEach(function (id) { if (!teamById(id)) err.push('Bedingung: Crew ' + id + ' fehlt') })
          f.cond.beatenRivals.forEach(function (id) {
            if (!rivalById(id)) err.push('Bedingung: Rivale ' + id + ' fehlt')
            if (id === f.id) err.push('Bedingung: sich selbst schlagen geht nicht')
          })
          if (f.cond.playerModel && !b.modelMap[f.cond.playerModel]) warn.push('Spieler-Auto ' + f.cond.playerModel + ' ist nicht installiert')
          if (f.cond.speedTraps !== '' && f.cond.speedTraps !== 'all' && !(parseInt(f.cond.speedTraps, 10) > 0)) err.push('Radarfallen: "all" oder Anzahl')
          var r = formToRival(f)
          var own = r.conditions && r.conditions.minRank || 0
          var eff = effRank(r)
          if (eff > own) warn.push('Kommt durch die Bedingungen effektiv erst ab Rang ' + scope.rankName(eff) + ' (eingestellt: ' + own + ')')
          if (!f.nick.de || !f.nick.en) warn.push('Spitzname DE/EN unvollständig')
          scope.lineKeys.forEach(function (k) { if (!f.lines[k.id].de || !f.lines[k.id].en) warn.push('Spruch "' + k.name + '" DE/EN unvollständig') })
          if (!f.desc.de || !f.desc.en) warn.push('Beschreibung DE/EN unvollständig')
          if ((f.role === 'wanderer' || f.role === 'boss') && (!f.hint.de || !f.hint.en)) warn.push('Hinweis DE/EN unvollständig')
          if (!f.portrait && !b.portraits[f.id]) warn.push('Kein Porträt (art/portraits/' + f.id + '.png oder .svg)')
          if (f.portrait && !/\.(png|jpg|svg)$/i.test(f.portrait)) warn.push('Porträt: nur .png, .jpg oder .svg')
        } else if (f.type === 'team') {
          if (!/^[a-z0-9_]+$/.test(f.id)) err.push('ID nur aus a-z, 0-9 und _')
          if (f.isNew && (teamById(f.id) || rivalById(f.id))) err.push('ID ' + f.id + ' gibt es schon')
          if (!f.name.trim()) err.push('Name fehlt')
          if (!/^#[0-9a-fA-F]{6}$/.test(f.color)) err.push('Farbe als #rrggbb')
          if (!f.isNew && !scope.teamMembers(f.id).some(function (r) { return r.leader })) warn.push('Crew hat noch keinen Leader')
          if (!f.desc.de || !f.desc.en) warn.push('Beschreibung DE/EN unvollständig')
        }
        b.issues = { err: err, warn: warn }
      }
      scope.validate = validate

      // --- Speichern, Löschen, Test ---------------------------------------------------------
      function insertRival(r) {
        var list = rivals(), at = list.length
        var role = roleOf(r)
        if (role === 'member' || role === 'leader') {
          for (var i = list.length - 1; i >= 0; i--) if (list[i].team === r.team) { at = i + 1; break }
        } else if (role === 'wanderer') {
          var firstBoss = -1, lastW = -1
          list.forEach(function (x, i) { if (x.boss && firstBoss < 0) firstBoss = i; if (x.wanderer) lastW = i })
          at = lastW >= 0 ? lastW + 1 : (firstBoss >= 0 ? firstBoss : list.length)
        }
        list.splice(at, 0, r)
      }
      function writeAll(msg) {
        var text = JSON.stringify(b.data, null, 2) + '\n'
        b.busy = true
        b.status = { ok: true, text: 'Speichere …' }
        sendText('save', text)
      }
      scope.save = function () {
        validate()
        if (!b.form || b.issues.err.length) return
        if (!b.root) { b.status = { ok: false, text: 'Mod-Ordner nicht gefunden, Speichern geht nicht' }; return }
        var f = b.form
        if (f.type === 'rival') {
          var r = formToRival(f)
          if (f.isNew) insertRival(r)
          else {
            var list = rivals()
            var i = list.indexOf(rivalById(f.orig.id))
            var oldRole = roleOf(list[i]), oldTeam = list[i].team
            if (oldRole !== roleOf(r) || oldTeam !== r.team) { list.splice(i, 1); insertRival(r) } else list[i] = r
          }
          b.sel = { kind: 'rival', id: r.id }
          b.form = rivalForm(r, false)
        } else if (f.type === 'team') {
          var t = formToTeam(f)
          if (f.isNew) teams().push(t)
          else teams()[teams().indexOf(teamById(f.orig.id))] = t
          b.sel = { kind: 'team', id: t.id }
          b.form = teamForm(t, false)
        } else if (f.type === 'settings') {
          b.data.settings = clone(f.settings)
          b.form = settingsForm()
        }
        b.snap = formJson()
        writeAll()
        validate()
      }
      scope.revert = function () { if (b.sel) doSelect(b.sel.newObj ? null : b.sel) }
      function usedBy(id, isTeam) {
        return rivals().filter(function (r) {
          var c = r.conditions || {}
          if (isTeam) return c.beatenTeam === id || (c.beatenTeams || []).indexOf(id) >= 0
          return (c.beatenRivals || []).indexOf(id) >= 0
        }).map(function (r) { return r.name })
      }
      scope.remove = function () {
        var f = b.form
        if (!f || f.type === 'settings') return
        if (f.isNew) { doSelect(null); return }
        var isTeam = f.type === 'team'
        var users = usedBy(f.orig.id, isTeam)
        if (users.length) { b.status = { ok: false, text: 'Nicht gelöscht: Bedingung bei ' + users.join(', ') }; return }
        if (isTeam && scope.teamMembers(f.orig.id).length) { b.status = { ok: false, text: 'Nicht gelöscht: Crew hat noch Mitglieder' }; return }
        if (b.armed !== 'remove') { b.armed = 'remove'; return }
        if (isTeam) teams().splice(teams().indexOf(teamById(f.orig.id)), 1)
        else rivals().splice(rivals().indexOf(rivalById(f.orig.id)), 1)
        doSelect(null)
        writeAll()
      }
      scope.testSpawn = function () {
        if (!b.form || b.form.type !== 'rival') return
        validate()
        if (b.issues.err.length) return
        sendText('spawn', JSON.stringify(formToRival(b.form)))
      }
      scope.saveCarConfig = function () {
        var name = b.carName || (b.form && b.form.id) || ''
        lua('saveCarConfig(' + luaStr(name) + ')')
      }
      scope.useCurrentModel = function () {
        if (b.player && b.form) { b.form.model = b.player.model; scope.modelChanged() }
      }
      scope.close = function () {
        if (scope.dirty() && b.armed !== 'close') { b.armed = 'close'; return }
        b.open = false; b.form = null; b.sel = null; b.armed = null
        lua('close()')
      }
      scope.reload = function () { lua('open()') }

      // --- Daten von Lua -------------------------------------------------------------------------
      scope.$watch('b.open', function (v) { setClickable(!!v) })

      scope.$on('HashiriyaBuilder', function (event, msg) {
        scope.$evalAsync(function () {
          if (!msg) return
          if (msg.open === false) { b.open = false; return }
          if (msg.open) {
            try { b.data = JSON.parse(msg.text) } catch (e) {
              b.data = null
              b.status = { ok: false, text: 'rivals.json ist kein gültiges JSON: ' + e.message }
            }
            b.configs = msg.configs || []
            b.modelMap = {}
            b.configs.forEach(function (m) { b.modelMap[m.id] = m })
            b.portraits = msg.portraits || {}
            b.plates = msg.plates
            b.player = msg.player
            b.active = msg.active
            b.root = msg.root
            b.open = true
            b.form = null; b.sel = null; b.pending = null
            if (!b.root) b.status = { ok: false, text: 'Mod-Ordner mods/unpacked/Hashiriya-Battle nicht gefunden: Speichern gesperrt' }
          }
          if (msg.status) {
            b.status = msg.status
            b.busy = false
          }
          if (msg.carConfig && b.form && b.form.type === 'rival') {
            var cc = msg.carConfig
            var m = b.modelMap[cc.model]
            if (m && !m.configs.some(function (c) { return c.key === cc.key })) m.configs.unshift({ key: cc.key, name: cc.key, source: 'Builder' })
            b.form.model = cc.model
            b.form.config = cc.config
            validate()
          }
        })
      })
    }
  }
}]);

// Eigenes Dropdown: BeamNG (CEF) öffnet keine nativen <select>-Listen.
// <div hbb-pick hbb-model="x" hbb-options="[{v, l}]" hbb-empty="– wählen –" hbb-change="f()"></div>
angular.module('beamng.apps')
.directive('hbbPick', ['$document', '$timeout', function ($document, $timeout) {
  return {
    restrict: 'A',
    scope: { model: '=hbbModel', options: '&hbbOptions', change: '&hbbChange', empty: '@hbbEmpty' },
    template:
      '<div class="hbb-dd" ng-class="{\'is-open\': open}">' +
        '<div class="hbb-dd-val" ng-click="toggle()"><span>{{ label() }}</span><i>\u25be</i></div>' +
        '<div class="hbb-dd-pop" ng-if="open">' +
          '<input type="text" class="hbb-dd-q" ng-if="list.length > 10" ng-model="q.text" placeholder="Suchen \u2026">' +
          '<div class="hbb-dd-list">' +
            '<div class="hbb-dd-opt" ng-repeat="o in filtered() track by $index" ng-class="{\'is-sel\': o.v === model}" ng-click="pick(o)">{{ o.l }}</div>' +
            '<div class="hbb-dd-none" ng-if="!filtered().length">Keine Treffer</div>' +
          '</div>' +
        '</div>' +
      '</div>',
    link: function (scope, element) {
      scope.open = false
      scope.q = { text: '' }
      scope.list = []
      function all() {
        var l = scope.options() || []
        return scope.empty ? [{ v: '', l: scope.empty }].concat(l) : l
      }
      scope.label = function () {
        var l = all()
        for (var i = 0; i < l.length; i++) if (l[i].v === scope.model) return l[i].l
        return scope.model ? String(scope.model) : (scope.empty || '')
      }
      var shown = []
      scope.filtered = function () {
        var q = (scope.q.text || '').toLowerCase()
        if (!q) return scope.list
        var out = scope.list.filter(function (o) { return String(o.l).toLowerCase().indexOf(q) >= 0 || String(o.v).toLowerCase().indexOf(q) >= 0 })
        // gleiche Liste zurückgeben, solange sich nichts ändert (sonst rechnet Angular endlos)
        if (out.length === shown.length && out.every(function (o, i) { return o === shown[i] })) return shown
        shown = out
        return shown
      }
      scope.toggle = function () {
        scope.open = !scope.open
        if (scope.open) { scope.list = all(); scope.q.text = '' }
      }
      scope.pick = function (o) {
        scope.model = o.v
        scope.open = false
        $timeout(function () { scope.change() })
      }
      function outside(ev) {
        if (!scope.open || element[0].contains(ev.target)) return
        scope.$apply(function () { scope.open = false })
      }
      $document.on('mousedown', outside)
      scope.$on('$destroy', function () { $document.off('mousedown', outside) })
    }
  }
}])

// Farbwahl ohne nativen Farbdialog: Hex-Feld, Vorschau und Schieber für Rot, Grün, Blau
.directive('hbbColor', ['$timeout', function ($timeout) {
  return {
    restrict: 'A',
    scope: { model: '=hbbModel', change: '&hbbChange' },
    template:
      '<div class="hbb-col-c">' +
        '<div class="hbb-col-top"><span class="hbb-swatch" ng-style="{background: model}"></span>' +
          '<input type="text" ng-model="c.hex" ng-change="fromHex()" placeholder="#ff6600"></div>' +
        '<input type="range" min="0" max="255" ng-model="c.r" ng-change="fromRgb()" style="accent-color:#e2453c">' +
        '<input type="range" min="0" max="255" ng-model="c.g" ng-change="fromRgb()" style="accent-color:#3cc46b">' +
        '<input type="range" min="0" max="255" ng-model="c.b" ng-change="fromRgb()" style="accent-color:#3c8ae2">' +
      '</div>',
    link: function (scope) {
      scope.c = { hex: '', r: 128, g: 128, b: 128 }
      function hx(v) { var s = Math.max(0, Math.min(255, Math.round(v))).toString(16); return s.length < 2 ? '0' + s : s }
      function sync(hex) {
        var m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex || '')
        scope.c.hex = hex || ''
        if (m) { scope.c.r = parseInt(m[1], 16); scope.c.g = parseInt(m[2], 16); scope.c.b = parseInt(m[3], 16) }
      }
      scope.$watch('model', function (v) { if (v !== scope.c.hex) sync(v) })
      function set(v) { scope.model = v; $timeout(function () { scope.change() }) }
      scope.fromHex = function () {
        var h = (scope.c.hex || '').trim()
        if (h && h[0] !== '#') h = '#' + h
        if (/^#[0-9a-fA-F]{6}$/.test(h)) { sync(h.toLowerCase()); set(h.toLowerCase()) }
      }
      scope.fromRgb = function () {
        var h = '#' + hx(+scope.c.r) + hx(+scope.c.g) + hx(+scope.c.b)
        scope.c.hex = h
        set(h)
      }
    }
  }
}]);
