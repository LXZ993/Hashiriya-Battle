// Hashiriya Battle: Hauptmenü als UI-App. Zustand kommt per Hook 'HashiriyaState' aus core.lua,
// Klicks gehen per hashiriyaBattle_core.uiAction(...) zurück.
angular.module('beamng.apps')
.directive('hashiriyaMenu', [function () {
  return {
    template:
      '<div class="bngApp" style="width:100%;height:100%;background:transparent;box-shadow:none;">' +
        '<div ng-if="s && s.menuVisible" class="hb-panel">' +
          '<div class="hb-title">HASHIRIYA BATTLE</div>' +
          '<div ng-if="s.screen == \'start\'">' +
            '<button class="hb-btn" ng-click="act(\'newGame\')">Neues Spiel</button>' +
            '<button class="hb-btn" ng-if="s.hasSave" ng-click="act(\'continue\')">Weiter</button>' +
            '<button class="hb-btn hb-dim" ng-click="act(\'hide\')">Ausblenden (Pos1)</button>' +
          '</div>' +
          '<div ng-if="s.screen == \'carSelect\'">' +
            '<div class="hb-sub">Wähle dein erstes Auto</div>' +
            '<button class="hb-btn" ng-repeat="car in s.cars" ng-click="act(\'chooseCar\', car.id)">' +
              '{{ car.name }}<span class="hb-price">{{ car.price }}</span></button>' +
            '<button class="hb-btn hb-dim" ng-click="act(\'back\')">Zurück</button>' +
          '</div>' +
          '<div ng-if="s.screen == \'status\'">' +
            '<div class="hb-row"><span>Geld</span><b>{{ s.money }}</b></div>' +
            '<div class="hb-row"><span>Siege / Niederlagen</span><b>{{ s.wins }} / {{ s.losses }}</b></div>' +
            '<div class="hb-row"><span>Rivale in der Nähe</span><b>{{ s.rival || \'-\' }}</b></div>' +
            '<button class="hb-btn" ng-click="act(\'callRival\')">Rivale rufen (Test)</button>' +
            '<button class="hb-btn" ng-click="act(\'capture\')">Position merken</button>' +
            '<button class="hb-btn" ng-click="act(\'save\')">Speichern</button>' +
            '<button class="hb-btn hb-dim" ng-click="act(\'stop\')">Modus beenden</button>' +
            '<button class="hb-btn hb-dim" ng-click="act(\'hide\')">Ausblenden (Pos1)</button>' +
          '</div>' +
        '</div>' +
        '<style>' +
          '.hb-panel{background:rgba(8,10,16,0.85);border-left:3px solid #e8352b;color:#eef1f4;padding:12px 14px;font-family:sans-serif;}' +
          '.hb-title{font-size:20px;font-weight:bold;letter-spacing:3px;margin-bottom:10px;color:#fff;}' +
          '.hb-sub{font-size:13px;opacity:.8;margin-bottom:6px;}' +
          '.hb-btn{display:block;width:100%;margin:4px 0;padding:8px 10px;text-align:left;background:rgba(255,255,255,0.08);' +
            'color:#eef1f4;border:1px solid rgba(255,255,255,0.15);font-size:14px;cursor:pointer;}' +
          '.hb-btn:hover{background:#e8352b;border-color:#e8352b;}' +
          '.hb-dim{opacity:.7;}' +
          '.hb-price{float:right;opacity:.85;}' +
          '.hb-row{display:flex;justify-content:space-between;font-size:14px;margin:3px 0;}' +
        '</style>' +
      '</div>',
    replace: true,
    link: function (scope) {
      'use strict'
      scope.s = null
      scope.act = function (action, arg) {
        var a = arg === undefined ? 'nil' : JSON.stringify(String(arg))
        bngApi.engineLua('if extensions.hashiriyaBattle_core then extensions.hashiriyaBattle_core.uiAction("' + action + '", ' + a + ') end')
      }
      scope.$on('HashiriyaState', function (event, data) {
        scope.$evalAsync(function () { scope.s = data })
      })
    }
  }
}]);
