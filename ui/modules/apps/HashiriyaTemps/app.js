// Hashiriya Battle: Öl- und Wassertemperatur im Stil des eigenen Drehzahlmessers (HashiriyaTacho).
// Daten wie im BeamNG-Original (0.40 ui/modules/apps/Tacho2/tacho.vue): electrics.oiltemp und electrics.watertemp in °C.
// Grenzwerte aus lua/vehicle/powertrain/combustionEngineThermals.lua und electrics.lua:
//   Kühlwasser: Thermostat 90 °C, Schaden ab 120 °C (coolantTemperatureDamageThreshold)
//   Öl: Öl-Thermostat 110 °C, Warnlampe im Spiel ab 130 °C, Schaden ab 150 °C (oilTemperatureDamageThreshold)
// Aussehen: zwei kleine 240°-Bögen aus Segmenten wie beim Drehzahlmesser (kalt blau, normal weiß, warm orange, Schaden rot),
// große kursive Zahl in der Mitte, schräges Abzeichen mit ÖL / WASSER (blinkt rot ab Schadensgrenze).
// Ohne Verbrennungsmotor (E-Auto) oder ohne Fahrzeug blendet die App aus.
// Skalen und Grenzen stehen unten in GAUGES und sind im Handbuch beschrieben.
angular.module('beamng.apps')
.directive('hashiriyaTemps', [function () {
  var SVGNS = 'http://www.w3.org/2000/svg'
  var R_OUT = 56, R_IN = 46, CY = 62
  var A0 = 150, SWEEP = 240, SEGS = 24

  // min/max = Skala, cold = darunter blau (noch kalt), warm = ab hier orange, red = ab hier rot (Motorschaden)
  var GAUGES = [
    { key: 'water', cx: 66,  field: 'watertemp', min: 40, max: 140, cold: 70, warm: 105, red: 120, labelKey: 'hud.water', label: 'Wasser' },
    { key: 'oil',   cx: 194, field: 'oiltemp',   min: 40, max: 160, cold: 70, warm: 130, red: 150, labelKey: 'hud.oil',   label: 'Öl' }
  ]

  function pt(cx, r, deg) { var a = deg * Math.PI / 180; return [cx + r * Math.cos(a), CY + r * Math.sin(a)] }
  function seg(cx, r1, r2, a1, a2) {
    var p1 = pt(cx, r2, a1), p2 = pt(cx, r2, a2), p3 = pt(cx, r1, a2), p4 = pt(cx, r1, a1)
    return 'M' + p1 + 'A' + r2 + ',' + r2 + ' 0 0 1 ' + p2 + 'L' + p3 + 'A' + r1 + ',' + r1 + ' 0 0 0 ' + p4 + 'Z'
  }
  function arc(cx, r, a1, a2) {
    var p1 = pt(cx, r, a1), p2 = pt(cx, r, a2)
    return 'M' + p1 + 'A' + r + ',' + r + ' 0 ' + (a2 - a1 > 180 ? 1 : 0) + ' 1 ' + p2
  }

  function gaugeSvg(g) {
    var c = g.cx
    return [
      '<g class="hxw-g hxw-' + g.key + '">',
        '<circle cx="' + c + '" cy="' + CY + '" r="62" fill="url(#hxwBg)"/>',
        '<path class="hxw-accent" d="' + arc(c, 62, 120, 175) + '"/>',
        '<g class="hxw-segs"></g>',
        '<line class="hxw-needle" x1="' + c + '" y1="' + (CY - 40) + '" x2="' + c + '" y2="' + (CY - 60) + '"/>',
        // Skalen-Enden unter den Bogen-Enden, damit die große Zahl frei bleibt
        '<text class="hxw-num hxw-min" x="' + (pt(c, 52, A0)[0] - 4) + '" y="' + (pt(c, 52, A0)[1] + 9) + '">' + g.min + '</text>',
        '<text class="hxw-num hxw-max" x="' + (pt(c, 52, A0 + SWEEP)[0] + 4) + '" y="' + (pt(c, 52, A0 + SWEEP)[1] + 9) + '">' + g.max + '</text>',
        '<text class="hxw-val" x="' + c + '" y="' + (CY + 9) + '">--</text>',
        '<text class="hxw-unit" x="' + c + '" y="' + (CY + 22) + '">°C</text>',
        '<g class="hxw-badge"><path class="hxw-badgebg" d="M' + (c - 30) + ',' + (CY + 34) + ' L' + (c + 34) + ',' + (CY + 34) + ' L' + (c + 28) + ',' + (CY + 52) + ' L' + (c - 36) + ',' + (CY + 52) + ' Z"/>',
        '<text class="hxw-label" x="' + (c - 1) + '" y="' + (CY + 47) + '">' + g.label + '</text></g>',
      '</g>'
    ].join('')
  }

  return {
    template: [
      '<div class="bngApp hxw-root is-off">',
        '<svg class="hxw" viewBox="0 0 260 130" xmlns="http://www.w3.org/2000/svg">',
          '<defs>',
            '<radialGradient id="hxwBg" cx="50%" cy="45%" r="55%"><stop offset="0" stop-color="#16181c" stop-opacity=".42"/><stop offset=".75" stop-color="#0e0f12" stop-opacity=".32"/><stop offset="1" stop-color="#0e0f12" stop-opacity="0"/></radialGradient>',
          '</defs>',
          GAUGES.map(gaugeSvg).join(''),
        '</svg>',
        '<style>',
          '.hxw-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;transition:opacity .25s;}',
          '.hxw-root.is-off{opacity:0;}',
          '.hxw{width:100%;height:100%;overflow:visible;font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;filter:drop-shadow(0 1px 2px rgba(0,0,0,.8));}',
          '.hxw-accent{fill:none;stroke:#ff6600;stroke-width:2;opacity:.9;}',
          '.hxw-seg{fill:rgba(255,255,255,.1);}',
          '.hxw-seg.on{fill:#f4f4f4;}',
          '.hxw-seg.cold.on{fill:#4d93ec;}',
          '.hxw-seg.hi.on{fill:#ff6600;}',
          '.hxw-seg.red{fill:rgba(255,58,40,.35);}',
          '.hxw-seg.red.on{fill:#ff3a28;}',
          '.hxw-num{fill:rgba(244,244,244,.55);font-size:8px;font-weight:900;font-style:italic;text-anchor:middle;}',
          '.hxw-max{fill:#ff5a3c;}',
          '.hxw-needle{stroke:#ff6600;stroke-width:2.5;stroke-linecap:round;}',
          '.hxw-val{fill:#f4f4f4;font-size:30px;font-weight:900;font-style:italic;text-anchor:middle;font-variant-numeric:tabular-nums;letter-spacing:-1px;}',
          '.hxw-g.is-cold .hxw-val{fill:#8fbaf3;}',
          '.hxw-g.is-warm .hxw-val{fill:#ff8a3d;}',
          '.hxw-g.is-red .hxw-val{fill:#ff3a28;}',
          '.hxw-unit{fill:rgba(244,244,244,.55);font-size:8px;letter-spacing:1px;text-anchor:middle;}',
          '.hxw-badgebg{fill:#9c3a2c;}',
          '.hxw-g.is-red .hxw-badgebg{fill:#ff3a28;animation:hxwFlash .5s steps(2) infinite;}',
          '.hxw-label{fill:#fff;font-size:11px;font-weight:900;font-style:italic;letter-spacing:1.5px;text-anchor:middle;text-transform:uppercase;}',
          '@keyframes hxwFlash{50%{fill:#9c3a2c;}}',
        '</style>',
      '</div>'
    ].join(''),
    replace: true,
    link: function (scope, element) {
      'use strict'
      var root = element[0]
      var streamsList = ['electrics']
      var hideTimer = null
      var parts = GAUGES.map(function (g) {
        var el = root.querySelector('.hxw-' + g.key)
        var segG = el.querySelector('.hxw-segs')
        var segs = []
        var gap = 1.4, w = SWEEP / SEGS
        for (var i = 0; i < SEGS; i++) {
          var a1 = A0 + i * w + gap / 2, a2 = A0 + (i + 1) * w - gap / 2
          var t = (i + 1) / SEGS, tMid = (i + 0.5) / SEGS
          var temp = g.min + tMid * (g.max - g.min)
          var p = document.createElementNS(SVGNS, 'path')
          p.setAttribute('d', seg(g.cx, R_IN - 4 + t * 4, R_OUT, a1, a2))
          var c = 'hxw-seg'
          if (temp >= g.red) c += ' red'
          else if (temp >= g.warm) c += ' hi'
          else if (temp < g.cold) c += ' cold'
          p.setAttribute('class', c)
          segG.appendChild(p)
          segs.push(p)
        }
        return {
          g: g, el: el, segs: segs,
          needle: el.querySelector('.hxw-needle'), val: el.querySelector('.hxw-val'),
          unit: el.querySelector('.hxw-unit'), label: el.querySelector('.hxw-label'),
          minEl: el.querySelector('.hxw-min'), maxEl: el.querySelector('.hxw-max'),
          cache: {}
        }
      })

      function set(p, key, val, fn) { if (p.cache[key] === val) return; p.cache[key] = val; fn(val) }

      // Spiel-Einheit (°C / °F) wie bei Tempo und Ladedruck über UiUnits, sonst °C
      function conv(c) {
        try {
          if (typeof UiUnits !== 'undefined' && UiUnits.temperature) {
            var r = UiUnits.temperature(c)
            if (r && isFinite(r.val)) return r
          }
        } catch (e) {}
        return { val: c, unit: '°C' }
      }

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
        if (!t) return
        parts.forEach(function (p) {
          set(p, 'label', t[p.g.labelKey] || p.g.label, function (v) { p.label.textContent = v })
        })
      })

      try { StreamsManager.add(streamsList) } catch (e) {}

      scope.$on('streamsUpdate', function (e, s) {
        var el = s && s.electrics
        // E-Autos und Fahrzeuge ohne Motor-Thermik liefern 0 bzw. nichts
        var has = el && (Number(el.oiltemp) > 0 || Number(el.watertemp) > 0)
        if (!has) { show(false); return }
        show(true)
        parts.forEach(function (p) {
          var g = p.g
          var c = Number(el[g.field]) || 0
          var tt = Math.max(0, Math.min(1, (c - g.min) / (g.max - g.min)))
          var lit = Math.round(tt * SEGS)
          set(p, 'lit', lit, function (v) { for (var i = 0; i < p.segs.length; i++) p.segs[i].classList.toggle('on', i < v) })
          var ang = Math.round((A0 + SWEEP * tt + 90) * 10) / 10
          set(p, 'ang', ang, function (v) { p.needle.setAttribute('transform', 'rotate(' + v + ',' + g.cx + ',' + CY + ')') })
          var u = conv(c)
          set(p, 'val', String(Math.round(u.val)), function (v) { p.val.textContent = v })
          set(p, 'unit', u.unit || '°C', function (v) {
            p.unit.textContent = v
            // Skalen-Enden in der gewählten Einheit beschriften
            p.minEl.textContent = String(Math.round(conv(g.min).val))
            p.maxEl.textContent = String(Math.round(conv(g.max).val))
          })
          var state = c >= g.red ? 'red' : (c >= g.warm ? 'warm' : (c < g.cold ? 'cold' : 'ok'))
          set(p, 'state', state, function (v) {
            p.el.classList.toggle('is-red', v === 'red')
            p.el.classList.toggle('is-warm', v === 'warm')
            p.el.classList.toggle('is-cold', v === 'cold')
          })
        })
      })

      scope.$on('$destroy', function () {
        if (hideTimer) clearTimeout(hideTimer)
        try { StreamsManager.remove(streamsList) } catch (e) {}
      })
    }
  }
}]);
