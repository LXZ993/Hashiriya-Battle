// Hashiriya Battle: Eintrag im BeamNG-Hauptmenü.
// BeamNG lädt jedes ui/modModules/<name>/<name>.js beim UI-Start und hängt das Angular-Modul <name>
// an die Haupt-App. Das Hauptmenü verteilt 'MainMenuButtons' mit einer addButton-Funktion.
angular.module('hashiriyaBattle', [])
.run(['$rootScope', function ($rootScope) {
  $rootScope.$on('MainMenuButtons', function (event, addButton) {
    try {
      addButton({
        title: 'Hashiriya Battle',
        iconId: 'flag',
        action: function () {
          bngApi.engineLua('if extensions.hashiriyaBattle_career then extensions.hashiriyaBattle_career.startFromMainMenu() end')
        }
      })
    } catch (e) {
      console.error('Hashiriya Battle: Hauptmenü-Eintrag fehlgeschlagen', e)
    }
  })
}])
