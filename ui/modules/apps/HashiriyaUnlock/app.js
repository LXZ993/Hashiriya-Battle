// Hashiriya Battle: Meldung "Neue Teile freigeschaltet" (links am Rand, schiebt sich herein und geht von selbst).
// Kommt, wenn eine Tuning-Stufe aus tuning.json (tiers) frei wird, aber erst nach dem Battle (shop.lua, unlockNotice).
// Daten: Hook 'HashiriyaState' -> unlock = { level, key, reason, carName, total, cats = [{ id, name, count, group }], more, left, seconds }.
angular.module('beamng.apps')
.directive('hashiriyaUnlock', [function () {
  return {
    template:
      '<div class="bngApp hbu-root">' +
        '<div class="hbu" ng-if="n" ng-class="[\'hbu-lv\' + n.level, {\'is-out\': out}]">' +
          '<div class="hbu-head"><span class="hbu-net">HashiNet</span><span class="hbu-title">{{ t(\'unlock.title\') }}</span></div>' +
          '<div class="hbu-tier">' +
            '<div class="hbu-badge"><small>LV</small>{{ n.level }}</div>' +
            '<div class="hbu-tier-txt"><span class="hbu-tier-name">{{ t(\'unlock.tier\') }} LV{{ n.level }}</span>' +
              '<span class="hbu-reason" ng-if="n.reason">{{ n.reason }}</span></div>' +
          '</div>' +
          '<div class="hbu-list" ng-if="n.total">' +
            '<div class="hbu-car"><span>{{ fmt(t(\'unlock.forCar\'), n.carName) }}</span><b>{{ n.total }}</b> {{ t(\'unlock.parts\') }}</div>' +
            '<div class="hbu-row" ng-repeat="c in n.cats track by c.id" ng-style="{\'animation-delay\': (0.35 + $index * 0.07) + \'s\'}">' +
              '<i class="hbu-dot" ng-class="\'g-\' + c.group"></i><span class="hbu-cat">{{ c.name }}</span><span class="hbu-fill"></span><b>+{{ c.count }}</b></div>' +
            '<div class="hbu-more" ng-if="n.more">{{ fmt(t(\'unlock.more\'), n.more) }}</div>' +
          '</div>' +
          '<div class="hbu-all" ng-if="!n.total">{{ t(\'unlock.allCars\') }}</div>' +
          '<div class="hbu-where">{{ t(\'unlock.where\') }}</div>' +
          '<div class="hbu-time"><span ng-style="{width: (n.left / n.seconds * 100) + \'%\'}"></span></div>' +
        '</div>' +
        '<style>' +
          '.hbu-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;' +
            'font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;color:#f4f4f4;}' +
          '.hbu{--lv:#ff6600;--lvBg:rgba(255,102,0,.18);position:absolute;left:0;top:0;width:400px;padding:12px 18px 0 20px;' +
            'background:linear-gradient(90deg,rgba(14,15,18,.92),rgba(14,15,18,.8) 75%,rgba(14,15,18,.55));' +
            'border-left:4px solid var(--lv);box-shadow:0 8px 28px rgba(0,0,0,.55);text-shadow:0 1px 2px rgba(0,0,0,.7);' +
            'clip-path:polygon(0 0,100% 0,calc(100% - 14px) 100%,0 100%);animation:hbuIn .5s cubic-bezier(.2,.9,.25,1) both;}' +
          '.hbu.is-out{animation:hbuOut .45s ease-in both;}' +
          '.hbu-lv1{--lv:#3fbf5a;--lvBg:#2f6f3a;}' +
          '.hbu-lv2{--lv:#4d93ec;--lvBg:#2c5d9c;}' +
          '.hbu-lv3{--lv:#ff5a3c;--lvBg:#9c3a2c;}' +
          // Lichtstreifen, der einmal über die Karte läuft
          '.hbu:before{content:"";position:absolute;top:0;bottom:0;left:-40%;width:35%;pointer-events:none;' +
            'background:linear-gradient(100deg,transparent,rgba(255,255,255,.12),transparent);animation:hbuSweep 1.1s .35s ease-out both;}' +
          '.hbu-head{display:flex;align-items:baseline;gap:10px;font-size:11px;letter-spacing:2.5px;text-transform:uppercase;}' +
          '.hbu-net{font-weight:900;font-style:italic;color:#ff6600;}' +
          '.hbu-title{font-weight:700;color:rgba(244,244,244,.85);}' +
          '.hbu-tier{display:flex;align-items:center;gap:14px;margin:8px 0 10px;}' +
          '.hbu-badge{flex:none;min-width:64px;height:52px;padding:0 10px;display:flex;align-items:center;justify-content:center;gap:2px;' +
            'background:var(--lvBg);color:#fff;font-size:36px;font-weight:900;font-style:italic;line-height:1;' +
            'clip-path:polygon(12% 0,100% 0,88% 100%,0 100%);box-shadow:inset 0 -3px 0 var(--lv);animation:hbuPop .5s .25s cubic-bezier(.3,1.6,.5,1) both;}' +
          '.hbu-badge small{font-size:14px;margin-top:12px;opacity:.85;}' +
          '.hbu-tier-txt{display:flex;flex-direction:column;gap:3px;min-width:0;}' +
          '.hbu-tier-name{font-size:20px;font-weight:900;font-style:italic;letter-spacing:.5px;text-transform:uppercase;}' +
          '.hbu-reason{font-size:12px;color:var(--lv);letter-spacing:1px;}' +
          '.hbu-list{border-top:1px solid rgba(255,255,255,.12);padding-top:7px;}' +
          '.hbu-car{font-size:11px;letter-spacing:1px;color:rgba(244,244,244,.65);margin-bottom:4px;display:flex;gap:6px;align-items:baseline;}' +
          '.hbu-car span{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}' +
          '.hbu-car b{color:#f4f4f4;font-size:14px;font-style:italic;}' +
          '.hbu-row{display:flex;align-items:center;gap:8px;height:22px;font-size:14px;animation:hbuRow .35s ease-out both;}' +
          '.hbu-dot{width:6px;height:6px;flex:none;transform:rotate(45deg);background:#ff6600;}' +
          '.hbu-dot.g-body{background:#ff9a3c;}.hbu-dot.g-more{background:#b9bec8;}' +
          '.hbu-cat{white-space:nowrap;}' +
          '.hbu-fill{flex:1;height:1px;margin-top:4px;background:repeating-linear-gradient(90deg,rgba(255,255,255,.25) 0 2px,transparent 2px 6px);}' +
          '.hbu-row b{font-style:italic;font-variant-numeric:tabular-nums;color:var(--lv);min-width:34px;text-align:right;}' +
          '.hbu-more{font-size:11px;color:rgba(244,244,244,.55);margin-top:2px;}' +
          '.hbu-all{font-size:13px;line-height:18px;color:rgba(244,244,244,.8);border-top:1px solid rgba(255,255,255,.12);padding-top:8px;}' +
          '.hbu-where{margin-top:9px;padding-bottom:9px;font-size:10px;letter-spacing:1.6px;text-transform:uppercase;color:rgba(244,244,244,.55);}' +
          '.hbu-time{position:absolute;left:0;right:14px;bottom:0;height:3px;background:rgba(255,255,255,.08);}' +
          '.hbu-time span{display:block;height:100%;background:var(--lv);transition:width .2s linear;}' +
          '@keyframes hbuIn{from{opacity:0;transform:translateX(-110%);}to{opacity:1;transform:none;}}' +
          '@keyframes hbuOut{from{opacity:1;transform:none;}to{opacity:0;transform:translateX(-110%);}}' +
          '@keyframes hbuSweep{from{left:-40%;}to{left:110%;}}' +
          '@keyframes hbuPop{from{opacity:0;transform:scale(.6);}to{opacity:1;transform:none;}}' +
          '@keyframes hbuRow{from{opacity:0;transform:translateX(-14px);}to{opacity:1;transform:none;}}' +
        '</style>' +
      '</div>',
    replace: true,
    link: function (scope) {
      'use strict'
      scope.n = null
      scope.out = false
      var strings = {}
      var lastKey = null
      var outTimer = null
      scope.t = function (k) { return strings[k] || k }
      scope.fmt = function (s, v) { return String(s).replace(/%[sd]/, v) }
      scope.$on('HashiriyaState', function (event, data) {
        if (data && data.t) strings = data.t
        var u = data && data.active ? data.unlock : null
        scope.$evalAsync(function () {
          if (u) {
            if (outTimer) { clearTimeout(outTimer); outTimer = null }
            scope.out = u.left < 0.5
            if (u.key !== lastKey) { lastKey = u.key; scope.n = u } else if (scope.n) { scope.n.left = u.left }
          } else if (scope.n && !outTimer) {
            // Meldung ist vorbei: noch kurz hinausgleiten lassen
            scope.out = true
            outTimer = setTimeout(function () { scope.$evalAsync(function () { scope.n = null; scope.out = false; outTimer = null }) }, 450)
          }
        })
      })
      scope.$on('$destroy', function () { if (outTimer) clearTimeout(outTimer) })
    }
  }
}]);
