// Hashiriya Battle: eigene "Messages"-App (oben links) im Design der HashiNet-Teile-Meldung.
// Ersetzt die BeamNG-App "Messages": hört auf denselben Hook 'Message' (ui_message / guihooks.trigger),
// also kommen hier sowohl die Meldungen der Mod (Kategorie 'hashiriya') als auch die vom Spiel an.
// Regeln wie im Original: gleiche Kategorie ersetzt die alte Karte, leerer Text oder ttl 0 löscht sie.
// Farben: Mod-Meldungen orange, Spiel-Meldungen grau-blau, Warnungen (Kategorie/Icon mit "warn"/"error") rot.
angular.module('beamng.apps')
.directive('hashiriyaMessages', ['$injector', function ($injector) {
  return {
    template:
      '<div class="bngApp hbm-root">' +
        '<div class="hbm" ng-repeat="m in list track by m.uid" ng-class="[\'hbm-\' + m.kind, {\'is-out\': m.out}]">' +
          '<div class="hbm-head"><span class="hbm-net">{{ m.kind === \'mod\' ? \'Hashiriya\' : \'BeamNG\' }}</span>' +
            '<span class="hbm-cat" ng-if="m.label">{{ m.label }}</span></div>' +
          '<div class="hbm-txt">{{ m.text }}</div>' +
          '<div class="hbm-time" ng-if="m.ttl > 0"><span ng-style="{\'animation-duration\': m.ttl + \'s\'}"></span></div>' +
        '</div>' +
        '<style>' +
          '.hbm-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;' +
            'font-family:"Overpass","Noto Sans JP","Segoe UI",sans-serif;color:#f4f4f4;}' +
          '.hbm{--ac:#ff6600;position:relative;width:360px;margin:0 0 6px 0;padding:8px 18px 10px 16px;box-sizing:border-box;' +
            'background:linear-gradient(90deg,rgba(14,15,18,.92),rgba(14,15,18,.8) 75%,rgba(14,15,18,.55));' +
            'border-left:4px solid var(--ac);box-shadow:0 6px 20px rgba(0,0,0,.5);text-shadow:0 1px 2px rgba(0,0,0,.7);' +
            'clip-path:polygon(0 0,100% 0,calc(100% - 12px) 100%,0 100%);animation:hbmIn .45s cubic-bezier(.2,.9,.25,1) both;}' +
          '.hbm.is-out{animation:hbmOut .4s ease-in both;}' +
          '.hbm-sys{--ac:#8fa3bf;}' +
          '.hbm-warn{--ac:#ff5a3c;}' +
          '.hbm:before{content:"";position:absolute;top:0;bottom:0;left:-40%;width:35%;pointer-events:none;' +
            'background:linear-gradient(100deg,transparent,rgba(255,255,255,.1),transparent);animation:hbmSweep 1s .3s ease-out both;}' +
          '.hbm-head{display:flex;align-items:baseline;gap:9px;font-size:10px;letter-spacing:2.4px;text-transform:uppercase;margin-bottom:3px;}' +
          '.hbm-net{font-weight:900;font-style:italic;color:var(--ac);}' +
          '.hbm-cat{font-weight:700;color:rgba(244,244,244,.6);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbm-txt{font-size:14px;line-height:19px;white-space:pre-line;word-wrap:break-word;}' +
          '.hbm-time{position:absolute;left:0;right:12px;bottom:0;height:2px;background:rgba(255,255,255,.08);}' +
          '.hbm-time span{display:block;height:100%;width:100%;background:var(--ac);transform-origin:left;animation:hbmTime linear both;}' +
          '@keyframes hbmIn{from{opacity:0;transform:translateX(-110%);}to{opacity:1;transform:none;}}' +
          '@keyframes hbmOut{from{opacity:1;transform:none;}to{opacity:0;transform:translateX(-110%);}}' +
          '@keyframes hbmSweep{from{left:-40%;}to{left:110%;}}' +
          '@keyframes hbmTime{from{transform:scaleX(1);}to{transform:scaleX(0);}}' +
        '</style>' +
      '</div>',
    replace: true,
    link: function (scope) {
      'use strict'
      var MAX = 5          // so viele Karten gleichzeitig, die älteste geht zuerst
      var uid = 0
      var timers = {}
      var $translate = null
      try { if ($injector.has('$translate')) $translate = $injector.get('$translate') } catch (e) {}
      scope.list = []

      // Text kann ein String oder { txt, context } sein (BeamNG-Übersetzungsschlüssel)
      function textOf(msg) {
        if (msg === undefined || msg === null) return ''
        if (typeof msg === 'object') {
          var key = msg.txt || msg.text || ''
          try { if ($translate) return $translate.instant(key, msg.context || {}) } catch (e) {}
          return String(key)
        }
        var s = String(msg)
        if ($translate && /^[a-z0-9_]+(\.[a-zA-Z0-9_]+)+$/.test(s)) {
          try { return $translate.instant(s) } catch (e) {}
        }
        return s
      }

      function kindOf(d) {
        var c = String(d.category || '') + ' ' + String(d.icon || '')
        if (/warn|error|fail|damage/i.test(c)) return 'warn'
        if (/hashiriya/i.test(String(d.category || ''))) return 'mod'
        return 'sys'
      }

      function labelOf(d) {
        var c = String(d.category || '')
        if (!c || /hashiriya/i.test(c) || /^[0-9a-f-]{8,}$/i.test(c)) return ''
        return c.replace(/[_.]/g, ' ')
      }

      function remove(m) {
        if (!m || m.out) return
        m.out = true
        clearTimeout(timers[m.uid])
        timers[m.uid] = setTimeout(function () {
          delete timers[m.uid]
          scope.$evalAsync(function () {
            var i = scope.list.indexOf(m)
            if (i >= 0) scope.list.splice(i, 1)
          })
        }, 420)
      }

      scope.$on('Message', function (event, d) {
        if (!d) return
        scope.$evalAsync(function () {
          var cat = d.category !== undefined && d.category !== null && d.category !== '' ? String(d.category) : null
          var text = textOf(d.msg)
          var ttl = Number(d.ttl)
          if (isNaN(ttl)) ttl = 5
          // gleiche Kategorie: alte Karte weg (sofort, ohne Animation, sonst flackert es)
          if (cat) {
            for (var i = scope.list.length - 1; i >= 0; i--) {
              if (scope.list[i].cat === cat) { clearTimeout(timers[scope.list[i].uid]); scope.list.splice(i, 1) }
            }
          }
          if (!text || ttl <= 0) return
          var m = { uid: ++uid, cat: cat, text: text, ttl: ttl, kind: kindOf(d), label: labelOf(d), out: false }
          scope.list.push(m)
          while (scope.list.filter(function (x) { return !x.out }).length > MAX) {
            remove(scope.list.filter(function (x) { return !x.out })[0])
          }
          timers[m.uid] = setTimeout(function () { scope.$evalAsync(function () { remove(m) }) }, ttl * 1000)
        })
      })

      scope.$on('ClearAllMessages', function () {
        scope.$evalAsync(function () { scope.list.slice().forEach(remove) })
      })

      scope.$on('$destroy', function () { for (var k in timers) clearTimeout(timers[k]) })
    }
  }
}]);
