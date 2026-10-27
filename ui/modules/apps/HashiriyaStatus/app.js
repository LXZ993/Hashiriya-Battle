// Hashiriya Battle: kleine Statusanzeige (Geld, Rivale in der Nähe). Daten: Hook 'HashiriyaState'.
angular.module('beamng.apps')
.directive('hashiriyaStatus', [function () {
  return {
    template:
      '<div class="bngApp" style="width:100%;height:100%;background:transparent;box-shadow:none;">' +
        '<div ng-if="s && s.active" style="background:rgba(8,10,16,0.7);border-right:3px solid #e8352b;color:#fff;' +
          'padding:6px 10px;font-family:sans-serif;text-align:right;">' +
          '<div style="font-size:18px;font-weight:bold;">{{ s.money }}</div>' +
          '<div style="font-size:12px;opacity:.85;" ng-if="s.rival">Rivale: {{ s.rival }}</div>' +
        '</div>' +
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
