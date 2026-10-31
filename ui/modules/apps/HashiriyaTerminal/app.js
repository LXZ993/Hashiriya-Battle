// Hashiriya Battle: HashiNet Teile-Terminal (Tuning-Shop) und Garagen-PC.
// Läuft im eigenen Layout "hashiriyaShop" über dem ganzen Bildschirm. Links das Terminal (Kategorien, Suche,
// Teile), in der Mitte ein offenes Fenster auf die echte 3D-Szene (Live-Vorschau: die Kamera steht auf dem Auto),
// rechts Fahrzeugwerte und Warenkorb. Zustand kommt per Hook 'HashiriyaState' (s.terminal), der Teilekatalog
// per Hook 'HashiriyaCatalog' (nur wenn er sich ändert). Klicks gehen an hashiriyaBattle_core.uiAction(...).
angular.module('beamng.apps')
.directive('hashiriyaTerminal', [function () {
  return {
    template:
      '<div class="hbt-root" ng-if="term">' +
        // ---------- Terminal (links) ----------
        '<div class="hbt-win hbt-main">' +
          '<div class="hbt-title"><span class="hbt-title-ico">&#9636;</span>' +
            '<span class="hbt-title-txt">{{ term.title }}</span>' +
            '<button class="hbt-cap hbt-capx" ng-click="act(\'termClose\')" title="{{ term.mode == \'garage\' ? t(\'term.close\') : t(\'shop.leave\') }}">&#10005; {{ term.mode == \'garage\' ? t(\'term.close\') : t(\'shop.leave\') }}</button></div>' +
          '<div class="hbt-bar">' +
            '<div class="hbt-addr">{{ addrText() }}</div>' +
            '<div class="hbt-search"><span class="hbt-search-ico">&#9906;</span>' +
              '<input type="text" ng-model="ui.query" ng-change="onSearch()" placeholder="{{ t(\'term.search\') }}">' +
              '<span class="hbt-search-x" ng-if="ui.query" ng-click="ui.query = \'\'; onSearch()">&#10005;</span></div>' +
          '</div>' +
          '<div class="hbt-tabs" ng-if="term.mode == \'garage\'">' +
            '<div class="hbt-tab" ng-class="{\'is-on\': ui.gtab == \'fit\'}" ng-click="ui.gtab = \'fit\'">{{ t(\'term.gtab.fit\') }}</div>' +
            '<div class="hbt-tab" ng-class="{\'is-on\': ui.gtab == \'store\'}" ng-click="ui.gtab = \'store\'">{{ t(\'term.gtab.store\') }}</div>' +
          '</div>' +
          '<div class="hbt-split">' +
            '<div class="hbt-nav" ng-if="!(term.mode == \'garage\' && ui.gtab == \'store\')">' +
              '<div ng-repeat="g in groups track by g.id">' +
                '<div class="hbt-navh">{{ t(\'term.group.\' + g.id) }}</div>' +
                '<div class="hbt-navi" ng-repeat="c in g.cats track by c.id" ng-class="{\'is-on\': c.id == ui.cat && !ui.query}" ng-click="pickCat(c.id)">' +
                  '<span>{{ c.name }}</span><span class="hbt-navn">{{ c.count || \'\' }}</span></div>' +
              '</div>' +
            '</div>' +
            '<div class="hbt-list">' +
              '<div class="hbt-note" ng-if="term.loading">{{ t(\'shop.loading\') }}</div>' +
              // Lackierer
              '<div ng-if="ui.cat == \'paint\' && !ui.query && term.paint">' +
                '<div class="hbt-grp"><span>{{ t(\'shop.item.paint\') }}</span><span class="hbt-grp-cur">{{ term.paint.current }}</span></div>' +
                '<div class="hbt-chips"><span class="hbt-chip" ng-repeat="ps in term.paint.paintSlots" ng-class="{\'is-on\': ps.id == term.paint.paintSlot}" ng-click="act(\'paintSlot\', ps.id)">' +
                  '<i class="hbt-sw" ng-style="{background: ps.swatch}"></i>{{ ps.name }}</span></div>' +
                '<div class="hbt-paints">' +
                  '<div class="hbt-paint" ng-repeat="o in term.paint.options track by o.part" ng-class="{\'is-on\': o.installed, \'is-prev\': o.previewing, \'is-poor\': !o.affordable}" ng-click="act(\'buyPaint\', o.part)">' +
                    '<i class="hbt-sw hbt-sw-l" ng-style="{background: o.swatch}"></i><span class="hbt-paint-n">{{ o.name }}</span><span class="hbt-paint-p">{{ o.price }}</span></div>' +
                '</div>' +
                '<div class="hbt-grp"><span>{{ t(\'shop.customPaint\') }}</span><span class="hbt-grp-cur">{{ term.paint.custom.price }}</span></div>' +
                '<div class="hbt-custom">' +
                  '<i class="hbt-sw hbt-sw-xl" ng-style="{background: customCss()}"></i>' +
                  '<div class="hbt-sliders">' +
                    '<label>{{ t(\'shop.hue\') }}<input type="range" min="0" max="360" ng-model="custom.h" ng-change="liveCustom()" class="hbt-hue"></label>' +
                    '<label>{{ t(\'shop.saturation\') }}<input type="range" min="0" max="100" ng-model="custom.s" ng-change="liveCustom()"></label>' +
                    '<label>{{ t(\'shop.brightness\') }}<input type="range" min="0" max="100" ng-model="custom.v" ng-change="liveCustom()"></label>' +
                    '<label ng-repeat="m in materials">{{ t(m.label) }}<input type="range" min="0" max="100" ng-model="custom[m.id]" ng-change="liveCustom()"></label>' +
                  '</div>' +
                  '<button class="hbt-btn" ng-click="previewCustom()">{{ t(\'term.toCart\') }}</button>' +
                '</div>' +
              '</div>' +
              // Teilelager (Garage)
              '<div ng-if="term.mode == \'garage\' && ui.gtab == \'store\'">' +
                '<div class="hbt-row hbt-head hbt-row-store"><span>{{ t(\'term.col.level\') }}</span><span>{{ t(\'term.col.part\') }}</span><span>{{ t(\'term.col.fits\') }}</span><span>{{ t(\'term.col.status\') }}</span><span></span></div>' +
                '<div class="hbt-note" ng-if="!storeList.length">{{ t(\'term.storeEmpty\') }}</div>' +
                '<div class="hbt-row hbt-row-store" ng-repeat="p in storeList track by p.key" ng-mouseenter="focus(p.slot)">' +
                  '<span class="hbt-lv" ng-class="\'lv\' + p.level">{{ lvText(p.level) }}</span><span>{{ p.name }}</span><span class="hbt-dim">{{ p.rowName }}</span>' +
                  '<span ng-class="p.installed ? \'hbt-ok\' : \'hbt-warn\'">{{ p.installed ? t(\'term.mounted\') : t(\'term.stored\') }}</span>' +
                  '<span class="hbt-right"><button class="hbt-btn hbt-btn-s" ng-if="!p.installed" ng-click="pick(p.row, p.opt)">{{ t(\'term.mount\') }}</button></span></div>' +
              '</div>' +
              // Teile (Kategorie oder Suchergebnis)
              '<div ng-if="!(term.mode == \'garage\' && ui.gtab == \'store\')">' +
                '<div class="hbt-note" ng-if="!term.loading && !visibleRows.length && (ui.cat != \'paint\' || ui.query)">{{ ui.query ? t(\'term.noHits\') : t(\'shop.none\') }}</div>' +
                '<div ng-repeat="r in visibleRows track by r.id">' +
                  '<div class="hbt-grp" ng-mouseenter="focus(r.slot)"><span>{{ r.name }}<span class="hbt-path" ng-if="ui.query || ui.cat == \'all\'"> · {{ r.path }}</span></span>' +
                    '<span class="hbt-grp-cur">{{ t(\'term.current\') }}: {{ r.current }}</span></div>' +
                  '<div class="hbt-hint" ng-if="r.hint">{{ r.hint }}</div>' +
                  '<div class="hbt-chips" ng-if="r.sizes && r.sizes.length > 1"><span class="hbt-chip" ng-repeat="z in r.sizes" ng-class="{\'is-on\': sizeOf(r) == z}" ng-click="setSize(r, z)">{{ z }}</span></div>' +
                  '<div class="hbt-row" ng-repeat="o in rowOptions(r) track by o.part" ng-mouseenter="focus(r.slot)" ' +
                    'ng-class="{\'is-on\': o.installed, \'is-prev\': o.previewing, \'is-locked\': o.locked, \'is-poor\': !o.locked && !canAfford(o)}" ng-click="pick(r, o)">' +
                    '<span class="hbt-lv" ng-class="\'lv\' + o.level">{{ lvText(o.level) }}</span>' +
                    '<span class="hbt-opt-n">{{ o.name }}</span>' +
                    '<span class="hbt-dim">{{ o.locked ? o.lockText : \'\' }}</span>' +
                    '<span class="hbt-right" ng-class="{\'hbt-ok\': o.free}">{{ o.price }}</span>' +
                    '<span class="hbt-right hbt-state">{{ stateText(o) }}</span></div>' +
                '</div>' +
              '</div>' +
            '</div>' +
          '</div>' +
          '<div class="hbt-status"><span>{{ statusText() }}</span><span>{{ term.unlockText }}</span></div>' +
        '</div>' +
        // ---------- Live-Vorschau (Mitte, durchsichtig) ----------
        '<div class="hbt-live">' +
          '<div class="hbt-live-frame"><span class="hbt-live-tag">{{ t(\'term.live\') }}</span>' +
            '<span class="hbt-live-part" ng-if="focusName">{{ focusName }}</span></div>' +
          '<div class="hbt-live-btns">' +
            '<button class="hbt-btn" ng-class="{\'hbt-btn-on\': term.view == \'car\'}" ng-click="act(\'termView\', \'car\')">{{ t(\'term.viewCar\') }}</button>' +
            '<button class="hbt-btn" ng-class="{\'hbt-btn-on\': term.view == \'part\'}" ng-click="act(\'termView\', \'part\')">{{ t(\'term.viewPart\') }}</button>' +
            '<button class="hbt-btn" ng-class="{\'hbt-btn-on\': term.xray}" ng-click="act(\'termXray\')">{{ t(\'term.xray\') }}</button>' +
            '<button class="hbt-btn" ng-click="act(\'termRotate\', -1)" title="{{ t(\'term.rotate\') }}">&#10226;</button>' +
            '<button class="hbt-btn" ng-click="act(\'termRotate\', 1)" title="{{ t(\'term.rotate\') }}">&#10227;</button>' +
          '</div>' +
        '</div>' +
        // ---------- Werte + Warenkorb (rechts) ----------
        '<div class="hbt-side">' +
          '<div class="hbt-win hbt-stats" ng-if="term.stats && term.stats.length">' +
            '<div class="hbt-title"><span class="hbt-title-txt">{{ term.carName }}</span></div>' +
            '<div class="hbt-stat" ng-repeat="r in term.stats"><span class="hbt-dim">{{ r.label }}</span><span>{{ r.value }} ' +
              '<b ng-if="r.delta" ng-class="r.good ? \'hbt-ok\' : \'hbt-bad\'">{{ r.delta }}</b></span></div>' +
          '</div>' +
          '<div class="hbt-win hbt-cart" ng-if="term.mode == \'shop\'">' +
            '<div class="hbt-title"><span class="hbt-title-txt">{{ t(\'shop.cart\') }} ({{ term.cart ? term.cart.count : 0 }})</span></div>' +
            '<div class="hbt-cart-list">' +
              '<div class="hbt-note" ng-if="!term.cart">{{ t(\'term.cartEmpty\') }}</div>' +
              '<div class="hbt-cart-item" ng-repeat="it in term.cart.items track by it.key" ng-mouseenter="focus(it.slot)">' +
                '<span class="hbt-lv" ng-class="\'lv\' + it.level">{{ lvText(it.level) }}</span>' +
                '<span class="hbt-cart-n">{{ it.name }}<span class="hbt-dim hbt-small">{{ it.slotName }}</span>' +
                  '<span class="hbt-bad hbt-small" ng-if="it.locked">{{ t(\'term.lockedUntil\') }} {{ it.lockText }}</span></span>' +
                '<span class="hbt-right" ng-class="{\'hbt-ok\': it.free}">{{ it.price }}</span>' +
                '<button class="hbt-cap" ng-click="act(\'cartRemove\', it.key)" title="{{ t(\'shop.cartRemove\') }}">&#10005;</button></div>' +
            '</div>' +
            '<div class="hbt-cart-foot">' +
              '<label class="hbt-toggle-row" ng-click="act(\'termMount\')"><span class="hbt-toggle" ng-class="{\'is-on\': term.mount}"><span class="hbt-knob"></span></span>' +
                '<span><b>{{ t(\'term.mountParts\') }}</b><span class="hbt-dim hbt-small">{{ term.mount ? t(\'term.mountOn\') : t(\'term.mountOff\') }}</span></span></label>' +
              '<div class="hbt-sum" ng-if="term.cart"><span>{{ t(\'shop.cartTotal\') }}</span><b ng-class="{\'hbt-bad\': !term.cart.affordable}">{{ term.cart.total }}</b></div>' +
              '<div class="hbt-sum hbt-dim" ng-if="term.cart && term.cart.affordable"><span>{{ t(\'term.after\') }}</span><span>{{ term.cart.after }}</span></div>' +
              '<div class="hbt-actions">' +
                '<button class="hbt-btn" ng-class="{\'hbt-dis\': !term.cart}" ng-click="term.cart && act(\'previewCancel\')">{{ t(\'term.clear\') }}</button>' +
                '<button class="hbt-btn hbt-btn-main" ng-class="{\'hbt-dis\': !term.cart || term.cart.locked || !term.cart.affordable}" ' +
                  'ng-click="term.cart && !term.cart.locked && term.cart.affordable && act(\'previewBuy\')">{{ t(\'shop.buy\') }}</button>' +
              '</div>' +
            '</div>' +
          '</div>' +
        '</div>' +
        // ---------- Taskleiste ----------
        '<div class="hbt-task">' +
          '<div class="hbt-orb">H</div>' +
          '<div class="hbt-tb is-on">{{ term.mode == \'garage\' ? t(\'term.garagePc\') : t(\'term.terminal\') }}</div>' +
          '<div class="hbt-tb hbt-tb-leave" ng-click="act(\'termClose\')"><span class="hbt-leave-ico">&#10140;</span>{{ term.mode == \'garage\' ? t(\'term.close\') : t(\'shop.leave\') }}</div>' +
          '<div class="hbt-tray"><span>{{ term.money }}</span><span>{{ term.carName }}</span><span>{{ term.clock }}</span></div>' +
        '</div>' +
      '</div>',
    replace: false,
    restrict: 'EA',
    link: function (scope, element) {
      var css =
        '.hbt-root{position:absolute;inset:0;pointer-events:none;font-family:"Segoe UI",Tahoma,sans-serif;font-size:13px;color:#e8edf3;}' +
        '.hbt-root *{box-sizing:border-box;}' +
        '.hbt-win{position:absolute;pointer-events:auto;display:flex;flex-direction:column;border-radius:8px;border:1px solid rgba(255,255,255,.35);' +
          'box-shadow:0 0 0 1px rgba(0,0,0,.6),0 14px 40px rgba(0,0,0,.55);background:linear-gradient(180deg,rgba(60,74,92,.95),rgba(26,33,44,.96) 34px,rgba(26,33,44,.96));overflow:hidden;}' +
        '.hbt-main{left:0.8vw;top:1.5vh;width:35vw;bottom:56px;}' +
        '.hbt-side{position:absolute;right:0.8vw;top:1.5vh;width:28vw;bottom:56px;display:flex;flex-direction:column;gap:12px;pointer-events:none;}' +
        '.hbt-side .hbt-win{position:relative;}' +
        '.hbt-stats{flex:none;}' +
        '.hbt-cart{flex:1 1 auto;min-height:0;}' +
        '.hbt-title{height:32px;flex:none;display:flex;align-items:center;gap:8px;padding:0 6px 0 12px;' +
          'background:linear-gradient(180deg,rgba(255,255,255,.22),rgba(255,255,255,.04) 50%,rgba(0,0,0,.05) 51%,rgba(255,255,255,.08));' +
          'border-bottom:1px solid rgba(0,0,0,.5);text-shadow:0 0 8px rgba(255,255,255,.35);}' +
        '.hbt-title-ico{color:#ffb070;}' +
        '.hbt-title-txt{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
        '.hbt-cap{width:26px;height:18px;border-radius:3px;border:1px solid rgba(0,0,0,.6);color:#fff;font-size:10px;line-height:14px;padding:0;cursor:pointer;' +
          'background:linear-gradient(180deg,rgba(255,255,255,.35),rgba(255,255,255,.08) 50%,rgba(0,0,0,.1) 51%);flex:none;}' +
        '.hbt-capx{width:auto;min-width:44px;padding:0 10px;font-size:11px;font-weight:700;letter-spacing:.3px;white-space:nowrap;' +
          'background:linear-gradient(180deg,#ffb3a0,#e0402a 50%,#b81e0c 51%,#ef5a36);box-shadow:0 0 6px rgba(255,60,30,.6);}' +
        '.hbt-capx:hover{background:linear-gradient(180deg,#ffc8b8,#ff5638 50%,#d42a12 51%,#ff7046);}' +
        '.hbt-bar{display:flex;align-items:center;gap:8px;padding:6px 10px;flex:none;background:linear-gradient(180deg,rgba(255,255,255,.10),rgba(255,255,255,.02));border-bottom:1px solid rgba(0,0,0,.45);}' +
        '.hbt-addr{flex:1;min-width:0;height:24px;line-height:22px;border:1px solid rgba(0,0,0,.6);border-radius:3px;background:rgba(10,14,20,.75);padding:0 8px;color:#c7d2de;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
        '.hbt-search{width:45%;height:24px;border:1px solid rgba(0,0,0,.6);border-radius:3px;background:#f6f8fb;display:flex;align-items:center;padding:0 6px;gap:4px;}' +
        '.hbt-search input{flex:1;min-width:0;border:0;outline:0;background:transparent;color:#1a2230;font:inherit;}' +
        '.hbt-search-ico{color:#475569;}' +
        '.hbt-search-x{color:#475569;cursor:pointer;padding:0 2px;}' +
        '.hbt-tabs{display:flex;gap:4px;padding:8px 10px 0;border-bottom:1px solid rgba(255,140,60,.5);flex:none;}' +
        '.hbt-tab{padding:5px 14px;border:1px solid rgba(0,0,0,.5);border-bottom:0;border-radius:4px 4px 0 0;background:rgba(255,255,255,.06);color:#c7d2de;cursor:pointer;}' +
        '.hbt-tab.is-on{background:rgba(255,102,0,.28);color:#fff;border-color:rgba(255,140,60,.6);}' +
        '.hbt-split{flex:1 1 auto;display:flex;min-height:0;}' +
        '.hbt-nav{width:170px;flex:none;overflow-y:auto;padding:6px 0;background:rgba(14,19,27,.65);border-right:1px solid rgba(0,0,0,.5);}' +
        '.hbt-navh{padding:8px 12px 3px;font-size:10px;letter-spacing:.08em;text-transform:uppercase;color:#8ea0b4;}' +
        '.hbt-navi{display:flex;justify-content:space-between;padding:4px 12px;cursor:pointer;border-top:1px solid transparent;border-bottom:1px solid transparent;}' +
        '.hbt-navi:hover{background:rgba(255,255,255,.06);}' +
        '.hbt-navi.is-on{background:linear-gradient(180deg,rgba(255,140,60,.38),rgba(255,102,0,.22));border-color:rgba(255,140,60,.5);}' +
        '.hbt-navn{color:#8ea0b4;font-size:11px;}' +
        '.hbt-list{flex:1 1 auto;min-width:0;overflow-y:auto;}' +
        '.hbt-grp{display:flex;justify-content:space-between;gap:10px;padding:10px 10px 4px;font-weight:600;color:#ffb070;border-bottom:1px solid rgba(255,140,60,.35);}' +
        '.hbt-grp-cur{color:#c7d2de;font-weight:400;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:55%;}' +
        '.hbt-path{color:#8ea0b4;font-weight:400;font-size:11px;}' +
        '.hbt-hint{padding:4px 10px;font-size:11px;color:#ffe2b0;background:rgba(201,138,42,.12);}' +
        '.hbt-row{display:grid;grid-template-columns:44px minmax(0,1fr) auto 86px 78px;align-items:center;gap:8px;padding:5px 10px;border-bottom:1px solid rgba(255,255,255,.06);cursor:pointer;}' +
        '.hbt-row:hover{background:rgba(255,255,255,.06);}' +
        '.hbt-row.is-on{cursor:default;}' +
        '.hbt-row.is-prev{background:rgba(255,102,0,.16);box-shadow:inset 0 0 0 1px rgba(255,140,60,.55);}' +
        '.hbt-row.is-locked,.hbt-row.is-poor{opacity:.55;}' +
        '.hbt-row-store{grid-template-columns:44px minmax(0,1fr) 30% 90px 90px;cursor:default;}' +
        '.hbt-head{color:#8ea0b4;font-size:10px;text-transform:uppercase;letter-spacing:.05em;background:rgba(0,0,0,.25);}' +
        '.hbt-opt-n{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
        '.hbt-state{color:#ffb070;font-size:12px;}' +
        '.hbt-right{text-align:right;}' +
        '.hbt-dim{color:#8ea0b4;}' +
        '.hbt-small{display:block;font-size:11px;}' +
        '.hbt-ok{color:#7ee08a;}' +
        '.hbt-bad{color:#ff8a7a;}' +
        '.hbt-warn{color:#ffb070;}' +
        '.hbt-lv{display:inline-block;text-align:center;font-size:10px;font-weight:700;border-radius:2px;padding:1px 3px;background:#4b5563;color:#f1f5f9;}' +
        '.hbt-lv.lv1{background:#2f6f3a;color:#e9ffe9;}.hbt-lv.lv2{background:#2c5d9c;color:#eaf3ff;}.hbt-lv.lv3{background:#9c3a2c;color:#fff0ea;}' +
        '.hbt-note{padding:12px;color:#aab6c3;}' +
        '.hbt-chips{display:flex;flex-wrap:wrap;gap:6px;padding:8px 10px;}' +
        '.hbt-chip{display:inline-flex;align-items:center;gap:5px;padding:2px 10px;border-radius:12px;border:1px solid rgba(255,255,255,.25);background:rgba(255,255,255,.06);cursor:pointer;}' +
        '.hbt-chip.is-on{border-color:#ff8a33;background:rgba(255,102,0,.3);}' +
        '.hbt-sw{display:inline-block;width:12px;height:12px;border-radius:2px;border:1px solid rgba(0,0,0,.6);}' +
        '.hbt-sw-l{width:22px;height:22px;}.hbt-sw-xl{width:56px;height:56px;flex:none;}' +
        '.hbt-paints{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:4px;padding:6px 10px;}' +
        '.hbt-paint{display:flex;align-items:center;gap:8px;padding:4px 6px;border:1px solid rgba(255,255,255,.08);cursor:pointer;}' +
        '.hbt-paint.is-on{border-color:#7ee08a;}.hbt-paint.is-prev{border-color:#ff8a33;background:rgba(255,102,0,.16);}.hbt-paint.is-poor{opacity:.55;}' +
        '.hbt-paint-n{flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}.hbt-paint-p{color:#c7d2de;font-size:12px;}' +
        '.hbt-custom{display:flex;gap:12px;align-items:flex-start;padding:8px 10px;}' +
        '.hbt-sliders{flex:1;display:flex;flex-direction:column;gap:2px;font-size:11px;color:#aab6c3;}' +
        '.hbt-sliders input{width:100%;}' +
        '.hbt-status{flex:none;height:24px;display:flex;align-items:center;justify-content:space-between;gap:14px;padding:0 10px;font-size:11px;color:#aab6c3;background:rgba(0,0,0,.35);border-top:1px solid rgba(0,0,0,.5);}' +
        '.hbt-live{position:absolute;left:36.6vw;right:29.6vw;top:1.5vh;bottom:56px;pointer-events:none;}' +
        '.hbt-live-frame{position:absolute;inset:0;border-radius:8px;border:6px solid rgba(40,50,64,.55);box-shadow:inset 0 0 0 1px rgba(255,255,255,.3),0 0 0 1px rgba(0,0,0,.6);}' +
        '.hbt-live-tag{position:absolute;left:8px;top:6px;font-size:10px;letter-spacing:.12em;color:#fff;background:rgba(0,0,0,.45);padding:2px 6px;}' +
        '.hbt-live-tag:before{content:"";display:inline-block;width:7px;height:7px;border-radius:50%;background:#ff3b2f;margin-right:6px;}' +
        '.hbt-live-part{position:absolute;right:8px;top:6px;max-width:70%;font-size:12px;background:rgba(0,0,0,.55);border:1px solid #ff8a33;padding:2px 8px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
        '.hbt-live-btns{position:absolute;left:12px;right:12px;bottom:12px;display:flex;flex-wrap:wrap;justify-content:center;gap:6px;pointer-events:auto;}' +
        '.hbt-btn{height:26px;padding:0 12px;border-radius:3px;border:1px solid #1b2430;cursor:pointer;color:#16202c;font:inherit;font-size:12px;' +
          'background:linear-gradient(180deg,#f4f6f9,#dde3ea 50%,#cdd5df 51%,#e3e8ee);}' +
        '.hbt-btn:hover{background:linear-gradient(180deg,#fff,#eaf2fb 50%,#d5e4f5 51%,#eef5fd);}' +
        '.hbt-btn-s{height:22px;padding:0 8px;}' +
        '.hbt-btn-on,.hbt-btn-main{border-color:#7a2e00;color:#fff;text-shadow:0 1px 1px rgba(0,0,0,.4);background:linear-gradient(180deg,#ffb27a,#ff7a1f 50%,#f06000 51%,#ff8a33);}' +
        '.hbt-btn-main{font-weight:700;}' +
        '.hbt-dis{opacity:.45;cursor:default;}' +
        '.hbt-stat{display:flex;justify-content:space-between;padding:4px 12px;border-bottom:1px solid rgba(255,255,255,.05);}' +
        '.hbt-cart-list{flex:1 1 auto;overflow-y:auto;min-height:0;}' +
        '.hbt-cart-item{display:grid;grid-template-columns:44px minmax(0,1fr) auto 26px;gap:8px;align-items:center;padding:7px 10px;border-bottom:1px solid rgba(255,255,255,.07);}' +
        '.hbt-cart-n{min-width:0;}' +
        '.hbt-cart-foot{flex:none;padding:10px 12px;background:rgba(0,0,0,.3);border-top:1px solid rgba(0,0,0,.5);display:flex;flex-direction:column;gap:8px;}' +
        '.hbt-toggle-row{display:flex;align-items:center;gap:10px;cursor:pointer;}' +
        '.hbt-toggle{width:40px;height:20px;border-radius:10px;background:#3b4654;border:1px solid #11161c;position:relative;flex:none;}' +
        '.hbt-toggle.is-on{background:#ff6600;border-color:#7a2e00;}' +
        '.hbt-knob{position:absolute;left:2px;top:2px;width:14px;height:14px;border-radius:50%;background:#fff;transition:left .15s;}' +
        '.hbt-toggle.is-on .hbt-knob{left:22px;}' +
        '.hbt-sum{display:flex;justify-content:space-between;align-items:baseline;}' +
        '.hbt-sum b{font-size:16px;}' +
        '.hbt-actions{display:flex;justify-content:flex-end;gap:8px;}' +
        '.hbt-task{position:absolute;left:0;right:0;bottom:0;height:44px;pointer-events:auto;display:flex;align-items:center;gap:10px;padding:0 8px;' +
          'background:linear-gradient(180deg,rgba(40,48,60,.95),rgba(8,10,14,.97) 50%,#000);border-top:1px solid rgba(255,255,255,.25);}' +
        '.hbt-orb{width:36px;height:36px;border-radius:50%;flex:none;display:flex;align-items:center;justify-content:center;font-weight:800;color:#fff;' +
          'background:radial-gradient(circle at 50% 30%,#ffd0a0,#ff6600 55%,#7a2a00);border:1px solid rgba(0,0,0,.7);box-shadow:0 0 10px rgba(255,102,0,.6);}' +
        '.hbt-tb{height:32px;min-width:150px;display:flex;align-items:center;padding:0 12px;border-radius:3px;border:1px solid rgba(255,255,255,.25);cursor:pointer;' +
          'background:linear-gradient(180deg,rgba(255,255,255,.18),rgba(255,255,255,.04) 50%,rgba(0,0,0,.1) 51%);}' +
        '.hbt-tb.is-on{border-color:rgba(255,170,110,.8);background:linear-gradient(180deg,rgba(255,170,110,.45),rgba(255,102,0,.25) 50%,rgba(150,50,0,.3) 51%);cursor:default;}' +
        '.hbt-tb-leave{height:36px;min-width:200px;justify-content:center;gap:10px;font-size:15px;font-weight:800;letter-spacing:.6px;text-transform:uppercase;color:#fff;' +
          'text-shadow:0 1px 2px rgba(0,0,0,.7);border:1px solid #ffb09c;border-radius:4px;' +
          'background:linear-gradient(180deg,#ff9a7e,#e8381c 48%,#b71a06 52%,#ff5a2e);animation:hbtLeaveGlow 1.6s ease-in-out infinite;}' +
        '.hbt-tb-leave:hover{background:linear-gradient(180deg,#ffb59e,#ff4a26 48%,#d42408 52%,#ff7448);border-color:#fff;}' +
        '.hbt-leave-ico{font-size:18px;line-height:1;}' +
        '@keyframes hbtLeaveGlow{0%,100%{box-shadow:0 0 6px rgba(255,70,30,.55),inset 0 0 0 1px rgba(255,255,255,.25);}' +
          '50%{box-shadow:0 0 18px rgba(255,90,40,.95),inset 0 0 0 1px rgba(255,255,255,.4);}}' +
        '.hbt-tray{margin-left:auto;display:flex;gap:18px;align-items:center;height:32px;padding:0 12px;border-left:1px solid rgba(255,255,255,.2);}'
      var styleEl = document.createElement('style')
      styleEl.textContent = css
      element[0].appendChild(styleEl)

      scope.term = null
      scope.strings = {}
      scope.catalog = { rows: [], categories: [], version: -1 }
      scope.ui = { cat: 'engine', query: '', gtab: 'fit', sizes: {} }
      scope.groups = []
      scope.visibleRows = []
      scope.storeList = []
      scope.focusName = ''
      scope.custom = { h: 20, s: 90, v: 85, metallic: 30, roughness: 40, clearcoat: 80, clearcoatRoughness: 10 }
      scope.materials = [{ id: 'metallic', label: 'shop.metallic' }, { id: 'roughness', label: 'shop.roughness' },
        { id: 'clearcoat', label: 'shop.clearcoat' }, { id: 'clearcoatRoughness', label: 'shop.clearcoatRoughness' }]

      scope.t = function (k) { return (scope.strings && scope.strings[k]) || k }
      scope.lvText = function (lv) { return lv > 0 ? 'LV' + lv : (lv < 0 ? '\u2013' : scope.t('shop.stock')) }

      scope.act = function (action, arg) {
        var a = arg === undefined ? 'nil' : '"' + String(arg).replace(/[\\"]/g, '\\$&').replace(/[\u0000-\u001f\u007f]/g, function (ch) { return '\\' + ('00' + ch.charCodeAt(0)).slice(-3) }) + '"'
        bngApi.engineLua('if extensions.hashiriyaBattle_core then extensions.hashiriyaBattle_core.uiAction("' + action + '", ' + a + ') end')
      }

      // Kategorien nach Gruppen (Mechaniker, Bodyshop, Weiteres); Lackierer nur im Shop
      var rebuildGroups = function () {
        var byGroup = {}, order = []
        var counts = {}
        scope.catalog.rows.forEach(function (r) { counts[r.cat] = (counts[r.cat] || 0) + garageOpts(r).length })
        scope.catalog.categories.forEach(function (c) {
          if (c.id === 'paint' && scope.term && scope.term.mode === 'garage') return
          if (!byGroup[c.group]) { byGroup[c.group] = { id: c.group, cats: [] }; order.push(byGroup[c.group]) }
          var n = c.id === 'all' ? null : counts[c.id]
          if (c.id !== 'paint' && c.id !== 'all' && !n) return
          byGroup[c.group].cats.push({ id: c.id, name: c.name, count: n })
        })
        scope.groups = order.filter(function (g) { return g.cats.length })
      }

      // Garage: nur Teile im Besitz (und das verbaute) zeigen
      var garageOpts = function (r) {
        if (!scope.term || scope.term.mode !== 'garage') return r.options
        return r.options.filter(function (o) { return o.owned || o.installed })
      }

      var norm = function (s) { return String(s || '').toLowerCase() }
      var rebuildRows = function () {
        var q = norm(scope.ui.query).trim()
        var words = q ? q.split(/\s+/) : []
        var garage = scope.term && scope.term.mode === 'garage'
        var out = []
        scope.catalog.rows.forEach(function (r) {
          var opts = garageOpts(r)
          if (garage && opts.length < 2) return
          if (!words.length) {
            if (r.cat === scope.ui.cat || (scope.ui.cat === 'all' && r.inAll)) out.push(r)
            return
          }
          var hay = norm(r.name + ' ' + r.path + ' ' + r.slot)
          var rowHit = words.every(function (w) { return hay.indexOf(w) >= 0 })
          if (rowHit) { out.push(r); return }
          var hits = opts.filter(function (o) {
            var h = norm(o.name + ' ' + o.part)
            return words.every(function (w) { return h.indexOf(w) >= 0 || hay.indexOf(w) >= 0 })
          })
          if (hits.length) out.push(angular.extend({}, r, { options: hits, searchHit: true }))
        })
        scope.visibleRows = out
        // Teilelager: alle Teile im Besitz (Garage)
        var store = []
        scope.catalog.rows.forEach(function (r) {
          r.options.forEach(function (o) {
            if (!o.owned) return
            var h = norm(o.name + ' ' + r.name + ' ' + r.path)
            if (words.length && !words.every(function (w) { return h.indexOf(w) >= 0 })) return
            store.push({ key: r.id + '|' + o.part, slot: r.slot, row: r, opt: o, name: o.name, rowName: r.name, level: o.level, installed: o.installed })
          })
        })
        store.sort(function (a, b) { return a.rowName < b.rowName ? -1 : a.rowName > b.rowName ? 1 : 0 })
        scope.storeList = store
      }

      scope.rowOptions = function (r) {
        var opts = garageOpts(r)
        if (!r.sizes || r.sizes.length < 2 || r.searchHit) return opts
        var z = scope.sizeOf(r)
        return opts.filter(function (o) { return !o.size || o.size === z || o.installed || o.previewing })
      }
      scope.sizeOf = function (r) { return scope.ui.sizes[r.id] || r.curSize || (r.sizes && r.sizes[0]) }
      scope.setSize = function (r, z) { scope.ui.sizes[r.id] = z }

      scope.pickCat = function (id) {
        scope.ui.cat = id
        scope.ui.query = ''
        rebuildRows()
        scope.act('termCat', id)
      }
      scope.onSearch = function () { rebuildRows() }

      scope.canAfford = function (o) { return o.owned || o.free || !scope.term || scope.term.moneyRaw >= (o.priceRaw || 0) }
      scope.stateText = function (o) {
        if (o.installed) return scope.t('term.mounted')
        if (o.previewing) return scope.t('term.inCart')
        if (o.owned) return scope.t('term.stored')
        return ''
      }
      scope.pick = function (r, o) {
        if (o.installed && !o.previewing) return
        if (o.previewing) return scope.act('cartRemove', 'part:' + r.slot)
        scope.act('buyPart', r.slot + '|' + o.part)
      }

      // Teil in der Vorschau hervorheben (nur wenn sich der Slot ändert)
      var lastFocus = null
      scope.focus = function (slot) {
        if (!slot || slot === lastFocus) return
        lastFocus = slot
        var r = scope.catalog.rows.filter(function (x) { return x.slot === slot })[0]
        scope.focusName = r ? r.name : ''
        scope.act('focusSlot', slot)
      }

      scope.addrText = function () {
        if (scope.ui.query) return scope.t('term.searchFor') + ' "' + scope.ui.query + '"'
        var c = scope.catalog.categories.filter(function (x) { return x.id === scope.ui.cat })[0]
        return scope.t('term.catalog') + ' \u25b8 ' + (c ? c.name : '')
      }
      scope.statusText = function () {
        if (scope.term && scope.term.mode === 'garage' && scope.ui.gtab === 'store') return scope.storeList.length + ' ' + scope.t('term.partsOwned')
        var n = 0
        scope.visibleRows.forEach(function (r) { n += scope.rowOptions(r).length })
        return n + ' ' + scope.t('term.partsShown')
      }

      var hsv = function (h, sat, val) {
        sat /= 100; val /= 100
        var c = val * sat, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = val - c
        var r = 0, g = 0, b = 0
        if (h < 60) { r = c; g = x } else if (h < 120) { r = x; g = c } else if (h < 180) { g = c; b = x }
        else if (h < 240) { g = x; b = c } else if (h < 300) { r = x; b = c } else { r = c; b = x }
        return [r + m, g + m, b + m]
      }
      scope.customCss = function () {
        var c = hsv(+scope.custom.h, +scope.custom.s, +scope.custom.v)
        return 'rgb(' + c.map(function (v) { return Math.round(v * 255) }).join(',') + ')'
      }
      var customArg = function () {
        var c = hsv(+scope.custom.h, +scope.custom.s, +scope.custom.v)
        var m = scope.materials.map(function (k) { return +scope.custom[k.id] / 100 })
        return c.concat(m).map(function (v) { return v.toFixed(3) }).join(',')
      }
      scope.previewCustom = function () {
        if (liveTimer) { clearTimeout(liveTimer); liveTimer = null }
        scope.act('customPaint', customArg())
      }
      // Regler bewegen = Farbe sofort am Auto (gedrosselt, letzte Stellung kommt immer an)
      var liveTimer = null, liveLast = 0
      var sendLive = function () { liveTimer = null; liveLast = Date.now(); scope.act('paintLive', customArg()) }
      scope.liveCustom = function () {
        if (liveTimer) return
        var wait = 90 - (Date.now() - liveLast)
        if (wait <= 0) sendLive(); else liveTimer = setTimeout(sendLive, wait)
      }

      var requested = null
      scope.$on('HashiriyaState', function (event, data) {
        scope.$evalAsync(function () {
          scope.strings = data.t || scope.strings
          var wasOpen = !!scope.term
          var prevMode = scope.term && scope.term.mode
          scope.term = data.terminal || null
          if (!scope.term) { lastFocus = null; return }
          if (!wasOpen || prevMode !== scope.term.mode) {
            scope.ui.query = ''
            scope.ui.gtab = 'fit'
            if (scope.term.cat) scope.ui.cat = scope.term.cat
          }
          // Katalog veraltet? Einmal je Version neu anfordern (kommt per HashiriyaCatalog)
          if (scope.term.catVersion >= 0 && scope.term.catVersion !== scope.catalog.version && requested !== scope.term.catVersion) {
            requested = scope.term.catVersion
            scope.act('termCatalog')
          }
          rebuildGroups()
        })
      })

      scope.$on('HashiriyaCatalog', function (event, data) {
        scope.$evalAsync(function () {
          scope.catalog = data || { rows: [], categories: [], version: -1 }
          if (!scope.catalog.rows) scope.catalog.rows = []
          if (!scope.catalog.categories) scope.catalog.categories = []
          rebuildGroups()
          rebuildRows()
        })
      })

      scope.act('termHello')
    }
  }
}])
