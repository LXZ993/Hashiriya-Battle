// Hashiriya Battle: analoger Geschwindigkeitsmesser im Stil des eigenen Drehzahlmessers (HashiriyaTacho).
// Daten: electrics.wheelspeed (sonst airspeed) in m/s, Einheit über UiUnits.speed (km/h oder mph, wie im Spiel eingestellt);
//        electrics.throttle_input (Gaspedal 0..1, sonst throttle) für den Gas-Balken unten.
// Skala: SCALES unten. Start mit der kleinsten Skala; fährt das Auto schneller als 95 % davon, springt die Skala
// eine Stufe höher und bleibt so, bis das Fahrzeug gewechselt wird.
// Aussehen: 270°-Bogen aus Segmenten (weiß, oberstes Achtel orange), Nadel, kleine Digitalzahl in der Mitte,
// unten ein feiner Segment-Balken fürs Gaspedal (grün).
angular.module('beamng.apps')
.directive('hashiriyaSpeedo', [function () {
  var SVGNS = 'http://www.w3.org/2000/svg'
  var CX = 150, CY = 150, R_OUT = 132, R_IN = 116, R_NUM = 100
  var A0 = 135, SWEEP = 270, SEGS = 54
  var PSEGS = 24
  // Skalen je Einheit: max = Vollausschlag, step = Beschriftung alle ... Einheiten
  var SCALES = {
    kmh: [{ max: 200, step: 20 }, { max: 280, step: 40 }, { max: 360, step: 40 }, { max: 480, step: 60 }],
    mph: [{ max: 120, step: 20 }, { max: 180, step: 20 }, { max: 240, step: 40 }, { max: 300, step: 50 }]
  }

  function pt(r, deg) { var a = deg * Math.PI / 180; return [CX + r * Math.cos(a), CY + r * Math.sin(a)] }
  function seg(r1, r2, a1, a2) {
    var p1 = pt(r2, a1), p2 = pt(r2, a2), p3 = pt(r1, a2), p4 = pt(r1, a1)
    return 'M' + p1 + 'A' + r2 + ',' + r2 + ' 0 0 1 ' + p2 + 'L' + p3 + 'A' + r1 + ',' + r1 + ' 0 0 0 ' + p4 + 'Z'
  }
  function arc(r, a1, a2) {
    var p1 = pt(r, a1), p2 = pt(r, a2)
    return 'M' + p1 + 'A' + r + ',' + r + ' 0 ' + (a2 - a1 > 180 ? 1 : 0) + ' 1 ' + p2
  }
  function pedalSvg(cls) {
    var out = []
    for (var i = 0; i < PSEGS; i++) {
      var x = 78 + i * 6
      out.push('<path class="hxs-pseg ' + cls + '" d="M' + (x + 1) + ',266 L' + (x + 5) + ',266 L' + (x + 4) + ',272 L' + x + ',272 Z"/>')
    }
    return out.join('')
  }

  return {
    template: [
      '<div class="bngApp hxs-root is-off">',
        '<svg class="hxs" viewBox="0 0 300 300" xmlns="http://www.w3.org/2000/svg">',
          '<defs>',
            '<radialGradient id="hxsBg" cx="50%" cy="45%" r="55%"><stop offset="0" stop-color="#16181c" stop-opacity=".42"/><stop offset=".75" stop-color="#0e0f12" stop-opacity=".32"/><stop offset="1" stop-color="#0e0f12" stop-opacity="0"/></radialGradient>',
          '</defs>',
          '<circle cx="150" cy="150" r="146" fill="url(#hxsBg)"/>',
          '<path class="hxs-accent" d="' + arc(146, 100, 170) + '"/>',
          '<g class="hxs-segs"></g>',
          '<g class="hxs-nums"></g>',
          '<text class="hxs-legend" x="150" y="96">km/h</text>',
          '<line class="hxs-needle" x1="150" y1="58" x2="150" y2="22"/>',
          '<text class="hxs-speed" x="150" y="182">0</text>',
          '<text class="hxs-unit" x="150" y="200">km/h</text>',
          '<g class="hxs-pedal">',
            '<text class="hxs-plabel" x="150" y="259">Gas</text>',
            pedalSvg('gas'),
          '</g>',
        '</svg>',
        '<style>',
          '.hxs-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;transition:opacity .25s;}',
          '.hxs-root.is-off{opacity:0;}',
          '.hxs{width:100%;height:100%;font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;filter:drop-shadow(0 1px 2px rgba(0,0,0,.8));}',
          '.hxs-accent{fill:none;stroke:#ff6600;stroke-width:2;opacity:.9;}',
          '.hxs-seg{fill:rgba(255,255,255,.1);}',
          '.hxs-seg.on{fill:#f4f4f4;}',
          '.hxs-seg.hi.on{fill:#ff6600;}',
          '.hxs-num{fill:rgba(244,244,244,.8);font-size:14px;font-weight:900;font-style:italic;text-anchor:middle;dominant-baseline:middle;}',
          '.hxs-legend{fill:rgba(244,244,244,.4);font-size:8px;letter-spacing:1.5px;text-anchor:middle;}',
          '.hxs-needle{stroke:#ff6600;stroke-width:3;stroke-linecap:round;}',
          '.hxs-speed{fill:#f4f4f4;font-size:40px;font-weight:900;font-style:italic;text-anchor:middle;font-variant-numeric:tabular-nums;letter-spacing:-1px;}',
          '.hxs-unit{fill:rgba(244,244,244,.55);font-size:9px;letter-spacing:2.5px;text-anchor:middle;text-transform:uppercase;}',
          '.hxs-plabel{fill:rgba(244,244,244,.5);font-size:8px;font-weight:700;letter-spacing:2px;text-anchor:middle;text-transform:uppercase;}',
          '.hxs-pseg{fill:rgba(255,255,255,.12);}',
          '.hxs-pseg.gas.on{fill:#3fbf5a;}',
        '</style>',
      '</div>'
    ].join(''),
    replace: true,
    link: function (scope, element) {
      'use strict'
      var root = element[0]
      var q = function (s) { return root.querySelector(s) }
      var segG = q('.hxs-segs'), numG = q('.hxs-nums'), needle = q('.hxs-needle')
      var speedEl = q('.hxs-speed'), unitEl = q('.hxs-unit'), legendEl = q('.hxs-legend'), pLabel = q('.hxs-plabel')
      var psegs = root.querySelectorAll('.hxs-pseg')
      var segs = []
      var scale = null, scaleIdx = 0, unitKey = ''
      var cache = {}
      var hideTimer = null
      var streamsList = ['electrics']

      function set(key, el, fn, val) { if (cache[key] === val) return; cache[key] = val; fn(el, val) }

      function build() {
        scale = SCALES[unitKey][scaleIdx]
        while (segG.firstChild) segG.removeChild(segG.firstChild)
        while (numG.firstChild) numG.removeChild(numG.firstChild)
        segs = []
        var gap = 1.2, w = SWEEP / SEGS
        for (var i = 0; i < SEGS; i++) {
          var a1 = A0 + i * w + gap / 2, a2 = A0 + (i + 1) * w - gap / 2
          var t = (i + 1) / SEGS
          var p = document.createElementNS(SVGNS, 'path')
          p.setAttribute('d', seg(R_IN + t * 6 - 6, R_OUT, a1, a2))
          p.setAttribute('class', 'hxs-seg' + (t > 0.875 ? ' hi' : ''))
          segG.appendChild(p)
          segs.push(p)
        }
        for (var v = 0; v <= scale.max; v += scale.step) {
          var pos = pt(R_NUM - 8, A0 + SWEEP * v / scale.max)
          var n = document.createElementNS(SVGNS, 'text')
          n.setAttribute('x', pos[0]); n.setAttribute('y', pos[1])
          n.setAttribute('class', 'hxs-num')
          n.textContent = String(v)
          numG.appendChild(n)
        }
        var lbl = cache.plabel
        cache = {}
        cache.plabel = lbl
      }

      function show(on) {
        if (on) {
          if (hideTimer) { clearTimeout(hideTimer); hideTimer = null }
          root.classList.remove('is-off')
        } else if (!hideTimer && !root.classList.contains('is-off')) {
          hideTimer = setTimeout(function () { root.classList.add('is-off'); hideTimer = null }, 500)
        }
      }

      function speedOf(ms) {
        try { if (typeof UiUnits !== 'undefined' && UiUnits.speed) return UiUnits.speed(ms) } catch (e) {}
        return { val: ms * 3.6, unit: 'km/h' }
      }

      function pedal(el, field) {
        var v = el[field + '_input']
        if (v === undefined || v === null) v = el[field]
        v = Number(v)
        return isFinite(v) ? Math.max(0, Math.min(1, v)) : 0
      }

      scope.$on('HashiriyaState', function (e, d) {
        var t = d && d.t
        if (t && t['hud.throttle']) set('plabel', pLabel, function (n, v) { n.textContent = v }, t['hud.throttle'])
      })

      try { StreamsManager.add(streamsList) } catch (e) {}

      scope.$on('streamsUpdate', function (e, s) {
        var el = s && s.electrics
        if (!el || (el.wheelspeed === undefined && el.airspeed === undefined)) { show(false); return }
        show(true)

        var ms = el.wheelspeed !== undefined && el.wheelspeed !== null ? Number(el.wheelspeed) : Number(el.airspeed)
        var sp = speedOf(ms || 0)
        var val = Math.abs(Number(sp.val) || 0)
        var unit = sp.unit || 'km/h'
        var key = /mph/i.test(unit) ? 'mph' : 'kmh'
        if (key !== unitKey) { unitKey = key; scaleIdx = 0; build() }
        // Skala wächst mit, wenn das Auto schneller ist als 95 % des Vollausschlags
        while (val > scale.max * 0.95 && scaleIdx < SCALES[unitKey].length - 1) { scaleIdx++; build() }

        var t = Math.min(1, val / scale.max)
        var lit = Math.round(t * SEGS)
        if (cache.lit !== lit) {
          for (var i = 0; i < segs.length; i++) segs[i].classList.toggle('on', i < lit)
          cache.lit = lit
        }
        var ang = Math.round((A0 + SWEEP * t + 90) * 10) / 10
        set('ang', needle, function (n, v) { n.setAttribute('transform', 'rotate(' + v + ',150,150)') }, ang)
        set('speed', speedEl, function (n, v) { n.textContent = v }, String(Math.round(val)))
        set('unit', unitEl, function (n, v) { n.textContent = v; legendEl.textContent = v }, unit)

        var g = Math.round(pedal(el, 'throttle') * PSEGS)
        if (cache.gas !== g) {
          for (var k = 0; k < psegs.length; k++) psegs[k].classList.toggle('on', k < g)
          cache.gas = g
        }
      })

      // Neues Fahrzeug: wieder mit der kleinsten Skala anfangen
      function resetCar() { if (unitKey) { scaleIdx = 0; build() } }
      scope.$on('VehicleChange', resetCar)
      scope.$on('VehicleFocusChanged', resetCar)
      scope.$on('$destroy', function () {
        if (hideTimer) clearTimeout(hideTimer)
        try { StreamsManager.remove(streamsList) } catch (e) {}
      })
    }
  }
}]);
