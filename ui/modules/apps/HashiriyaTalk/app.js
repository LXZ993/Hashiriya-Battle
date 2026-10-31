// Hashiriya Battle: Sprechblase unten mit Porträt des Sprechers (Silhouetten aus art/portraits).
// Der Rivale steht rechts neben der Blase (wie im SP-HUD rechts der Rivale), die Blase zeigt auf ihn.
// Daten: Hook 'HashiriyaState' (battle.quote, quoteKind, portrait, rivalName, rivalNick, rivalTag).
// Später auch für die PA-Gespräche (talk = { text, name, portrait, side }).
angular.module('beamng.apps')
.directive('hashiriyaTalk', [function () {
  return {
    template:
      '<div class="bngApp hbk-root">' +
        '<div class="hbk" ng-if="line" ng-class="[\'hbk-\' + line.side, \'hbk-k-\' + line.kind, \'hbk-t-\' + line.tag]">' +
          '<div class="hbk-pic" ng-if="line.side == \'left\'"><img ng-if="line.portrait" ng-src="{{ line.portrait }}"><div class="hbk-pic-none" ng-if="!line.portrait">?</div></div>' +
          '<div class="hbk-bubble">' +
            '<div class="hbk-who"><b>{{ line.name }}</b><span ng-if="line.nick">{{ line.nick }}</span></div>' +
            '<div class="hbk-text">{{ line.text }}</div>' +
          '</div>' +
          '<div class="hbk-pic" ng-if="line.side != \'left\'"><img ng-if="line.portrait" ng-src="{{ line.portrait }}"><div class="hbk-pic-none" ng-if="!line.portrait">?</div></div>' +
        '</div>' +
        '<style>' +
          '.hbk-root{width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;overflow:visible;' +
            '--o:#ff6600;--o2:#ff9a3c;--w:#f4f4f4;--dim:rgba(244,244,244,.65);font-family:"Overpass","Noto Sans JP",sans-serif;}' +
          '.hbk{position:absolute;left:0;right:0;bottom:0;display:flex;align-items:flex-end;gap:14px;animation:hbkIn .35s ease-out;}' +
          '.hbk-left{flex-direction:row;}' +
          '.hbk-pic{flex:none;width:150px;height:150px;position:relative;clip-path:polygon(10% 0,100% 0,90% 100%,0 100%);' +
            'background:#0e1015;box-shadow:0 0 0 2px var(--o);}' +
          '.hbk-pic img{width:100%;height:100%;display:block;}' +
          '.hbk-pic:after{content:"";position:absolute;left:0;right:0;bottom:0;height:4px;background:var(--o);}' +
          '.hbk-pic-none{width:100%;height:100%;display:flex;align-items:center;justify-content:center;font-size:64px;font-weight:900;color:rgba(255,255,255,.15);}' +
          '.hbk-bubble{position:relative;flex:1;min-height:70px;margin-bottom:22px;padding:10px 18px 12px;background:rgba(10,11,14,.88);' +
            'border:1px solid rgba(255,255,255,.12);border-top:3px solid var(--o);box-shadow:0 6px 20px rgba(0,0,0,.6);}' +
          // Zipfel der Blase zeigt zum Porträt
          '.hbk-bubble:after{content:"";position:absolute;bottom:18px;width:0;height:0;border-top:10px solid transparent;border-bottom:10px solid transparent;}' +
          '.hbk-right .hbk-bubble:after{right:-12px;border-left:12px solid rgba(10,11,14,.88);}' +
          '.hbk-left .hbk-bubble:after{left:-12px;border-right:12px solid rgba(10,11,14,.88);}' +
          '.hbk-who{display:flex;align-items:baseline;gap:8px;margin-bottom:4px;}' +
          '.hbk-who b{font-size:12px;font-weight:900;font-style:italic;letter-spacing:2px;text-transform:uppercase;color:var(--o2);}' +
          '.hbk-who span{font-size:11px;color:var(--dim);font-style:italic;}' +
          '.hbk-text{font-size:17px;line-height:23px;color:var(--w);}' +
          '.hbk-k-win .hbk-bubble{border-top-color:#e2453c;}' +
          '.hbk-k-lose .hbk-bubble{border-top-color:#8a8f99;}' +
          '.hbk-t-wanderer .hbk-pic{box-shadow:0 0 0 2px #b77bff;}' +
          '.hbk-t-boss .hbk-pic{box-shadow:0 0 0 2px #ff3b30;}' +
          '.hbk-t-leader .hbk-pic{box-shadow:0 0 0 2px #ffd23f;}' +
          '@keyframes hbkIn{from{opacity:0;transform:translateY(16px);}to{opacity:1;transform:none;}}' +
        '</style>' +
      '</div>',
    replace: true,
    link: function (scope) {
      'use strict'
      scope.line = null
      var lastKey = null
      scope.$on('HashiriyaState', function (event, data) {
        var b = data && data.battle
        var line = null
        if (b && b.quote) {
          line = { text: b.quote, kind: b.quoteKind || 'challenge', name: b.rivalName, nick: b.rivalNick,
            portrait: b.portrait, tag: b.rivalTag || 'rival', side: 'right' }
        } else if (data && data.talk && data.talk.text) {
          line = data.talk
        }
        var key = line ? (line.name + '|' + line.text) : null
        if (key === lastKey) return
        lastKey = key
        scope.$evalAsync(function () { scope.line = line })
      })
    }
  }
}]);
