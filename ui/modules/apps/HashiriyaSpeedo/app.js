// Hashiriya Battle: analoger Geschwindigkeitsmesser im Stil des eigenen Drehzahlmessers (HashiriyaTacho).
// Daten: electrics.wheelspeed (sonst airspeed) in m/s, Einheit über UiUnits.speed (km/h oder mph, wie im Spiel eingestellt);
//        electrics.throttle_input (Gaspedal 0..1, sonst throttle) für den Gas-Balken unten,
//        engineInfo[11]/[12] (Tank jetzt/voll in Liter, Einheit über UiUnits.volume) für den Tank-Balken in der Mitte.
// Skala: SCALES unten. Start mit der kleinsten Skala; fährt das Auto schneller als 95 % davon, springt die Skala
// eine Stufe höher und bleibt so, bis das Fahrzeug gewechselt wird.
// Aussehen: 270°-Bogen aus Segmenten (weiß, oberstes Achtel orange), Nadel, kleine Digitalzahl in der Mitte,
// darunter der Tank als kleiner Segment-Balken mit Litern (orange unter FUEL_LOW, rot blinkend unter FUEL_EMPTY),
// unten ein feiner Segment-Balken fürs Gaspedal (grün). Ohne Tank (E-Auto) blendet nur der Tank-Teil aus.
angular.module('beamng.apps')
.directive('hashiriyaSpeedo', [function () {
  var SVGNS = 'http://www.w3.org/2000/svg'
  var CX = 150, CY = 150, R_OUT = 132, R_IN = 116, R_NUM = 100
  var A0 = 135, SWEEP = 270, SEGS = 54
  var PSEGS = 24
  var FSEGS = 16, FUEL_LOW = 0.25, FUEL_EMPTY = 0.1
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
  function pedalSvg(cls) {
    var out = []
    for (var i = 0; i < PSEGS; i++) {
      var x = 78 + i * 6
      out.push('<path class="hxs-pseg ' + cls + '" d="M' + (x + 1) + ',266 L' + (x + 5) + ',266 L' + (x + 4) + ',272 L' + x + ',272 Z"/>')
    }
    return out.join('')
  }

  // Tank-Balken: 16 schräge Segmente von x 118 bis 182 unter der Digitalzahl
  function fuelSvg() {
    var out = []
    for (var i = 0; i < FSEGS; i++) {
      var x = 118 + i * 4
      out.push('<path class="hxs-fseg" d="M' + (x + 1.2) + ',209 L' + (x + 4.4) + ',209 L' + (x + 3.6) + ',214 L' + (x + 0.4) + ',214 Z"/>')
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
          '<g class="hxs-segs"></g>',
          '<g class="hxs-nums"></g>',
          '<text class="hxs-legend" x="150" y="96">km/h</text>',
          '<line class="hxs-needle" x1="150" y1="58" x2="150" y2="22"/>',
          '<text class="hxs-speed" x="150" y="182">0</text>',
          '<text class="hxs-unit" x="150" y="200">km/h</text>',
          '<g class="hxs-fuel">',
            '<text class="hxs-fe" x="112" y="214">E</text>',
            fuelSvg(),
            '<text class="hxs-fe" x="188" y="214">F</text>',
            '<text class="hxs-fval" x="150" y="229"><tspan class="hxs-flabel">Tank</tspan> <tspan class="hxs-fnum">0</tspan> <tspan class="hxs-fcap">/ 0 L</tspan></text>',
          '</g>',
          '<g class="hxs-pedal">',
            '<text class="hxs-plabel" x="150" y="259">Gas</text>',
            pedalSvg('gas'),
          '</g>',
        '</svg>',
        '<style>',
          '.hxs-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;transition:opacity .25s;}',
          '.hxs-root.is-off{opacity:0;}',
          '.hxs{width:100%;height:100%;font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;filter:drop-shadow(0 1px 2px rgba(0,0,0,.8));}',
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
          '.hxs-fuel{transition:opacity .25s;}',
          '.hxs-root.no-fuel .hxs-fuel{opacity:0;}',
          '.hxs-fseg{fill:rgba(255,255,255,.12);}',
          '.hxs-fseg.on{fill:#f4f4f4;}',
          '.hxs-root.fuel-low .hxs-fseg.on{fill:#ff6600;}',
          '.hxs-root.fuel-empty .hxs-fseg.on{fill:#ff3a28;animation:hxsBlink .8s ease-in-out infinite alternate;}',
          '.hxs-fe{fill:rgba(244,244,244,.45);font-size:7px;font-weight:700;text-anchor:middle;}',
          '.hxs-fval{fill:#f4f4f4;font-size:10px;font-weight:900;font-style:italic;text-anchor:middle;font-variant-numeric:tabular-nums;}',
          '.hxs-flabel{fill:#ff6600;font-size:8px;letter-spacing:1.5px;text-transform:uppercase;}',
          '.hxs-fcap{fill:rgba(244,244,244,.55);font-weight:400;font-style:normal;font-size:8px;}',
          '.hxs-root.fuel-empty .hxs-fnum{fill:#ff5a3c;}',
          '@keyframes hxsBlink{to{opacity:.3;}}',
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
      var psegs = root.querySelectorAll('.hxs-pseg'), fsegs = root.querySelectorAll('.hxs-fseg')
      var fNum = q('.hxs-fnum'), fCap = q('.hxs-fcap'), fLabel = q('.hxs-flabel')
      var segs = []
      var scale = null, scaleIdx = 0, unitKey = ''
      var cache = {}
      var hideTimer = null
      var streamsList = ['electrics', 'engineInfo']

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
        var lbl = cache.plabel, flbl = cache.flabel
        cache = {}
        cache.plabel = lbl; cache.flabel = flbl
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

      function vol(l) {
        try {
          if (typeof UiUnits !== 'undefined' && UiUnits.volume) {
            var r = UiUnits.volume(l)
            if (r && isFinite(r.val)) return r
          }
        } catch (e) {}
        return { val: l, unit: 'L' }
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
        if (t && t['hud.fuel']) set('flabel', fLabel, function (n, v) { n.textContent = v }, t['hud.fuel'])
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

        // Tank
        var ei = s.engineInfo
        var cur = ei ? Number(ei[11]) : NaN, cap = ei ? Number(ei[12]) : NaN
        var hasFuel = isFinite(cur) && isFinite(cap) && cap > 0
        set('hasFuel', root, function (n, v) { n.classList.toggle('no-fuel', !v) }, hasFuel)
        if (hasFuel) {
          var fp = Math.max(0, Math.min(1, cur / cap))
          var fl = Math.round(fp * FSEGS)
          if (fp > 0 && fl === 0) fl = 1
          if (cache.fuel !== fl) {
            for (var j = 0; j < fsegs.length; j++) fsegs[j].classList.toggle('on', j < fl)
            cache.fuel = fl
          }
          var c = vol(cur), k = vol(cap)
          set('fnum', fNum, function (n, v) { n.textContent = v }, c.val.toFixed(k.val < 20 ? 1 : 0))
          set('fcap', fCap, function (n, v) { n.textContent = v }, '/ ' + Math.round(k.val) + ' ' + (c.unit || 'L'))
          set('flow', root, function (n, v) { n.classList.toggle('fuel-low', v) }, fp < FUEL_LOW && fp >= FUEL_EMPTY)
          set('fempty', root, function (n, v) { n.classList.toggle('fuel-empty', v) }, fp < FUEL_EMPTY)
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
