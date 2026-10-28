// Hashiriya Battle: Hauptmenü als UI-App, in BeamNG-Farben.
// Zustand und Texte (s.t = Übersetzungen der aktuellen Spielsprache) kommen per Hook 'HashiriyaState'
// aus core.lua, Klicks gehen per hashiriyaBattle_core.uiAction(...) zurück.
angular.module('beamng.apps')
.directive('hashiriyaMenu', ['$injector', function ($injector) {
  return {
    template:
      '<div class="bngApp hbm-root">' +
        '<div class="hbm" ng-if="s && s.menuVisible">' +
          '<div class="hbm-head">' +
            '<div class="hbm-logo">HASHIRIYA<span>BATTLE</span></div>' +
            '<div class="hbm-jp">\u8d70\u308a\u5c4b\u30d0\u30c8\u30eb</div>' +
          '</div>' +

          '<div class="hbm-body" ng-if="s.screen == \'start\'">' +
            '<div class="hbm-item" ng-click="act(\'newGame\')"><span class="hbm-num">01</span>{{ s.t[\'menu.newGame\'] }}</div>' +
            '<div class="hbm-item" ng-if="s.hasSave" ng-click="act(\'continue\')"><span class="hbm-num">02</span>{{ s.t[\'menu.continue\'] }}</div>' +
          '</div>' +

          '<div class="hbm-body" ng-if="s.screen == \'carSelect\'">' +
            '<div class="hbm-section">{{ s.t[\'menu.chooseCar\'] }}</div>' +
            '<div class="hbm-item hbm-car" ng-repeat="car in s.cars" ng-click="act(\'chooseCar\', car.id)">' +
              '<span class="hbm-num">{{ ($index + 1) < 10 ? \'0\' + ($index + 1) : ($index + 1) }}</span>' +
              '<span class="hbm-car-name">{{ car.name }}</span><span class="hbm-price">{{ car.price }}</span></div>' +
            '<div class="hbm-item hbm-sub" ng-click="act(\'back\')">{{ s.t[\'menu.back\'] }}</div>' +
          '</div>' +

          '<div class="hbm-body" ng-if="s.screen == \'status\'">' +
            '<div class="hbm-money"><span class="hbm-label">{{ s.t[\'menu.money\'] }}</span><span class="hbm-yen">{{ s.money }}</span></div>' +
            '<div class="hbm-stat"><span class="hbm-label">{{ s.t[\'menu.record\'] }}</span><b>{{ s.wins }} <i>/</i> {{ s.losses }}</b></div>' +
            '<div class="hbm-stat"><span class="hbm-label">{{ s.t[\'menu.rivalNear\'] }}</span><b>{{ s.rival || \'\u2014\' }}</b></div>' +
            '<div class="hbm-section">{{ s.t[\'menu.career\'] }}</div>' +
            '<div class="hbm-item" ng-click="act(\'save\')">{{ s.t[\'menu.save\'] }}</div>' +
            '<div class="hbm-item hbm-sub" ng-click="act(\'stop\')">{{ s.t[\'menu.stop\'] }}</div>' +
            '<div class="hbm-section">{{ s.t[\'menu.tools\'] }}</div>' +
            '<div class="hbm-item hbm-sub" ng-click="act(\'callRival\')">{{ s.t[\'menu.callRival\'] }}</div>' +
            '<div class="hbm-item hbm-sub" ng-click="act(\'capture\')">{{ s.t[\'menu.capture\'] }}</div>' +
            '<div class="hbm-item hbm-sub" ng-click="act(\'dumpConfigs\')">{{ s.t[\'menu.dumpConfigs\'] }}</div>' +
          '</div>' +

          '<div class="hbm-body" ng-if="s.screen == \'garage\' || s.screen == \'shop\'">' +
            '<div class="hbm-area"><span class="hbm-area-tag">{{ s.screen == \'garage\' ? \'P\' : \'T\' }}</span>{{ s.area }}</div>' +
            '<div class="hbm-money"><span class="hbm-label">{{ s.t[\'menu.money\'] }}</span><span class="hbm-yen">{{ s.money }}</span></div>' +
            '<div class="hbm-stat"><span class="hbm-label">{{ s.t[\'menu.car\'] }}</span><b>{{ s.carName }}</b></div>' +
            '<div ng-if="s.screen == \'garage\'">' +
              '<div class="hbm-section">{{ s.t[\'pa.garage\'] }}</div>' +
              '<div class="hbm-item" ng-class="{\'hbm-off\': !s.repairCost || !s.canAffordRepair}" ng-click="s.repairCost && s.canAffordRepair && act(\'repair\')">' +
                '<span class="hbm-car-name">{{ s.t[\'menu.repair\'] }}</span><span class="hbm-price">{{ s.repairCost || s.t[\'menu.noDamage\'] }}</span></div>' +
              '<div class="hbm-item" ng-click="act(\'save\')">{{ s.t[\'menu.save\'] }}</div>' +
            '</div>' +
            '<div ng-if="s.screen == \'shop\'">' +
              '<div class="hbm-section">{{ s.t[\'shop.title\'] }}</div>' +
              '<div class="hbm-note" ng-if="!s.shop || !s.shop.available">{{ s.t[\'shop.none\'] }}</div>' +
              '<div class="hbm-cat" ng-repeat="c in s.shop.categories track by c.id">' +
                '<div class="hbm-cat-head"><span>{{ c.name }}</span><i>{{ c.installed > 0 ? (\'LV\' + c.installed) : s.t[\'shop.stock\'] }}</i></div>' +
                '<div class="hbm-tiers">' +
                  '<div class="hbm-tier" ng-repeat="tr in c.tiers track by tr.level" ' +
                    'ng-class="{\'is-on\': tr.installed, \'is-locked\': tr.locked, \'is-poor\': !tr.locked && !tr.affordable}" ' +
                    'ng-click="!tr.installed && !tr.locked && tr.affordable && act(\'buyPart\', c.id + \':\' + tr.level)">' +
                    '<b>LV{{ tr.level }}</b><span>{{ tr.locked ? tr.lockText : tr.price }}</span></div>' +
                '</div>' +
              '</div>' +
            '</div>' +
            '<div class="hbm-hint">{{ s.t[\'menu.driveOff\'] }}</div>' +
          '</div>' +

          '<div class="hbm-foot"><span ng-click="act(\'hide\')" class="hbm-close">&#10005; {{ s.t[\'menu.hide\'] }}</span><span>{{ s.t[\'menu.hint\'] }}</span></div>' +
        '</div>' +

        '<style>' +
          '.hbm-root{width:100%;height:100%;background:transparent;box-shadow:none;}' +
          '.hbm{--o:#ff6600;--o2:#ff9a3c;--w:#f4f4f4;--dim:rgba(244,244,244,.55);' +
            'font-family:"Overpass","Noto Sans","Segoe UI",sans-serif;color:var(--w);width:100%;' +
            'background:linear-gradient(160deg,rgba(26,26,29,.94),rgba(14,14,16,.9));' +
            'box-shadow:0 8px 24px rgba(0,0,0,.55);border-left:4px solid var(--o);animation:hbmIn .22s ease-out;}' +
          '@keyframes hbmIn{from{opacity:0;transform:translateX(-14px);}to{opacity:1;transform:none;}}' +
          '.hbm-head{position:relative;padding:14px 18px 12px;overflow:hidden;' +
            'background:linear-gradient(100deg,rgba(255,102,0,.22),rgba(255,102,0,0) 70%);border-bottom:1px solid rgba(255,255,255,.08);}' +
          '.hbm-head:after{content:"";position:absolute;right:-30px;top:0;bottom:0;width:120px;transform:skewX(-28deg);' +
            'background:repeating-linear-gradient(90deg,rgba(255,102,0,.18) 0 6px,transparent 6px 14px);}' +
          '.hbm-logo{font-size:22px;font-weight:900;font-style:italic;letter-spacing:2px;line-height:1;}' +
          '.hbm-logo span{color:var(--o);margin-left:8px;}' +
          '.hbm-jp{font-size:11px;letter-spacing:4px;color:var(--dim);margin-top:5px;}' +
          '.hbm-body{padding:8px 0 6px;}' +
          '.hbm-section{font-size:10px;font-weight:800;letter-spacing:2.5px;text-transform:uppercase;color:var(--o2);padding:10px 18px 4px;}' +
          '.hbm-item{position:relative;display:flex;align-items:center;padding:9px 18px;font-size:15px;font-weight:600;letter-spacing:.5px;' +
            'cursor:pointer;transition:background .12s,padding-left .12s;}' +
          '.hbm-item:before{content:"";position:absolute;left:0;top:4px;bottom:4px;width:0;background:var(--o);transition:width .12s;}' +
          '.hbm-item:hover{background:linear-gradient(90deg,rgba(255,102,0,.28),rgba(255,102,0,0));padding-left:24px;}' +
          '.hbm-item:hover:before{width:4px;}' +
          '.hbm-sub{font-size:13px;font-weight:500;color:rgba(244,244,244,.8);padding-top:7px;padding-bottom:7px;}' +
          '.hbm-num{font-size:11px;font-weight:800;font-style:italic;color:var(--o);width:28px;flex:none;}' +
          '.hbm-car-name{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbm-price{font-size:13px;font-variant-numeric:tabular-nums;color:var(--o2);margin-left:10px;}' +
          '.hbm-label{display:block;font-size:10px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:var(--dim);}' +
          '.hbm-money{padding:8px 18px 6px;}' +
          '.hbm-yen{display:block;font-size:28px;font-weight:900;font-style:italic;font-variant-numeric:tabular-nums;color:var(--w);}' +
          '.hbm-stat{display:flex;align-items:baseline;justify-content:space-between;gap:12px;padding:3px 18px;}' +
          '.hbm-stat .hbm-label{display:inline;flex:none;}' +
          '.hbm-stat b{font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbm-stat i{font-style:normal;color:var(--dim);}' +
          '.hbm-area{display:flex;align-items:center;gap:10px;padding:10px 18px 2px;font-size:16px;font-weight:800;font-style:italic;letter-spacing:1px;text-transform:uppercase;}' +
          '.hbm-area-tag{display:inline-block;width:24px;height:24px;line-height:25px;text-align:center;font-style:normal;font-size:14px;' +
            'background:var(--o);color:#141414;border-radius:3px;}' +
          '.hbm-off{opacity:.45;cursor:default;} .hbm-off:hover{background:none;padding-left:18px;} .hbm-off:hover:before{width:0;}' +
          '.hbm-cat{padding:5px 18px 6px;border-bottom:1px solid rgba(255,255,255,.05);}' +
          '.hbm-cat-head{display:flex;justify-content:space-between;align-items:baseline;font-size:12px;font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-bottom:4px;}' +
          '.hbm-cat-head i{font-style:italic;font-weight:900;font-size:11px;color:var(--o2);}' +
          '.hbm-tiers{display:flex;gap:4px;}' +
          '.hbm-tier{flex:1;min-width:0;padding:4px 6px 3px;cursor:pointer;background:rgba(255,255,255,.06);border-bottom:2px solid transparent;' +
            'transform:skewX(-10deg);transition:background .12s;}' +
          '.hbm-tier > *{display:block;transform:skewX(10deg);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbm-tier b{font-size:11px;font-weight:900;font-style:italic;color:var(--w);}' +
          '.hbm-tier span{font-size:10px;font-variant-numeric:tabular-nums;color:var(--dim);}' +
          '.hbm-tier:hover{background:rgba(255,102,0,.3);}' +
          '.hbm-tier.is-on{background:rgba(255,102,0,.85);border-bottom-color:#fff;cursor:default;}' +
          '.hbm-tier.is-on b,.hbm-tier.is-on span{color:#141414;}' +
          '.hbm-tier.is-locked,.hbm-tier.is-poor{opacity:.4;cursor:default;} .hbm-tier.is-locked:hover,.hbm-tier.is-poor:hover{background:rgba(255,255,255,.06);}' +
          '.hbm-note{font-size:12px;line-height:1.45;color:rgba(244,244,244,.75);padding:4px 18px 8px;}' +
          '.hbm-hint{font-size:10px;letter-spacing:1.5px;text-transform:uppercase;color:var(--dim);padding:8px 18px 2px;}' +
          '.hbm-foot{display:flex;justify-content:space-between;padding:8px 18px;font-size:11px;color:var(--dim);' +
            'border-top:1px solid rgba(255,255,255,.08);background:rgba(0,0,0,.25);}' +
          '.hbm-close{cursor:pointer;} .hbm-close:hover{color:var(--o);}' +
        '</style>' +
      '</div>',
    replace: true,
    link: function (scope) {
      'use strict'
      scope.s = null
      scope.act = function (action, arg) {
        var a = arg === undefined ? 'nil' : JSON.stringify(String(arg))
        bngApi.engineLua('if extensions.hashiriyaBattle_core then extensions.hashiriyaBattle_core.uiAction("' + action + '", ' + a + ') end')
      }

      // Spielsprache an Lua melden (BeamNG-UI-Sprache, sonst Systemsprache).
      var reportLanguage = function () {
        var lang = null
        try { if ($injector.has('$translate')) lang = $injector.get('$translate').use() } catch (e) {}
        lang = lang || navigator.language || 'en'
        scope.act('setLanguage', lang)
      }
      reportLanguage()
      var langTimer = setInterval(reportLanguage, 5000)
      scope.$on('$destroy', function () { clearInterval(langTimer) })

      scope.$on('HashiriyaState', function (event, data) {
        scope.$evalAsync(function () { scope.s = data })
      })
    }
  }
}]);
