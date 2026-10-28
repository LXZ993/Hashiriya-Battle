// Hashiriya Battle: kleine Statusanzeige (Geld, Rivale in der Nähe, nächster Parkplatz), sichtbar solange der Modus läuft.
// Daten: Hook 'HashiriyaState'.
angular.module('beamng.apps')
.directive('hashiriyaStatus', [function () {
  return {
    template:
      '<div class="bngApp hbt-root">' +
        '<div class="hbt" ng-if="s && s.active">' +
          '<div class="hbt-clock" ng-if="s.clock"><span class="hbt-clock-time" ng-class="{\'is-night\': s.clock.night}">{{ s.clock.time }}</span>' +
            '<span class="hbt-clock-date"><b>{{ s.clock.weekday }}</b> {{ s.clock.date }}</span></div>' +
          '<div class="hbt-money">{{ s.money }}</div>' +
          '<div class="hbt-streak" ng-if="s.style && s.style.streak >= 2">{{ s.t[\'hud.streak\'] }} <b>{{ s.style.streak }}</b></div>' +
          '<div class="hbt-combo" ng-if="s.style && s.style.combo">' +
            '<div class="hbt-combo-label" ng-if="s.style.combo.label">{{ s.style.combo.label }} <span>+{{ s.style.combo.labelPts }}</span></div>' +
            '<div class="hbt-combo-main"><span class="hbt-combo-tag">{{ s.t[\'hud.combo\'] }}</span>' +
              '<b>{{ s.style.combo.points }}</b><i>{{ s.style.combo.mult }}</i></div>' +
            '<div class="hbt-combo-bar"><span ng-style="{width: s.style.combo.left + \'%\'}"></span></div>' +
          '</div>' +
          '<div class="hbt-bank" ng-if="s.style && s.style.banked && !s.style.combo" ng-class="{\'is-lost\': s.style.banked.lost}">' +
            '<span ng-if="!s.style.banked.lost">+{{ s.style.banked.yen }}<em ng-if="s.style.banked.rep > 0"> · +{{ s.style.banked.rep }} REP</em></span>' +
            '<span ng-if="s.style.banked.lost">{{ s.t[\'hud.comboLost\'] }}</span>' +
          '</div>' +
          '<div class="hbt-rival" ng-if="s.rival" ng-class="\'k-\' + s.rivalKind"><i></i>VS <b>{{ s.rival }}</b></div>' +
          '<div class="hbt-radar" ng-if="s.radar">' +
            '<span class="hbt-radar-me"></span>' +
            '<span class="hbt-radar-dot" ng-repeat="r in s.radar.list" ng-class="[\'k-\' + r.kind, {\'is-edge\': r.edge, \'is-engaged\': r.engaged}]"' +
              ' ng-style="{left: (50 + r.x * 46) + \'%\', top: (50 - r.y * 46) + \'%\', transform: \'translate(-50%,-50%) rotate(\' + r.heading + \'deg)\'}">' +
              '<svg viewBox="0 0 12 12"><path d="M6 0.5 L11 11 L6 8.4 L1 11 Z"/></svg></span>' +
            '<span class="hbt-radar-dist" ng-if="s.radar.near">{{ s.radar.near.dist }}</span>' +
          '</div>' +
          '<div class="hbt-pa" ng-if="s.nav && !s.nav.arrived && !(s.battle && s.battle.state !== \'idle\')" ng-class="\'hbt-pa-\' + s.nav.type">' +
            '<span class="hbt-pa-tag">PA</span>' +
            '<span class="hbt-pa-name">{{ s.nav.name }}</span>' +
            '<span class="hbt-pa-stop" ng-if="s.nav.inside">{{ s.t[\'hud.stopHere\'] }}</span>' +
            '<span class="hbt-pa-dist" ng-if="!s.nav.inside">{{ s.nav.distText }}</span>' +
            '<span class="hbt-pa-dir" ng-if="!s.nav.inside"><svg viewBox="0 0 12 12" ng-style="{transform: \'rotate(\' + s.nav.angle + \'deg)\'}">' +
              '<path d="M6 1 L10.5 10 L6 7.6 L1.5 10 Z"/></svg></span>' +
          '</div>' +
        '</div>' +
        '<style>' +
          '.hbt-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;}' +
          '.hbt{float:right;font-family:"Overpass","Noto Sans","Segoe UI",sans-serif;color:#f4f4f4;text-align:right;' +
            'padding:6px 14px 6px 22px;background:linear-gradient(270deg,rgba(18,18,20,.85),rgba(18,18,20,.55) 70%,rgba(18,18,20,0));' +
            'border-right:3px solid #ff6600;text-shadow:0 1px 2px rgba(0,0,0,.8);}' +
          '.hbt-money{font-size:20px;font-weight:900;font-style:italic;font-variant-numeric:tabular-nums;letter-spacing:.5px;}' +
          '.hbt-rival{font-size:11px;letter-spacing:1px;color:rgba(244,244,244,.7);margin-top:1px;}' +
          '.hbt-rival b{color:#ff9a3c;font-weight:700;}' +
          '.hbt-rival i{display:inline-block;width:6px;height:6px;border-radius:50%;background:#ff6600;margin-right:6px;' +
            'animation:hbtPing 1s ease-in-out infinite alternate;}' +
          '.hbt-pa{--c:#ff6600;display:flex;align-items:center;justify-content:flex-end;gap:7px;margin-top:5px;padding-top:5px;' +
            'border-top:1px solid rgba(255,255,255,.12);font-size:11px;letter-spacing:1.2px;text-transform:uppercase;white-space:nowrap;}' +
          '.hbt-pa-shop{--c:#3fb6ff;}' +
          '.hbt-pa-gas{--c:#5ae673;}' +
          '.hbt-pa-tag{font-size:9px;font-weight:900;font-style:italic;color:#141414;background:var(--c);padding:1px 4px 0;border-radius:2px;letter-spacing:.5px;}' +
          '.hbt-pa-name{font-weight:700;color:#f4f4f4;}' +
          '.hbt-pa-dist{font-variant-numeric:tabular-nums;color:rgba(244,244,244,.65);min-width:46px;}' +
          '.hbt-pa-dir{display:inline-block;width:12px;height:12px;}' +
          '.hbt-pa-dir svg{width:12px;height:12px;fill:var(--c);transition:transform .1s linear;display:block;}' +
          '.hbt-pa-stop{font-weight:800;color:var(--c);animation:hbtPing .6s ease-in-out infinite alternate;}' +
          '.hbt{--k-rival:#ff6600;--k-leader:#ffd23f;--k-wanderer:#b98cff;--k-boss:#ff3b30;--k-beaten:#9e9e9e;--k-lost:#3fa9ff;}' +
          '.hbt-rival.k-leader i{background:var(--k-leader);} .hbt-rival.k-leader b{color:var(--k-leader);}' +
          '.hbt-rival.k-wanderer i{background:var(--k-wanderer);} .hbt-rival.k-wanderer b{color:var(--k-wanderer);}' +
          '.hbt-rival.k-boss i{background:var(--k-boss);} .hbt-rival.k-boss b{color:var(--k-boss);}' +
          '.hbt-rival.k-beaten i{background:var(--k-beaten);} .hbt-rival.k-beaten b{color:var(--k-beaten);}' +
          '.hbt-rival.k-lost i{background:var(--k-lost);} .hbt-rival.k-lost b{color:var(--k-lost);}' +
          '.hbt-radar{position:relative;width:96px;height:96px;margin:6px 0 14px auto;border-radius:50%;' +
            'background:radial-gradient(circle,rgba(255,255,255,.06) 0 33%,transparent 33.5% 66%,rgba(255,255,255,.04) 66.5%),rgba(14,14,16,.6);' +
            'border:1px solid rgba(255,255,255,.14);}' +
          '.hbt-radar-me{position:absolute;left:50%;top:50%;width:6px;height:6px;margin:-3px 0 0 -3px;background:#f4f4f4;border-radius:50%;}' +
          '.hbt-radar-dot{position:absolute;width:11px;height:11px;}' +
          '.hbt-radar-dot svg{width:11px;height:11px;display:block;fill:var(--k-rival);filter:drop-shadow(0 0 2px rgba(0,0,0,.9));}' +
          '.hbt-radar-dot.k-leader svg{fill:var(--k-leader);} .hbt-radar-dot.k-wanderer svg{fill:var(--k-wanderer);}' +
          '.hbt-radar-dot.k-boss svg{fill:var(--k-boss);} .hbt-radar-dot.k-beaten svg{fill:var(--k-beaten);} .hbt-radar-dot.k-lost svg{fill:var(--k-lost);}' +
          '.hbt-radar-dot.is-edge{opacity:.6;}' +
          '.hbt-radar-dot.is-engaged svg{animation:hbtPing .4s ease-in-out infinite alternate;}' +
          '.hbt-radar-dist{position:absolute;left:0;right:0;bottom:-14px;text-align:center;font-size:9px;letter-spacing:1px;color:rgba(244,244,244,.6);}' +
          '.hbt-clock{display:flex;align-items:baseline;justify-content:flex-end;gap:8px;margin-bottom:2px;}' +
          '.hbt-clock-time{font-size:15px;font-weight:900;font-style:italic;font-variant-numeric:tabular-nums;letter-spacing:.5px;color:#ffd23f;}' +
          '.hbt-clock-time.is-night{color:#8fb8ff;}' +
          '.hbt-clock-date{font-size:10px;letter-spacing:1px;color:rgba(244,244,244,.65);font-variant-numeric:tabular-nums;}' +
          '.hbt-clock-date b{color:#f4f4f4;font-weight:800;text-transform:uppercase;margin-right:2px;}' +
          '.hbt-streak{font-size:10px;letter-spacing:1.5px;text-transform:uppercase;color:rgba(244,244,244,.65);margin-top:1px;}' +
          '.hbt-streak b{color:#ffd23f;font-weight:900;font-style:italic;font-size:12px;}' +
          '.hbt-combo{margin-top:5px;padding-top:5px;border-top:1px solid rgba(255,255,255,.12);}' +
          '.hbt-combo-label{font-size:11px;font-weight:800;font-style:italic;letter-spacing:1px;text-transform:uppercase;color:#ff9a3c;' +
            'animation:hbtPop .25s ease-out;}' +
          '.hbt-combo-label span{color:#f4f4f4;font-weight:700;}' +
          '.hbt-combo-main{display:flex;align-items:baseline;justify-content:flex-end;gap:6px;}' +
          '.hbt-combo-tag{font-size:9px;font-weight:900;font-style:italic;color:#141414;background:#ff6600;padding:1px 4px 0;border-radius:2px;letter-spacing:.5px;text-transform:uppercase;}' +
          '.hbt-combo-main b{font-size:18px;font-weight:900;font-style:italic;font-variant-numeric:tabular-nums;}' +
          '.hbt-combo-main i{font-size:13px;font-weight:800;color:#ffd23f;}' +
          '.hbt-combo-bar{height:2px;margin-top:3px;background:rgba(255,255,255,.12);}' +
          '.hbt-combo-bar span{display:block;height:100%;margin-left:auto;background:#ff6600;transition:width .1s linear;}' +
          '.hbt-bank{margin-top:5px;font-size:13px;font-weight:900;font-style:italic;color:#5ae673;font-variant-numeric:tabular-nums;animation:hbtPop .25s ease-out;}' +
          '.hbt-bank em{font-style:italic;color:#ffd23f;font-size:11px;}' +
          '.hbt-bank.is-lost{color:#ff3b30;font-size:11px;letter-spacing:1px;text-transform:uppercase;}' +
          '@keyframes hbtPop{from{transform:scale(1.25);opacity:0;}to{transform:scale(1);opacity:1;}}' +
          '@keyframes hbtPing{from{opacity:1;}to{opacity:.25;}}' +
        '</style>' +
      '</div>',
    replace: true,
    link: function (scope) {
      'use strict'
      scope.s = null
      scope.$on('HashiriyaState', function (event, data) {
        scope.$evalAsync(function () { scope.s = data })
      })
    }
  }
}]);
