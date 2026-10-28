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
            '<div class="hbm-item" ng-click="act(\'career\')"><span class="hbm-num">01</span>{{ s.t[\'menu.career\'] }}</div>' +
            '<div class="hbm-item" ng-if="s.hasSave" ng-click="act(\'continue\')"><span class="hbm-num">02</span>{{ s.t[\'menu.continue\'] }}</div>' +
          '</div>' +

          '<div class="hbm-body" ng-if="s.screen == \'carSelect\'">' +
            '<div class="hbm-section">{{ s.t[\'menu.chooseCar\'] }}</div>' +
            '<div class="hbm-item hbm-car" ng-repeat="car in s.cars" ng-click="act(\'chooseCar\', car.id)">' +
              '<span class="hbm-num">{{ ($index + 1) < 10 ? \'0\' + ($index + 1) : ($index + 1) }}</span>' +
              '<span class="hbm-car-name hbm-mq"><span>{{ car.name }}</span></span><span class="hbm-price">{{ car.price }}</span></div>' +
            '<div class="hbm-item hbm-sub" ng-click="act(\'back\')">{{ s.t[\'menu.back\'] }}</div>' +
          '</div>' +

          '<div class="hbm-body" ng-if="s.screen == \'status\'">' +
            '<div class="hbm-money"><span class="hbm-label">{{ s.t[\'menu.money\'] }}</span><span class="hbm-yen">{{ s.money }}</span></div>' +
            '<div class="hbm-stat"><span class="hbm-label">{{ s.t[\'menu.record\'] }}</span><b>{{ s.wins }} <i>/</i> {{ s.losses }}</b></div>' +
            '<div class="hbm-stat"><span class="hbm-label">{{ s.t[\'menu.rivalNear\'] }}</span><b>{{ s.rival || \'\u2014\' }}</b></div>' +
            '<div class="hbm-section">{{ s.t[\'menu.career\'] }}</div>' +
            '<div class="hbm-item" ng-click="act(\'save\')">{{ s.t[\'menu.save\'] }}</div>' +
            '<div class="hbm-item" ng-if="s.tow" ng-class="{\'hbm-off\': !s.tow.can}" ng-click="s.tow.can && towClick()" title="{{ s.tow.reason }}">' +
              '<span class="hbm-car-name">{{ towArmed ? s.t[\'menu.towConfirm\'] : s.t[\'menu.tow\'] }}</span><span class="hbm-price">{{ s.tow.can ? s.tow.cost : (s.tow.reason || s.tow.cost) }}</span></div>' +
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
            '<div class="hbm-tabs" ng-if="s.screen == \'garage\'">' +
              '<div class="hbm-tab" ng-repeat="g in [\'service\', \'parts\', \'setup\']" ng-class="{\'is-on\': g == s.garageTab}" ' +
                'ng-click="act(\'garageTab\', g); open.slot = null">{{ s.t[\'garage.tab.\' + g] }}</div>' +
            '</div>' +
            '<div ng-if="s.screen == \'garage\' && s.garageTab == \'service\'">' +
              '<div class="hbm-item" ng-class="{\'hbm-off\': !s.repairCost || !s.canAffordRepair}" ng-click="s.repairCost && s.canAffordRepair && act(\'repair\')">' +
                '<span class="hbm-car-name">{{ s.t[\'menu.repair\'] }}</span><span class="hbm-price">{{ s.repairCost || s.t[\'menu.noDamage\'] }}</span></div>' +
              '<div class="hbm-item" ng-click="act(\'save\')">{{ s.t[\'menu.save\'] }}</div>' +
              '<div class="hbm-section">{{ s.t[\'garage.plate\'] }}</div>' +
              '<div class="hbm-plate">' +
                '<input type="text" maxlength="12" ng-model="plate.text" placeholder="{{ s.plate }}">' +
                '<span class="hbm-btn hbm-btn-main" ng-class="{\'hbm-dis\': !plate.text || plate.text == s.plate}" ' +
                  'ng-click="plate.text && plate.text != s.plate && act(\'setPlate\', plate.text); plate.text = \'\'">{{ s.t[\'garage.plateChange\'] }} \u00b7 {{ s.platePrice }}</span>' +
              '</div>' +
            '</div>' +

            '<div ng-if="s.screen == \'garage\' && s.garageTab == \'setup\' && s.setup">' +
              '<div class="hbm-note" ng-if="!s.setup.cats.length">{{ s.t[\'setup.none\'] }}</div>' +
              '<div class="hbm-scroll">' +
                '<div class="hbm-part" ng-repeat="c in s.setup.cats track by c.id" ng-class="{\'is-open\': s.setup.open == c.id}">' +
                  '<div class="hbm-part-head" ng-click="act(\'setupCat\', c.id)">' +
                    '<span class="hbm-part-name">{{ c.name }}</span>' +
                    '<span class="hbm-lv lv2">{{ c.changed ? s.t[\'setup.changed\'].replace(\'%d\', c.changed) : \'\' }}</span>' +
                  '</div>' +
                  '<div class="hbm-opts" ng-if="s.setup.open == c.id">' +
                    '<div class="hbm-var" ng-repeat="v in c.rows track by v.name" ng-class="{\'is-changed\': v.changed}">' +
                      '<span class="hbm-opt-name hbm-mq"><span>{{ v.title }}</span></span>' +
                      '<span class="hbm-step" ng-class="{\'hbm-dis\': v.atMin}" ng-click="!v.atMin && act(\'setupAdjust\', v.name + \'|-1\')">&#8722;</span>' +
                      '<span class="hbm-var-val">{{ v.value }}</span>' +
                      '<span class="hbm-step" ng-class="{\'hbm-dis\': v.atMax}" ng-click="!v.atMax && act(\'setupAdjust\', v.name + \'|1\')">+</span>' +
                    '</div>' +
                  '</div>' +
                '</div>' +
              '</div>' +
              '<div class="hbm-actions" ng-if="s.setup.cats.length">' +
                '<span class="hbm-btn hbm-btn-main" ng-class="{\'hbm-dis\': !s.setup.pending}" ng-click="s.setup.pending && act(\'setupApply\')">{{ s.t[\'setup.apply\'] }}</span>' +
                '<span class="hbm-btn" ng-click="act(\'setupDefaults\')">{{ s.t[\'setup.defaults\'] }}</span>' +
                '<span class="hbm-btn" ng-class="{\'hbm-dis\': !s.setup.pending}" ng-click="s.setup.pending && act(\'setupDiscard\')">{{ s.t[\'setup.discard\'] }}</span>' +
              '</div>' +
            '</div>' +

            '<div ng-if="s.shop && (s.screen == \'shop\' || s.garageTab == \'parts\')">' +
              '<div class="hbm-note" ng-if="s.screen == \'garage\'">{{ s.t[\'garage.partsHint\'] }}</div>' +
              '<div class="hbm-tabs hbm-subtabs">' +
                '<div class="hbm-tab" ng-repeat="tb in s.shop.tabs track by tb.id" ng-class="{\'is-on\': tb.id == s.shop.tab}" ' +
                  'ng-click="act(\'shopTab\', tb.id); open.slot = null">{{ tb.name }}</div>' +
              '</div>' +
              '<div class="hbm-preview" ng-if="s.shop.preview">' +
                '<div class="hbm-preview-top"><span class="hbm-preview-tag">{{ s.t[\'shop.preview\'] }}</span>' +
                  '<span class="hbm-lv" ng-class="\'lv\' + s.shop.preview.level">{{ s.shop.preview.level > 0 ? (\'LV\' + s.shop.preview.level) : \'\' }}</span>' +
                  '<span class="hbm-opt-name hbm-mq"><span>{{ s.shop.preview.name }}</span></span>' +
                  '<span class="hbm-opt-price">{{ s.shop.preview.locked ? s.shop.preview.lockText : s.shop.preview.price }}</span></div>' +
                '<div class="hbm-actions">' +
                  '<span class="hbm-btn hbm-btn-main" ng-class="{\'hbm-dis\': s.shop.preview.locked || !s.shop.preview.affordable}" ' +
                    'ng-click="!s.shop.preview.locked && s.shop.preview.affordable && act(\'previewBuy\')">{{ s.t[\'shop.buy\'] }}</span>' +
                  '<span class="hbm-btn" ng-click="act(\'previewCancel\')">{{ s.t[\'shop.cancel\'] }}</span>' +
                '</div>' +
                '<div class="hbm-preview-hint">{{ s.t[\'shop.previewHint\'] }}</div>' +
              '</div>' +
              '<div class="hbm-note" ng-if="s.shop.loading">{{ s.t[\'shop.loading\'] }}</div>' +
              '<div class="hbm-note" ng-if="!s.shop.loading && !s.shop.rows.length">{{ s.t[\'shop.none\'] }}</div>' +
              '<div class="hbm-scroll">' +
                '<div class="hbm-part" ng-repeat="r in s.shop.rows track by r.slot" ng-class="{\'is-open\': open.slot == r.slot}">' +
                  '<div class="hbm-part-head" ng-click="toggleRow(r)">' +
                    '<span class="hbm-part-name">{{ r.name }}</span>' +
                    '<span class="hbm-lv" ng-class="\'lv\' + r.currentLevel">{{ r.currentLevel > 0 ? (\'LV\' + r.currentLevel) : s.t[\'shop.stock\'] }}</span>' +
                    '<span class="hbm-part-cur hbm-mq"><span>{{ r.current }}</span></span>' +
                  '</div>' +
                  '<div class="hbm-opts" ng-if="open.slot == r.slot">' +
                    '<div class="hbm-pslots" ng-if="r.paintSlots">' +
                      '<span ng-repeat="ps in r.paintSlots" ng-class="{\'is-on\': ps.id == r.paintSlot}" ng-click="act(\'paintSlot\', ps.id)">' +
                        '<i class="hbm-swatch" ng-style="{background: ps.swatch}"></i>{{ ps.name }}</span>' +
                    '</div>' +
                    '<div class="hbm-opt" ng-repeat="o in r.options track by o.part" ' +
                      'ng-class="{\'is-on\': o.installed, \'is-preview\': o.previewing, \'is-locked\': o.locked, \'is-poor\': !o.locked && !o.affordable}" ' +
                      'ng-click="pick(r, o)">' +
                      '<span class="hbm-swatch" ng-if="o.swatch" ng-style="{background: o.swatch}"></span>' +
                      '<span class="hbm-lv" ng-if="!o.swatch" ng-class="\'lv\' + o.level">{{ o.level > 0 ? (\'LV\' + o.level) : \'\u2014\' }}</span>' +
                      '<span class="hbm-opt-name hbm-mq"><span>{{ o.name }}</span></span>' +
                      '<span class="hbm-opt-price">{{ o.locked ? o.lockText : o.price }}</span>' +
                    '</div>' +
                    '<div class="hbm-group" ng-repeat="g in r.groups track by g.id">' +
                      '<div class="hbm-group-head" ng-class="{\'is-open\': isGroupOpen(r, g), \'is-active\': g.active}" ng-click="toggleGroup(r, g)">' +
                        '<span class="hbm-group-arrow">&#9656;</span><span class="hbm-opt-name">{{ g.name }}</span><span class="hbm-group-count">{{ g.count }}</span></div>' +
                      '<div ng-if="isGroupOpen(r, g)">' +
                      '<div class="hbm-opt hbm-opt-in" ng-repeat="o in g.options track by o.part" ' +
                        'ng-class="{\'is-on\': o.installed, \'is-preview\': o.previewing, \'is-locked\': o.locked, \'is-poor\': !o.locked && !o.affordable}" ' +
                        'ng-click="pick(r, o)">' +
                        '<span class="hbm-swatch" ng-if="o.swatch" ng-style="{background: o.swatch}"></span>' +
                        '<span class="hbm-lv" ng-if="!o.swatch" ng-class="\'lv\' + o.level">{{ o.level > 0 ? (\'LV\' + o.level) : \'\u2014\' }}</span>' +
                        '<span class="hbm-opt-name hbm-mq"><span>{{ o.name }}</span></span>' +
                        '<span class="hbm-opt-price">{{ o.locked ? o.lockText : o.price }}</span>' +
                      '</div>' +
                      '</div>' +
                    '</div>' +
                    '<div class="hbm-custom" ng-if="r.kind == \'paint\' && r.custom">' +
                      '<div class="hbm-custom-head"><span class="hbm-swatch hbm-swatch-big" ng-style="{background: customCss()}"></span>' +
                        '<span class="hbm-opt-name">{{ s.t[\'shop.customPaint\'] }}</span>' +
                        '<span class="hbm-opt-price">{{ r.custom.price }}</span></div>' +
                      '<div class="hbm-slider"><span>{{ s.t[\'shop.hue\'] }}</span><input type="range" min="0" max="360" step="1" ng-model="custom.h" class="hbm-hue"></div>' +
                      '<div class="hbm-slider"><span>{{ s.t[\'shop.saturation\'] }}</span><input type="range" min="0" max="100" step="1" ng-model="custom.s" ng-style="{background: satBg()}"></div>' +
                      '<div class="hbm-slider"><span>{{ s.t[\'shop.brightness\'] }}</span><input type="range" min="0" max="100" step="1" ng-model="custom.v" ng-style="{background: valBg()}"></div>' +
                      '<div class="hbm-slider" ng-repeat="m in materialSliders"><span>{{ s.t[m.label] }}</span>' +
                        '<input type="range" min="0" max="100" step="1" ng-model="custom[m.id]" class="hbm-plain"><b>{{ custom[m.id] }}</b></div>' +
                      '<div class="hbm-actions"><span class="hbm-btn hbm-btn-main" ng-click="previewCustom()">{{ s.t[\'shop.preview\'] }}</span></div>' +
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
          '.hbm-subtabs{display:grid;grid-template-columns:repeat(4,1fr);padding-top:2px;}' +
          '.hbm-opt.is-preview{background:rgba(255,154,60,.18);box-shadow:inset 3px 0 0 var(--o2);}' +
          '.hbm-swatch{width:14px;height:14px;flex:none;align-self:center;border-radius:2px;box-shadow:0 0 0 1px rgba(255,255,255,.35);margin-right:10px;}' +
          '.hbm-preview{margin:0 18px 8px;padding:8px 10px;border:1px solid rgba(255,154,60,.55);background:rgba(255,102,0,.1);}' +
          '.hbm-preview-top{display:flex;align-items:baseline;gap:8px;font-size:12px;}' +
          '.hbm-preview-tag{font-size:9px;font-weight:900;letter-spacing:1.5px;text-transform:uppercase;color:#141414;background:var(--o2);padding:1px 5px;}' +
          '.hbm-preview-hint{font-size:10px;color:var(--dim);margin-top:6px;}' +
          '.hbm-preview .hbm-actions{padding:8px 0 0;}' +
          '.hbm-actions{display:flex;gap:6px;padding:8px 18px 2px;}' +
          '.hbm-btn{flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;text-align:center;padding:6px 4px;font-size:10px;font-weight:800;letter-spacing:.5px;text-transform:uppercase;cursor:pointer;' +
            'background:rgba(255,255,255,.08);transform:skewX(-12deg);}' +
          '.hbm-btn:hover{background:rgba(255,255,255,.16);}' +
          '.hbm-btn-main{background:var(--o);color:#141414;} .hbm-btn-main:hover{background:var(--o2);}' +
          '.hbm-dis,.hbm-dis:hover{opacity:.35;cursor:default;}' +
          '.hbm-var{display:flex;align-items:center;gap:6px;padding:4px 18px 4px 24px;font-size:12px;}' +
          '.hbm-var.is-changed .hbm-var-val{color:var(--o2);}' +
          '.hbm-var-val{width:78px;text-align:center;font-variant-numeric:tabular-nums;font-weight:700;white-space:nowrap;}' +
          '.hbm-step{width:20px;height:20px;line-height:20px;text-align:center;flex:none;cursor:pointer;font-weight:900;background:rgba(255,255,255,.08);}' +
          '.hbm-step:hover{background:var(--o);color:#141414;}' +
          '.hbm-mq{display:block;min-width:0;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;}' +
          '.hbm-mq.is-run{text-overflow:clip;} .hbm-mq.is-run > span{display:inline-block;}' +
          '.hbm-custom{padding:8px 18px 8px 24px;border-top:1px solid rgba(255,255,255,.06);}' +
          '.hbm-custom-head{display:flex;align-items:center;gap:8px;font-size:12px;margin-bottom:6px;}' +
          '.hbm-swatch-big{width:22px;height:22px;margin-right:2px;}' +
          '.hbm-slider{display:flex;align-items:center;gap:8px;font-size:10px;letter-spacing:1px;text-transform:uppercase;color:var(--dim);margin:5px 0;}' +
          '.hbm-slider span{width:112px;flex:none;white-space:nowrap;}' +
          '.hbm-slider input{flex:1;-webkit-appearance:none;height:8px;border-radius:4px;outline:none;margin:0;}' +
          '.hbm-slider input::-webkit-slider-thumb{-webkit-appearance:none;width:12px;height:16px;background:#f4f4f4;border:2px solid #141414;border-radius:2px;cursor:pointer;}' +
          '.hbm-hue{background:linear-gradient(90deg,#f00,#ff0,#0f0,#0ff,#00f,#f0f,#f00);}' +
          '.hbm-finish{display:flex;gap:4px;margin:8px 0 2px;}' +
          '.hbm-finish span{flex:1;text-align:center;padding:4px 2px;font-size:9.5px;font-weight:800;letter-spacing:.5px;text-transform:uppercase;cursor:pointer;background:rgba(255,255,255,.06);color:var(--dim);}' +
          '.hbm-finish span.is-on{background:var(--o2);color:#141414;}' +
          '.hbm-custom .hbm-actions{padding:8px 0 0;}' +
          '.hbm-group-head{display:flex;align-items:center;gap:8px;padding:5px 18px 5px 24px;font-size:12px;font-weight:800;cursor:pointer;border-top:1px solid rgba(255,255,255,.05);}' +
          '.hbm-group-head:hover{background:rgba(255,102,0,.15);}' +
          '.hbm-group-head.is-active .hbm-opt-name{color:var(--o2);}' +
          '.hbm-group-arrow{display:inline-block;width:10px;color:var(--o);transition:transform .12s;}' +
          '.hbm-group-head.is-open .hbm-group-arrow{transform:rotate(90deg);}' +
          '.hbm-group-count{font-size:10px;color:var(--dim);font-weight:600;}' +
          '.hbm-opt-in{padding-left:42px;}' +
          '.hbm-plain{background:rgba(255,255,255,.18);}' +
          '.hbm-slider b{width:24px;text-align:right;font-size:10px;color:var(--w);font-variant-numeric:tabular-nums;}' +
          '.hbm-pslots{display:flex;gap:4px;padding:6px 18px 6px 24px;}' +
          '.hbm-pslots span{flex:1;display:flex;align-items:center;justify-content:center;gap:6px;padding:5px 2px;font-size:10px;font-weight:800;letter-spacing:.5px;text-transform:uppercase;cursor:pointer;background:rgba(255,255,255,.06);color:var(--dim);}' +
          '.hbm-pslots span.is-on{background:var(--o2);color:#141414;}' +
          '.hbm-pslots .hbm-swatch{margin:0;width:10px;height:10px;}' +
          '.hbm-plate{display:flex;gap:6px;align-items:center;padding:4px 18px 8px;}' +
          '.hbm-plate input{flex:1;min-width:0;height:26px;padding:0 8px;font:700 13px "Overpass",sans-serif;letter-spacing:1px;color:#141414;background:#f4f1e6;border:2px solid #2a2a2a;border-radius:3px;outline:none;}' +
          '.hbm-plate .hbm-btn{flex:none;padding:6px 10px;}' +
          '.hbm-note{font-size:12px;line-height:1.45;color:rgba(244,244,244,.75);padding:4px 18px 8px;}' +
          '.hbm-hint{font-size:10px;letter-spacing:1.5px;text-transform:uppercase;color:var(--dim);padding:8px 18px 2px;}' +
          '.hbm-foot{display:flex;justify-content:space-between;padding:8px 18px;font-size:11px;color:var(--dim);' +
            'border-top:1px solid rgba(255,255,255,.08);background:rgba(0,0,0,.25);}' +
          '.hbm-close{cursor:pointer;} .hbm-close:hover{color:var(--o);}' +
        '</style>' +
      '</div>',
    replace: true,
    link: function (scope, element) {
      'use strict'
      scope.s = null
      scope.open = { slot: null }
      scope.plate = { text: '' }
      // Abschleppen kostet viel: erster Klick fragt nach, zweiter Klick (innerhalb 4 s) bestätigt.
      scope.towArmed = false
      var towTimer = null
      scope.towClick = function () {
        if (scope.towArmed) { scope.towArmed = false; clearTimeout(towTimer); scope.act('tow'); return }
        scope.towArmed = true
        towTimer = setTimeout(function () { scope.$evalAsync(function () { scope.towArmed = false }) }, 4000)
      }
      // Aufgeklappte Zeile: Teil am Auto hervorheben, Kamera schwenkt drauf (zu: Ansicht zurück).
      // Felgen-Gruppen nach Zoll: die Gruppe mit dem verbauten Teil ist anfangs offen.
      scope.groups = {}
      scope.isGroupOpen = function (r, g) {
        var k = r.slot + '|' + g.id
        return scope.groups[k] === undefined ? !!g.active : scope.groups[k]
      }
      scope.toggleGroup = function (r, g) { scope.groups[r.slot + '|' + g.id] = !scope.isGroupOpen(r, g) }
      scope.toggleRow = function (r) {
        scope.open.slot = scope.open.slot == r.slot ? null : r.slot
        scope.act('focusSlot', scope.open.slot || '')
      }

      // Eigene Lackfarbe: HSV-Regler, Vorschau erst auf Knopfdruck (Auto wird dafür neu gespawnt).
      scope.custom = { h: 0, s: 80, v: 70, metallic: 0, roughness: 30, clearcoat: 100, clearcoatRoughness: 5 }
      scope.materialSliders = [
        { id: 'metallic', label: 'shop.metallic' }, { id: 'roughness', label: 'shop.roughness' },
        { id: 'clearcoat', label: 'shop.clearcoat' }, { id: 'clearcoatRoughness', label: 'shop.clearcoatRoughness' }]
      var hsv = function (h, sat, val) {
        h = (+h % 360) / 60; sat = +sat / 100; val = +val / 100
        var c = val * sat, x = c * (1 - Math.abs(h % 2 - 1)), m = val - c, r = 0, g = 0, b = 0
        if (h < 1) { r = c; g = x } else if (h < 2) { r = x; g = c } else if (h < 3) { g = c; b = x }
        else if (h < 4) { g = x; b = c } else if (h < 5) { r = x; b = c } else { r = c; b = x }
        return [r + m, g + m, b + m]
      }
      var css = function (c) { return 'rgb(' + c.map(function (v) { return Math.round(v * 255) }).join(',') + ')' }
      scope.customCss = function () { return css(hsv(scope.custom.h, scope.custom.s, scope.custom.v)) }
      scope.satBg = function () { return 'linear-gradient(90deg,' + css(hsv(scope.custom.h, 0, scope.custom.v)) + ',' + css(hsv(scope.custom.h, 100, scope.custom.v)) + ')' }
      scope.valBg = function () { return 'linear-gradient(90deg,#000,' + css(hsv(scope.custom.h, scope.custom.s, 100)) + ')' }
      scope.previewCustom = function () {
        var c = hsv(scope.custom.h, scope.custom.s, scope.custom.v)
        var m = ['metallic', 'roughness', 'clearcoat', 'clearcoatRoughness'].map(function (k) { return +scope.custom[k] / 100 })
        scope.act('customPaint', c.concat(m).map(function (v) { return v.toFixed(3) }).join(','))
      }

      // Zu lange Texte laufen beim Drüberfahren durch (Laufschrift), danach wieder zurück.
      var rowSel = '.hbm-opt, .hbm-part-head, .hbm-var, .hbm-item, .hbm-preview-top'
      var marquee = function (row, on) {
        var list = row.querySelectorAll('.hbm-mq')
        for (var i = 0; i < list.length; i++) {
          var box = list[i], inner = box.firstElementChild
          if (!inner) continue
          var over = inner.offsetWidth - box.clientWidth
          clearTimeout(box.hbmTimer)
          if (on && over > 2) {
            box.classList.add('is-run')
            inner.style.transition = 'transform ' + (over / 40 + 0.5).toFixed(2) + 's linear .35s'
            inner.style.transform = 'translateX(-' + over + 'px)'
          } else {
            inner.style.transition = 'transform .25s ease-out'
            inner.style.transform = ''
            box.hbmTimer = setTimeout(function (b) { b.classList.remove('is-run') }.bind(null, box), 280)
          }
        }
      }
      var root = element[0]
      root.addEventListener('mouseover', function (e) {
        var row = e.target.closest && e.target.closest(rowSel)
        if (row && !row.contains(e.relatedTarget)) marquee(row, true)
      })
      root.addEventListener('mouseout', function (e) {
        var row = e.target.closest && e.target.closest(rowSel)
        if (row && !row.contains(e.relatedTarget)) marquee(row, false)
      })
      // Shop: Klick baut probeweise ein (Vorschau); Garage: nur Besitz/Serie umrüsten.
      scope.pick = function (r, o) {
        if (o.installed && !o.previewing) return
        if (r.kind === 'paint') { if (!o.previewing) scope.act('buyPaint', o.part); return }
        if (o.previewing) return
        scope.act('buyPart', r.slot + '|' + (o.part || ''))
      }
      scope.act = function (action, arg) {
        // Lua-String: Steuerzeichen als \ddd, da Lua kein \uXXXX kennt
        var a = arg === undefined ? 'nil' : '"' + String(arg).replace(/[\\"]/g, '\\$&').replace(/[\u0000-\u001f\u007f]/g, function (ch) { return '\\' + ('00' + ch.charCodeAt(0)).slice(-3) }) + '"'
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
