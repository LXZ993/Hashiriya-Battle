// Hashiriya Battle: kleine Statusanzeige (Geld, Rivale in der Nähe, nächster Parkplatz), sichtbar solange der Modus läuft.
// Daten: Hook 'HashiriyaState'.
angular.module('beamng.apps')
.directive('hashiriyaStatus', [function () {
  return {
    template:
      '<div class="bngApp hbt-root">' +
        '<div class="hbt" ng-if="s && s.active">' +
          '<div class="hbt-money">{{ s.money }}</div>' +
          '<div class="hbt-rival" ng-if="s.rival"><i></i>VS <b>{{ s.rival }}</b></div>' +
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
