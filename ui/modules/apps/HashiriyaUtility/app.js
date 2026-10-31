// Hashiriya Battle: eigene Version der BeamNG-App "topLeftApps" (Utility Apps oben links) im Design der
// HashiNet-Teile-Meldung. Enthält untereinander: Scoreboard, Aufgaben (Tasks) und Meldungen (Messages).
//
// Daten kommen von denselben Stellen wie bei den Originalen (BeamNG 0.40, ui-vue messagesStore/tasklistStore,
// ui/modules/apps/Scoreboard), also funktionieren auch alle Meldungen und Aufgaben vom Spiel selbst:
//   Meldungen:  Hook 'Message' { msg|text|txt, ttl (Sek., -1 = bleibt), ttlMs, category (Regex zum Ersetzen), clear, icon, context }
//               Hook 'ClearAllMessages'
//   Aufgaben:   Hooks 'SetTasklistHeader', 'SetTasklistTask', 'UpdateTasklistItem', 'CompleteTasklistGoal', 'FailTasklistGoal',
//               'DiscardTasklistItem', 'HighlightTasklistItem', 'SortTasklistItems', 'ClearTasklist'
//   Scoreboard: Stream 'scoreboard' { players, style { entries, orderBy }, localMPClientId } (ui_gameplayScoreboard)
//   Ein/aus:    wie beim Original über ui_appContainers, Container 'topLeft' (Hook 'setTopLeftAppVisibility')
// Farben: Mod-Meldungen (Kategorie 'hashiriya') orange, Spiel-Meldungen grau-blau, Warnungen/Schäden rot.
angular.module('beamng.apps')
.directive('hashiriyaUtility', ['$injector', function ($injector) {
  return {
    template: [
      '<div class="bngApp hbx-root">',

      // ---- Scoreboard ----
      '<div class="hbx-card hbx-score" ng-if="show.scoreboard && board.rows.length">',
        '<div class="hbx-head"><span class="hbx-net">Hashiriya</span><span class="hbx-title">{{ tx(\'hud.scoreboard\', \'Standings\') }}</span></div>',
        '<div class="hbx-srow hbx-shead"><span class="hbx-sname"></span><span class="hbx-scol" ng-repeat="c in board.cols track by c.key">{{ c.name }}</span></div>',
        '<div class="hbx-srow" ng-repeat="p in board.rows track by p.id" ng-class="{\'is-me\': p.me, \'is-dq\': p.dq, \'is-pulse\': p.pulse}">',
          '<span class="hbx-sname">',
            '<b class="hbx-rank" ng-if="board.ranks" ng-class="\'r\' + p.rank">{{ p.rank }}</b>',
            '<i class="hbx-pcol" ng-if="p.color" ng-style="{background: p.color}"></i>',
            '<span class="hbx-pname">{{ p.name }}</span>',
            '<span class="hbx-flag" ng-if="p.finish">&#9873;</span>',
          '</span>',
          '<span class="hbx-scol" ng-repeat="c in board.cols track by c.key">',
            '<span ng-if="c.type !== \'verticalBar\'">{{ p.vals[c.key] }}</span>',
            '<span class="hbx-vbar" ng-if="c.type === \'verticalBar\'"><span ng-style="{height: (p.raw[c.key] || 0) * 100 + \'%\'}"></span></span>',
          '</span>',
        '</div>',
      '</div>',

      // ---- Aufgaben ----
      '<div class="hbx-card hbx-tasks" ng-if="show.tasks && (tasks.length || header)">',
        '<div class="hbx-head"><span class="hbx-net">Hashiriya</span><span class="hbx-title">{{ tx(\'hud.tasks\', \'Objectives\') }}</span></div>',
        '<div class="hbx-thead" ng-if="header">',
          '<div class="hbx-ttitle">{{ header.title }}</div>',
          '<div class="hbx-tdesc" ng-if="header.desc">{{ header.desc }}</div>',
        '</div>',
        '<div class="hbx-task" ng-repeat="k in tasks track by k.id" ng-class="{\'is-msg\': k.type === \'message\', \'is-ok\': k.complete && k.success, \'is-fail\': k.complete && !k.success, \'is-att\': k.attention}" ng-style="{\'animation-delay\': ($index * 0.06) + \'s\'}">',
          '<i class="hbx-check" ng-if="k.type !== \'message\'"><span ng-if="k.complete">{{ k.success ? \'✓\' : \'✕\' }}</span></i>',
          '<div class="hbx-ttxt"><span class="hbx-tlabel">{{ k.label }}</span><span class="hbx-tsub" ng-if="k.desc">{{ k.desc }}</span></div>',
        '</div>',
      '</div>',

      // ---- Meldungen ----
      '<div ng-if="show.messages">',
        '<div class="hbx-card hbx-msg" ng-repeat="m in msgs track by m.uid" ng-class="[\'hbx-\' + m.kind, {\'is-out\': m.out}]">',
          '<div class="hbx-head"><span class="hbx-net">{{ m.kind === \'mod\' ? \'Hashiriya\' : \'BeamNG\' }}</span><span class="hbx-title" ng-if="m.label">{{ m.label }}</span></div>',
          '<div class="hbx-mtxt">{{ m.text }}</div>',
          '<div class="hbx-time" ng-if="!m.infinite"><span ng-style="{\'animation-duration\': (m.ttl / 1000) + \'s\'}"></span></div>',
        '</div>',
      '</div>',

      '<style>',
        '.hbx-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;',
          'display:flex;flex-direction:column;align-items:flex-start;',
          'font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;color:#f4f4f4;}',
        '.hbx-card{--ac:#ff6600;position:relative;width:360px;max-width:100%;margin:0 0 6px 0;padding:8px 18px 10px 16px;box-sizing:border-box;',
          'background:linear-gradient(90deg,rgba(14,15,18,.92),rgba(14,15,18,.8) 75%,rgba(14,15,18,.55));',
          'border-left:4px solid var(--ac);box-shadow:0 6px 20px rgba(0,0,0,.5);text-shadow:0 1px 2px rgba(0,0,0,.7);',
          'clip-path:polygon(0 0,100% 0,calc(100% - 12px) 100%,0 100%);animation:hbxIn .45s cubic-bezier(.2,.9,.25,1) both;}',
        '.hbx-card.is-out{animation:hbxOut .4s ease-in both;}',
        '.hbx-sys{--ac:#8fa3bf;}',
        '.hbx-warn{--ac:#ff5a3c;}',
        '.hbx-msg:before{content:"";position:absolute;top:0;bottom:0;left:-40%;width:35%;pointer-events:none;',
          'background:linear-gradient(100deg,transparent,rgba(255,255,255,.1),transparent);animation:hbxSweep 1s .3s ease-out both;}',
        '.hbx-head{display:flex;align-items:baseline;gap:9px;font-size:10px;letter-spacing:2.4px;text-transform:uppercase;margin-bottom:4px;}',
        '.hbx-net{font-weight:900;font-style:italic;color:var(--ac);}',
        '.hbx-title{font-weight:700;color:rgba(244,244,244,.65);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}',
        '.hbx-mtxt{font-size:14px;line-height:19px;white-space:pre-line;word-wrap:break-word;}',
        '.hbx-time{position:absolute;left:0;right:12px;bottom:0;height:2px;background:rgba(255,255,255,.08);}',
        '.hbx-time span{display:block;height:100%;width:100%;background:var(--ac);transform-origin:left;animation:hbxTime linear both;}',
        // Aufgaben
        '.hbx-thead{border-bottom:1px solid rgba(255,255,255,.12);padding-bottom:6px;margin-bottom:5px;}',
        '.hbx-ttitle{font-size:18px;font-weight:900;font-style:italic;letter-spacing:.4px;text-transform:uppercase;line-height:22px;}',
        '.hbx-tdesc{font-size:12px;color:var(--ac);letter-spacing:.6px;margin-top:2px;}',
        '.hbx-task{display:flex;align-items:flex-start;gap:10px;padding:4px 0;animation:hbxRow .35s ease-out both;}',
        '.hbx-check{flex:none;width:12px;height:12px;margin-top:4px;transform:rotate(45deg);border:2px solid rgba(244,244,244,.7);',
          'display:flex;align-items:center;justify-content:center;font-style:normal;transition:background .3s,border-color .3s;}',
        '.hbx-check span{transform:rotate(-45deg);font-size:10px;font-weight:900;line-height:1;}',
        '.hbx-task.is-ok .hbx-check{background:#3fbf5a;border-color:#3fbf5a;}',
        '.hbx-task.is-fail .hbx-check{background:#ff5a3c;border-color:#ff5a3c;}',
        '.hbx-task.is-ok .hbx-tlabel{color:rgba(244,244,244,.55);}',
        '.hbx-task.is-fail .hbx-tlabel{color:rgba(244,244,244,.55);text-decoration:line-through;}',
        '.hbx-task.is-att .hbx-check{animation:hbxAtt 1s ease-in-out infinite alternate;}',
        '.hbx-task.is-msg .hbx-tlabel{font-weight:400;color:rgba(244,244,244,.8);}',
        '.hbx-ttxt{display:flex;flex-direction:column;gap:1px;min-width:0;}',
        '.hbx-tlabel{font-size:14px;font-weight:700;line-height:18px;}',
        '.hbx-tsub{font-size:12px;line-height:15px;color:rgba(244,244,244,.6);}',
        // Scoreboard
        '.hbx-srow{display:flex;align-items:center;gap:8px;height:24px;font-size:14px;animation:hbxRow .35s ease-out both;}',
        '.hbx-srow.is-me{background:linear-gradient(90deg,rgba(255,102,0,.25),transparent);}',
        '.hbx-srow.is-dq{opacity:.45;text-decoration:line-through;}',
        '.hbx-srow.is-pulse{animation:hbxPulse .6s ease-out;}',
        '.hbx-shead{height:16px;font-size:10px;letter-spacing:1.5px;text-transform:uppercase;color:rgba(244,244,244,.5);}',
        '.hbx-sname{flex:1;display:flex;align-items:center;gap:7px;min-width:0;}',
        '.hbx-pname{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}',
        '.hbx-rank{flex:none;min-width:24px;height:18px;display:flex;align-items:center;justify-content:center;font-style:italic;font-weight:900;',
          'background:rgba(255,255,255,.12);clip-path:polygon(15% 0,100% 0,85% 100%,0 100%);}',
        '.hbx-rank.r1{background:#ff6600;}.hbx-rank.r2{background:#8fa3bf;color:#111;}.hbx-rank.r3{background:#9c5a2c;}',
        '.hbx-pcol{flex:none;width:4px;height:16px;}',
        '.hbx-flag{color:#f4f4f4;font-size:12px;}',
        '.hbx-scol{min-width:46px;text-align:right;font-style:italic;font-weight:700;font-variant-numeric:tabular-nums;}',
        '.hbx-vbar{display:inline-block;width:4px;height:16px;background:rgba(255,255,255,.12);position:relative;vertical-align:middle;}',
        '.hbx-vbar span{position:absolute;left:0;right:0;bottom:0;background:var(--ac);}',
        '@keyframes hbxIn{from{opacity:0;transform:translateX(-110%);}to{opacity:1;transform:none;}}',
        '@keyframes hbxOut{from{opacity:1;transform:none;}to{opacity:0;transform:translateX(-110%);}}',
        '@keyframes hbxSweep{from{left:-40%;}to{left:110%;}}',
        '@keyframes hbxTime{from{transform:scaleX(1);}to{transform:scaleX(0);}}',
        '@keyframes hbxRow{from{opacity:0;transform:translateX(-14px);}to{opacity:1;transform:none;}}',
        '@keyframes hbxAtt{from{border-color:rgba(244,244,244,.7);box-shadow:none;}to{border-color:#ff6600;box-shadow:0 0 8px #ff6600;}}',
        '@keyframes hbxPulse{from{background:rgba(255,255,255,.35);}to{background:transparent;}}',
      '</style>',
      '</div>'
    ].join(''),
    replace: true,
    link: function (scope) {
      'use strict'
      var MAX_MSGS = 5
      var TICK = 300
      var strings = {}
      var $translate = null
      try { if ($injector.has('$translate')) $translate = $injector.get('$translate') } catch (e) {}

      scope.show = { messages: true, tasks: true, scoreboard: false }
      scope.msgs = []
      scope.tasks = []
      scope.header = null
      scope.board = { rows: [], cols: [], ranks: false }

      scope.tx = function (k, fallback) { return strings[k] || fallback || k }
      scope.$on('HashiriyaState', function (e, d) { if (d && d.t) strings = d.t })

      function lua(cmd, cb) { try { bngApi.engineLua(cmd, cb) } catch (e) {} }

      // Text kann ein String, ein Übersetzungsschlüssel oder { txt, context } sein
      function textOf(v, context) {
        if (v === undefined || v === null) return ''
        if (typeof v === 'object') {
          var key = v.txt || v.text || ''
          try { if ($translate) return $translate.instant(String(key), v.context || context || {}) } catch (e) {}
          return String(key)
        }
        var s = String(v)
        if ($translate && /^[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)+$/.test(s)) {
          try { return $translate.instant(s, context || {}) } catch (e) {}
        }
        return s
      }

      // ---------------- Sichtbarkeit wie topLeftApps ----------------
      function setVis(d) {
        if (!d) return
        scope.$evalAsync(function () {
          if (d.hideAll) { scope.show.messages = scope.show.tasks = scope.show.scoreboard = false }
          if (d.appId && scope.show.hasOwnProperty(d.appId)) scope.show[d.appId] = !!d.visible
        })
      }
      scope.$on('setTopLeftAppVisibility', function (e, d) { setVis(d) })
      lua('ui_appContainers and ui_appContainers.getVisibleApps("topLeft")', function (list) {
        if (!list || typeof list !== 'object') return
        var arr = Array.isArray(list) ? list : Object.keys(list).map(function (k) { return list[k] })
        scope.$evalAsync(function () {
          scope.show.messages = arr.indexOf('messages') >= 0
          scope.show.tasks = arr.indexOf('tasks') >= 0
          scope.show.scoreboard = arr.indexOf('scoreboard') >= 0
        })
      })

      // ---------------- Meldungen ----------------
      var uid = 0
      function kindOf(cat, icon) {
        var c = String(cat || '') + ' ' + String(icon || '')
        if (/warn|error|fail|damage|overheat|deflated|punctur|stall/i.test(c)) return 'warn'
        if (/hashiriya/i.test(String(cat || ''))) return 'mod'
        return 'sys'
      }
      // Kategorie als kleine Überschrift nur, wenn sie ein lesbares Wort ist (z. B. 'delivery', 'refueling')
      function labelOf(cat) {
        var c = String(cat || '')
        if (!c || c === 'default' || /hashiriya/i.test(c) || c.indexOf('.') >= 0 || /^[0-9a-f-]{8,}$/i.test(c)) return ''
        return c.replace(/[_-]/g, ' ').replace(/([a-z])([A-Z])/g, '$1 $2')
      }
      function removeMsg(m) {
        if (!m || m.out) return
        m.out = true
        setTimeout(function () {
          scope.$evalAsync(function () {
            var i = scope.msgs.indexOf(m)
            if (i >= 0) scope.msgs.splice(i, 1)
          })
        }, 420)
      }
      scope.$on('Message', function (e, a) {
        if (!a) return
        scope.$evalAsync(function () {
          var cat = a.category !== undefined && a.category !== null && a.category !== '' ? String(a.category) : 'default'
          var text = textOf(a.text !== undefined ? a.text : (a.msg !== undefined ? a.msg : a.txt), a.context)
          var infinite = a.ttl === -1 || a.ttlMs === -1
          var ttl = typeof a.ttlMs === 'number' ? a.ttlMs : (typeof a.ttl === 'number' ? a.ttl * 1000 : 5000)
          // gleiche Kategorie (wie im Original als Regex) ersetzt bzw. löscht die alte Karte
          var re = null
          try { re = new RegExp(cat) } catch (err) { re = null }
          for (var i = scope.msgs.length - 1; i >= 0; i--) {
            var old = scope.msgs[i]
            if (old.out) continue
            if (old.cat === cat || (re && re.test(old.cat))) scope.msgs.splice(i, 1)
          }
          if (a.clear || text === '' || (!infinite && ttl <= 0)) return
          scope.msgs.push({ uid: ++uid, cat: cat, text: text, ttl: ttl, left: ttl, infinite: infinite,
            kind: kindOf(cat, a.icon), label: labelOf(cat), out: false })
          var live = scope.msgs.filter(function (x) { return !x.out })
          while (live.length > MAX_MSGS) removeMsg(live.shift())
        })
      })
      scope.$on('ClearAllMessages', function () {
        scope.$evalAsync(function () { scope.msgs.slice().forEach(removeMsg) })
      })
      var timer = setInterval(function () {
        if (!scope.msgs.length) return
        scope.$evalAsync(function () {
          scope.msgs.forEach(function (m) {
            if (m.infinite || m.out) return
            m.left -= TICK
            if (m.left <= 0) removeMsg(m)
          })
        })
      }, TICK)

      // ---------------- Aufgaben ----------------
      function findTask(id) {
        for (var i = 0; i < scope.tasks.length; i++) if (scope.tasks[i].id === id) return i
        return -1
      }
      function setTask(d) {
        if (!d) return
        var id = d.id === null || d.id === undefined ? 'default' : d.id
        var i = findTask(id)
        if (d.clear) { if (i >= 0) scope.tasks.splice(i, 1); return }
        var complete = !!d.done || !!d.fail
        var success = !!d.done || (d.fail !== undefined && !d.fail)
        var t = i >= 0 ? scope.tasks[i] : { id: id, label: '', desc: '' }
        if (d.label !== undefined || i < 0) t.label = textOf(d.label)
        if (d.subtext !== undefined || i < 0) t.desc = d.subtext && d.subtext !== 0 ? textOf(d.subtext) : ''
        if (d.type !== undefined || i < 0) t.type = d.type
        t.attention = !!d.attention
        t.complete = complete
        t.success = success
        if (i < 0) scope.tasks.push(t)
      }
      function on(name, fn) {
        scope.$on(name, function (e, a, b) { scope.$evalAsync(function () { fn(a, b) }) })
      }
      on('SetTasklistHeader', function (d) {
        if (d === undefined || d === null || d === '') { scope.header = null; return }
        scope.header = { title: textOf(d.label), desc: d.subtext && d.subtext !== 0 ? textOf(d.subtext) : '' }
      })
      on('SetTasklistTask', function (d) {
        if (Array.isArray(d)) d.forEach(setTask); else setTask(d)
      })
      on('UpdateTasklistItem', function (id, d) {
        var i = findTask(id)
        if (i < 0 || !d) return
        for (var k in d) if (scope.tasks[i][k] !== undefined) scope.tasks[i][k] = d[k]
      })
      on('CompleteTasklistGoal', function (id) {
        var i = findTask(id); if (i >= 0) { scope.tasks[i].complete = true; scope.tasks[i].success = true }
      })
      on('FailTasklistGoal', function (id) {
        var i = findTask(id); if (i >= 0) { scope.tasks[i].complete = true; scope.tasks[i].success = false }
      })
      on('DiscardTasklistItem', function (id, delay) {
        var go = function () { scope.$evalAsync(function () { setTask({ id: id, clear: true }) }) }
        if (delay > 0) setTimeout(go, delay * 1000); else go()
      })
      on('HighlightTasklistItem', function (id, duration) {
        var i = findTask(id); if (i < 0) return
        scope.tasks[i].attention = true
        if (duration > 0) setTimeout(function () { scope.$evalAsync(function () { var j = findTask(id); if (j >= 0) scope.tasks[j].attention = false }) }, duration * 1000)
      })
      on('SortTasklistItems', function (order) {
        if (!Array.isArray(order)) return
        var inOrder = scope.tasks.filter(function (t) { return order.indexOf(t.id) >= 0 })
        inOrder.sort(function (a, b) { return order.indexOf(a.id) - order.indexOf(b.id) })
        scope.tasks = inOrder.concat(scope.tasks.filter(function (t) { return order.indexOf(t.id) < 0 }))
      })
      on('ClearTasklist', function () { scope.header = null; scope.tasks = [] })

      // ---------------- Scoreboard ----------------
      var streamsList = ['scoreboard']
      var pulses = {}
      try { StreamsManager.add(streamsList) } catch (e) {}
      function fmtScore(v) {
        if (v === undefined || v === null || v === '') return '-'
        var n = Number(v)
        if (!isFinite(n)) return String(v)
        return Math.round(n).toLocaleString()
      }
      function rgb(c) {
        if (!Array.isArray(c) || c.length < 3) return null
        return 'rgb(' + Math.round(c[0] * 255) + ',' + Math.round(c[1] * 255) + ',' + Math.round(c[2] * 255) + ')'
      }
      scope.$on('streamsUpdate', function (e, streams) {
        var s = streams && streams.scoreboard
        if (!s) return
        scope.$evalAsync(function () {
          var style = s.style || {}
          var cols = Array.isArray(style.entries) ? style.entries.slice() : []
          cols.sort(function (a, b) { return (a.order || 0) - (b.order || 0) })
          var raw = s.players || []
          var list = Array.isArray(raw) ? raw : Object.keys(raw).map(function (k) { return raw[k] })
          scope.board.cols = cols
          scope.board.ranks = !!style.orderBy
          scope.board.rows = list.map(function (p, i) {
            var vals = {}
            cols.forEach(function (c) {
              var v = p.scores ? p.scores[c.key] : undefined
              vals[c.key] = c.type === 'points' ? fmtScore(v) : (v === undefined || v === null ? '-' : v)
            })
            return {
              id: p.mpClientId || ('p' + i), name: p.name || p.persona || p.mpClientId, rank: p.rank || (i + 1),
              color: rgb(p.color), vals: vals, raw: p.scores || {}, dq: p.status === 'disqualified', finish: p.status === 'finishLine',
              me: s.localMPClientId && p.mpClientId === s.localMPClientId, pulse: !!pulses[p.mpClientId]
            }
          })
        })
      })
      scope.$on('scoreboardPlayerPulseColor', function (e, d) {
        if (!d || !d.mpClientId) return
        pulses[d.mpClientId] = true
        setTimeout(function () { delete pulses[d.mpClientId] }, 600)
      })

      scope.$on('$destroy', function () {
        clearInterval(timer)
        try { StreamsManager.remove(streamsList) } catch (e) {}
      })
    }
  }
}]);
