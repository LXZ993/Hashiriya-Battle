// Hashiriya Battle: eigener Drehzahlmesser im HashiNet-Design (abgeleitet von der BeamNG-App "Tacho2" / Advanced Tachometer).
// Seit 0.9.x (Tacho-Umbau) nur noch Drehzahl + Gang + Bremsanzeige; Geschwindigkeit hat eine eigene Rundanzeige
// (HashiriyaSpeedo, dort auch der Tank), Öl/Wasser stehen in HashiriyaTemps.
// Gleiche Daten wie das Original (BeamNG 0.40 ui/modules/apps/Tacho2/tacho.vue):
//   engineInfo[1] = Höchstdrehzahl, [5] = Gang, [13] = Getriebeart ("manual" ...)
//   electrics: rpmTacho, gear_A (Automatik P R N D 2 1), parkingbrake, abs, signal_L/R, lowbeam, highbeam,
//              brake_input (Bremspedal 0..1, sonst brake)
// Skala wie im Original: Vollausschlag = Höchstdrehzahl auf 1000 aufgerundet + 1000, Teilung 500/1000/2000.
// Aussehen: 270°-Bogen aus Segmenten (weiß, ab 85 % orange, ab Höchstdrehzahl rot), großer Gang in der Mitte
// im schrägen Abzeichen (blinkt rot am Begrenzer), unten ein feiner Segment-Balken für das Bremspedal.
angular.module('beamng.apps')
.directive('hashiriyaTacho', [function () {
  var SVGNS = 'http://www.w3.org/2000/svg'
  var CX = 150, CY = 150, R_OUT = 132, R_IN = 116, R_NUM = 100
  var A0 = 135, SWEEP = 270, SEGS = 54
  var PSEGS = 24 // Segmente im Pedal-Balken

  function pt(r, deg) { var a = deg * Math.PI / 180; return [CX + r * Math.cos(a), CY + r * Math.sin(a)] }
  function seg(r1, r2, a1, a2) {
    var p1 = pt(r2, a1), p2 = pt(r2, a2), p3 = pt(r1, a2), p4 = pt(r1, a1)
    return 'M' + p1 + 'A' + r2 + ',' + r2 + ' 0 0 1 ' + p2 + 'L' + p3 + 'A' + r1 + ',' + r1 + ' 0 0 0 ' + p4 + 'Z'
  }
  // Pedal-Balken: 24 kleine schräge Segmente von x 78 bis 222
  function pedalSvg(cls) {
    var out = []
    for (var i = 0; i < PSEGS; i++) {
      var x = 78 + i * 6
      out.push('<path class="hxt-pseg ' + cls + '" d="M' + (x + 1) + ',266 L' + (x + 5) + ',266 L' + (x + 4) + ',272 L' + x + ',272 Z"/>')
    }
    return out.join('')
  }

  return {
    template: [
      '<div class="bngApp hxt-root">',
        '<svg class="hxt" viewBox="0 0 300 300" xmlns="http://www.w3.org/2000/svg">',
          '<defs>',
            '<radialGradient id="hxtBg" cx="50%" cy="45%" r="55%"><stop offset="0" stop-color="#16181c" stop-opacity=".42"/><stop offset=".75" stop-color="#0e0f12" stop-opacity=".32"/><stop offset="1" stop-color="#0e0f12" stop-opacity="0"/></radialGradient>',
          '</defs>',
          '<circle cx="150" cy="150" r="146" fill="url(#hxtBg)"/>',
          '<g class="hxt-segs"></g>',
          '<g class="hxt-nums"></g>',
          '<text class="hxt-legend" x="150" y="96">x1000 RPM</text>',
          '<line class="hxt-needle" x1="150" y1="58" x2="150" y2="22"/>',
          '<g class="hxt-gearbox"><path class="hxt-gearbg" d="M122,136 L190,136 L176,198 L108,198 Z"/><text class="hxt-gear" x="149" y="187">N</text></g>',
          '<text class="hxt-gearlbl" x="150" y="214">GEAR</text>',
          '<g class="hxt-lamps">',
            '<text class="hxt-lamp hxt-sigl" x="88" y="140">◀</text>',
            '<text class="hxt-lamp hxt-sigr" x="212" y="140">▶</text>',
            '<text class="hxt-lamp hxt-park" x="100" y="232">P</text>',
            '<text class="hxt-lamp hxt-abs" x="200" y="232">ABS</text>',
            '<text class="hxt-lamp hxt-beam" x="150" y="120">●</text>',
          '</g>',
          '<g class="hxt-pedal">',
            '<text class="hxt-plabel" x="150" y="259">Bremse</text>',
            pedalSvg('brake'),
          '</g>',
        '</svg>',
        '<style>',
          '.hxt-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;transition:opacity .25s;}',
          '.hxt-root.is-off{opacity:0;}',
          '.hxt{width:100%;height:100%;font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;filter:drop-shadow(0 1px 2px rgba(0,0,0,.8));}',
          '.hxt-seg{fill:rgba(255,255,255,.1);}',
          '.hxt-seg.on{fill:#f4f4f4;}',
          '.hxt-seg.hi.on{fill:#ff6600;}',
          '.hxt-seg.red{fill:rgba(255,58,40,.35);}',
          '.hxt-seg.red.on{fill:#ff3a28;}',
          '.hxt-num{fill:rgba(244,244,244,.8);font-size:15px;font-weight:900;font-style:italic;text-anchor:middle;dominant-baseline:middle;}',
          '.hxt-num.red{fill:#ff5a3c;}',
          '.hxt-legend{fill:rgba(244,244,244,.4);font-size:8px;letter-spacing:1.5px;text-anchor:middle;}',
          '.hxt-needle{stroke:#ff6600;stroke-width:3;stroke-linecap:round;}',
          '.hxt-gearbg{fill:#9c3a2c;}',
          '.hxt-gearbox{transition:opacity .1s;}',
          '.hxt-root.is-limit .hxt-gearbg{fill:#ff3a28;animation:hxtFlash .12s steps(2) infinite;}',
          '.hxt-gear{fill:#fff;font-size:56px;font-weight:900;font-style:italic;text-anchor:middle;letter-spacing:-2px;}',
          '.hxt-gearlbl{fill:rgba(244,244,244,.4);font-size:8px;letter-spacing:2.5px;text-anchor:middle;}',
          '.hxt-lamp{fill:rgba(255,255,255,.12);font-size:12px;font-weight:900;text-anchor:middle;}',
          '.hxt-lamp.on{fill:#ff6600;}',
          '.hxt-sigl.on,.hxt-sigr.on{fill:#3fbf5a;}',
          '.hxt-beam.on{fill:#3fbf5a;}.hxt-beam.high{fill:#4d93ec;}',
          '.hxt-abs.on,.hxt-park.on{fill:#ff5a3c;}',
          '.hxt-plabel{fill:rgba(244,244,244,.5);font-size:8px;font-weight:700;letter-spacing:2px;text-anchor:middle;text-transform:uppercase;}',
          '.hxt-pseg{fill:rgba(255,255,255,.12);}',
          '.hxt-pseg.brake.on{fill:#ff3a28;}',
          '@keyframes hxtFlash{50%{fill:#9c3a2c;}}',
        '</style>',
      '</div>'
    ].join(''),
    replace: true,
    link: function (scope, element) {
      'use strict'
      var root = element[0]
      var q = function (s) { return root.querySelector(s) }
      var segG = q('.hxt-segs'), numG = q('.hxt-nums'), needle = q('.hxt-needle')
      var gearEl = q('.hxt-gear'), legendEl = q('.hxt-legend'), pLabel = q('.hxt-plabel')
      var lamps = { sigl: q('.hxt-sigl'), sigr: q('.hxt-sigr'), park: q('.hxt-park'), abs: q('.hxt-abs'), beam: q('.hxt-beam') }
      var psegs = root.querySelectorAll('.hxt-pseg')
      var segs = []
      var fullRange = 0, maxRpm = 0
      var cache = {}
      var hideTimer = null
      var streamsList = ['electrics', 'engineInfo']

      function set(key, el, fn, val) { if (cache[key] === val) return; cache[key] = val; fn(el, val) }
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
          var c = 'hxt-seg'
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
          n.setAttribute('class', 'hxt-num' + (r > maxRpm ? ' red' : ''))
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

      // Pedalstellung 0..1: erst der Eingang (was der Spieler drückt), sonst der Wert nach Fahrhilfen
      function pedal(el, field) {
        var v = el[field + '_input']
        if (v === undefined || v === null) v = el[field]
        v = Number(v)
        return isFinite(v) ? Math.max(0, Math.min(1, v)) : 0
      }

      scope.$on('HashiriyaState', function (e, d) {
        var t = d && d.t
        if (t && t['hud.brake']) set('plabel', pLabel, function (n, v) { n.textContent = v }, t['hud.brake'])
      })

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
        set('gear', gearEl, function (n, v) { n.textContent = v }, g)

        // Lampen
        set('sigl', lamps.sigl, cls('on'), !!el.signal_L)
        set('sigr', lamps.sigr, cls('on'), !!el.signal_R)
        set('park', lamps.park, cls('on'), !!el.parkingbrake && el.parkingbrake > 0.1)
        set('abs', lamps.abs, cls('on'), !!el.abs)
        set('low', lamps.beam, cls('on'), el.lowbeam > 0.9 || el.highbeam > 0.9)
        set('high', lamps.beam, cls('high'), el.highbeam > 0.9)

        // Bremspedal
        var b = Math.round(pedal(el, 'brake') * PSEGS)
        if (cache.brake !== b) {
          for (var k = 0; k < psegs.length; k++) psegs[k].classList.toggle('on', k < b)
          cache.brake = b
        }
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
