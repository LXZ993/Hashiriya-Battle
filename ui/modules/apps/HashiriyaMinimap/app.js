// Hashiriya Battle: eigene Minimap unten links im HashiNet-Design (ersetzt die BeamNG-App "Navigation").
// Die Karte selbst zeichnet weiterhin BeamNG (Lua-Erweiterung ui_apps_minimap_minimap) genau in das freie
// Feld dieser App: wir melden die Bildschirm-Position mit setDrawTransform(x, y, breite, höhe) (Werte 0..1),
// wie es die Original-App tut. Rahmen, Ortsname und Ziel-Abstand kommen von uns.
// Daten: Stream 'minimap' { locationName, distToTarget, policeMode, visible } (ui_apps_minimap_additionalInfo).
// Achtung: Es kann nur EINE Minimap geben. Die BeamNG-App "Navigation" darf nicht gleichzeitig im Layout sein.
angular.module('beamng.apps')
.directive('hashiriyaMinimap', [function () {
  return {
    template: [
      '<div class="bngApp hbn-root">',
        '<div class="hbn" ng-show="shown" ng-class="{\'hbn-round\': mode === \'circle\', \'hbn-police\': info.policeMode === \'visibleToPolice\'}">',
          '<div class="hbn-top">',
            '<span class="hbn-net">Navi</span>',
            '<span class="hbn-loc">{{ info.locationName || \'\' }}</span>',
            '<span class="hbn-dist" ng-if="info.distToTarget">{{ info.distToTarget }}</span>',
          '</div>',
          '<div class="hbn-map"><div class="hbn-hole"></div></div>',
          '<div class="hbn-pol" ng-if="info.policeMode === \'visibleToPolice\'">{{ tx(\'hud.policeSeen\', \'Police on you\') }}</div>',
          '<div class="hbn-pol hbn-pol-low" ng-if="info.policeMode === \'hiddenFromPolice\'">{{ tx(\'hud.policeLost\', \'Out of sight\') }}</div>',
        '</div>',
        '<style>',
          '.hbn-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;',
            'font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;color:#f4f4f4;}',
          '.hbn{--ac:#ff6600;position:absolute;inset:0;display:flex;flex-direction:column;text-shadow:0 1px 2px rgba(0,0,0,.9);}',
          // schmale Kopfzeile: Navi | Ort ......... Abstand
          '.hbn-top{display:flex;align-items:baseline;gap:8px;height:18px;padding:0 2px 0 8px;border-left:3px solid var(--ac);white-space:nowrap;}',
          '.hbn-net{font-size:10px;font-weight:900;font-style:italic;letter-spacing:2px;text-transform:uppercase;color:var(--ac);}',
          '.hbn-loc{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;font-size:12px;font-weight:700;font-style:italic;text-transform:uppercase;letter-spacing:.3px;}',
          '.hbn-dist{font-size:13px;font-weight:900;font-style:italic;font-variant-numeric:tabular-nums;}',
          // freies Feld: hier zeichnet BeamNG die Karte hinein (Querformat)
          '.hbn-map{position:relative;flex:1;min-height:0;margin-top:4px;display:flex;justify-content:flex-start;}',
          '.hbn-hole{width:100%;height:100%;background:rgba(0,0,0,.28);border-bottom:1px solid rgba(255,102,0,.6);}',
          '.hbn-round .hbn-hole{border-radius:50%;width:auto;aspect-ratio:1/1;border:1px solid rgba(255,102,0,.6);}',
          '.hbn-police .hbn-hole{animation:hbnPolice .7s ease-in-out infinite alternate;}',
          '.hbn-pol{position:absolute;left:8px;bottom:-18px;font-size:11px;font-weight:900;font-style:italic;letter-spacing:1px;text-transform:uppercase;color:#ff5a3c;}',
          '.hbn-pol-low{color:#8fa3bf;}',
          '@keyframes hbnPolice{from{box-shadow:inset 0 0 10px 3px rgba(255,40,40,.9);}to{box-shadow:inset 0 0 10px 3px rgba(40,90,255,.9);}}',
        '</style>',
      '</div>'
    ].join(''),
    replace: true,
    link: function (scope, element) {
      'use strict'
      var strings = {}
      var streamsList = ['minimap']
      var hole = element[0].querySelector('.hbn-hole')
      var last = ''
      var ready = false
      var loading = false
      var cefVisible = true
      var streamVisible = true
      var route = 'play'
      var allowedRoutes = { play: true, '': true }

      scope.info = { locationName: null, distToTarget: null, policeMode: 'disabled' }
      scope.mode = 'rect'
      scope.shown = true
      scope.tx = function (k, fallback) { return strings[k] || fallback || k }
      scope.$on('HashiriyaState', function (e, d) { if (d && d.t) strings = d.t })

      function lua(cmd, cb) { try { bngApi.engineLua(cmd, cb) } catch (e) {} }

      function init(cb) {
        if (ready) { cb(); return }
        if (loading) return
        loading = true
        // mit Rückruf muss es EIN Ausdruck sein (kein ';'), sonst bricht Lua ab
        lua('extensions.load("ui_apps_minimap_minimap", "ui_apps_minimap_additionalInfo")', function () {
          lua('ui_apps_minimap_minimap and ui_apps_minimap_minimap.getMode()', function (m) {
            scope.$evalAsync(function () { scope.mode = m === 'circle' ? 'circle' : 'rect' })
            ready = true
            loading = false
            cb()
          })
        })
      }

      function wanted() { return cefVisible && streamVisible && !!allowedRoutes[route] }

      // Position des freien Feldes an Lua melden (nur wenn sie sich ändert)
      function send(force) {
        scope.shown = wanted()
        init(function () {
          if (!wanted()) {
            if (last !== 'hidden') { lua('if ui_apps_minimap_minimap then ui_apps_minimap_minimap.hide() end'); last = 'hidden' }
            return
          }
          var r = hole.getBoundingClientRect()
          var W = window.innerWidth, H = window.innerHeight
          if (!W || !H || r.width < 4 || r.height < 4) return
          var x = r.left / W, y = r.top / H, w = r.width / W, h = r.height / H
          if (x < 0 || y < 0 || w > 1 || h > 1 || x + w > 1.0001 || y + h > 1.0001) return
          var key = [x, y, w, h].map(function (v) { return v.toFixed(5) }).join(',')
          if (key === last && !force) return
          last = key
          lua('if ui_apps_minimap_minimap then ui_apps_minimap_minimap.setDrawTransform(' + key + ') end')
          lua('if ui_apps_minimap_additionalInfo then ui_apps_minimap_additionalInfo.requestAdditionalInfo() end')
        })
      }

      try { StreamsManager.add(streamsList) } catch (e) {}
      scope.$on('streamsUpdate', function (e, streams) {
        var m = streams && streams.minimap
        if (!m) return
        scope.$evalAsync(function () {
          streamVisible = m.visible !== false
          scope.info.locationName = m.locationName || null
          scope.info.distToTarget = m.distToTarget || null
          scope.info.policeMode = m.policeMode || 'disabled'
        })
      })
      scope.$on('onCefVisibilityChanged', function (e, v) { cefVisible = v !== false; send(true) })
      function routeOf(d) { return (d && ((d.resolved && d.resolved.name) || (d.request && d.request.name) || (d.toRoute && d.toRoute.name))) || '' }
      scope.$on('ui_router_routeChange', function (e, d) { route = routeOf(d); send(true) })
      scope.$on('ui_router_routeRefresh', function (e, d) { route = routeOf(d); send(true) })
      scope.$on('onMinimapSettingsChanged', function () { ready = false; send(true) })

      // Größe/Position kann sich durch den Layout-Editor oder die Fenstergröße ändern
      var ro = null
      try { ro = new ResizeObserver(function () { send() }); ro.observe(hole) } catch (e) {}
      window.addEventListener('resize', send)
      var poll = setInterval(send, 1000)
      setTimeout(function () { send(true) }, 300)

      scope.$on('$destroy', function () {
        clearInterval(poll)
        window.removeEventListener('resize', send)
        if (ro) ro.disconnect()
        try { StreamsManager.remove(streamsList) } catch (e) {}
        lua('if ui_apps_minimap_minimap then ui_apps_minimap_minimap.hide() end')
      })
    }
  }
}]);
