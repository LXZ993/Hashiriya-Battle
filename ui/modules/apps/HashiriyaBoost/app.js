// Hashiriya Battle: Ladedruck-Anzeige im HashiNet-Design (abgeleitet von der BeamNG-App "Forced Induction").
// Daten wie im Original (BeamNG 0.40 ui/modules/apps/Forcedinduction): Stream 'forcedInductionInfo' { boost, maxBoost } in kPa.
// Skala wie im Original: von -100 kPa (Unterdruck) bis max(150 kPa, maxBoost), umgerechnet in die Spiel-Einheit (bar/psi/kPa).
// Ab 80 % der Skala wird der Balken rot (wie die rote Zone im Original). Ohne Turbo/Kompressor blendet die App aus.
angular.module('beamng.apps')
.directive('hashiriyaBoost', [function () {
  return {
    template: [
      '<div class="bngApp hbb-root is-off">',
        '<div class="hbb">',
          '<div class="hbb-head"><span class="hbb-net">Hashiriya</span><span class="hbb-title">Boost</span></div>',
          '<div class="hbb-val"><b class="hbb-num">0.0</b><small class="hbb-unit">bar</small></div>',
          '<div class="hbb-bar">',
            '<span class="hbb-red"></span><span class="hbb-fill"></span><span class="hbb-zero"></span>',
          '</div>',
          '<div class="hbb-scale"><span class="hbb-min">-1</span><span class="hbb-max">1.5</span></div>',
        '</div>',
        '<style>',
          '.hbb-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;transition:opacity .25s;',
            'font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;color:#f4f4f4;}',
          '.hbb-root.is-off{opacity:0;}',
          '.hbb{--ac:#ff6600;position:absolute;left:0;right:0;bottom:0;padding:8px 18px 9px 14px;box-sizing:border-box;',
            'background:linear-gradient(90deg,rgba(14,15,18,.92),rgba(14,15,18,.8));border-left:4px solid var(--ac);',
            'box-shadow:0 6px 20px rgba(0,0,0,.5);text-shadow:0 1px 2px rgba(0,0,0,.7);',
            'clip-path:polygon(0 0,100% 0,calc(100% - 12px) 100%,0 100%);}',
          '.hbb-head{display:flex;align-items:baseline;gap:9px;font-size:10px;letter-spacing:2.4px;text-transform:uppercase;}',
          '.hbb-net{font-weight:900;font-style:italic;color:var(--ac);}',
          '.hbb-title{font-weight:700;color:rgba(244,244,244,.65);}',
          '.hbb-val{display:flex;align-items:baseline;gap:6px;margin:1px 0 5px;}',
          '.hbb-num{font-size:30px;line-height:32px;font-weight:900;font-style:italic;font-variant-numeric:tabular-nums;}',
          '.hbb-unit{font-size:11px;letter-spacing:2px;text-transform:uppercase;color:rgba(244,244,244,.55);}',
          '.hbb-bar{position:relative;height:8px;background:repeating-linear-gradient(90deg,rgba(255,255,255,.14) 0 6px,transparent 6px 8px);',
            'clip-path:polygon(0 0,100% 0,calc(100% - 4px) 100%,0 100%);}',
          '.hbb-fill{position:absolute;top:0;bottom:0;left:0;width:0;background:#f4f4f4;transition:width .08s linear;}',
          '.hbb-fill.hi{background:#ff6600;}',
          '.hbb-fill.red{background:#ff3a28;}',
          '.hbb-red{position:absolute;top:0;bottom:0;left:80%;right:0;background:rgba(255,58,40,.3);}',
          '.hbb-zero{position:absolute;top:-3px;bottom:-3px;width:2px;background:var(--ac);}',
          '.hbb-scale{display:flex;justify-content:space-between;font-size:10px;color:rgba(244,244,244,.5);margin-top:3px;font-variant-numeric:tabular-nums;}',
        '</style>',
      '</div>'
    ].join(''),
    replace: true,
    link: function (scope, element) {
      'use strict'
      var root = element[0]
      var q = function (s) { return root.querySelector(s) }
      var numEl = q('.hbb-num'), unitEl = q('.hbb-unit'), fillEl = q('.hbb-fill'), zeroEl = q('.hbb-zero')
      var minEl = q('.hbb-min'), maxEl = q('.hbb-max')
      var streamsList = ['forcedInductionInfo']
      var hideTimer = null
      var last = {}

      function conv(kpa) {
        try {
          if (typeof UiUnits !== 'undefined' && UiUnits.pressure) {
            var c = UiUnits.pressure(kpa)
            if (c && isFinite(c.val)) return c
          }
        } catch (e) {}
        return { val: kpa / 100, unit: 'bar' }
      }
      function round(v, d) { var f = Math.pow(10, d); return Math.round(v * f) / f }

      function show(on) {
        if (on) {
          if (hideTimer) { clearTimeout(hideTimer); hideTimer = null }
          root.classList.remove('is-off')
        } else if (!hideTimer && !root.classList.contains('is-off')) {
          hideTimer = setTimeout(function () { root.classList.add('is-off'); hideTimer = null }, 500)
        }
      }

      try { StreamsManager.add(streamsList) } catch (e) {}

      scope.$on('streamsUpdate', function (e, s) {
        var d = s && s.forcedInductionInfo
        if (!d || !isFinite(Number(d.boost)) || !isFinite(Number(d.maxBoost))) { show(false); return }
        show(true)
        var boost = conv(Number(d.boost))
        var max = conv(Math.max(150, Number(d.maxBoost))).val
        var min = conv(-100).val
        var maxR = Math.ceil(max), minR = Math.floor(min)
        if (maxR - minR < 3) { maxR = round(max, 1); minR = round(min, 1) }
        var dec = maxR > 10 ? 0 : 1
        if (last.unit !== boost.unit) { unitEl.textContent = boost.unit; last.unit = boost.unit }
        if (last.max !== maxR || last.min !== minR) {
          maxEl.textContent = round(maxR, dec); minEl.textContent = round(minR, dec)
          zeroEl.style.left = ((0 - minR) / (maxR - minR) * 100) + '%'
          last.max = maxR; last.min = minR
        }
        numEl.textContent = boost.val.toFixed(dec === 0 ? 0 : 1)
        var p = Math.max(0, Math.min(1, (boost.val - minR) / (maxR - minR)))
        fillEl.style.width = (p * 100).toFixed(1) + '%'
        fillEl.classList.toggle('red', p >= 0.8)
        fillEl.classList.toggle('hi', p < 0.8 && boost.val > 0)
      })

      scope.$on('$destroy', function () {
        if (hideTimer) clearTimeout(hideTimer)
        try { StreamsManager.remove(streamsList) } catch (e) {}
      })
    }
  }
}]);
