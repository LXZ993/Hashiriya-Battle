// Hashiriya Battle: SP-Anzeige im Stil der TXR-Reihe, in BeamNG-Farben.
// Aufbau: Autonamen links/rechts, Zeit in der Mitte, zwei schräge SP-Balken mit "SP" dazwischen,
// darunter Titel/Rivalenname und Abstand. Die Balken leeren sich von außen zur Mitte; ein heller
// Nachlauf-Balken zeigt kurz, wie viel SP gerade verloren ging.
// Daten: Hook 'HashiriyaState' (battle = battle.lua getHudState()).
angular.module('beamng.apps')
.directive('hashiriyaSpHud', [function () {
  return {
    template:
      '<div class="bngApp hbh-root">' +
        '<div class="hbh" ng-if="b" ng-class="{\'hbh-in\': b}">' +

          '<div class="hbh-row hbh-head">' +
            '<div class="hbh-id hbh-id-l">' +
              '<div class="hbh-badge">{{ t[\'hud.you\'] }}</div>' +
              '<div class="hbh-car">{{ b.playerCar | uppercase }}</div>' +
            '</div>' +
            '<div class="hbh-clock">{{ fmtTime(b.time) }}</div>' +
            '<div class="hbh-id hbh-id-r">' +
              '<div class="hbh-car">{{ b.rivalCar | uppercase }}</div>' +
              '<div class="hbh-badge hbh-badge-r" ng-class="{\'hbh-badge-lead\': b.rivalTag == \'leader\', \'hbh-badge-wand\': b.rivalTag == \'wanderer\'}">{{ t[\'hud.tag.\' + b.rivalTag] }}</div>' +
            '</div>' +
          '</div>' +

          '<div class="hbh-row hbh-gauges">' +
            '<div class="hbh-gauge hbh-gauge-l" ng-class="{\'hbh-low\': low(b.playerSp, b.playerMaxSp), \'hbh-hit\': hitP}">' +
              '<div class="hbh-trail" ng-style="{width: pct(trailP, b.playerMaxSp)}"></div>' +
              '<div class="hbh-fill" ng-style="{width: pct(b.playerSp, b.playerMaxSp)}"></div>' +
              '<div class="hbh-ticks"></div>' +
            '</div>' +
            '<div class="hbh-sp">' +
              '<span class="hbh-arrow hbh-arrow-l" ng-show="b.state == \'battle\' && b.gap < 0">&#9664;</span>' +
              'SP' +
              '<span class="hbh-arrow hbh-arrow-r" ng-show="b.state == \'battle\' && b.gap > 0">&#9654;</span>' +
            '</div>' +
            '<div class="hbh-gauge hbh-gauge-r" ng-class="{\'hbh-low\': low(b.rivalSp, b.rivalMaxSp), \'hbh-hit\': hitR}">' +
              '<div class="hbh-trail" ng-style="{width: pct(trailR, b.rivalMaxSp)}"></div>' +
              '<div class="hbh-fill" ng-style="{width: pct(b.rivalSp, b.rivalMaxSp)}"></div>' +
              '<div class="hbh-ticks"></div>' +
            '</div>' +
          '</div>' +

          '<div class="hbh-row hbh-foot">' +
            '<div class="hbh-title">{{ b.playerTitle }}</div>' +
            '<div class="hbh-gap" ng-show="b.state == \'battle\'" ng-class="{\'hbh-gap-lead\': b.gap < 0}">' +
              '{{ b.gap < 0 ? t[\'hud.lead\'] : t[\'hud.behind\'] }}<b>{{ abs(b.gap) }}</b><i>m</i></div>' +
            '<div class="hbh-title hbh-title-r">{{ b.rivalName }}</div>' +
          '</div>' +

          '<div class="hbh-count" ng-if="b.state == \'countdown\'"><span ng-attr-key="{{ b.countdown }}">{{ b.countdown }}</span></div>' +
          '<div class="hbh-result" ng-if="b.state == \'result\'" ng-class="b.won ? \'hbh-win\' : \'hbh-lose\'">' +
            '<div class="hbh-result-band"><span>{{ b.won ? t[\'hud.win\'] : t[\'hud.lose\'] }}</span></div>' +
          '</div>' +
        '</div>' +

        '<style>' +
          '.hbh-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;}' +
          '.hbh{--o:#ff6600;--o2:#ff9a3c;--o3:#b84a00;--w:#f4f4f4;--dim:rgba(244,244,244,.62);' +
            'font-family:"Overpass","Noto Sans","Segoe UI",sans-serif;color:var(--w);padding:6px 26px 0;' +
            'text-shadow:0 1px 3px rgba(0,0,0,.85);' +
            'background:linear-gradient(to bottom,rgba(12,12,14,.72) 0%,rgba(12,12,14,.38) 62%,rgba(12,12,14,0) 100%);}' +
          '.hbh-row{display:flex;align-items:center;}' +

          /* Kopfzeile */
          '.hbh-head{justify-content:space-between;height:28px;}' +
          '.hbh-id{display:flex;align-items:center;gap:10px;width:40%;min-width:0;}' +
          '.hbh-id-r{justify-content:flex-end;}' +
          '.hbh-badge{flex:none;font-size:10px;font-weight:800;letter-spacing:1.5px;line-height:20px;height:22px;padding:0 9px;' +
            'border:2px solid var(--w);border-radius:12px;}' +
          '.hbh-badge-r{border-color:var(--o);color:var(--o);}' +
          '.hbh-badge-lead{background:var(--o);color:#141414;text-shadow:none;}' +
          '.hbh-badge-wand{border-color:#b98cff;color:#b98cff;}' +
          '.hbh-car{font-size:13px;font-weight:700;letter-spacing:1.6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbh-clock{font-family:"Overpass Mono","Roboto Mono",monospace;font-size:21px;font-weight:700;font-style:italic;' +
            'letter-spacing:1px;font-variant-numeric:tabular-nums;}' +

          /* SP-Balken */
          '.hbh-gauges{margin-top:2px;height:16px;}' +
          '.hbh-gauge{position:relative;flex:1;height:10px;transform:skewX(-28deg);' +
            'background:rgba(0,0,0,.45);box-shadow:inset 0 0 0 1px rgba(255,255,255,.55),0 0 6px rgba(0,0,0,.6);overflow:hidden;}' +
          '.hbh-gauge > div{position:absolute;top:0;bottom:0;}' +
          '.hbh-gauge-l > .hbh-fill,.hbh-gauge-l > .hbh-trail{right:0;}' +
          '.hbh-gauge-r > .hbh-fill,.hbh-gauge-r > .hbh-trail{left:0;}' +
          '.hbh-fill{transition:width .12s linear;}' +
          '.hbh-gauge-l .hbh-fill{background:linear-gradient(to left,var(--o2) 0%,var(--o) 35%,var(--o3) 100%);}' +
          '.hbh-gauge-r .hbh-fill{background:linear-gradient(to right,var(--o2) 0%,var(--o) 35%,var(--o3) 100%);}' +
          '.hbh-fill:after{content:"";position:absolute;left:0;right:0;top:0;height:40%;background:rgba(255,255,255,.28);}' +
          '.hbh-trail{background:rgba(255,236,210,.85);transition:width .45s ease-out .25s;}' +
          '.hbh-ticks{left:0;right:0;background:repeating-linear-gradient(to right,transparent 0,transparent calc(10% - 1px),rgba(0,0,0,.45) calc(10% - 1px),rgba(0,0,0,.45) 10%);}' +
          '.hbh-low .hbh-fill{background:linear-gradient(to right,#ff5a3c,#e01e12) !important;animation:hbhPulse .45s ease-in-out infinite alternate;}' +
          '.hbh-hit{animation:hbhShake .18s linear;}' +
          '@keyframes hbhPulse{from{opacity:1;}to{opacity:.45;}}' +
          '@keyframes hbhShake{0%,100%{margin-left:0;}25%{margin-left:-3px;}75%{margin-left:3px;}}' +
          '.hbh-sp{flex:none;position:relative;width:64px;text-align:center;font-size:16px;font-weight:900;font-style:italic;letter-spacing:1px;}' +
          '.hbh-arrow{position:absolute;top:2px;font-size:10px;color:var(--o);font-style:normal;}' +
          '.hbh-arrow-l{left:4px;} .hbh-arrow-r{right:4px;}' +

          /* Fußzeile */
          '.hbh-foot{justify-content:space-between;margin-top:3px;height:20px;font-size:12px;}' +
          '.hbh-title{width:40%;color:var(--dim);font-style:italic;letter-spacing:.6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbh-title-r{text-align:right;}' +
          '.hbh-gap{font-size:10px;font-weight:800;letter-spacing:2px;color:var(--o2);padding:1px 10px 0;' +
            'background:rgba(0,0,0,.45);border-radius:2px;}' +
          '.hbh-gap b{font-size:14px;margin-left:8px;letter-spacing:0;color:var(--w);}' +
          '.hbh-gap i{font-style:normal;margin-left:2px;color:var(--dim);}' +
          '.hbh-gap-lead{color:#8fe388;}' +

          /* Countdown und Ergebnis */
          '.hbh-count{text-align:center;margin-top:4px;height:62px;}' +
          '.hbh-count span{display:inline-block;font-size:58px;line-height:62px;font-weight:900;font-style:italic;color:var(--o);' +
            'text-shadow:0 0 18px rgba(255,102,0,.55),0 2px 4px rgba(0,0,0,.9);animation:hbhPop .9s ease-out;}' +
          '@keyframes hbhPop{0%{transform:scale(1.8);opacity:0;}25%{transform:scale(1);opacity:1;}100%{transform:scale(.92);opacity:.85;}}' +
          '.hbh-result{margin-top:8px;text-align:center;}' +
          '.hbh-result-band{display:inline-block;padding:4px 60px;transform:skewX(-20deg);animation:hbhSlide .35s ease-out;' +
            'background:linear-gradient(to right,rgba(255,102,0,0),rgba(255,102,0,.92) 18%,rgba(255,102,0,.92) 82%,rgba(255,102,0,0));}' +
          '.hbh-lose .hbh-result-band{background:linear-gradient(to right,rgba(40,40,44,0),rgba(40,40,44,.92) 18%,rgba(40,40,44,.92) 82%,rgba(40,40,44,0));}' +
          '.hbh-result-band span{display:inline-block;transform:skewX(20deg);font-size:30px;font-weight:900;font-style:italic;letter-spacing:4px;}' +
          '@keyframes hbhSlide{from{transform:skewX(-20deg) translateX(-40px);opacity:0;}to{transform:skewX(-20deg);opacity:1;}}' +
        '</style>' +
      '</div>',
    replace: true,
    link: function (scope) {
      'use strict'
      scope.b = null
      scope.t = {}
      scope.trailP = 0
      scope.trailR = 0
      scope.hitP = false
      scope.hitR = false
      scope.abs = Math.abs
      scope.pct = function (v, max) { return Math.max(0, Math.min(100, (v / (max || 1)) * 100)) + '%' }
      scope.low = function (v, max) { return v / (max || 1) < 0.2 }
      scope.fmtTime = function (t) {
        t = t || 0
        var m = Math.floor(t / 60), s = Math.floor(t % 60), ms = Math.floor((t * 1000) % 1000)
        var pad = function (n, l) { n = String(n); while (n.length < l) n = '0' + n; return n }
        return pad(m, 2) + '\'' + pad(s, 2) + '"' + pad(ms, 3)
      }

      // Nachlauf-Balken: folgt dem echten Wert verzögert (per CSS-Transition); ein großer Treffer wackelt kurz.
      var lastP = null, lastR = null
      var hit = function (key) {
        scope[key] = true
        setTimeout(function () { scope.$evalAsync(function () { scope[key] = false }) }, 200)
      }

      scope.$on('HashiriyaState', function (event, data) {
        scope.$evalAsync(function () {
          var b = (data && data.battle) || null
          if (b && (!scope.b || scope.b.state === 'result') && b.state === 'countdown') { lastP = null; lastR = null }
          scope.b = b
          scope.t = (data && data.t) || scope.t
          if (!b) { lastP = null; lastR = null; return }
          if (lastP !== null && lastP - b.playerSp > b.playerMaxSp * 0.04) hit('hitP')
          if (lastR !== null && lastR - b.rivalSp > b.rivalMaxSp * 0.04) hit('hitR')
          lastP = b.playerSp
          lastR = b.rivalSp
          scope.trailP = b.playerSp
          scope.trailR = b.rivalSp
        })
      })
    }
  }
}]);
