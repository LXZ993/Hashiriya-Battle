// Hashiriya Battle: Antriebs-Steuerung im HashiNet-Design (abgeleitet von der BeamNG-App "Simple Powertrain Control").
// Wie im Original (BeamNG 0.40 ui/modules/apps/SimplePowertrainControl/app.vue):
//   Knöpfe kommen vom Fahrzeug über Hook 'ChangePowerTrainButtons' { id, icon, tooltip, color, ringValue, onClick, remove }
//   und werden mit extensions.ui_simplePowertrainControl.updateButtons() im Fahrzeug angefragt.
//   Klick führt onClick im Fahrzeug aus (bngApi.activeObjectLua). Zündung: gedrückt halten wie im Original
//   (electrics.toggleIgnitionLevelOnDown/OnUp). Stream electrics.ignitionLevel (0 aus, 1 Zündung, 2+ Motor an).
// Aussehen: Karte mit START/STOP-Taste links und schrägen Kacheln für Differenzial-Sperren, 4WD, ESC, N2O usw.
// Der Ring-Wert des Originals ist hier der Balken unten in der Kachel.
angular.module('beamng.apps')
.directive('hashiriyaPowertrain', [function () {
  return {
    template: [
      '<div class="bngApp hbp-root" ng-show="hasIgnition || buttons.length">',
        '<div class="hbp">',
          '<div class="hbp-tip" ng-show="tip">{{ tip }}</div>',
          '<div class="hbp-row">',
            '<div class="hbp-ign" ng-if="hasIgnition" ng-class="{on: ignOn, acc: ignAcc}" ng-mousedown="ignDown()" ng-mouseup="ignUp()" ng-mouseleave="ignLeave()"',
              ' ng-mouseenter="hover(tx(\'hud.ignitionTip\', \'Hold: start / stop engine\'))">',
              '<i class="hbp-led"></i><b>Start</b>',
            '</div>',
            '<div class="hbp-btn" ng-repeat="b in buttons track by b.id" ng-click="click(b)" ng-mouseenter="hover(b.tooltip)" ng-mouseleave="hover(\'\')"',
              ' ng-attr-style="--bc:{{ b.color || \'#f4f4f4\' }}" ng-class="{\'has-color\': b.color && !b.hasRing, \'has-ring\': b.hasRing}">',
              '<svg class="hbp-ico" ng-if="b.hasIcon" viewBox="0 0 36 36"><use ng-attr-href="{{ \'#\' + b.icon }}" width="36" height="36"></use></svg>',
              '<span class="hbp-abbr" ng-if="!b.hasIcon">{{ b.abbr }}</span>',
              '<span class="hbp-ring" ng-if="b.hasRing"><span ng-style="{width: (b.ring * 100) + \'%\'}"></span></span>',
            '</div>',
          '</div>',
        '</div>',
        '<style>',
          '.hbp-root{width:100%;height:100%;background:transparent;box-shadow:none;overflow:visible;pointer-events:none;',
            'font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;color:#f4f4f4;}',
          '.hbp{--ac:#ff6600;position:absolute;left:0;bottom:0;max-width:100%;padding:4px 14px 4px 8px;box-sizing:border-box;',
            'background:linear-gradient(90deg,rgba(10,11,14,.62),rgba(10,11,14,.3) 70%,rgba(10,11,14,0));border-left:3px solid var(--ac);',
            'text-shadow:0 1px 2px rgba(0,0,0,.8);}',
          '.hbp-tip{position:absolute;left:8px;bottom:100%;margin-bottom:3px;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;white-space:nowrap;text-shadow:0 1px 2px #000;}',
          '.hbp-row{display:flex;flex-wrap:wrap;gap:3px;align-items:stretch;}',
          '.hbp-ign,.hbp-btn{pointer-events:auto;cursor:pointer;position:relative;background:rgba(255,255,255,.07);',
            'clip-path:polygon(5px 0,100% 0,calc(100% - 5px) 100%,0 100%);transition:background .15s;}',
          '.hbp-ign:hover,.hbp-btn:hover{background:rgba(255,255,255,.2);}',
          '.hbp-ign{width:44px;height:28px;display:flex;flex-direction:column;align-items:center;justify-content:center;}',
          '.hbp-ign b{font-size:10px;line-height:11px;font-style:italic;font-weight:900;letter-spacing:.5px;text-transform:uppercase;}',
          '.hbp-led{width:14px;height:2px;margin-bottom:3px;background:rgba(255,255,255,.2);}',
          '.hbp-ign.on .hbp-led{background:var(--ac);box-shadow:0 0 5px var(--ac);}',
          '.hbp-ign.acc .hbp-led{animation:hbpLed 2s linear infinite;}',
          '.hbp-btn{width:34px;height:28px;display:flex;align-items:center;justify-content:center;}',
          '.hbp-btn.has-color{background:linear-gradient(0deg,var(--bc) 0 2px,rgba(255,255,255,.07) 2px);}',
          '.hbp-ico{width:22px;height:22px;fill:#f4f4f4;}',
          '.hbp-btn.has-color .hbp-ico{fill:var(--bc);}',
          '.hbp-abbr{font-size:9px;font-weight:900;font-style:italic;text-transform:uppercase;}',
          '.hbp-btn.has-color .hbp-abbr{color:var(--bc);}',
          '.hbp-ring{position:absolute;left:5px;right:5px;bottom:2px;height:2px;background:rgba(255,255,255,.15);}',
          '.hbp-ring span{display:block;height:100%;background:var(--bc);}',
          '@keyframes hbpLed{50%{background:rgba(255,255,255,.15);box-shadow:none;}}',
        '</style>',
      '</div>'
    ].join(''),
    replace: true,
    link: function (scope) {
      'use strict'
      var strings = {}
      var holding = false
      var streamsList = ['electrics', 'powertrainDeviceData']
      scope.buttons = []
      scope.hasIgnition = false
      scope.ignOn = false
      scope.ignAcc = false
      scope.tip = ''
      scope.tx = function (k, fallback) { return strings[k] || fallback || k }
      scope.$on('HashiriyaState', function (e, d) { if (d && d.t) strings = d.t })

      function veh(cmd) { try { bngApi.activeObjectLua(cmd) } catch (e) {} }

      function apply(b, d) {
        var ring = Number(d.ringValue)
        b.hasRing = d.ringValue !== undefined && d.ringValue !== null && isFinite(ring)
        b.ring = b.hasRing ? Math.max(0, Math.min(1, ring)) : 0
        b.icon = d.icon
        // Symbole liegen als SVG-Sprite im Spiel-UI; fehlt eins, zeigen wir eine Abkürzung
        b.hasIcon = !!(d.icon && document.getElementById(d.icon))
        b.abbr = String(d.tooltip || d.id || '').replace(/[^A-Za-z0-9]/g, '').slice(0, 4)
        b.tooltip = d.tooltip || ''
        b.onClick = d.onClick
        b.color = d.color || null
      }

      scope.$on('ChangePowerTrainButtons', function (e, d) {
        if (!d || !d.id) return
        scope.$evalAsync(function () {
          var i = -1
          for (var k = 0; k < scope.buttons.length; k++) if (scope.buttons[k].id === d.id) { i = k; break }
          if (d.remove) { if (i >= 0) scope.buttons.splice(i, 1); scope.tip = ''; return }
          if (i < 0) { var b = { id: d.id }; apply(b, d); scope.buttons.push(b) } else apply(scope.buttons[i], d)
        })
      })

      function requestButtons() { veh('extensions.ui_simplePowertrainControl.updateButtons()') }
      function reset() { scope.$evalAsync(function () { scope.buttons = []; scope.tip = '' }); requestButtons() }
      scope.$on('VehicleChange', reset)
      scope.$on('VehicleFocusChanged', reset)
      requestButtons()

      scope.click = function (b) { if (b.onClick) veh(b.onClick) }
      scope.hover = function (t) { scope.tip = t || '' }
      scope.ignDown = function () { holding = true; veh('electrics.toggleIgnitionLevelOnDown()') }
      scope.ignUp = function () { if (!holding) return; holding = false; veh('electrics.toggleIgnitionLevelOnUp()') }
      scope.ignLeave = function () { scope.ignUp(); scope.tip = '' }

      try { StreamsManager.add(streamsList) } catch (e) {}
      scope.$on('streamsUpdate', function (e, s) {
        var dev = s && s.powertrainDeviceData && s.powertrainDeviceData.devices
        var el = s && s.electrics
        var has = dev ? !!(dev.mainEngine || dev.frontMotor || dev.rearMotor) : scope.hasIgnition
        var lvl = el ? (el.ignitionLevel || 0) : 0
        if (has !== scope.hasIgnition || (lvl > 0) !== scope.ignOn || (lvl === 1) !== scope.ignAcc) {
          scope.$evalAsync(function () { scope.hasIgnition = has; scope.ignOn = lvl > 0; scope.ignAcc = lvl === 1 })
        }
      })
      scope.$on('$destroy', function () {
        if (holding) veh('electrics.toggleIgnitionLevelOnUp()')
        try { StreamsManager.remove(streamsList) } catch (e) {}
      })
    }
  }
}]);
