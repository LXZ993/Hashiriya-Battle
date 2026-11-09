// Hashiriya Battle: SP-Anzeige im Stil der TXR-Reihe, in BeamNG-Farben.
// Aufbau: Autonamen links/rechts, Zeit in der Mitte, zwei schräge SP-Balken mit "SP" dazwischen,
// darunter Titel/Rivalenname und Abstand. Die Balken leeren sich von außen zur Mitte; ein heller
// Nachlauf-Balken zeigt kurz, wie viel SP gerade verloren ging.
// Daten: Hook 'HashiriyaState' (battle = battle.lua getHudState()). Der Spruch des Rivalen steht in der Sprechblase unten (App HashiriyaTalk).
// Alpha 0.9.3: Hook 'HashiriyaBattleFx' (crew.lua showFx) = Stopp-Zeichen in der Bildschirmmitte, wenn ein Rivale ablehnt;
// Kette (KETTE 2/3), Wette (Angebot und Einsatz) und Crew-Blocker als Plaketten.
angular.module('beamng.apps')
.directive('hashiriyaSpHud', [function () {
  return {
    template:
      '<div class="bngApp hbh-root">' +
        // Crew-Kette: wartet auf den nächsten Gegner (JDMArsch 09.11.2026: man wusste nicht, was zu tun ist)
        '<div class="hbh-cw" ng-if="b && b.chainWait">' +
          '<div class="hbh-cw-head"><span class="hbh-cw-tag">{{ t[\'hud.chainWait.title\'] }} {{ b.chainWait.step }}/{{ b.chainWait.total }}</span>' +
            '<span class="hbh-cw-lead" ng-if="b.chainWait.leader">{{ b.chainWait.leader }}</span></div>' +
          '<div class="hbh-cw-name"><small>{{ t[\'hud.chainWait.next\'] }}</small>{{ b.chainWait.name }}<i class="hbh-cw-haz"></i><em>{{ t[\'hud.chainWait.hazard\'] }}</em></div>' +
          '<div class="hbh-cw-dist" ng-class="{\'is-close\': b.chainWait.dist <= b.chainWait.startAt}">' +
            '<span class="hbh-cw-arrow">{{ b.chainWait.ahead ? \'\u25B2\' : \'\u25BC\' }}</span><b>{{ b.chainWait.dist }}</b><i>m</i>' +
            '<span>{{ b.chainWait.ahead ? t[\'hud.chainWait.ahead\'] : t[\'hud.chainWait.behind\'] }}</span></div>' +
          '<div class="hbh-cw-foot"><span>{{ fmtStart(b.chainWait.startAt) }}</span><span>{{ b.chainWait.timer }} s</span></div>' +
        '</div>' +
        '<div class="hbh" ng-if="b && !b.chainWait" ng-class="{\'hbh-in\': b}">' +

          '<div class="hbh-row hbh-head">' +
            '<div class="hbh-id hbh-id-l">' +
              '<div class="hbh-badge">{{ t[\'hud.you\'] }}</div>' +
              '<div class="hbh-car">{{ b.playerCar | uppercase }}</div>' +
            '</div>' +
            '<div class="hbh-clock">{{ fmtTime(b.time) }}</div>' +
            '<div class="hbh-id hbh-id-r">' +
              '<div class="hbh-car">{{ b.rivalCar | uppercase }}</div>' +
              '<div class="hbh-badge hbh-badge-r" ng-class="{\'hbh-badge-lead\': b.rivalTag == \'leader\', \'hbh-badge-wand\': b.rivalTag == \'wanderer\', \'hbh-badge-boss\': b.rivalTag == \'boss\'}">{{ t[\'hud.tag.\' + b.rivalTag] }}</div>' +
              '<div class="hbh-badge hbh-badge-r hbh-badge-pink" ng-if="b.pinkSlip">{{ t[\'hud.tag.pink\'] }}</div>' +
              '<div class="hbh-badge hbh-badge-r hbh-badge-chain" ng-if="b.chain">{{ t[\'hud.chain\'] }} {{ b.chain.step }}/{{ b.chain.total }}</div>' +
              '<div class="hbh-badge hbh-badge-r hbh-badge-bet" ng-if="b.bet && b.bet.accepted">{{ t[\'hud.bet\'] }} {{ b.bet.stake }}</div>' +
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
            '<div class="hbh-title hbh-title-r"><span class="hbh-rname">{{ b.rivalName }}<small ng-if="b.rivalTeam"> · {{ b.rivalTeam }}</small></span>' +
              '</div>' +
          '</div>' +

          // Embleme fest in der Anzeige: links dein Logo (Logo-Sammlung, ohne Wahl das Zeichen 走), rechts Crew-Symbol / Wanderer-Siegel / Boss-Emblem
          '<img class="hbh-slot hbh-slot-l" ng-class="{\'hbh-slot-own\': b.playerLogo && b.playerLogo != playerMark}" ng-src="{{ b.playerLogo || playerMark }}" alt="">' +
          '<img class="hbh-slot hbh-slot-r" ng-if="b.rivalLogo" ng-src="{{ b.rivalLogo }}" alt="">' +
          '<div class="hbh-sync" ng-if="b.state == \'sync\'">{{ t[\'hud.sync\'] }}</div>' +
          '<div class="hbh-betoffer" ng-if="b.state == \'sync\' && b.bet && b.bet.offer">' +
            '<b>{{ t[\'hud.bet\'] }} {{ b.bet.stake }}?</b><span class="hbh-bet-t">{{ b.bet.timer }}</span>' +
            '<small>{{ t[\'hud.betHint\'] }}</small></div>' +
          '<div class="hbh-blockers" ng-if="b.state == \'battle\' && b.blockers">{{ t[\'hud.blockers\'] }} &times;{{ b.blockers }}</div>' +
          '<div class="hbh-count" ng-if="b.state == \'countdown\'"><span ng-attr-key="{{ b.countdown }}">{{ b.countdown }}</span></div>' +
          '<div class="hbh-result" ng-if="b.state == \'result\'" ng-class="b.won ? \'hbh-win\' : \'hbh-lose\'">' +
            '<div class="hbh-result-band"><span>{{ b.won ? t[\'hud.win\'] : t[\'hud.lose\'] }}</span></div>' +
          '</div>' +
        '</div>' +

        // Rivale lehnt ab: Stopp-Zeichen (Kreuz im Ring) in der Bildschirmmitte, kurz eingeblendet
        '<div class="hbh-fx" ng-if="fx" ng-class="{\'hbh-fx-out\': fxOut, \'hbh-fx-player\': fx.who == \'player\'}">' +
          '<div class="hbh-fx-sign"><svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="42" class="hbh-fx-ring"/>' +
            '<path d="M32 32 L68 68 M68 32 L32 68" class="hbh-fx-x"/></svg></div>' +
          '<div class="hbh-fx-band"><span>{{ t[\'hud.decline\'] }}</span></div>' +
          '<div class="hbh-fx-who" ng-if="fx.name">{{ fx.name }}</div>' +
          '<div class="hbh-fx-text" ng-if="fx.text">{{ fx.text }}</div>' +
        '</div>' +

        '<style>' +
          '.hbh-cw{width:340px;margin:0 auto;padding:8px 14px 9px;background:linear-gradient(180deg,rgba(10,10,12,.82),rgba(10,10,12,.55));border-top:3px solid #ff6600;color:#f4f4f4;text-shadow:0 1px 2px rgba(0,0,0,.8);animation:hbhCwIn .25s ease-out;}' +
          '@keyframes hbhCwIn{from{opacity:0;transform:translateY(-6px);}to{opacity:1;transform:none;}}' +
          '.hbh-cw-head{display:flex;justify-content:space-between;align-items:baseline;font-size:10px;font-weight:900;font-style:italic;letter-spacing:1.4px;text-transform:uppercase;}' +
          '.hbh-cw-tag{color:#ff9a3c;}' +
          '.hbh-cw-lead{color:rgba(244,244,244,.62);}' +
          '.hbh-cw-name{margin-top:4px;font-size:17px;font-weight:900;font-style:italic;display:flex;align-items:center;gap:6px;}' +
          '.hbh-cw-name small{font-size:9px;letter-spacing:1px;text-transform:uppercase;color:rgba(244,244,244,.62);font-weight:700;margin-right:2px;}' +
          '.hbh-cw-haz{width:10px;height:10px;background:#ffb000;clip-path:polygon(50% 0,100% 100%,0 100%);animation:hbhHaz .6s steps(1) infinite;}' +
          '.hbh-cw-name em{font-size:9px;font-style:normal;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:#ffb000;}' +
          '@keyframes hbhHaz{50%{opacity:.15;}}' +
          '.hbh-cw-dist{margin-top:4px;display:flex;align-items:baseline;gap:5px;font-size:12px;color:rgba(244,244,244,.8);}' +
          '.hbh-cw-dist b{font-size:22px;font-weight:900;font-style:italic;color:#fff;}' +
          '.hbh-cw-dist i{font-style:normal;font-size:11px;color:rgba(244,244,244,.62);margin-right:6px;}' +
          '.hbh-cw-arrow{color:#ff9a3c;font-size:13px;}' +
          '.hbh-cw-dist.is-close b,.hbh-cw-dist.is-close .hbh-cw-arrow{color:#5ae673;}' +
          '.hbh-cw-foot{margin-top:3px;display:flex;justify-content:space-between;font-size:10px;letter-spacing:1px;text-transform:uppercase;color:rgba(244,244,244,.55);}' +
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
          '.hbh-badge-boss{border-color:#ff5a36;color:#ff5a36;}' +
          '.hbh-badge-pink{border-color:#ff7eb6;color:#ff7eb6;}' +
          '.hbh-badge-chain{border-color:#ffd23f;color:#ffd23f;}' +
          '.hbh-badge-bet{border-color:#8fe388;color:#8fe388;}' +
          /* Wett-Angebot unter "Tempo angleichen" */
          '.hbh-betoffer{text-align:center;margin-top:6px;font-style:italic;animation:hbhFade .3s ease-out;}' +
          '.hbh-betoffer b{font-size:15px;font-weight:900;letter-spacing:1.5px;color:#8fe388;}' +
          '.hbh-bet-t{display:inline-block;margin-left:8px;min-width:20px;font-size:12px;font-weight:800;color:var(--dim);font-style:normal;}' +
          '.hbh-betoffer small{display:block;font-size:10px;letter-spacing:1px;color:var(--dim);font-style:normal;margin-top:1px;}' +
          '.hbh-blockers{text-align:center;margin-top:6px;font-size:10px;font-weight:800;letter-spacing:2px;color:#ffd23f;}' +
          /* Stopp-Zeichen */
          '.hbh-fx{position:fixed;left:0;right:0;top:34%;display:flex;flex-direction:column;align-items:center;z-index:40;pointer-events:none;' +
            'font-family:"Overpass","Noto Sans","Segoe UI",sans-serif;color:#f4f4f4;text-shadow:0 1px 3px rgba(0,0,0,.9);animation:hbhFxIn .28s ease-out;}' +
          '.hbh-fx-out{animation:hbhFxOut .35s ease-in forwards;}' +
          '.hbh-fx-sign{width:96px;height:96px;filter:drop-shadow(0 0 14px rgba(224,30,18,.55)) drop-shadow(0 2px 4px rgba(0,0,0,.9));}' +
          '.hbh-fx-sign svg{width:100%;height:100%;}' +
          '.hbh-fx-ring{fill:rgba(12,12,14,.55);stroke:#e01e12;stroke-width:8;}' +
          '.hbh-fx-x{stroke:#f4f4f4;stroke-width:10;stroke-linecap:round;fill:none;}' +
          '.hbh-fx-player .hbh-fx-ring{stroke:#ff6600;}' +
          '.hbh-fx-band{margin-top:8px;padding:2px 46px;transform:skewX(-20deg);' +
            'background:linear-gradient(to right,rgba(224,30,18,0),rgba(224,30,18,.9) 18%,rgba(224,30,18,.9) 82%,rgba(224,30,18,0));}' +
          '.hbh-fx-player .hbh-fx-band{background:linear-gradient(to right,rgba(255,102,0,0),rgba(255,102,0,.9) 18%,rgba(255,102,0,.9) 82%,rgba(255,102,0,0));}' +
          '.hbh-fx-band span{display:inline-block;transform:skewX(20deg);font-size:20px;font-weight:900;font-style:italic;letter-spacing:4px;}' +
          '.hbh-fx-who{margin-top:5px;font-size:13px;font-weight:800;letter-spacing:2px;text-transform:uppercase;}' +
          '.hbh-fx-text{margin-top:2px;font-size:12px;font-style:italic;color:rgba(244,244,244,.75);}' +
          '@keyframes hbhFxIn{0%{opacity:0;transform:scale(1.35);}60%{opacity:1;transform:scale(.96);}100%{transform:none;}}' +
          '@keyframes hbhFxOut{to{opacity:0;transform:scale(.9);}}' +
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
          '.hbh-title-r{text-align:right;display:flex;align-items:center;justify-content:flex-end;gap:7px;overflow:visible;}' +
          '.hbh-rname{min-width:0;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbh-rname small{font-size:10px;letter-spacing:.8px;opacity:.8;}' +
          /* Team-Logo / Wanderer-Siegel: dezent, ragt etwas über die Zeile, leichter Schatten wie ein Aufkleber */
          '.hbh{position:relative;}' +
          '.hbh{padding-left:108px !important;padding-right:108px !important;}' +
          '.hbh-slot{position:absolute;top:4px;width:84px;height:84px;object-fit:contain;filter:drop-shadow(0 2px 5px rgba(0,0,0,.85));}' +
          '.hbh-slot-l{left:14px;width:64px;height:64px;top:14px;}' +
          '.hbh-slot-l.hbh-slot-own{left:12px;width:84px;height:84px;top:4px;}' +
          '.hbh-slot-r{right:12px;animation:hbhEmblem .35s ease-out;}' +
          '@keyframes hbhEmblem{from{opacity:0;transform:scale(.8) rotate(-6deg);}to{opacity:1;transform:none;}}' +
          '.hbh-gap{font-size:10px;font-weight:800;letter-spacing:2px;color:var(--o2);padding:1px 10px 0;' +
            'background:rgba(0,0,0,.45);border-radius:2px;}' +
          '.hbh-gap b{font-size:14px;margin-left:8px;letter-spacing:0;color:var(--w);}' +
          '.hbh-gap i{font-style:normal;margin-left:2px;color:var(--dim);}' +
          '.hbh-gap-lead{color:#8fe388;}' +

          /* Countdown und Ergebnis */
          '.hbh-count{text-align:center;margin-top:4px;height:62px;}' +
          '.hbh-sync{text-align:center;margin-top:18px;font-size:14px;font-weight:900;font-style:italic;letter-spacing:2px;text-transform:uppercase;color:#ffd23f;text-shadow:0 1px 3px rgba(0,0,0,.9);animation:hbhSyncPulse .5s ease-in-out infinite alternate;}' +
          '@keyframes hbhSyncPulse{from{opacity:1;}to{opacity:.45;}}' +
          '.hbh-count span{display:inline-block;font-size:58px;line-height:62px;font-weight:900;font-style:italic;color:var(--o);' +
            'text-shadow:0 0 18px rgba(255,102,0,.55),0 2px 4px rgba(0,0,0,.9);animation:hbhPop .9s ease-out;}' +
          '@keyframes hbhPop{0%{transform:scale(1.8);opacity:0;}25%{transform:scale(1);opacity:1;}100%{transform:scale(.92);opacity:.85;}}' +
          '.hbh-result{margin-top:4px;text-align:center;}' +
          '.hbh-result-band{display:inline-block;padding:4px 60px;transform:skewX(-20deg);animation:hbhSlide .35s ease-out;' +
            'background:linear-gradient(to right,rgba(255,102,0,0),rgba(255,102,0,.92) 18%,rgba(255,102,0,.92) 82%,rgba(255,102,0,0));}' +
          '.hbh-lose .hbh-result-band{background:linear-gradient(to right,rgba(40,40,44,0),rgba(40,40,44,.92) 18%,rgba(40,40,44,.92) 82%,rgba(40,40,44,0));}' +
          '.hbh-result-band span{display:inline-block;transform:skewX(20deg);font-size:30px;font-weight:900;font-style:italic;letter-spacing:4px;}' +
          '.hbh-quote{margin:6px auto 0;max-width:560px;text-align:center;font-size:13px;font-style:italic;line-height:17px;' +
            'color:var(--w);padding:4px 14px;background:rgba(12,12,14,.6);border-left:3px solid var(--o);animation:hbhFade .4s ease-out;}' +
          '.hbh-quote-who{display:block;font-size:9px;font-style:normal;font-weight:800;letter-spacing:2px;color:var(--o2);text-transform:uppercase;}' +
          '@keyframes hbhFade{from{opacity:0;transform:translateY(-4px);}to{opacity:1;transform:none;}}' +
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
      scope.playerMark = '/ui/ui-vue/mods/hashiriyaBattle/assets/icon.png'
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

      // Stopp-Zeichen (Rivale lehnt ab): ttl Sekunden sichtbar, dann ausblenden
      scope.fx = null
      scope.fxOut = false
      var fxTimer = null, fxOutTimer = null
      scope.$on('HashiriyaBattleFx', function (event, data) {
        scope.$evalAsync(function () {
          if (!data || data.kind !== 'decline') return
          clearTimeout(fxTimer); clearTimeout(fxOutTimer)
          scope.fx = data
          scope.fxOut = false
          var ms = Math.max(800, (data.ttl || 2.6) * 1000)
          fxOutTimer = setTimeout(function () { scope.$evalAsync(function () { scope.fxOut = true }) }, ms - 350)
          fxTimer = setTimeout(function () { scope.$evalAsync(function () { scope.fx = null; scope.fxOut = false }) }, ms)
        })
      })

      scope.fmtStart = function (m) { return String((scope.t && scope.t['hud.chainWait.start']) || '%d m').replace('%d', m) }

      scope.$on('HashiriyaState', function (event, data) {
        scope.$evalAsync(function () {
          var b = (data && data.battle) || null
          if (b && (!scope.b || scope.b.state === 'result') && (b.state === 'countdown' || b.state === 'sync')) { lastP = null; lastR = null }
          scope.b = b
          scope.t = (data && data.t) || scope.t
          if (!b || b.chainWait) { lastP = null; lastR = null; return }
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
