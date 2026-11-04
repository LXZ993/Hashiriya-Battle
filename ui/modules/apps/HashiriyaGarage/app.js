// Hashiriya Battle: Gegner-Garage (Entwickler-Werkzeug, nicht im Release).
// Erscheint in der BeamNG-Garage (Hauptmenü > Mehr > Garage) im eigenen Layout "hashiriyaGarage".
// Lua-Seite: lua/ge/extensions/hashiriyaBattle/garagetool.lua (Hook 'HashiriyaGarage', Aktionen über action(name, json)).
// Die App liegt über dem ganzen Bildschirm, fängt aber nur im Panel selbst Klicks ab (Garage-Menüs bleiben bedienbar).
// Keine nativen <select>/<input type=color>: die öffnen sich im BeamNG-Browser nicht.
angular.module('beamng.apps')
.directive('hashiriyaGarage', [function () {
  return {
    template:
      '<div class="hbg-root">' +
      '<div class="hbg" ng-class="{\'is-min\': ui.min}" ng-style="{left: win.x + \'px\', top: win.y + \'px\'}">' +
        '<div class="hbg-head" ng-mousedown="dragStart($event)">' +
          '<div class="hbg-title">GEGNER<span>GARAGE</span></div>' +
          '<div class="hbg-sub" ng-if="!ui.min">{{ d.rivals.length }} Gegner \u00b7 in der Garage: <b>{{ loadedName() }}</b></div>' +
          '<div class="hbg-sub" ng-if="ui.min && sel">{{ sel.name }} \u00b7 {{ sel.modelName }}</div>' +
          '<div class="hbg-x" ng-click="ui.min = !ui.min; remember()" title="{{ ui.min ? \'Aufklappen\' : \'Einklappen\' }}">{{ ui.min ? \'\u25be\' : \'\u2013\' }}</div>' +
        '</div>' +
        '<div class="hbg-status" ng-if="status && !ui.min" ng-class="{\'is-bad\': !status.ok}">{{ status.time }} \u00b7 {{ status.text }}</div>' +

        '<div class="hbg-body" ng-if="!ui.min">' +
          '<div class="hbg-note" ng-if="!d.full">Lade Gegnerliste \u2026</div>' +
          // --- Liste ------------------------------------------------------------------------
          '<div class="hbg-pick" ng-if="d.full">' +
            '<input class="hbg-search" type="text" ng-model="q.text" placeholder="Suchen: Name, Spitzname, ID, Crew, Auto, Config \u2026">' +
            '<div class="hbg-chips">' +
              '<span class="hbg-chip" ng-repeat="f in filters" ng-class="{\'is-on\': q.role == f.id}" ng-click="q.role = f.id; q.team = null">{{ f.name }} <em>{{ countRole(f.id) }}</em></span>' +
            '</div>' +
            '<div class="hbg-chips" ng-if="q.role == \'crew\' || q.role == \'leader\' || q.team">' +
              '<span class="hbg-chip hbg-team" ng-repeat="t in d.teams track by t.id" ng-class="{\'is-on\': q.team == t.id}" ng-click="q.team = (q.team == t.id ? null : t.id)">' +
                '<i class="hbg-dot" ng-style="{background: t.color}"></i>{{ t.name }}</span>' +
            '</div>' +
            '<div class="hbg-sub2">{{ matches().length }} Treffer</div>' +
            '<div class="hbg-list">' +
              '<div class="hbg-li" ng-repeat="r in matches() | limitTo: 150 track by r.id" ng-click="select(r)" ' +
                'ng-class="{\'is-sel\': sel && sel.id == r.id, \'is-bad\': !r.configOk}" ng-style="{\'border-left-color\': r.color || roleColor(r.role)}">' +
                '<div class="hbg-li-main"><b>{{ r.name }}<i ng-if="d.loadedId == r.id"> \u25cf in der Garage</i></b>' +
                  '<span>{{ roleName(r) }} \u00b7 {{ r.modelName }} \u00b7 {{ r.configName }}</span></div>' +
                '<span class="hbg-tag" ng-if="r.own">eigene</span>' +
                '<span class="hbg-tag hbg-tag-bad" ng-if="!r.configOk">fehlt</span>' +
              '</div>' +
            '</div>' +
          '</div>' +

          // --- Details ----------------------------------------------------------------------
          '<div class="hbg-detail" ng-if="sel">' +
            '<div class="hbg-name" ng-style="{\'border-left-color\': sel.color || roleColor(sel.role)}">' +
              '<b>{{ sel.name }}</b><span class="hbg-role" ng-style="{background: roleColor(sel.role)}">{{ roleLabel[sel.role] }}</span>' +
              '<em>\u201e{{ sel.nick }}\u201c \u00b7 {{ sel.id }}</em>' +
            '</div>' +
            '<div class="hbg-warn" ng-if="sel.placeholder">Platzhalter: {{ sel.placeholder }}</div>' +

            '<div class="hbg-sec">Auto</div>' +
            '<div class="hbg-kv"><span>Modell</span><b>{{ sel.modelName }} <i>({{ sel.model }})</i></b></div>' +
            '<div class="hbg-kv"><span>Config</span><b>{{ sel.configName }}</b></div>' +
            '<div class="hbg-path" ng-class="{\'is-bad\': !sel.configOk}">{{ sel.config }}{{ sel.configOk ? \'\' : \'  \u2014 Datei fehlt!\' }}</div>' +
            '<div class="hbg-kv" ng-if="sel.power || sel.value"><span>Werte</span><b><i ng-if="sel.power">{{ sel.power | number:0 }} PS</i><i ng-if="sel.weight"> \u00b7 {{ sel.weight | number:0 }} kg</i><i ng-if="sel.value"> \u00b7 Wert ${{ sel.value | number:0 }}</i></b></div>' +
            '<div class="hbg-kv" ng-if="sel.plate"><span>Kennzeichen</span><b>{{ sel.plate.text }} <i>{{ sel.plate.design }}</i></b></div>' +
            '<div class="hbg-kv" ng-if="sel.paint"><span>Fester Lack</span><b><i class="hbg-sw" ng-style="{background: paintCss(sel.paint)}"></i>{{ sel.paint.name || \'eigene Farbe\' }}</b></div>' +
            '<div class="hbg-note" ng-if="sel.paint">Im Spiel überdeckt dieser Lack aus rivals.json (paint) den Lack der Config, außer die Config hat eine Livery. Lackänderungen in der Garage wirken dann nicht.</div>' +
            '<div class="hbg-note" ng-if="sel.shared.length">Diese Config fahren auch: <span class="hbg-link" ng-repeat="id in sel.shared" ng-click="selectId(id)">{{ nameOf(id) }}{{ $last ? \'\' : \', \' }}</span></div>' +
            '<div class="hbg-btns">' +
              '<span class="hbg-btn hbg-main" ng-click="act(\'load\', {id: sel.id, mode: \'game\'})" title="Mit Kennzeichen-Design und festem Lack aus rivals.json, so wie er auf der Strecke auftaucht">Laden (wie im Spiel)</span>' +
              '<span class="hbg-btn" ng-click="act(\'load\', {id: sel.id, mode: \'pure\'})" title="Nur die .pc-Datei, ohne Kennzeichen-Design und Lack aus rivals.json">Nur Config laden</span>' +
            '</div>' +

            '<div class="hbg-sec">Charakter</div>' +
            '<div class="hbg-text">{{ sel.desc }}</div>' +
            '<div class="hbg-kv" ng-if="sel.hint"><span>Hinweis</span><b>{{ sel.hint }}</b></div>' +
            '<div class="hbg-kv" ng-repeat="c in condList(sel) track by $index"><span>{{ $first ? \'Bedingungen\' : \'\' }}</span><b>{{ c }}</b></div>' +
            '<div class="hbg-kv" ng-if="sel.appear"><span>Auftauchen</span><b>{{ appearText(sel.appear) }}</b></div>' +
            '<div class="hbg-kv"><span>Fahrstil</span><b>Aggression {{ sel.aggression }} \u00b7 Reise {{ sel.cruiseKmh }} km/h \u00b7 SP {{ sel.maxSp }}</b></div>' +
            '<div class="hbg-kv"><span>Belohnung</span><b>{{ sel.rewardYen ? (\'\u00a5\' + sel.rewardYen) : (\'$\' + sel.rewardUsd) }} \u00b7 Ruf {{ sel.rep }}</b></div>' +
            '<div class="hbg-line" ng-repeat="l in lineList(sel)"><span>{{ l.k }}</span>\u201e{{ l.t }}\u201c</div>' +

            '<div ng-if="team(sel)">' +
              '<div class="hbg-sec">Crew</div>' +
              '<div class="hbg-crew" ng-style="{\'border-color\': team(sel).color}">' +
                '<b>{{ team(sel).name }}</b> <i>{{ team(sel).jp }}</i>' +
                '<div class="hbg-text">{{ team(sel).desc }}</div>' +
                '<div class="hbg-mate" ng-repeat="m in mates(sel) track by m.id" ng-click="select(m)" ng-class="{\'is-sel\': m.id == sel.id}">' +
                  '<span>{{ m.leader ? \'\u2605 \' : \'\' }}{{ m.name }}</span><em>{{ m.modelName }} \u00b7 {{ m.configName }}</em></div>' +
              '</div>' +
            '</div>' +

            '<div class="hbg-sec">Speichern</div>' +
            '<div class="hbg-warn" ng-if="d.loadedId != sel.id">In der Garage steht gerade {{ loadedName() }}, nicht {{ sel.name }}. Erst laden, dann anpassen.</div>' +
            '<div class="hbg-note" ng-if="sel.own">Eigene Mod-Config: wird überschrieben (Sicherung in settings/hashiriya_battle/builder_backups/).</div>' +
            '<div class="hbg-note" ng-if="!sel.own">BeamNG-/fremde Config: bleibt unverändert. Es entsteht vehicles/{{ d.player.model || sel.model }}/hashiriya_r_{{ sel.id }}.pc im Mod-Ordner, rivals.json bekommt den neuen Pfad.</div>' +
            '<div class="hbg-note" ng-if="d.player && d.player.model != sel.model">Achtung: Das Auto in der Garage ist ein {{ d.player.modelName }}, der Gegner fährt {{ sel.modelName }}. Beim Speichern wechselt auch sein Modell.</div>' +
            '<span class="hbg-check" ng-if="sel.own && sel.shared.length" ng-class="{\'is-on\': ui.ownFile}" ng-click="ui.ownFile = !ui.ownFile"><i></i>Eigene Datei nur für {{ sel.name }} (die anderen behalten die alte)</span>' +
            '<div class="hbg-btns">' +
              '<span class="hbg-btn hbg-main hbg-wide" ng-class="{\'hbg-off\': d.loadedId != sel.id && !isArmed(\'save\')}" ng-click="armed(\'save\') ? save() : arm(\'save\')">' +
                '{{ isArmed(\'save\') ? \'Sicher? Nochmal klicken\' : \'Auf \' + sel.name + \' speichern\' }}</span>' +
            '</div>' +
          '</div>' +

          '<div class="hbg-foot">' +
            '<span class="hbg-btn" ng-click="act(\'refresh\')">Liste neu laden</span>' +
            '<span class="hbg-btn hbg-right" ng-click="armed(\'leave\') ? act(\'leave\') : arm(\'leave\')" title="Zurück ins BeamNG-Hauptmenü (nicht gespeicherte Änderungen am Auto gehen verloren)">{{ isArmed(\'leave\') ? \'Wirklich? Nochmal klicken\' : \'Garage verlassen\' }}</span>' +
          '</div>' +
        '</div>' +
      '</div>' +
      '<style>' +
        '.hbg-root{position:absolute;left:0;top:0;width:100%;height:100%;pointer-events:none;}' +
        '.hbg{--o:#ff6600;--o2:#ff9a3c;--w:#f4f4f4;--dim:rgba(244,244,244,.58);position:absolute;width:440px;max-height:calc(100% - 110px);' +
          'display:flex;flex-direction:column;pointer-events:auto;font-family:"Overpass","Noto Sans","Segoe UI",sans-serif;color:var(--w);' +
          'background:linear-gradient(160deg,rgba(26,26,29,.95),rgba(14,14,16,.93));box-shadow:0 8px 24px rgba(0,0,0,.55);border-left:4px solid var(--o);}' +
        '.hbg.is-min{width:300px;}' +
        '.hbg-head{position:relative;padding:9px 40px 7px 14px;cursor:move;user-select:none;flex:none;' +
          'background:linear-gradient(100deg,rgba(255,102,0,.22),rgba(255,102,0,0) 70%);border-bottom:1px solid rgba(255,255,255,.08);}' +
        '.hbg-title{font-size:17px;font-weight:900;font-style:italic;letter-spacing:2px;line-height:1;} .hbg-title span{color:var(--o);margin-left:6px;}' +
        '.hbg-sub{font-size:11px;color:var(--dim);margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;} .hbg-sub b{color:var(--w);font-weight:700;}' +
        '.hbg-x{position:absolute;right:8px;top:8px;width:24px;height:24px;line-height:24px;text-align:center;cursor:pointer;color:var(--dim);font-size:14px;}' +
        '.hbg-x:hover{color:var(--w);background:rgba(255,102,0,.3);}' +
        '.hbg-status{flex:none;font-size:11px;padding:4px 14px;background:rgba(61,220,132,.15);color:#bff5d5;} .hbg-status.is-bad{background:rgba(220,40,40,.25);color:#ffc9c9;}' +
        '.hbg-body{flex:1 1 auto;min-height:0;overflow-y:auto;overflow-x:hidden;padding:4px 12px 10px;}' +
        '.hbg-body::-webkit-scrollbar,.hbg-list::-webkit-scrollbar{width:4px;} .hbg-body::-webkit-scrollbar-thumb,.hbg-list::-webkit-scrollbar-thumb{background:var(--o);}' +
        '.hbg-sec{font-size:10px;font-weight:800;letter-spacing:2px;text-transform:uppercase;color:var(--o2);padding:10px 0 4px;}' +
        '.hbg-note{font-size:11px;color:var(--dim);padding:3px 0;line-height:1.4;}' +
        '.hbg-warn{font-size:11px;padding:5px 8px;margin:4px 0;background:rgba(255,180,0,.14);border-left:2px solid #ffb400;line-height:1.35;}' +
        '.hbg input[type=text]{box-sizing:border-box;background:rgba(0,0,0,.4);border:1px solid rgba(255,255,255,.12);color:var(--w);padding:5px 7px;font-size:12px;font-family:inherit;outline:none;width:100%;}' +
        '.hbg input[type=text]:focus{border-color:var(--o);}' +
        '.hbg-search{margin:6px 0 3px;}' +
        '.hbg-chips{display:flex;flex-wrap:wrap;gap:3px;padding:3px 0;}' +
        '.hbg-chip{padding:3px 7px;font-size:10px;font-weight:700;background:rgba(255,255,255,.06);cursor:pointer;white-space:nowrap;}' +
        '.hbg-chip em{font-style:normal;color:var(--dim);margin-left:2px;} .hbg-chip:hover{background:rgba(255,102,0,.25);} .hbg-chip.is-on{background:rgba(255,102,0,.6);} .hbg-chip.is-on em{color:var(--w);}' +
        '.hbg-team{font-weight:600;}' +
        '.hbg-dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:5px;box-shadow:0 0 0 1px rgba(0,0,0,.5);}' +
        '.hbg-sub2{font-size:10px;color:var(--dim);padding:2px 0 3px;}' +
        '.hbg-list{display:flex;flex-direction:column;gap:2px;max-height:30vh;overflow-y:auto;}' +
        '.hbg-li{display:flex;align-items:center;gap:4px;padding:4px 6px;background:rgba(255,255,255,.04);border-left:3px solid transparent;cursor:pointer;}' +
        '.hbg-li:hover{background:rgba(255,102,0,.14);} .hbg-li.is-sel{background:rgba(255,102,0,.32);} .hbg-li.is-bad .hbg-li-main span{color:#ff9d9d;}' +
        '.hbg-li-main{flex:1;min-width:0;} .hbg-li-main b{display:block;font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
        '.hbg-li-main b i{font-style:normal;font-size:10px;color:#3ddc84;font-weight:600;}' +
        '.hbg-li-main span{display:block;font-size:10px;color:var(--dim);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
        '.hbg-tag{font-size:9px;font-weight:800;letter-spacing:.5px;padding:1px 5px;background:rgba(255,255,255,.1);text-transform:uppercase;} .hbg-tag-bad{background:rgba(220,40,40,.6);}' +
        '.hbg-detail{margin-top:8px;border-top:1px solid rgba(255,255,255,.08);padding-top:6px;}' +
        '.hbg-name{border-left:4px solid var(--o);padding:2px 0 2px 8px;} .hbg-name b{font-size:16px;font-weight:800;}' +
        '.hbg-name em{display:block;font-style:normal;font-size:11px;color:var(--dim);margin-top:2px;}' +
        '.hbg-role{display:inline-block;margin-left:8px;font-size:9px;font-weight:800;letter-spacing:1px;text-transform:uppercase;padding:2px 6px;color:#111;vertical-align:3px;}' +
        '.hbg-kv{display:flex;gap:8px;font-size:12px;padding:2px 0;line-height:1.35;} .hbg-kv span{flex:0 0 86px;color:var(--dim);font-size:11px;}' +
        '.hbg-kv b{flex:1;font-weight:600;min-width:0;} .hbg-kv b i{font-style:normal;color:var(--dim);font-weight:500;}' +
        '.hbg-path{font-family:monospace;font-size:10px;color:var(--dim);padding:1px 0 3px 94px;word-break:break-all;} .hbg-path.is-bad{color:#ff8a8a;}' +
        '.hbg-sw{display:inline-block;width:12px;height:12px;margin-right:6px;vertical-align:-2px;box-shadow:inset 0 0 0 1px rgba(0,0,0,.4);}' +
        '.hbg-link{color:var(--o2);cursor:pointer;} .hbg-link:hover{text-decoration:underline;}' +
        '.hbg-text{font-size:12px;line-height:1.45;padding:2px 0 4px;}' +
        '.hbg-line{font-size:11px;font-style:italic;color:rgba(244,244,244,.82);padding:2px 0;line-height:1.35;} .hbg-line span{display:inline-block;width:86px;font-style:normal;color:var(--dim);margin-right:8px;}' +
        '.hbg-crew{border-left:3px solid var(--o);background:rgba(255,255,255,.03);padding:5px 8px;} .hbg-crew > b{font-size:13px;} .hbg-crew > i{font-style:normal;color:var(--dim);font-size:11px;}' +
        '.hbg-mate{display:flex;justify-content:space-between;gap:8px;font-size:11px;padding:3px 4px;cursor:pointer;} .hbg-mate:hover{background:rgba(255,102,0,.15);} .hbg-mate.is-sel{background:rgba(255,102,0,.3);}' +
        '.hbg-mate em{font-style:normal;color:var(--dim);text-align:right;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
        '.hbg-btns{display:flex;gap:4px;padding:6px 0 2px;}' +
        '.hbg-btn{display:inline-block;padding:5px 9px;font-size:11px;font-weight:700;letter-spacing:.3px;background:rgba(255,255,255,.08);cursor:pointer;white-space:nowrap;text-align:center;}' +
        '.hbg-btn:hover{background:rgba(255,102,0,.35);} .hbg-main{background:rgba(255,102,0,.55);} .hbg-main:hover{background:var(--o);}' +
        '.hbg-off{opacity:.5;} .hbg-wide{flex:1;} .hbg-right{margin-left:auto;}' +
        '.hbg-check{display:flex;align-items:center;gap:6px;font-size:11px;color:var(--dim);cursor:pointer;padding:4px 0;}' +
        '.hbg-check i{width:12px;height:12px;border:1px solid rgba(255,255,255,.4);flex:none;} .hbg-check.is-on{color:var(--w);} .hbg-check.is-on i{background:var(--o);border-color:var(--o);}' +
        '.hbg-foot{display:flex;gap:4px;margin-top:10px;padding-top:6px;border-top:1px solid rgba(255,255,255,.08);}' +
      '</style>' +
      '</div>',
    replace: true,
    link: function (scope, element) {
      'use strict'
      // Vollbild-App: App-Element und BeamNG-Host bleiben durchlässig, nur das Panel (.hbg) nimmt Klicks
      ;(function () {
        var el = element[0]
        var host = el.closest && el.closest('.ui-app-host')
        while (el) {
          el.style.pointerEvents = 'none'
          if (!host || el === host) break
          el = el.parentElement
        }
      })()

      scope.d = { full: false, rivals: [], teams: [], ranks: [] }
      scope.q = { text: '', role: 'all', team: null }
      scope.ui = { min: false, ownFile: false }
      scope.sel = null
      scope.status = null
      scope.filters = [
        { id: 'all', name: 'Alle' }, { id: 'crew', name: 'Crews' }, { id: 'leader', name: 'Leader' },
        { id: 'wanderer', name: 'Wanderer' }, { id: 'boss', name: 'Bosse' }, { id: 'own', name: 'Eigene Configs' }, { id: 'missing', name: 'Config fehlt' }
      ]
      scope.roleLabel = { crew: 'Crew', leader: 'Leader', wanderer: 'Wanderer', boss: 'Boss', final: 'Endboss', other: 'Sonstige' }
      var roleColors = { crew: '#ff9a3c', leader: '#ffd400', wanderer: '#b07bff', boss: '#ff3b3b', final: '#ff3b3b', other: '#a0a0a0' }
      scope.roleColor = function (role) { return roleColors[role] || '#a0a0a0' }

      // Fensterposition und Einklappen merken (Browser-Speicher)
      var win = scope.win = { x: 0, y: 0 }
      try {
        var saved = JSON.parse(localStorage.getItem('hashiriyaGarageWin2') || 'null')
        if (saved) { win.x = saved.x; win.y = saved.y; scope.ui.min = !!saved.min }
      } catch (e) {}
      function clampWin() {
        var w = window.innerWidth || 1920, h = window.innerHeight || 1080
        if (!win.x && !win.y) { win.x = Math.max(10, w - 600); win.y = 130 } // rechts
        win.x = Math.min(Math.max(0, win.x), w - 120); win.y = Math.min(Math.max(0, win.y), h - 60)
      }
      clampWin()
      scope.remember = function () {
        try { localStorage.setItem('hashiriyaGarageWin2', JSON.stringify({ x: win.x, y: win.y, min: scope.ui.min })) } catch (e) {}
      }
      var drag = null
      scope.dragStart = function (e) {
        if (e.target && e.target.classList.contains('hbg-x')) return
        drag = { mx: e.clientX, my: e.clientY, x: win.x, y: win.y }
        e.preventDefault()
      }
      function onMove(e) {
        if (!drag) return
        scope.$evalAsync(function () { win.x = drag.x + e.clientX - drag.mx; win.y = drag.y + e.clientY - drag.my; clampWin() })
      }
      function onUp() { if (drag) { drag = null; scope.remember() } }
      window.addEventListener('mousemove', onMove)
      window.addEventListener('mouseup', onUp)
      scope.$on('$destroy', function () { window.removeEventListener('mousemove', onMove); window.removeEventListener('mouseup', onUp) })

      // --- Lua -------------------------------------------------------------------------------
      function luaStr(s) {
        return '"' + String(s).replace(/[\\"]/g, '\\$&').replace(/[\u0000-\u001f\u007f]/g, function (ch) { return '\\' + ('00' + ch.charCodeAt(0)).slice(-3) }) + '"'
      }
      scope.act = function (name, arg) {
        var a = arg === undefined ? 'nil' : luaStr(JSON.stringify(arg))
        bngApi.engineLua('if extensions.hashiriyaBattle_garagetool then extensions.hashiriyaBattle_garagetool.action("' + name + '", ' + a + ') end')
      }
      scope.save = function () { if (scope.sel) scope.act('save', { id: scope.sel.id, ownFile: scope.ui.ownFile }) }

      var armedKey = null, armTimer = null
      scope.arm = function (k) {
        armedKey = k; clearTimeout(armTimer)
        armTimer = setTimeout(function () { scope.$evalAsync(function () { armedKey = null }) }, 4000)
      }
      scope.armed = function (k) { if (armedKey === k) { armedKey = null; return true } return false }
      scope.isArmed = function (k) { return armedKey === k }

      // --- Liste -------------------------------------------------------------------------------
      function roleMatch(r, role) {
        if (role === 'all') return true
        if (role === 'crew') return r.role === 'crew' || r.role === 'leader'
        if (role === 'boss') return r.role === 'boss' || r.role === 'final'
        if (role === 'own') return r.own
        if (role === 'missing') return !r.configOk
        return r.role === role
      }
      scope.countRole = function (role) {
        var n = 0
        ;(scope.d.rivals || []).forEach(function (r) { if (roleMatch(r, role)) n++ })
        return n
      }
      var cache = { key: null, list: [] }
      scope.matches = function () {
        var q = (scope.q.text || '').toLowerCase(), role = scope.q.role, team = scope.q.team
        var key = q + '|' + role + '|' + team
        if (cache.key === key && cache.src === scope.d.rivals) return cache.list
        var list = (scope.d.rivals || []).filter(function (r) {
          if (!roleMatch(r, role)) return false
          if (team && r.team !== team) return false
          if (!q) return true
          return [r.id, r.name, r.nick, r.teamName, r.modelName, r.model, r.configName, r.config].some(function (s) {
            return s && String(s).toLowerCase().indexOf(q) >= 0
          })
        })
        cache = { key: key, list: list, src: scope.d.rivals }
        return list
      }
      scope.select = function (r) {
        if (r && r.ref) r = r.ref // Eintrag aus der Crew-Liste
        scope.sel = r; scope.ui.ownFile = false
        try { localStorage.setItem('hashiriyaGarageSel', r.id) } catch (e) {}
      }
      function byId(id) {
        var l = scope.d.rivals || []
        for (var i = 0; i < l.length; i++) if (l[i].id === id) return l[i]
        return null
      }
      scope.selectId = function (id) { var r = byId(id); if (r) scope.select(r) }
      scope.nameOf = function (id) { var r = byId(id); return r ? r.name : id }
      scope.loadedName = function () {
        var r = scope.d.loadedId && byId(scope.d.loadedId)
        if (r) return r.name
        return scope.d.player ? scope.d.player.modelName + ' (kein Gegner)' : '\u2014'
      }
      scope.roleName = function (r) {
        if ((r.role === 'crew' || r.role === 'leader') && r.teamName) return (r.role === 'leader' ? 'Leader ' : '') + r.teamName
        return scope.roleLabel[r.role] || r.role
      }

      // --- Details -------------------------------------------------------------------------------
      scope.team = function (r) {
        if (!r || !r.team) return null
        var l = scope.d.teams || []
        for (var i = 0; i < l.length; i++) if (l[i].id === r.team) return l[i]
        return null
      }
      // Listen für ng-repeat pro Gegner zwischenspeichern (sonst Endlos-Digest: jedes Mal ein neues Array)
      function memo(fn) {
        var c = { r: null, src: null, v: null }
        return function (r) {
          if (c.r === r && c.src === scope.d.rivals) return c.v
          c = { r: r, src: scope.d.rivals, v: fn(r) }
          return c.v
        }
      }
      scope.mates = memo(function (r) {
        if (!r || !r.team) return []
        return (scope.d.rivals || []).filter(function (m) { return m.team === r.team })
          .map(function (m) { return { id: m.id, name: m.name, leader: m.role === 'leader', modelName: m.modelName, configName: m.configName, ref: m } })
      })
      scope.paintCss = function (p) {
        var c = (p && p.color) || [0.5, 0.5, 0.5]
        return 'rgb(' + Math.round(c[0] * 255) + ',' + Math.round(c[1] * 255) + ',' + Math.round(c[2] * 255) + ')'
      }
      var lineNames = { challenge: 'Herausfordern', win: 'Er gewinnt', lose: 'Er verliert' }
      scope.lineList = memo(function (r) {
        var out = []
        ;['challenge', 'win', 'lose'].forEach(function (k) { if (r.lines && r.lines[k]) out.push({ k: lineNames[k], t: r.lines[k] }) })
        Object.keys(r.lines || {}).forEach(function (k) { if (!lineNames[k]) out.push({ k: k, t: r.lines[k] }) })
        return out
      })
      function teamName(id) { var t = scope.team({ team: id }); return t ? t.name : id }
      function list(v) { return Array.isArray(v) ? v : [v] }
      scope.condList = memo(function (r) {
        var c = r.conditions || {}, out = []
        Object.keys(c).forEach(function (k) {
          var v = c[k]
          switch (k) {
            case 'minRank': out.push('ab Rang ' + (v + 1) + (scope.d.ranks[v] ? ' (' + scope.d.ranks[v] + ')' : '')); break
            case 'minWins': out.push('mindestens ' + v + ' Siege'); break
            case 'minDay': out.push('ab Spieltag ' + v); break
            case 'hours': case 'timeWindow': out.push('nur ' + v[0] + ':00 bis ' + v[1] + ':00 Uhr'); break
            case 'playerModel': out.push('nur gegen Spieler im ' + v); break
            case 'playerPart': out.push('Spielerauto braucht Teil mit \u201e' + v + '\u201c'); break
            case 'noPart': out.push('Spielerauto ohne Teil \u201e' + v + '\u201c'); break
            case 'speedTraps': out.push(v === 'all' ? 'alle Blitzer ausgelöst' : v + ' Blitzer ausgelöst'); break
            case 'beatenTeam': out.push('Crew ' + teamName(v) + ' geschlagen'); break
            case 'beatenTeams': out.push('Crews geschlagen: ' + list(v).map(teamName).join(', ')); break
            case 'beatenRivals': case 'requires': out.push('Gegner geschlagen: ' + list(v).map(scope.nameOf).join(', ')); break
            case 'naOnly': out.push('nur Sauger'); break
            case 'forcedInduction': out.push('nur Turbo/Kompressor'); break
            case 'manual': out.push('nur Schaltgetriebe'); break
            case 'drive': out.push('Antrieb ' + list(v).join('/')); break
            case 'minPower': out.push('ab ' + v + ' PS'); break
            case 'maxPower': out.push('bis ' + v + ' PS'); break
            case 'paintColor': out.push('Lackfarbe ' + list(v).join('/')); break
            default: out.push(k + ': ' + (typeof v === 'object' ? JSON.stringify(v) : v))
          }
        })
        return out
      })
      scope.appearText = function (a) {
        var m = { sameNight: 'in derselben Nacht', nextNight: 'ab der nächsten Nacht' }
        return list(a).map(function (x) { return m[x] || x }).join(', ')
      }

      scope.$on('HashiriyaGarage', function (event, msg) {
        scope.$evalAsync(function () {
          if (!msg) return
          if (msg.status) { scope.status = msg.status; return }
          if (!msg.full) return
          ;['rivals', 'teams', 'ranks'].forEach(function (k) { if (!Array.isArray(msg[k])) msg[k] = [] })
          msg.rivals.forEach(function (r) { if (!Array.isArray(r.shared)) r.shared = [] })
          var keep = scope.sel && scope.sel.id
          if (!keep) { try { keep = localStorage.getItem('hashiriyaGarageSel') } catch (e) {} }
          scope.d = msg
          scope.sel = keep ? byId(keep) : null
        })
      })
      bngApi.engineLua('if extensions.hashiriyaBattle_garagetool then extensions.hashiriyaBattle_garagetool.refresh() end')
    }
  }
}])
