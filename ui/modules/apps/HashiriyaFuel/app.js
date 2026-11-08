// Hashiriya Battle: Tankanzeige als waagerechter Balken im Stil der Ladedruck-Anzeige (HashiriyaBoost).
// Daten wie im BeamNG-Original (0.40 ui/modules/apps/Tacho2): engineInfo[11] = Tankinhalt jetzt, [12] = Tank voll (Liter).
// Einheit über UiUnits.volume (Liter oder Gallonen, wie im Spiel eingestellt), sonst Liter.
// Farben: weiß, unter LOW orange, unter EMPTY rot blinkend. Ohne Tank (z. B. E-Auto ohne Kraftstoff) blendet die App aus.
angular.module('beamng.apps')
.directive('hashiriyaFuel', [function () {
  var LOW = 0.25, EMPTY = 0.1

  return {
    template: [
      '<div class="bngApp hxf-root is-off">',
        '<div class="hxf">',
          '<div class="hxf-val"><span class="hxf-net">Tank</span><b class="hxf-num">0</b><small class="hxf-cap">/ 0</small><small class="hxf-unit">L</small></div>',
          '<div class="hxf-bar">',
            '<span class="hxf-red"></span><span class="hxf-fill"></span>',
          '</div>',
          '<div class="hxf-scale"><span>E</span><span>½</span><span>F</span></div>',
        '</div>',
        '<style>',
          '.hxf-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;transition:opacity .25s;',
            'font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;color:#f4f4f4;}',
          '.hxf-root.is-off{opacity:0;}',
          '.hxf{--ac:#ff6600;position:absolute;left:0;right:0;bottom:0;padding:3px 14px 5px 8px;box-sizing:border-box;',
            'background:linear-gradient(90deg,rgba(10,11,14,.62),rgba(10,11,14,.3) 70%,rgba(10,11,14,0));border-left:3px solid var(--ac);',
            'text-shadow:0 1px 2px rgba(0,0,0,.8);}',
          '.hxf-net{font-size:10px;font-weight:900;font-style:italic;letter-spacing:2px;text-transform:uppercase;color:var(--ac);margin-right:4px;}',
          '.hxf-val{display:flex;align-items:baseline;gap:5px;margin-bottom:3px;}',
          '.hxf-num{font-size:20px;line-height:22px;font-weight:900;font-style:italic;font-variant-numeric:tabular-nums;}',
          '.hxf-cap{font-size:11px;color:rgba(244,244,244,.55);font-variant-numeric:tabular-nums;}',
          '.hxf-unit{font-size:10px;letter-spacing:1.5px;text-transform:uppercase;color:rgba(244,244,244,.6);}',
          '.hxf-bar{position:relative;height:4px;background:repeating-linear-gradient(90deg,rgba(255,255,255,.18) 0 5px,transparent 5px 7px);',
            'clip-path:polygon(0 0,100% 0,calc(100% - 4px) 100%,0 100%);}',
          '.hxf-fill{position:absolute;top:0;bottom:0;left:0;width:0;background:#f4f4f4;transition:width .3s linear;}',
          '.hxf-root.is-low .hxf-fill{background:#ff6600;}',
          '.hxf-root.is-empty .hxf-fill{background:#ff3a28;animation:hxfBlink .8s ease-in-out infinite alternate;}',
          '.hxf-root.is-empty .hxf-num{color:#ff5a3c;}',
          '.hxf-red{position:absolute;top:0;bottom:0;left:0;width:10%;background:rgba(255,58,40,.3);}',
          '.hxf-scale{display:flex;justify-content:space-between;font-size:9px;color:rgba(244,244,244,.45);margin-top:1px;}',
          '@keyframes hxfBlink{to{opacity:.3;}}',
        '</style>',
      '</div>'
    ].join(''),
    replace: true,
    link: function (scope, element) {
      'use strict'
      var root = element[0]
      var q = function (s) { return root.querySelector(s) }
      var numEl = q('.hxf-num'), capEl = q('.hxf-cap'), unitEl = q('.hxf-unit'), fillEl = q('.hxf-fill'), netEl = q('.hxf-net')
      var streamsList = ['engineInfo']
      var hideTimer = null
      var last = {}

      function conv(l) {
        try {
          if (typeof UiUnits !== 'undefined' && UiUnits.volume) {
            var c = UiUnits.volume(l)
            if (c && isFinite(c.val)) return c
          }
        } catch (e) {}
        return { val: l, unit: 'L' }
      }
      function put(key, val, fn) { if (last[key] === val) return; last[key] = val; fn(val) }

      function show(on) {
        if (on) {
          if (hideTimer) { clearTimeout(hideTimer); hideTimer = null }
          root.classList.remove('is-off')
        } else if (!hideTimer && !root.classList.contains('is-off')) {
          hideTimer = setTimeout(function () { root.classList.add('is-off'); hideTimer = null }, 500)
        }
      }

      scope.$on('HashiriyaState', function (e, d) {
        var t = d && d.t
        if (t && t['hud.fuel']) put('label', t['hud.fuel'], function (v) { netEl.textContent = v })
      })

      try { StreamsManager.add(streamsList) } catch (e) {}

      scope.$on('streamsUpdate', function (e, s) {
        var ei = s && s.engineInfo
        var cur = ei ? Number(ei[11]) : NaN, cap = ei ? Number(ei[12]) : NaN
        if (!isFinite(cur) || !isFinite(cap) || cap <= 0) { show(false); return }
        show(true)
        var p = Math.max(0, Math.min(1, cur / cap))
        var c = conv(cur), k = conv(cap)
        var dec = k.val < 20 ? 1 : 0
        put('num', c.val.toFixed(dec), function (v) { numEl.textContent = v })
        put('cap', '/ ' + Math.round(k.val), function (v) { capEl.textContent = v })
        put('unit', c.unit || 'L', function (v) { unitEl.textContent = v })
        put('w', (p * 100).toFixed(1), function (v) { fillEl.style.width = v + '%' })
        put('low', p < LOW && p >= EMPTY, function (v) { root.classList.toggle('is-low', v) })
        put('empty', p < EMPTY, function (v) { root.classList.toggle('is-empty', v) })
      })

      scope.$on('$destroy', function () {
        if (hideTimer) clearTimeout(hideTimer)
        try { StreamsManager.remove(streamsList) } catch (e) {}
      })
    }
  }
}]);
