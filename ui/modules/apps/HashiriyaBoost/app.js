// Hashiriya Battle: Ladedruck als kleine Rundanzeige im Stil des eigenen Drehzahlmessers (wie HashiriyaTemps).
// Daten wie im BeamNG-Original (0.40 ui/modules/apps/Forcedinduction): Stream 'forcedInductionInfo' { boost, maxBoost } in kPa.
// Skala wie im Original: von -100 kPa (Unterdruck) bis max(150 kPa, maxBoost), umgerechnet in die Spiel-Einheit (bar/psi/kPa).
// Segmente: Unterdruck grau-blau, Ladedruck weiß, ab RED (Anteil der Skala) rot. Große Zahl in der Mitte, Abzeichen BOOST
// (blinkt rot im roten Bereich). Ohne Turbo/Kompressor blendet die App aus.
angular.module('beamng.apps')
.directive('hashiriyaBoost', [function () {
  var SVGNS = 'http://www.w3.org/2000/svg'
  var CX = 65, CY = 62, R_OUT = 56, R_IN = 46
  var A0 = 150, SWEEP = 240, SEGS = 24
  var RED = 0.8

  function pt(r, deg) { var a = deg * Math.PI / 180; return [CX + r * Math.cos(a), CY + r * Math.sin(a)] }
  function seg(r1, r2, a1, a2) {
    var p1 = pt(r2, a1), p2 = pt(r2, a2), p3 = pt(r1, a2), p4 = pt(r1, a1)
    return 'M' + p1 + 'A' + r2 + ',' + r2 + ' 0 0 1 ' + p2 + 'L' + p3 + 'A' + r1 + ',' + r1 + ' 0 0 0 ' + p4 + 'Z'
  }
  var pMin = pt(52, A0), pMax = pt(52, A0 + SWEEP)

  return {
    template: [
      '<div class="bngApp hxb-root is-off">',
        '<svg class="hxb" viewBox="0 0 130 130" xmlns="http://www.w3.org/2000/svg">',
          '<defs>',
            '<radialGradient id="hxbBg" cx="50%" cy="45%" r="55%"><stop offset="0" stop-color="#16181c" stop-opacity=".42"/><stop offset=".75" stop-color="#0e0f12" stop-opacity=".32"/><stop offset="1" stop-color="#0e0f12" stop-opacity="0"/></radialGradient>',
          '</defs>',
          '<circle cx="' + CX + '" cy="' + CY + '" r="62" fill="url(#hxbBg)"/>',
          '<g class="hxb-segs"></g>',
          '<line class="hxb-needle" x1="' + CX + '" y1="' + (CY - 40) + '" x2="' + CX + '" y2="' + (CY - 60) + '"/>',
          '<text class="hxb-num hxb-min" x="' + (pMin[0] - 4) + '" y="' + (pMin[1] + 9) + '">-1</text>',
          '<text class="hxb-num hxb-max" x="' + (pMax[0] + 4) + '" y="' + (pMax[1] + 9) + '">1.5</text>',
          '<text class="hxb-val" x="' + CX + '" y="' + (CY + 9) + '">0.0</text>',
          '<text class="hxb-unit" x="' + CX + '" y="' + (CY + 22) + '">bar</text>',
          '<g class="hxb-badge"><path class="hxb-badgebg" d="M' + (CX - 30) + ',' + (CY + 34) + ' L' + (CX + 34) + ',' + (CY + 34) + ' L' + (CX + 28) + ',' + (CY + 52) + ' L' + (CX - 36) + ',' + (CY + 52) + ' Z"/>',
          '<text class="hxb-label" x="' + (CX - 1) + '" y="' + (CY + 47) + '">Boost</text></g>',
        '</svg>',
        '<style>',
          '.hxb-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;transition:opacity .25s;}',
          '.hxb-root.is-off{opacity:0;}',
          '.hxb{width:100%;height:100%;overflow:visible;font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;filter:drop-shadow(0 1px 2px rgba(0,0,0,.8));}',
          '.hxb-seg{fill:rgba(255,255,255,.1);}',
          '.hxb-seg.on{fill:#f4f4f4;}',
          '.hxb-seg.vac.on{fill:#8fa6c4;}',
          '.hxb-seg.red{fill:rgba(255,58,40,.35);}',
          '.hxb-seg.red.on{fill:#ff3a28;}',
          '.hxb-num{fill:rgba(244,244,244,.55);font-size:8px;font-weight:900;font-style:italic;text-anchor:middle;}',
          '.hxb-max{fill:#ff5a3c;}',
          '.hxb-needle{stroke:#ff6600;stroke-width:2.5;stroke-linecap:round;}',
          '.hxb-val{fill:#f4f4f4;font-size:28px;font-weight:900;font-style:italic;text-anchor:middle;font-variant-numeric:tabular-nums;letter-spacing:-1px;}',
          '.hxb-root.is-red .hxb-val{fill:#ff3a28;}',
          '.hxb-unit{fill:rgba(244,244,244,.55);font-size:8px;letter-spacing:1px;text-anchor:middle;text-transform:uppercase;}',
          '.hxb-badgebg{fill:#9c3a2c;}',
          '.hxb-root.is-red .hxb-badgebg{fill:#ff3a28;animation:hxbFlash .5s steps(2) infinite;}',
          '.hxb-label{fill:#fff;font-size:11px;font-weight:900;font-style:italic;letter-spacing:1.5px;text-anchor:middle;text-transform:uppercase;}',
          '@keyframes hxbFlash{50%{fill:#9c3a2c;}}',
        '</style>',
      '</div>'
    ].join(''),
    replace: true,
    link: function (scope, element) {
      'use strict'
      var root = element[0]
      var q = function (s) { return root.querySelector(s) }
      var segG = q('.hxb-segs'), needle = q('.hxb-needle'), valEl = q('.hxb-val'), unitEl = q('.hxb-unit')
      var minEl = q('.hxb-min'), maxEl = q('.hxb-max')
      var streamsList = ['forcedInductionInfo']
      var hideTimer = null
      var segs = []
      var cache = {}

      function set(key, val, fn) { if (cache[key] === val) return; cache[key] = val; fn(val) }

      // Segmente neu bauen, wenn sich die Skala ändert (Null-Punkt verschiebt sich)
      function build(zeroT) {
        while (segG.firstChild) segG.removeChild(segG.firstChild)
        segs = []
        var gap = 1.4, w = SWEEP / SEGS
        for (var i = 0; i < SEGS; i++) {
          var a1 = A0 + i * w + gap / 2, a2 = A0 + (i + 1) * w - gap / 2
          var t = (i + 1) / SEGS, tMid = (i + 0.5) / SEGS
          var p = document.createElementNS(SVGNS, 'path')
          p.setAttribute('d', seg(R_IN - 4 + t * 4, R_OUT, a1, a2))
          var c = 'hxb-seg'
          if (tMid >= RED) c += ' red'
          else if (tMid < zeroT) c += ' vac'
          p.setAttribute('class', c)
          segG.appendChild(p)
          segs.push(p)
        }
        delete cache.lit
      }

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
        set('unit', boost.unit || 'bar', function (v) { unitEl.textContent = v })
        set('scale', minR + '|' + maxR, function () {
          minEl.textContent = round(minR, dec); maxEl.textContent = round(maxR, dec)
          build((0 - minR) / (maxR - minR))
        })
        var t = Math.max(0, Math.min(1, (boost.val - minR) / (maxR - minR)))
        var lit = Math.round(t * SEGS)
        set('lit', lit, function (v) { for (var i = 0; i < segs.length; i++) segs[i].classList.toggle('on', i < v) })
        var ang = Math.round((A0 + SWEEP * t + 90) * 10) / 10
        set('ang', ang, function (v) { needle.setAttribute('transform', 'rotate(' + v + ',' + CX + ',' + CY + ')') })
        set('val', boost.val.toFixed(dec === 0 ? 0 : 1), function (v) { valEl.textContent = v })
        set('red', t >= RED, function (v) { root.classList.toggle('is-red', v) })
      })

      scope.$on('$destroy', function () {
        if (hideTimer) clearTimeout(hideTimer)
        try { StreamsManager.remove(streamsList) } catch (e) {}
      })
    }
  }
}]);
