// Hashiriya Battle: SP-Anzeige im Stil der TXR-Reihe (zwei Balken, Mitte "SP"), in BeamNG-Farben.
// Daten: Hook 'HashiriyaState' (battle = battle.lua getHudState()).
angular.module('beamng.apps')
.directive('hashiriyaSpHud', [function () {
  return {
    template:
      '<div class="bngApp" style="width:100%;height:100%;background:transparent;box-shadow:none;">' +
        '<div ng-if="b" class="hbs">' +
          '<div class="hbs-top">' +
            '<div class="hbs-side hbs-left">' +
              '<span class="hbs-badge">DU</span>' +
              '<span class="hbs-car">{{ b.playerCar }}</span>' +
            '</div>' +
            '<div class="hbs-timer">{{ fmtTime(b.time) }}</div>' +
            '<div class="hbs-side hbs-right">' +
              '<span class="hbs-car">{{ b.rivalCar }}</span>' +
              '<span class="hbs-badge hbs-badge-rival">{{ b.rivalTag }}</span>' +
            '</div>' +
          '</div>' +
          '<div class="hbs-bars">' +
            '<div class="hbs-track hbs-track-l"><div class="hbs-fill hbs-fill-l" ng-class="{\'hbs-low\': low(b.playerSp, b.playerMaxSp)}" ng-style="{width: pct(b.playerSp, b.playerMaxSp)}"></div></div>' +
            '<div class="hbs-sp">SP</div>' +
            '<div class="hbs-track hbs-track-r"><div class="hbs-fill hbs-fill-r" ng-class="{\'hbs-low\': low(b.rivalSp, b.rivalMaxSp)}" ng-style="{width: pct(b.rivalSp, b.rivalMaxSp)}"></div></div>' +
          '</div>' +
          '<div class="hbs-bottom">' +
            '<span class="hbs-title">{{ b.playerTitle }}</span>' +
            '<span class="hbs-gap" ng-if="b.state == \'battle\'" ng-class="{\'hbs-lead\': b.gap < 0}">' +
              '{{ b.gap < 0 ? \'VORNE\' : \'HINTEN\' }} {{ abs(b.gap) }} m</span>' +
            '<span class="hbs-title">{{ b.rivalName }}</span>' +
          '</div>' +
          '<div class="hbs-big" ng-if="b.state == \'countdown\'">{{ b.countdown }}</div>' +
          '<div class="hbs-big hbs-result" ng-if="b.state == \'result\'" ng-class="{\'hbs-lose\': !b.won}">{{ b.won ? \'YOU WIN\' : \'YOU LOSE\' }}</div>' +
        '</div>' +
        '<style>' +
          '.hbs{font-family:"Overpass","Noto Sans",sans-serif;color:#fff;padding:6px 14px 4px;' +
            'background:linear-gradient(to bottom, rgba(20,20,22,0.75), rgba(20,20,22,0));text-shadow:0 1px 2px rgba(0,0,0,.8);}' +
          '.hbs-top{display:flex;align-items:center;justify-content:space-between;height:26px;}' +
          '.hbs-side{display:flex;align-items:center;gap:8px;width:42%;}' +
          '.hbs-right{justify-content:flex-end;}' +
          '.hbs-badge{font-size:11px;font-weight:bold;border:2px solid #fff;border-radius:50%;width:36px;height:22px;line-height:18px;text-align:center;}' +
          '.hbs-badge-rival{border-color:#ff6600;color:#ff6600;}' +
          '.hbs-car{font-size:13px;font-weight:600;letter-spacing:.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbs-timer{font-size:20px;font-style:italic;font-weight:bold;letter-spacing:1px;font-variant-numeric:tabular-nums;}' +
          '.hbs-bars{display:flex;align-items:center;margin-top:3px;}' +
          '.hbs-track{flex:1;height:9px;background:rgba(255,255,255,0.12);border:1px solid rgba(255,255,255,0.35);display:flex;}' +
          '.hbs-track-l{justify-content:flex-end;} .hbs-track-r{justify-content:flex-start;}' +
          '.hbs-fill{height:100%;transition:width .12s linear;}' +
          '.hbs-fill-l{background:linear-gradient(to left,#ffb066,#ff6600 60%,#c94d00);}' +
          '.hbs-fill-r{background:linear-gradient(to right,#ffb066,#ff6600 60%,#c94d00);}' +
          '.hbs-low{background:#ff2a1a !important;animation:hbsBlink .5s steps(2) infinite;}' +
          '@keyframes hbsBlink{50%{opacity:.35;}}' +
          '.hbs-sp{font-size:15px;font-weight:900;font-style:italic;margin:0 10px;letter-spacing:1px;}' +
          '.hbs-bottom{display:flex;justify-content:space-between;align-items:center;margin-top:3px;font-size:12px;}' +
          '.hbs-title{opacity:.9;}' +
          '.hbs-gap{font-weight:bold;color:#ff8a3d;letter-spacing:1px;} .hbs-lead{color:#7fdc6f;}' +
          '.hbs-big{text-align:center;font-size:44px;font-weight:900;font-style:italic;color:#ff6600;margin-top:6px;}' +
          '.hbs-result{color:#ffd23f;} .hbs-lose{color:#ff3b30;}' +
        '</style>' +
      '</div>',
    replace: true,
    link: function (scope) {
      'use strict'
      scope.b = null
      scope.abs = Math.abs
      scope.pct = function (v, max) { return Math.max(0, Math.min(100, (v / (max || 1)) * 100)) + '%' }
      scope.low = function (v, max) { return v / (max || 1) < 0.2 }
      scope.fmtTime = function (t) {
        t = t || 0
        var m = Math.floor(t / 60), s = Math.floor(t % 60), ms = Math.floor((t * 1000) % 1000)
        var pad = function (n, l) { n = String(n); while (n.length < l) n = '0' + n; return n }
        return pad(m, 2) + '\'' + pad(s, 2) + '"' + pad(ms, 3)
      }
      scope.$on('HashiriyaState', function (event, data) {
        scope.$evalAsync(function () { scope.b = (data && data.battle) || null })
      })
    }
  }
}]);
