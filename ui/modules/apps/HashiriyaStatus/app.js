// Hashiriya Battle: kleine Statusanzeige (Geld, Rivale in der Nähe), sichtbar solange der Modus läuft.
// Daten: Hook 'HashiriyaState'.
angular.module('beamng.apps')
.directive('hashiriyaStatus', [function () {
  return {
    template:
      '<div class="bngApp hbt-root">' +
        '<div class="hbt" ng-if="s && s.active">' +
          '<div class="hbt-money">{{ s.money }}</div>' +
          '<div class="hbt-rival" ng-if="s.rival"><i></i>VS <b>{{ s.rival }}</b></div>' +
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
