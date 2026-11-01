// Release-Platzhalter für den Builder: zeigt nichts und fängt keine Klicks ab.
// Alte HUD-Layouts aus der Entwicklung enthalten den Builder noch (Vollbild); ohne diese App
// zeigt BeamNG dort "Unknown app" über den ganzen Bildschirm.
angular.module('beamng.apps')
.directive('hashiriyaBuilder', [function () {
  return {
    template: '<div style="display:none"></div>',
    replace: true,
    link: function (scope, element) {
      var el = element[0]
      for (var i = 0; i < 4 && el; i++) { el.style.pointerEvents = 'none'; el = el.parentElement }
    }
  }
}])
