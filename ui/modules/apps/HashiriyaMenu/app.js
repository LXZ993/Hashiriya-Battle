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
            '<div class="hbm-item hbm-sub" ng-click="act(\'toggleMarkers\')"><span class="hbm-car-name">{{ s.t[\'menu.markers\'] }}</span>' +
              '<span class="hbm-toggle" ng-class="{\'is-on\': s.markers}">{{ s.markers ? s.t[\'menu.on\'] : s.t[\'menu.off\'] }}</span></div>' +
            '<div class="hbm-item hbm-sub" ng-click="act(\'cheatMoney\')">{{ s.t[\'menu.cheatMoney\'] }}</div>' +
            '<div class="hbm-item hbm-sub" ng-click="act(\'cheatWins\')">{{ s.t[\'menu.cheatWins\'] }}</div>' +
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
              '<div class="hbm-tabs">' +
                '<div class="hbm-tab" ng-repeat="tb in s.shop.tabs track by tb.id" ng-class="{\'is-on\': tb.id == s.shop.tab}" ' +
                  'ng-click="act(\'shopTab\', tb.id); open.slot = null">{{ tb.name }}</div>' +
              '</div>' +
              '<div class="hbm-note" ng-if="s.shop.loading">{{ s.t[\'shop.loading\'] }}</div>' +
              '<div class="hbm-note" ng-if="!s.shop.loading && !s.shop.rows.length">{{ s.t[\'shop.none\'] }}</div>' +
              '<div class="hbm-scroll">' +
                '<div class="hbm-part" ng-repeat="r in s.shop.rows track by r.slot" ng-class="{\'is-open\': open.slot == r.slot}">' +
                  '<div class="hbm-part-head" ng-click="open.slot = (open.slot == r.slot ? null : r.slot)">' +
                    '<span class="hbm-part-name">{{ r.name }}</span>' +
                    '<span class="hbm-lv" ng-class="\'lv\' + r.currentLevel">{{ r.currentLevel > 0 ? (\'LV\' + r.currentLevel) : s.t[\'shop.stock\'] }}</span>' +
                    '<span class="hbm-part-cur">{{ r.current }}</span>' +
                  '</div>' +
                  '<div class="hbm-opts" ng-if="open.slot == r.slot">' +
                    '<div class="hbm-opt" ng-repeat="o in r.options track by o.part" ' +
                      'ng-class="{\'is-on\': o.installed, \'is-locked\': o.locked, \'is-poor\': !o.locked && !o.affordable}" ' +
                      'ng-click="!o.installed && !o.locked && o.affordable && act(\'buyPart\', r.slot + \'|\' + o.part)">' +
                      '<span class="hbm-lv" ng-class="\'lv\' + o.level">{{ o.level > 0 ? (\'LV\' + o.level) : \'\u2014\' }}</span>' +
                      '<span class="hbm-opt-name">{{ o.name }}</span>' +
                      '<span class="hbm-opt-price">{{ o.locked ? o.lockText : o.price }}</span>' +
                    '</div>' +
                  '</div>' +
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
          '.hbm-toggle{font-size:10px;font-weight:800;letter-spacing:1.5px;text-transform:uppercase;padding:1px 6px;border:1px solid var(--dim);color:var(--dim);}' +
          '.hbm-toggle.is-on{border-color:var(--o);color:var(--o);}' +
          '.hbm-tabs{display:flex;gap:3px;padding:6px 18px 8px;}' +
          '.hbm-tab{flex:1 1 auto;text-align:center;padding:5px 4px;font-size:9.5px;font-weight:800;letter-spacing:.4px;text-transform:uppercase;cursor:pointer;' +
            'background:rgba(255,255,255,.06);color:var(--dim);transform:skewX(-12deg);white-space:nowrap;overflow:hidden;}' +
          '.hbm-tab.is-on{background:var(--o);color:#141414;} .hbm-tab:hover{color:var(--w);} .hbm-tab.is-on:hover{color:#141414;}' +
          '.hbm-scroll{max-height:330px;overflow-y:auto;overflow-x:hidden;}' +
          '.hbm-scroll::-webkit-scrollbar{width:4px;} .hbm-scroll::-webkit-scrollbar-thumb{background:var(--o);}' +
          '.hbm-part{border-bottom:1px solid rgba(255,255,255,.05);}' +
          '.hbm-part-head{display:grid;grid-template-columns:1fr auto;grid-template-rows:auto auto;column-gap:8px;padding:6px 18px;cursor:pointer;}' +
          '.hbm-part-head:hover,.hbm-part.is-open .hbm-part-head{background:linear-gradient(90deg,rgba(255,102,0,.2),rgba(255,102,0,0));}' +
          '.hbm-part-name{font-size:12px;font-weight:700;letter-spacing:.8px;text-transform:uppercase;}' +
          '.hbm-part-cur{grid-column:1 / span 2;font-size:11px;color:var(--dim);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbm-lv{font-size:10px;font-weight:900;font-style:italic;color:var(--dim);}' +
          '.hbm-lv.lv1{color:#ffd27a;} .hbm-lv.lv2{color:var(--o2);} .hbm-lv.lv3{color:#ff4d4d;}' +
          '.hbm-opts{padding:2px 0 6px;background:rgba(0,0,0,.25);}' +
          '.hbm-opt{display:flex;align-items:baseline;gap:8px;padding:5px 18px 5px 24px;font-size:12px;cursor:pointer;}' +
          '.hbm-opt .hbm-lv{width:24px;flex:none;}' +
          '.hbm-opt-name{flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbm-opt-price{font-size:11px;font-variant-numeric:tabular-nums;color:var(--o2);white-space:nowrap;}' +
          '.hbm-opt:hover{background:rgba(255,102,0,.22);}' +
          '.hbm-opt.is-on{background:rgba(255,102,0,.85);color:#141414;cursor:default;}' +
          '.hbm-opt.is-on .hbm-lv,.hbm-opt.is-on .hbm-opt-price{color:#141414;}' +
          '.hbm-opt.is-locked,.hbm-opt.is-poor{opacity:.4;cursor:default;} .hbm-opt.is-locked:hover,.hbm-opt.is-poor:hover{background:none;}' +
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
      scope.open = { slot: null }
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

      // Fotomodus melden, damit die Parkplatz-Markierung ausgeblendet wird.
      var lastPhoto = null
      var checkPhoto = function () {
        var photo = false
        try { if ($injector.has('$state')) photo = /photo/i.test($injector.get('$state').current.name || '') } catch (e) {}
        if (photo !== lastPhoto) { lastPhoto = photo; scope.act('photoMode', photo ? 'true' : 'false') }
      }
      var photoTimer = setInterval(checkPhoto, 500)
      scope.$on('$destroy', function () { clearInterval(photoTimer) })
      var langTimer = setInterval(reportLanguage, 5000)
      scope.$on('$destroy', function () { clearInterval(langTimer) })

      scope.$on('HashiriyaState', function (event, data) {
        scope.$evalAsync(function () { scope.s = data })
      })
    }
  }
}]);
