// Release-Platzhalter für das Dev-Menü: zeigt nichts und fängt keine Klicks ab.
// Alte HUD-Layouts aus der Entwicklung enthalten das Dev-Menü noch (Vollbild, ganz oben).
// BeamNG legt jede App in einen Host (.ui-app-host), der Klicks abfängt, solange die App
// in app.json nicht "interactive": "no" ist. Darum: interactive "no" in app.json und hier
// zur Sicherheit pointer-events:none bis einschließlich zum eigenen Host, nie darüber hinaus.
angular.module('beamng.apps')
.directive('hashiriyaDev', [function () {
  return {
    template: '<div style="display:none"></div>',
    replace: true,
    link: function (scope, element) {
      var el = element[0]
      var host = el.closest && el.closest('.ui-app-host')
      while (el) {
        el.style.pointerEvents = 'none'
        if (!host || el === host) break
        el = el.parentElement
      }
    }
  }
}])
