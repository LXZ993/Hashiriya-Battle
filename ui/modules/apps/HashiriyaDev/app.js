// Hashiriya Battle: Dev-Menü (Entwickler-Werkzeug, eigenes Fenster).
// Öffnen: Shift+Ende oder Hashiriya-Menü > Werkzeuge > Dev-Menü. Lua-Seite: lua/ge/extensions/hashiriyaBattle/devtools.lua
// Zustand kommt per Hook 'HashiriyaDev' (ganz beim Öffnen und nach jeder Aktion, alle 0,5 s nur Spielerposition/Uhrzeit).
// Neue Aktionen gehen an hashiriyaBattle_devtools.action(name, json), alte Dev-Aktionen an hashiriyaBattle_core.uiAction.
// Die App liegt im Layout über dem ganzen Bildschirm: geschlossen fängt sie keine Klicks ab. Nicht im Release-Zip.
angular.module('beamng.apps')
.directive('hashiriyaDev', [function () {
  return {
    template:
      '<div class="hbd-root">' +
      '<div class="hbd" ng-if="d.open" ng-style="{left: win.x + \'px\', top: win.y + \'px\'}">' +
        '<div class="hbd-head" ng-mousedown="dragStart($event)">' +
          '<div class="hbd-title">DEV<span>MENÜ</span></div>' +
          '<div class="hbd-sub">{{ d.level || \'\u2014\' }} \u00b7 {{ clock() }}<span ng-if="d.save"> \u00b7 {{ d.moneyText || d.save.moneyText }}</span></div>' +
          '<div class="hbd-x" ng-click="close()">\u2715</div>' +
        '</div>' +
        '<div class="hbd-tabs">' +
          '<div class="hbd-tab" ng-repeat="t in tabs" ng-class="{\'is-on\': tab == t.id}" ng-click="setTab(t.id)">{{ t.name }}</div>' +
        '</div>' +

        // --- Spielstand -----------------------------------------------------------
        '<div class="hbd-body" ng-if="tab == \'save\'">' +
          '<div class="hbd-note" ng-if="!d.save">Nur in einer laufenden Karriere (Weiterspielen oder Neues Spiel).</div>' +
          '<div ng-if="d.save">' +
            '<div class="hbd-big"><b>{{ d.save.rankIdx + 1 }}</b> {{ d.save.rankName }}<span>Ruf {{ d.save.rep }} \u00b7 Teile {{ levelText() }}</span></div>' +
            '<div class="hbd-sec">Rang setzen</div>' +
            '<div class="hbd-ranks">' +
              '<div class="hbd-rank" ng-repeat="r in d.save.ranks" ng-class="{\'is-on\': r.idx == d.save.rankIdx}" ng-click="dev(\'setRank\', {idx: r.idx})" title="ab {{ r.rep }} Ruf">' +
                '<i>{{ r.idx + 1 }}</i>{{ r.name }}<em>{{ r.rep }}{{ r.requiresFinal ? \' + Endboss\' : \'\' }}</em></div>' +
            '</div>' +
            '<div class="hbd-row hbd-toggle" ng-click="dev(\'setFinal\', {on: !d.save.finalBeaten})"><span>Endboss besiegt</span><b ng-class="{\'is-on\': d.save.finalBeaten}">{{ d.save.finalBeaten ? \'JA\' : \'NEIN\' }}</b></div>' +
            '<div class="hbd-sec">Werte</div>' +
            '<div class="hbd-val" ng-repeat="f in fields">' +
              '<span class="hbd-lbl">{{ f.name }}</span><b>{{ f.id == \'money\' ? (d.moneyText || d.save.moneyText) : d.save[f.id] }}</b>' +
              '<input type="text" ng-model="inp[f.id]" placeholder="Wert" ng-keydown="$event.keyCode == 13 && setVal(f.id)">' +
              '<span class="hbd-btn hbd-main" ng-click="setVal(f.id)">Setzen</span>' +
              '<span class="hbd-btn" ng-repeat="q in f.quick" ng-click="dev(\'addValue\', {field: f.id, value: q.v})">{{ q.l }}</span>' +
            '</div>' +
            '<div class="hbd-val">' +
              '<span class="hbd-lbl">Uhrzeit</span><b>{{ clock() }}</b>' +
              '<input type="text" ng-model="inp.hour" placeholder="0-23,5" ng-keydown="$event.keyCode == 13 && setHour()">' +
              '<span class="hbd-btn hbd-main" ng-click="setHour()">Setzen</span>' +
              '<span class="hbd-btn" ng-repeat="h in [6, 20, 22, 2]" ng-click="dev(\'setHour\', {hour: h})">{{ h }}h</span>' +
            '</div>' +
            '<div class="hbd-sec">Freischaltungen</div>' +
            '<div class="hbd-grid">' +
              '<span class="hbd-btn" ng-click="dev(\'resetUnlockSeen\')">Freischalt-Meldungen neu zeigen</span>' +
              '<span class="hbd-btn" ng-click="act(\'devUnlock\', 2)">Meldung testen (LV2)</span>' +
            '</div>' +
          '</div>' +
        '</div>' +

        // --- Rivalen ---------------------------------------------------------------
        '<div class="hbd-body" ng-if="tab == \'rivals\'">' +
          '<div class="hbd-note" ng-if="!d.active">Nur in einer laufenden Karriere.</div>' +
          '<div ng-if="d.active">' +
            '<div class="hbd-grid">' +
              '<span class="hbd-btn" ng-click="act(\'callRival\')">Rivale rufen</span>' +
              '<span class="hbd-btn" ng-click="act(\'devSpawnRival\', \'__random\')">Zufälliger Rivale</span>' +
              '<span class="hbd-btn" ng-click="act(\'devClearRivals\')">Alle entfernen</span>' +
              '<span class="hbd-btn" ng-click="act(\'devTalkRespawn\')">PA-Fahrer neu</span>' +
              '<span class="hbd-btn hbd-warn" ng-click="armed(\'resetDef\') ? dev(\'resetDefeated\') : arm(\'resetDef\')">{{ isArmed(\'resetDef\') ? \'Sicher? Nochmal klicken\' : \'Alle wieder unbesiegt\' }}</span>' +
            '</div>' +
            '<input class="hbd-search" type="text" ng-model="q.rival" placeholder="Suchen: Name, ID oder Crew \u2026">' +
            '<div class="hbd-sub2">{{ rivalMatches().length }} von {{ d.rivals.length }} \u00b7 besiegt: {{ defeatedCount() }}</div>' +
            '<div class="hbd-list">' +
              '<div class="hbd-li" ng-repeat="r in rivalMatches() | limitTo: 80 track by r.id" ng-class="{\'is-beaten\': d.save.defeated[r.id]}">' +
                '<div class="hbd-li-main"><b>{{ r.name }}</b><span>{{ r.tag }} \u00b7 {{ r.id }}</span></div>' +
                '<span class="hbd-btn hbd-main" ng-click="act(\'devSpawnRival\', r.id)">Spawnen</span>' +
                '<span class="hbd-btn" ng-click="dev(\'setDefeated\', {id: r.id, on: !d.save.defeated[r.id]})">{{ d.save.defeated[r.id] ? \'Besiegt \u2713\' : \'Offen\' }}</span>' +
              '</div>' +
            '</div>' +
          '</div>' +
        '</div>' +

        // --- Orte ------------------------------------------------------------------
        '<div class="hbd-body" ng-if="tab == \'places\'">' +
          '<div class="hbd-card">' +
            '<div class="hbd-sec">Neuen Ort merken <em>{{ posText() }}</em></div>' +
            '<div class="hbd-form">' +
              '<input type="text" ng-model="nw.name" placeholder="Name (leer = Typ + Nummer)" ng-keydown="$event.keyCode == 13 && capture()">' +
              '<input type="text" ng-model="nw.note" placeholder="Notiz (optional)">' +
            '</div>' +
            '<div class="hbd-chips">' +
              '<span class="hbd-chip" ng-repeat="t in d.types" ng-class="{\'is-on\': nw.type == t.id}" ng-click="nw.type = t.id"><i class="hbd-dot" ng-style="{background: t.color}"></i>{{ t.name }}</span>' +
            '</div>' +
            '<div class="hbd-form">' +
              '<span class="hbd-check" ng-click="nw.useCam = !nw.useCam" ng-class="{\'is-on\': nw.useCam || (d.player && d.player.freecam)}">' +
                '<i></i>Kamera-Position (Freecam){{ d.player && d.player.freecam ? \' \u00b7 aktiv\' : \'\' }}</span>' +
              '<span class="hbd-btn hbd-main hbd-wide" ng-click="capture()">Hier merken</span>' +
            '</div>' +
          '</div>' +
          '<div class="hbd-card hbd-mk">' +
            '<div class="hbd-sec">Markierungen <em>Säulen auf der Map, solange das Dev-Menü offen ist</em></div>' +
            '<div class="hbd-chips">' +
              '<span class="hbd-check" ng-class="{\'is-on\': d.markers.on}" ng-click="dev(\'setMarkers\', {on: !d.markers.on})"><i></i>Säulen</span>' +
              '<span class="hbd-check" ng-class="{\'is-on\': d.markers.labels}" ng-click="dev(\'setMarkers\', {labels: !d.markers.labels})"><i></i>Namen</span>' +
              '<span class="hbd-check" ng-class="{\'is-on\': d.markers.showMap}" ng-click="dev(\'setMarkers\', {showMap: !d.markers.showMap})"><i></i>Orte aus Kartendatei</span>' +
            '</div>' +
            '<div class="hbd-chips"><span class="hbd-lbl">Höhe</span>' +
              '<span class="hbd-chip" ng-repeat="h in [15, 40, 80, 150]" ng-class="{\'is-on\': d.markers.height == h}" ng-click="dev(\'setMarkers\', {height: h})">{{ h }} m</span>' +
              '<span class="hbd-btn hbd-right" ng-click="ui.colors = !ui.colors">{{ ui.colors ? \'Farben zu\' : \'Farben ändern\' }}</span>' +
            '</div>' +
            '<div ng-if="ui.colors">' +
              '<div class="hbd-crow" ng-repeat="t in d.types track by t.id">' +
                '<i class="hbd-dot hbd-dot-big" ng-style="{background: t.color}"></i><span class="hbd-cname">{{ t.name }}</span>' +
                '<span class="hbd-sw" ng-repeat="c in palette" ng-style="{background: c}" ng-class="{\'is-on\': c == t.color}" ng-click="dev(\'setColor\', {type: t.id, color: c})"></span>' +
                '<span class="hbd-btn hbd-mini" ng-if="t.custom" ng-click="dev(\'setColor\', {type: t.id, color: \'\'})" title="Standardfarbe">\u21ba</span>' +
              '</div>' +
            '</div>' +
          '</div>' +
          '<div class="hbd-form">' +
            '<input class="hbd-search" type="text" ng-model="q.place" placeholder="Suchen \u2026">' +
            '<span class="hbd-btn" ng-click="sortNear = !sortNear">{{ sortNear ? \'Nach Nähe\' : \'Nach Liste\' }}</span>' +
          '</div>' +
          '<div class="hbd-chips">' +
            '<span class="hbd-chip" ng-class="{\'is-on\': !q.type}" ng-click="q.type = null">Alle ({{ d.places.length }})</span>' +
            '<span class="hbd-chip" ng-repeat="t in usedTypes() track by t.id" ng-class="{\'is-on\': q.type == t.id}" ng-click="q.type = t.id">{{ t.name }} ({{ t.n }})</span>' +
          '</div>' +
          '<div class="hbd-list">' +
            '<div ng-repeat="p in placeMatches() track by p.id">' +
              '<div class="hbd-li" ng-class="{\'is-map\': p.map}" ng-style="{\'border-left-color\': color(p.type)}">' +
                '<div class="hbd-li-main" ng-click="toggleEdit(p)"><b>{{ p.name }}</b>' +
                  '<span><i class="hbd-type" ng-style="{color: color(p.type)}">{{ p.typeName }}</i>{{ p.map ? \' \u00b7 Kartendatei\' : \'\' }}{{ p.onFoot ? \' \u00b7 zu Fuß\' : \'\' }} \u00b7 {{ distText(p) }}{{ p.note ? \' \u00b7 \' + p.note : \'\' }}</span></div>' +
                '<span class="hbd-btn hbd-main" ng-click="dev(\'teleport\', {id: p.id})">Hin</span>' +
                '<span class="hbd-btn" ng-click="toggleEdit(p)">{{ edit.id == p.id ? \'Zu\' : \'Bearb.\' }}</span>' +
              '</div>' +
              '<div class="hbd-edit" ng-if="edit.id == p.id">' +
                '<div class="hbd-form">' +
                  '<input type="text" ng-model="edit.name" placeholder="Name" ng-keydown="$event.keyCode == 13 && saveEdit(p)">' +
                  '<input type="text" ng-model="edit.note" placeholder="Notiz" ng-if="!p.map">' +
                '</div>' +
                '<div class="hbd-chips" ng-if="!p.map">' +
                  '<span class="hbd-chip" ng-repeat="t in d.types" ng-class="{\'is-on\': edit.type == t.id}" ng-click="edit.type = t.id"><i class="hbd-dot" ng-style="{background: t.color}"></i>{{ t.name }}</span>' +
                '</div>' +
                '<div class="hbd-note" ng-if="p.map">Ort aus der Kartendatei: nur der Anzeigename lässt sich hier ändern (leer = Standardname).</div>' +
                '<div class="hbd-grid">' +
                  '<span class="hbd-btn hbd-main" ng-click="saveEdit(p)">Speichern</span>' +
                  '<span class="hbd-btn" ng-if="!p.map" ng-click="dev(\'movePlace\', {id: p.id, useCam: nw.useCam})">Auf aktuelle Stelle setzen</span>' +
                  '<span class="hbd-btn hbd-warn" ng-if="!p.map" ng-click="armed(\'del\' + p.id) ? delPlace(p) : arm(\'del\' + p.id)">{{ isArmed(\'del\' + p.id) ? \'Sicher? Nochmal klicken\' : \'Löschen\' }}</span>' +
                '</div>' +
                '<div class="hbd-coords">{{ coords(p) }}</div>' +
              '</div>' +
            '</div>' +
            '<div class="hbd-note" ng-if="!placeMatches().length">Keine Orte gefunden.</div>' +
          '</div>' +
          '<div class="hbd-note">Gespeichert in BeamNG-Userordner/settings/hashiriya_battle/dev_places.json</div>' +
        '</div>' +

        // --- Werkzeuge ----------------------------------------------------------------
        '<div class="hbd-body" ng-if="tab == \'tools\'">' +
          '<div class="hbd-sec">Auto</div>' +
          '<div class="hbd-grid">' +
            '<span class="hbd-btn" ng-click="act(\'cheatRepair\')">Gratis reparieren</span>' +
            '<span class="hbd-btn" ng-click="act(\'cheatFuel\')">Gratis volltanken</span>' +
          '</div>' +
          '<div class="hbd-sec">Exporte und Editoren</div>' +
          '<div class="hbd-grid">' +
            '<span class="hbd-btn" ng-click="act(\'builder\')">Builder (Crews, Wanderer, Bosse)</span>' +
            '<span class="hbd-btn" ng-click="act(\'titleCamera\')">Titelbild-Kamera merken</span>' +
            '<span class="hbd-btn" ng-click="act(\'dumpConfigs\')">Configs exportieren</span>' +
            '<span class="hbd-btn" ng-click="act(\'dumpParts\')">Teile des Autos exportieren</span>' +
          '</div>' +
          '<div class="hbd-note">Exporte landen in BeamNG-Userordner/settings/hashiriya_battle/.</div>' +
        '</div>' +
      '</div>' +
      '<style>' +
        '.hbd-root{position:absolute;left:0;top:0;width:100%;height:100%;pointer-events:none;}' +
        '.hbd{--o:#ff6600;--o2:#ff9a3c;--w:#f4f4f4;--dim:rgba(244,244,244,.55);position:absolute;width:510px;max-height:calc(100% - 40px);' +
          'display:flex;flex-direction:column;pointer-events:auto;font-family:"Overpass","Noto Sans","Segoe UI",sans-serif;color:var(--w);' +
          'background:linear-gradient(160deg,rgba(26,26,29,.95),rgba(14,14,16,.92));box-shadow:0 8px 24px rgba(0,0,0,.55);border-left:4px solid var(--o);}' +
        '.hbd-head{position:relative;padding:10px 40px 8px 14px;cursor:move;user-select:none;flex:none;' +
          'background:linear-gradient(100deg,rgba(255,102,0,.22),rgba(255,102,0,0) 70%);border-bottom:1px solid rgba(255,255,255,.08);}' +
        '.hbd-title{font-size:18px;font-weight:900;font-style:italic;letter-spacing:2px;line-height:1;} .hbd-title span{color:var(--o);margin-left:6px;}' +
        '.hbd-sub{font-size:11px;color:var(--dim);margin-top:4px;letter-spacing:.5px;}' +
        '.hbd-x{position:absolute;right:8px;top:8px;width:24px;height:24px;line-height:24px;text-align:center;cursor:pointer;color:var(--dim);font-size:14px;}' +
        '.hbd-x:hover{color:var(--w);background:rgba(255,102,0,.3);}' +
        '.hbd-tabs{display:flex;flex:none;border-bottom:1px solid rgba(255,255,255,.08);}' +
        '.hbd-tab{flex:1;text-align:center;padding:7px 4px;font-size:11px;font-weight:800;letter-spacing:1.5px;text-transform:uppercase;color:var(--dim);cursor:pointer;}' +
        '.hbd-tab:hover{color:var(--w);background:rgba(255,102,0,.12);} .hbd-tab.is-on{color:var(--w);box-shadow:inset 0 -2px 0 var(--o);}' +
        '.hbd-body{flex:1 1 auto;min-height:0;overflow-y:auto;overflow-x:hidden;padding:6px 12px 10px;}' +
        '.hbd-body::-webkit-scrollbar{width:4px;} .hbd-body::-webkit-scrollbar-thumb{background:var(--o);}' +
        '.hbd-sec{font-size:10px;font-weight:800;letter-spacing:2px;text-transform:uppercase;color:var(--o2);padding:10px 0 4px;}' +
        '.hbd-sec em{font-style:normal;color:var(--dim);letter-spacing:.5px;text-transform:none;font-weight:500;margin-left:6px;}' +
        '.hbd-note{font-size:11px;color:var(--dim);padding:6px 0;line-height:1.4;}' +
        '.hbd-big{font-size:15px;font-weight:700;padding:6px 0 2px;} .hbd-big b{color:var(--o);font-style:italic;margin-right:6px;}' +
        '.hbd-big span{display:block;font-size:11px;font-weight:500;color:var(--dim);margin-top:2px;}' +
        '.hbd-ranks{display:grid;grid-template-columns:1fr 1fr 1fr;gap:3px;}' +
        '.hbd-rank{position:relative;padding:5px 6px 5px 22px;font-size:11px;font-weight:600;background:rgba(255,255,255,.05);cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
        '.hbd-rank i{position:absolute;left:5px;top:5px;font-style:italic;font-weight:900;color:var(--o);font-size:11px;}' +
        '.hbd-rank em{display:block;font-style:normal;font-size:9px;color:var(--dim);}' +
        '.hbd-rank:hover{background:rgba(255,102,0,.22);} .hbd-rank.is-on{background:rgba(255,102,0,.45);}' +
        '.hbd-row{display:flex;justify-content:space-between;align-items:center;padding:6px 8px;margin-top:4px;background:rgba(255,255,255,.04);font-size:12px;cursor:pointer;}' +
        '.hbd-row:hover{background:rgba(255,102,0,.15);} .hbd-row b{font-size:11px;color:var(--dim);} .hbd-row b.is-on{color:var(--o2);}' +
        '.hbd-val{display:flex;align-items:center;flex-wrap:wrap;gap:4px;padding:4px 0;border-bottom:1px solid rgba(255,255,255,.05);}' +
        '.hbd-lbl{width:72px;font-size:11px;color:var(--dim);} .hbd-val b{min-width:92px;font-size:12px;}' +
        '.hbd .hbd-val input[type=text]{flex:0 0 76px;width:76px;}' +
        '.hbd input[type=text]{box-sizing:border-box;background:rgba(0,0,0,.4);border:1px solid rgba(255,255,255,.12);color:var(--w);padding:4px 6px;font-size:12px;font-family:inherit;outline:none;flex:1;min-width:0;}' +
        '.hbd input[type=text]:focus{border-color:var(--o);}' +
        '.hbd-btn{display:inline-block;padding:4px 8px;font-size:11px;font-weight:700;letter-spacing:.3px;background:rgba(255,255,255,.08);cursor:pointer;white-space:nowrap;text-align:center;}' +
        '.hbd-btn:hover{background:rgba(255,102,0,.35);} .hbd-main{background:rgba(255,102,0,.55);} .hbd-main:hover{background:var(--o);}' +
        '.hbd-warn:hover{background:rgba(220,40,40,.6);} .hbd-wide{flex:1;}' +
        '.hbd-grid{display:grid;grid-template-columns:1fr 1fr;gap:4px;padding:2px 0;}' +
        '.hbd-form{display:flex;gap:4px;align-items:center;padding:3px 0;}' +
        '.hbd-search{width:100%;margin:6px 0 2px;}' +
        '.hbd-sub2{font-size:10px;color:var(--dim);padding:2px 0 4px;}' +
        '.hbd-card{background:rgba(255,102,0,.07);border:1px solid rgba(255,102,0,.18);padding:2px 8px 6px;margin:4px 0 6px;}' +
        '.hbd-chips{display:flex;flex-wrap:wrap;gap:3px;padding:3px 0;}' +
        '.hbd-chip{padding:3px 7px;font-size:10px;font-weight:700;background:rgba(255,255,255,.06);cursor:pointer;}' +
        '.hbd-chip:hover{background:rgba(255,102,0,.25);} .hbd-chip.is-on{background:rgba(255,102,0,.6);}' +
        '.hbd-check{display:flex;align-items:center;gap:6px;font-size:11px;color:var(--dim);cursor:pointer;flex:1;}' +
        '.hbd-check i{width:12px;height:12px;border:1px solid rgba(255,255,255,.4);} .hbd-check.is-on{color:var(--w);} .hbd-check.is-on i{background:var(--o);border-color:var(--o);}' +
        '.hbd-list{display:flex;flex-direction:column;gap:2px;}' +
        '.hbd-li{display:flex;align-items:center;gap:4px;padding:4px 6px;background:rgba(255,255,255,.04);}' +
        '.hbd-li:hover{background:rgba(255,102,0,.12);} .hbd-li.is-beaten{opacity:.6;} .hbd-li.is-map{background:rgba(255,255,255,.02);} .hbd-li.is-map .hbd-li-main b{font-style:italic;}' +
        '.hbd-li-main{flex:1;min-width:0;cursor:pointer;} .hbd-li-main b{display:block;font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
        '.hbd-li-main span{display:block;font-size:10px;color:var(--dim);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
        '.hbd-type{font-style:normal;color:var(--o2);}' +
        '.hbd-edit{background:rgba(0,0,0,.25);padding:4px 6px 6px;margin-bottom:3px;}' +
        '.hbd-dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:5px;vertical-align:0;box-shadow:0 0 0 1px rgba(0,0,0,.5);}' +
        '.hbd-dot-big{width:12px;height:12px;flex:none;}' +
        '.hbd-li{border-left:3px solid transparent;}' +
        '.hbd-mk .hbd-check{flex:none;margin-right:12px;} .hbd-mk .hbd-lbl{width:auto;margin-right:6px;align-self:center;} .hbd-right{margin-left:auto;}' +
        '.hbd-crow{display:flex;align-items:center;gap:3px;padding:2px 0;} .hbd-cname{width:130px;font-size:11px;flex:none;}' +
        '.hbd-sw{width:14px;height:14px;cursor:pointer;box-shadow:inset 0 0 0 1px rgba(0,0,0,.4);} .hbd-sw:hover{transform:scale(1.25);}' +
        '.hbd-sw.is-on{box-shadow:0 0 0 2px #fff;} .hbd-mini{padding:1px 5px;margin-left:4px;}' +
        '.hbd-coords{font-size:9px;color:var(--dim);padding-top:4px;font-family:monospace;}' +
      '</style>' +
      '</div>',
    replace: true,
    link: function (scope, element) {
      'use strict'
      // Die App liegt über dem ganzen Bildschirm: App-Element und BeamNG-Host bleiben immer durchlässig,
      // nur das Fenster selbst (.hbd, pointer-events:auto) nimmt Klicks.
      ;(function () {
        var el = element[0]
        var host = el.closest && el.closest('.ui-app-host')
        while (el) {
          el.style.pointerEvents = 'none'
          if (!host || el === host) break
          el = el.parentElement
        }
      })()

      scope.d = { open: false, places: [], types: [], rivals: [] }
      scope.tabs = [{ id: 'save', name: 'Spielstand' }, { id: 'rivals', name: 'Rivalen' }, { id: 'places', name: 'Orte' }, { id: 'tools', name: 'Werkzeuge' }]
      scope.tab = 'save'
      scope.inp = {}
      scope.q = { rival: '', place: '', type: null }
      scope.nw = { name: '', note: '', type: 'pa', useCam: false }
      scope.edit = { id: null }
      scope.sortNear = true
      scope.ui = { colors: false }
      scope.palette = ['#ff6600', '#ff9a3c', '#ffd400', '#c6ff00', '#3ddc84', '#00e5d4', '#3fa9ff', '#1e40ff', '#9b30ff', '#b07bff', '#ff4fd8', '#ff3b3b', '#ffffff', '#ffe9a8', '#a0a0a0', '#7a7a7a']
      scope.color = function (type) {
        var l = scope.d.types || []
        for (var i = 0; i < l.length; i++) if (l[i].id === type) return l[i].color
        return 'transparent'
      }
      scope.fields = [
        { id: 'money', name: 'Geld (\u00a5)', quick: [{ l: '+1 Mio', v: 1000000 }, { l: '+10 Mio', v: 10000000 }, { l: '\u22121 Mio', v: -1000000 }] },
        { id: 'rep', name: 'Ruf', quick: [{ l: '+100', v: 100 }, { l: '+500', v: 500 }, { l: '\u2212500', v: -500 }] },
        { id: 'wins', name: 'Siege', quick: [{ l: '+1', v: 1 }, { l: '\u22121', v: -1 }] },
        { id: 'losses', name: 'Niederlagen', quick: [{ l: '+1', v: 1 }, { l: '\u22121', v: -1 }] },
        { id: 'day', name: 'Tag', quick: [{ l: '+1', v: 1 }, { l: '\u22121', v: -1 }] }
      ]

      // Fensterposition (verschiebbar am Kopf, wird im Browser-Speicher gemerkt)
      var win = scope.win = { x: 0, y: 0 }
      try { var saved = JSON.parse(localStorage.getItem('hashiriyaDevWin') || 'null'); if (saved) { win.x = saved.x; win.y = saved.y } } catch (e) {}
      function clampWin() {
        var w = window.innerWidth || 1920, h = window.innerHeight || 1080
        if (!win.x && !win.y) { win.x = Math.max(10, w - 560); win.y = 90 }
        win.x = Math.min(Math.max(0, win.x), w - 120); win.y = Math.min(Math.max(0, win.y), h - 60)
      }
      clampWin()
      var drag = null
      scope.dragStart = function (e) {
        if (e.target && e.target.classList.contains('hbd-x')) return
        drag = { mx: e.clientX, my: e.clientY, x: win.x, y: win.y }
        e.preventDefault()
      }
      function onMove(e) {
        if (!drag) return
        scope.$evalAsync(function () { win.x = drag.x + e.clientX - drag.mx; win.y = drag.y + e.clientY - drag.my; clampWin() })
      }
      function onUp() {
        if (!drag) return
        drag = null
        try { localStorage.setItem('hashiriyaDevWin', JSON.stringify(win)) } catch (e) {}
      }
      window.addEventListener('mousemove', onMove)
      window.addEventListener('mouseup', onUp)
      scope.$on('$destroy', function () { window.removeEventListener('mousemove', onMove); window.removeEventListener('mouseup', onUp) })

      // --- Lua -----------------------------------------------------------------------
      function luaStr(s) {
        return '"' + String(s).replace(/[\\"]/g, '\\$&').replace(/[\u0000-\u001f\u007f]/g, function (ch) { return '\\' + ('00' + ch.charCodeAt(0)).slice(-3) }) + '"'
      }
      scope.dev = function (name, arg) {
        var a = arg === undefined ? 'nil' : luaStr(JSON.stringify(arg))
        bngApi.engineLua('if extensions.hashiriyaBattle_devtools then extensions.hashiriyaBattle_devtools.action("' + name + '", ' + a + ') end')
      }
      scope.act = function (action, arg) {
        var a = arg === undefined ? 'nil' : luaStr(arg)
        bngApi.engineLua('if extensions.hashiriyaBattle_core then extensions.hashiriyaBattle_core.uiAction("' + action + '", ' + a + ') end')
        // alte Dev-Aktionen ändern evtl. den Spielstand: danach Zustand neu holen
        setTimeout(function () { bngApi.engineLua('if extensions.hashiriyaBattle_devtools then extensions.hashiriyaBattle_devtools.refresh() end') }, 400)
      }
      scope.close = function () { bngApi.engineLua('if extensions.hashiriyaBattle_devtools then extensions.hashiriyaBattle_devtools.close() end') }
      scope.setTab = function (id) { scope.tab = id; scope.dev('tab', { tab: id }) }

      // --- Spielstand ----------------------------------------------------------------
      function num(v) { var n = parseFloat(String(v || '').replace(/[^0-9.,\-]/g, '').replace(',', '.')); return isNaN(n) ? null : n }
      scope.setVal = function (field) {
        var n = num(scope.inp[field])
        if (n === null) return
        scope.dev('setValue', { field: field, value: n })
        scope.inp[field] = ''
      }
      scope.setHour = function () {
        var n = num(scope.inp.hour)
        if (n === null) return
        scope.dev('setHour', { hour: n })
        scope.inp.hour = ''
      }
      scope.clock = function () {
        var h = scope.d.hour
        if (h === undefined || h === null) return '--:--'
        var hh = Math.floor(h), mm = Math.floor((h - hh) * 60)
        return (hh < 10 ? '0' : '') + hh + ':' + (mm < 10 ? '0' : '') + mm
      }
      scope.levelText = function () {
        var l = (scope.d.save && scope.d.save.levels) || []
        return l.length ? 'LV' + l.join(', ') : 'keine'
      }

      // Zwei-Klick-Bestätigung (4 s)
      var armedKey = null, armTimer = null
      scope.arm = function (k) {
        armedKey = k; clearTimeout(armTimer)
        armTimer = setTimeout(function () { scope.$evalAsync(function () { armedKey = null }) }, 4000)
      }
      scope.armed = function (k) { if (armedKey === k) { armedKey = null; return true } return false }
      scope.isArmed = function (k) { return armedKey === k }

      // --- Rivalen ---------------------------------------------------------------------
      scope.rivalMatches = function () {
        var list = scope.d.rivals || [], q = (scope.q.rival || '').toLowerCase()
        if (!q) return list
        return list.filter(function (r) {
          return r.id.toLowerCase().indexOf(q) >= 0 || String(r.name).toLowerCase().indexOf(q) >= 0 || (r.tag || '').toLowerCase().indexOf(q) >= 0
        })
      }
      scope.defeatedCount = function () { return Object.keys((scope.d.save && scope.d.save.defeated) || {}).length }

      // --- Orte --------------------------------------------------------------------------
      function dist(p) {
        var pl = scope.d.player
        if (!pl || !pl.pos || !p.pos) return null
        var dx = p.pos[0] - pl.pos[0], dy = p.pos[1] - pl.pos[1], dz = p.pos[2] - pl.pos[2]
        return Math.sqrt(dx * dx + dy * dy + dz * dz)
      }
      scope.distText = function (p) {
        var m = dist(p)
        if (m === null) return '?'
        return m < 1000 ? Math.round(m) + ' m' : (m / 1000).toFixed(1) + ' km'
      }
      scope.posText = function () {
        var pl = scope.d.player
        if (!pl || !pl.pos) return ''
        return (pl.freecam ? 'Freecam' : pl.onFoot ? 'zu Fuß' : 'im Auto') + ' \u00b7 ' + Math.round(pl.pos[0]) + ' / ' + Math.round(pl.pos[1])
      }
      scope.coords = function (p) {
        var f = function (a) { return a ? a.map(function (v) { return (+v).toFixed(2) }).join(', ') : '\u2014' }
        return 'pos [' + f(p.pos) + ']  dir [' + f(p.dir) + ']' + (p.id ? '  id ' + p.id : '')
      }
      var placeCache = { key: null, list: [] }
      scope.placeMatches = function () {
        var q = (scope.q.place || '').toLowerCase(), t = scope.q.type
        var list = (scope.d.places || []).filter(function (p) {
          if (t && p.type !== t) return false
          return !q || String(p.name).toLowerCase().indexOf(q) >= 0 || String(p.note || '').toLowerCase().indexOf(q) >= 0 || String(p.typeName).toLowerCase().indexOf(q) >= 0
        })
        if (scope.sortNear && scope.d.player) list.sort(function (a, b) { return (dist(a) || 0) - (dist(b) || 0) })
        // gleiche Liste zurückgeben, solange sich nichts ändert (ng-repeat bleibt ruhig)
        var key = list.map(function (p) { return p.id }).join('|')
        if (key === placeCache.key && placeCache.src === scope.d.places) return placeCache.list
        placeCache = { key: key, list: list, src: scope.d.places }
        return list
      }
      var typeCache = { src: null, list: [] }
      scope.usedTypes = function () {
        if (typeCache.src === scope.d.places) return typeCache.list
        var n = {}
        ;(scope.d.places || []).forEach(function (p) { n[p.type] = (n[p.type] || 0) + 1 })
        typeCache = { src: scope.d.places, list: (scope.d.types || []).filter(function (t) { return n[t.id] }).map(function (t) { return { id: t.id, name: t.name, n: n[t.id] } }) }
        return typeCache.list
      }
      scope.capture = function () {
        scope.dev('capture', { name: scope.nw.name, note: scope.nw.note, type: scope.nw.type, useCam: scope.nw.useCam })
        scope.nw.name = ''; scope.nw.note = ''
      }
      scope.toggleEdit = function (p) {
        if (scope.edit.id === p.id) { scope.edit = { id: null }; return }
        scope.edit = { id: p.id, name: p.name, note: p.note || '', type: p.type }
      }
      scope.saveEdit = function (p) {
        scope.dev('editPlace', { id: p.id, name: scope.edit.name, note: scope.edit.note, type: scope.edit.type })
        scope.edit = { id: null }
      }
      scope.delPlace = function (p) {
        scope.dev('deletePlace', { id: p.id })
        scope.edit = { id: null }
      }

      scope.$on('HashiriyaDev', function (event, msg) {
        scope.$evalAsync(function () {
          if (!msg) return
          if (msg.open === false) { scope.d.open = false; return }
          if (msg.tick) {
            scope.d.player = msg.player
            scope.d.hour = msg.hour
            scope.d.moneyText = msg.moneyText
            scope.d.active = msg.active
            return
          }
          var wasOpen = scope.d.open
          // leere Lua-Tabellen kommen als {} an: Listen absichern
          ;['places', 'types', 'rivals'].forEach(function (k) { if (!Array.isArray(msg[k])) msg[k] = [] })
          msg.markers = msg.markers || {}
          if (msg.save) {
            if (!Array.isArray(msg.save.ranks)) msg.save.ranks = []
            if (!Array.isArray(msg.save.levels)) msg.save.levels = []
          }
          scope.d = msg
          if (!wasOpen) { scope.tab = msg.tab || scope.tab; clampWin() }
        })
      })
    }
  }
}])
