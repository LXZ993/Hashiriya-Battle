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
        '<div class="hbn" ng-show="shown" ng-class="{\'hbn-round\': mode === \'circle\', \'hbn-police\': info.policeMode === \'visibleToPolice\', \'hbn-hidden\': info.policeMode === \'hiddenFromPolice\'}">',
          '<div class="hbn-head">',
            '<span class="hbn-net">Hashiriya</span><span class="hbn-title">{{ tx(\'hud.navi\', \'Navi\') }}</span>',
          '</div>',
          '<div class="hbn-loc">{{ info.locationName || \' \' }}</div>',
          '<div class="hbn-map"><div class="hbn-hole"></div>',
            '<i class="hbn-c hbn-c1"></i><i class="hbn-c hbn-c2"></i><i class="hbn-c hbn-c3"></i><i class="hbn-c hbn-c4"></i>',
          '</div>',
          '<div class="hbn-foot">',
            '<span class="hbn-pol" ng-if="info.policeMode === \'visibleToPolice\'">{{ tx(\'hud.policeSeen\', \'Police on you\') }}</span>',
            '<span class="hbn-pol hbn-pol-low" ng-if="info.policeMode === \'hiddenFromPolice\'">{{ tx(\'hud.policeLost\', \'Out of sight\') }}</span>',
            '<span class="hbn-fill"></span>',
            '<span class="hbn-dist" ng-if="info.distToTarget"><small>{{ tx(\'hud.target\', \'Target\') }}</small> {{ info.distToTarget }}</span>',
          '</div>',
        '</div>',
        '<style>',
          '.hbn-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;',
            'font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;color:#f4f4f4;}',
          '.hbn{--ac:#ff6600;position:absolute;inset:0;display:flex;flex-direction:column;box-sizing:border-box;padding:8px 14px 0 14px;',
            'background:linear-gradient(180deg,rgba(14,15,18,.92),rgba(14,15,18,.82));border-left:4px solid var(--ac);',
            'box-shadow:0 8px 28px rgba(0,0,0,.55);text-shadow:0 1px 2px rgba(0,0,0,.7);',
            'clip-path:polygon(0 0,calc(100% - 14px) 0,100% 14px,100% 100%,0 100%);animation:hbnIn .5s cubic-bezier(.2,.9,.25,1) both;}',
          '.hbn-head{display:flex;align-items:baseline;gap:9px;font-size:10px;letter-spacing:2.4px;text-transform:uppercase;}',
          '.hbn-net{font-weight:900;font-style:italic;color:var(--ac);}',
          '.hbn-title{font-weight:700;color:rgba(244,244,244,.65);}',
          '.hbn-loc{font-size:14px;font-weight:900;font-style:italic;text-transform:uppercase;letter-spacing:.3px;line-height:17px;',
            'margin:2px 0 7px;max-height:34px;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;}',
          '.hbn-map{position:relative;flex:1;min-height:0;display:flex;align-items:center;justify-content:center;}',
          // freies Feld: hier zeichnet BeamNG die Karte hinein
          '.hbn-hole{width:100%;height:100%;background:rgba(0,0,0,.35);box-shadow:inset 0 0 12px rgba(0,0,0,.7);}',
          '.hbn-round .hbn-hole{border-radius:50%;width:auto;height:100%;aspect-ratio:1/1;max-width:100%;}',
          '.hbn-c{position:absolute;width:10px;height:10px;border-color:var(--ac);border-style:solid;border-width:0;opacity:.85;}',
          '.hbn-c1{left:-2px;top:-2px;border-left-width:2px;border-top-width:2px;}',
          '.hbn-c2{right:-2px;top:-2px;border-right-width:2px;border-top-width:2px;}',
          '.hbn-c3{left:-2px;bottom:-2px;border-left-width:2px;border-bottom-width:2px;}',
          '.hbn-c4{right:-2px;bottom:-2px;border-right-width:2px;border-bottom-width:2px;}',
          '.hbn-round .hbn-c{display:none;}',
          '.hbn-foot{display:flex;align-items:center;gap:8px;height:26px;font-size:12px;letter-spacing:1px;}',
          '.hbn-fill{flex:1;}',
          '.hbn-dist{font-style:italic;font-weight:900;font-size:15px;font-variant-numeric:tabular-nums;}',
          '.hbn-dist small{font-size:10px;font-weight:700;letter-spacing:1.6px;text-transform:uppercase;color:rgba(244,244,244,.55);font-style:normal;margin-right:4px;}',
          '.hbn-pol{font-weight:900;font-style:italic;text-transform:uppercase;color:#ff5a3c;animation:hbnBlink .7s ease-in-out infinite alternate;}',
          '.hbn-pol-low{color:#8fa3bf;animation-duration:1.4s;}',
          '.hbn-police{animation:hbnIn .5s both,hbnPolice .7s ease-in-out infinite alternate;}',
          '@keyframes hbnIn{from{opacity:0;transform:translateX(-30px);}to{opacity:1;transform:none;}}',
          '@keyframes hbnBlink{from{opacity:1;}to{opacity:.35;}}',
          '@keyframes hbnPolice{from{border-left-color:#ff2a2a;}to{border-left-color:#2a5bff;}}',
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
        lua('extensions.load("ui_apps_minimap_minimap"); extensions.load("ui_apps_minimap_additionalInfo")', function () {
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
