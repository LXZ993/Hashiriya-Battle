// Hashiriya Battle: eigener Drehzahlmesser im HashiNet-Design (abgeleitet von der BeamNG-App "Tacho2" / Advanced Tachometer).
// Gleiche Daten wie das Original (BeamNG 0.40 ui/modules/apps/Tacho2/tacho.vue):
//   engineInfo[1] = Höchstdrehzahl, [5] = Gang, [11]/[12] = Tank jetzt/voll, [13] = Getriebeart ("manual" ...)
//   electrics: rpmTacho, wheelspeed/airspeed (m/s), gear_A (Automatik P R N D 2 1), parkingbrake, abs,
//              signal_L/R, lowbeam, highbeam, watertemp, ignition
// Skala wie im Original: Vollausschlag = Höchstdrehzahl auf 1000 aufgerundet + 1000, Teilung 500/1000/2000.
// Aussehen: 270°-Bogen aus Segmenten (weiß, ab 85 % orange, ab Höchstdrehzahl rot), große kursive Geschwindigkeit,
// Gang im schrägen Abzeichen (blinkt rot am Begrenzer), darunter Tank und Wassertemperatur als feine Balken.
angular.module('beamng.apps')
.directive('hashiriyaTacho', [function () {
  var SVGNS = 'http://www.w3.org/2000/svg'
  var CX = 150, CY = 150, R_OUT = 132, R_IN = 116, R_NUM = 100
  var A0 = 135, SWEEP = 270, SEGS = 54

  function pt(r, deg) { var a = deg * Math.PI / 180; return [CX + r * Math.cos(a), CY + r * Math.sin(a)] }
  function seg(r1, r2, a1, a2) {
    var p1 = pt(r2, a1), p2 = pt(r2, a2), p3 = pt(r1, a2), p4 = pt(r1, a1)
    return 'M' + p1 + 'A' + r2 + ',' + r2 + ' 0 0 1 ' + p2 + 'L' + p3 + 'A' + r1 + ',' + r1 + ' 0 0 0 ' + p4 + 'Z'
  }
  function arc(r, a1, a2) {
    var p1 = pt(r, a1), p2 = pt(r, a2)
    return 'M' + p1 + 'A' + r + ',' + r + ' 0 ' + (a2 - a1 > 180 ? 1 : 0) + ' 1 ' + p2
  }

  return {
    template: [
      '<div class="bngApp hbt-root">',
        '<svg class="hbt" viewBox="0 0 300 300" xmlns="http://www.w3.org/2000/svg">',
          '<defs>',
            '<radialGradient id="hbtBg" cx="50%" cy="45%" r="55%"><stop offset="0" stop-color="#16181c" stop-opacity=".7"/><stop offset=".8" stop-color="#0e0f12" stop-opacity=".55"/><stop offset="1" stop-color="#0e0f12" stop-opacity="0"/></radialGradient>',
          '</defs>',
          '<circle cx="150" cy="150" r="146" fill="url(#hbtBg)"/>',
          '<path class="hbt-accent" d="' + arc(146, 100, 170) + '"/>',
          '<g class="hbt-segs"></g>',
          '<g class="hbt-nums"></g>',
          '<text class="hbt-legend" x="150" y="96">x1000 RPM</text>',
          '<line class="hbt-needle" x1="150" y1="58" x2="150" y2="22"/>',
          '<text class="hbt-speed" x="150" y="186">0</text>',
          '<text class="hbt-unit" x="150" y="204">km/h</text>',
          '<g class="hbt-gearbox"><path class="hbt-gearbg" d="M128,214 L182,214 L172,250 L118,250 Z"/><text class="hbt-gear" x="150" y="243">N</text></g>',
          '<g class="hbt-lamps">',
            '<text class="hbt-lamp hbt-sigl" x="96" y="132">◀</text>',
            '<text class="hbt-lamp hbt-sigr" x="204" y="132">▶</text>',
            '<text class="hbt-lamp hbt-park" x="104" y="226">P</text>',
            '<text class="hbt-lamp hbt-abs" x="196" y="226">ABS</text>',
            '<text class="hbt-lamp hbt-beam" x="150" y="122">●</text>',
          '</g>',
          '<g class="hbt-bars">',
            '<text class="hbt-blabel" x="88" y="276">F</text><rect class="hbt-btrack" x="96" y="270" width="48" height="4"/><rect class="hbt-fuel" x="96" y="270" width="48" height="4"/>',
            '<text class="hbt-blabel" x="212" y="276">T</text><rect class="hbt-btrack" x="156" y="270" width="48" height="4"/><rect class="hbt-temp" x="156" y="270" width="0" height="4"/>',
          '</g>',
        '</svg>',
        '<style>',
          '.hbt-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;transition:opacity .25s;}',
          '.hbt-root.is-off{opacity:0;}',
          '.hbt{width:100%;height:100%;font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;filter:drop-shadow(0 1px 2px rgba(0,0,0,.8));}',
          '.hbt-accent{fill:none;stroke:#ff6600;stroke-width:2;opacity:.9;}',
          '.hbt-seg{fill:rgba(255,255,255,.1);}',
          '.hbt-seg.on{fill:#f4f4f4;}',
          '.hbt-seg.hi.on{fill:#ff6600;}',
          '.hbt-seg.red{fill:rgba(255,58,40,.35);}',
          '.hbt-seg.red.on{fill:#ff3a28;}',
          '.hbt-num{fill:rgba(244,244,244,.8);font-size:15px;font-weight:900;font-style:italic;text-anchor:middle;dominant-baseline:middle;}',
          '.hbt-num.red{fill:#ff5a3c;}',
          '.hbt-legend{fill:rgba(244,244,244,.4);font-size:8px;letter-spacing:1.5px;text-anchor:middle;}',
          '.hbt-needle{stroke:#ff6600;stroke-width:3;stroke-linecap:round;}',
                    '.hbt-speed{fill:#f4f4f4;font-size:52px;font-weight:900;font-style:italic;text-anchor:middle;font-variant-numeric:tabular-nums;letter-spacing:-1px;}',
          '.hbt-unit{fill:rgba(244,244,244,.55);font-size:10px;letter-spacing:2.5px;text-anchor:middle;text-transform:uppercase;}',
          '.hbt-gearbg{fill:#9c3a2c;}',
          '.hbt-gearbox{transition:opacity .1s;}',
          '.hbt-root.is-limit .hbt-gearbg{fill:#ff3a28;animation:hbtFlash .12s steps(2) infinite;}',
          '.hbt-gear{fill:#fff;font-size:30px;font-weight:900;font-style:italic;text-anchor:middle;}',
          '.hbt-lamp{fill:rgba(255,255,255,.12);font-size:12px;font-weight:900;text-anchor:middle;}',
          '.hbt-lamp.on{fill:#ff6600;}',
          '.hbt-sigl.on,.hbt-sigr.on{fill:#3fbf5a;}',
          '.hbt-beam.on{fill:#3fbf5a;}.hbt-beam.high{fill:#4d93ec;}',
          '.hbt-abs.on,.hbt-park.on{fill:#ff5a3c;}',
          '.hbt-blabel{fill:rgba(244,244,244,.5);font-size:9px;font-weight:700;text-anchor:middle;}',
          '.hbt-btrack{fill:rgba(255,255,255,.12);}',
          '.hbt-fuel{fill:#f4f4f4;}.hbt-fuel.low{fill:#ff5a3c;animation:hbtBlink .8s ease-in-out infinite alternate;}',
          '.hbt-temp{fill:#4d93ec;}.hbt-temp.hot{fill:#ff5a3c;}',
          '@keyframes hbtFlash{50%{fill:#9c3a2c;}}',
          '@keyframes hbtBlink{to{opacity:.3;}}',
        '</style>',
      '</div>'
    ].join(''),
    replace: true,
    link: function (scope, element) {
      'use strict'
      var root = element[0]
      var q = function (s) { return root.querySelector(s) }
      var segG = q('.hbt-segs'), numG = q('.hbt-nums'), needle = q('.hbt-needle')
      var speedEl = q('.hbt-speed'), unitEl = q('.hbt-unit'), gearEl = q('.hbt-gear'), legendEl = q('.hbt-legend')
      var lamps = { sigl: q('.hbt-sigl'), sigr: q('.hbt-sigr'), park: q('.hbt-park'), abs: q('.hbt-abs'), beam: q('.hbt-beam') }
      var fuelEl = q('.hbt-fuel'), tempEl = q('.hbt-temp')
      var segs = []
      var fullRange = 0, maxRpm = 0
      var cache = {}
      var hideTimer = null
      var streamsList = ['electrics', 'engineInfo']

      function set(key, el, fn, val) { if (cache[key] === val) return; cache[key] = val; fn(el, val) }
      function txt(el, v) { el.textContent = v }
      function cls(name) { return function (el, on) { el.classList.toggle(name, !!on) } }

      function build(engineMax) {
        maxRpm = engineMax
        fullRange = Math.ceil(engineMax / 1000) * 1000 + 1000
        var step = engineMax < 4000 ? 500 : (engineMax > 15000 ? 2000 : 1000)
        var div = step === 500 ? 100 : 1000
        legendEl.textContent = div === 100 ? 'x100 RPM' : 'x1000 RPM'
        while (segG.firstChild) segG.removeChild(segG.firstChild)
        while (numG.firstChild) numG.removeChild(numG.firstChild)
        segs = []
        var gap = 1.2
        var w = SWEEP / SEGS
        for (var i = 0; i < SEGS; i++) {
          var a1 = A0 + i * w + gap / 2, a2 = A0 + (i + 1) * w - gap / 2
          var t = (i + 1) / SEGS
          var p = document.createElementNS(SVGNS, 'path')
          var rIn = R_IN + (t * 6) // Segmente werden nach außen leicht breiter (TXR-artiger Keil)
          p.setAttribute('d', seg(rIn - 6, R_OUT, a1, a2))
          var c = 'hbt-seg'
          if (t * fullRange > maxRpm) c += ' red'
          else if (t * fullRange > maxRpm * 0.85) c += ' hi'
          p.setAttribute('class', c)
          segG.appendChild(p)
          segs.push(p)
        }
        for (var r = 0; r <= fullRange + 1; r += step) {
          var a = A0 + SWEEP * r / fullRange
          var pos = pt(R_NUM - 8, a)
          var n = document.createElementNS(SVGNS, 'text')
          n.setAttribute('x', pos[0]); n.setAttribute('y', pos[1])
          n.setAttribute('class', 'hbt-num' + (r > maxRpm ? ' red' : ''))
          n.textContent = String(r / div)
          numG.appendChild(n)
        }
        cache = {}
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

      try { StreamsManager.add(streamsList) } catch (e) {}
      root.classList.add('is-off')

      scope.$on('streamsUpdate', function (e, s) {
        var ei = s && s.engineInfo, el = s && s.electrics
        var engineMax = ei ? Number(ei[1]) : NaN
        if (!ei || !el || !isFinite(engineMax) || engineMax <= 0) { show(false); return }
        show(true)
        if (engineMax !== maxRpm) build(engineMax)

        // Drehzahl
        var rpm = Math.max(0, Number(el.rpmTacho) || 0)
        var t = Math.min(1, rpm / fullRange)
        var lit = Math.round(t * SEGS)
        if (cache.lit !== lit) {
          for (var i = 0; i < segs.length; i++) segs[i].classList.toggle('on', i < lit)
          cache.lit = lit
        }
        var ang = Math.round((A0 + SWEEP * t + 90) * 10) / 10
        set('ang', needle, function (n, v) { n.setAttribute('transform', 'rotate(' + v + ',150,150)') }, ang)
        set('limit', root, cls('is-limit'), rpm >= maxRpm * 0.97)

        // Geschwindigkeit
        var ms = el.wheelspeed !== undefined && el.wheelspeed !== null ? Number(el.wheelspeed) : Number(el.airspeed)
        var sp = speedOf(ms || 0)
        set('speed', speedEl, txt, String(Math.round(Math.abs(sp.val))))
        set('unit', unitEl, txt, sp.unit || '')

        // Gang
        // Gang: engineInfo[5] kann Zahl oder schon Text sein ("N", "R", "1"), sonst electrics.gear
        var g
        if (ei[13] === 'manual' || ei[13] === undefined) {
          var raw = ei[5] !== undefined && ei[5] !== null ? ei[5] : el.gear
          var gear = Number(raw)
          if (raw === '' || raw === undefined || raw === null) g = 'N'
          else if (!isFinite(gear)) g = String(raw).toUpperCase().slice(0, 2)
          else g = gear === 0 ? 'N' : (gear === -1 ? 'R' : (gear < -1 ? 'R' + (-gear) : String(gear)))
        } else {
          var ga = Number(el.gear_A)
          if (isFinite(ga)) g = ['P', 'R', 'N', 'D', '2', '1'][Math.max(0, Math.min(5, Math.round(ga * 5)))]
          else g = el.gear !== undefined && el.gear !== null && String(el.gear) !== '' ? String(el.gear).toUpperCase().slice(0, 2) : 'N'
        }
        set('gear', gearEl, txt, g)

        // Lampen
        set('sigl', lamps.sigl, cls('on'), !!el.signal_L)
        set('sigr', lamps.sigr, cls('on'), !!el.signal_R)
        set('park', lamps.park, cls('on'), !!el.parkingbrake && el.parkingbrake > 0.1)
        set('abs', lamps.abs, cls('on'), !!el.abs)
        set('low', lamps.beam, cls('on'), el.lowbeam > 0.9 || el.highbeam > 0.9)
        set('high', lamps.beam, cls('high'), el.highbeam > 0.9)

        // Tank und Temperatur
        var fuel = Number(ei[11]) / Number(ei[12])
        if (!isFinite(fuel)) fuel = 0
        set('fuel', fuelEl, function (n, v) { n.setAttribute('width', v) }, Math.round(Math.max(0, Math.min(1, fuel)) * 48))
        set('fuelLow', fuelEl, cls('low'), fuel < 0.1)
        var temp = Math.max(0, Math.min(1, ((Number(el.watertemp) || 0) - 50) / 80))
        set('temp', tempEl, function (n, v) { n.setAttribute('width', v) }, Math.round(temp * 48))
        set('hot', tempEl, cls('hot'), temp > 0.8125)
      })

      function resetCar() { maxRpm = 0; cache = {} }
      scope.$on('VehicleChange', resetCar)
      scope.$on('VehicleFocusChanged', resetCar)
      scope.$on('$destroy', function () {
        if (hideTimer) clearTimeout(hideTimer)
        try { StreamsManager.remove(streamsList) } catch (e) {}
      })
    }
  }
}]);
