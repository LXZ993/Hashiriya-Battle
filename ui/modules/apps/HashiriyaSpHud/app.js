// Hashiriya Battle: SP-Balken im Battle. Daten: Hook 'HashiriyaState' (battle = battle.lua getHudState()).
angular.module('beamng.apps')
.directive('hashiriyaSpHud', [function () {
  return {
    template:
      '<div class="bngApp" style="width:100%;height:100%;background:transparent;box-shadow:none;">' +
        '<div ng-if="b" class="hbs">' +
          '<div class="hbs-line">' +
            '<span class="hbs-name">DU</span>' +
            '<div class="hbs-bar"><div class="hbs-fill hbs-blue" ng-style="{width: pct(b.playerSp, b.playerMaxSp)}"></div></div>' +
            '<span class="hbs-num">{{ b.playerSp }}</span>' +
          '</div>' +
          '<div class="hbs-line">' +
            '<span class="hbs-name">{{ b.rivalName }}</span>' +
            '<div class="hbs-bar"><div class="hbs-fill hbs-red" ng-style="{width: pct(b.rivalSp, b.rivalMaxSp)}"></div></div>' +
            '<span class="hbs-num">{{ b.rivalSp }}</span>' +
          '</div>' +
          '<div class="hbs-info" ng-if="b.state == \'countdown\'">START IN {{ b.countdown }}</div>' +
          '<div class="hbs-info" ng-if="b.state == \'battle\'">{{ b.gap > 0 ? \'-\' : \'+\' }}{{ abs(b.gap) }} m</div>' +
          '<div class="hbs-info hbs-result" ng-if="b.state == \'result\'">{{ b.won ? \'SIEG!\' : \'NIEDERLAGE\' }}</div>' +
        '</div>' +
        '<style>' +
          '.hbs{background:rgba(8,10,16,0.7);padding:8px 12px;font-family:sans-serif;color:#fff;}' +
          '.hbs-line{display:flex;align-items:center;margin:3px 0;}' +
          '.hbs-name{width:140px;font-size:13px;font-weight:bold;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbs-bar{flex:1;height:14px;background:rgba(255,255,255,0.12);margin:0 8px;}' +
          '.hbs-fill{height:100%;transition:width .1s linear;}' +
          '.hbs-blue{background:#2f8fff;} .hbs-red{background:#e8352b;}' +
          '.hbs-num{width:44px;text-align:right;font-size:13px;}' +
          '.hbs-info{text-align:center;font-size:16px;font-weight:bold;margin-top:4px;letter-spacing:2px;}' +
          '.hbs-result{font-size:22px;color:#ffd23f;}' +
        '</style>' +
      '</div>',
    replace: true,
    link: function (scope) {
      'use strict'
      scope.b = null
      scope.abs = Math.abs
      scope.pct = function (v, max) { return Math.max(0, Math.min(100, (v / (max || 1)) * 100)) + '%' }
      scope.$on('HashiriyaState', function (event, data) {
        scope.$evalAsync(function () { scope.b = (data && data.battle) || null })
      })
    }
  }
}]);
