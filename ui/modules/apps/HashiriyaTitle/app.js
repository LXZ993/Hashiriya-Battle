// Hashiriya Battle: Titelbildschirm und "Neues Spiel" (Fahrer, Auto, Lack, Bestätigung).
// Läuft im eigenen Layout 'hashiriyaTitle' ohne HUD. Zustand kommt als s.flow über 'HashiriyaState',
// Eingaben gehen als uiAction('flow', 'befehl|wert') zurück an Lua (career.lua).
angular.module('beamng.apps')
.directive('hashiriyaTitle', [function () {
  return {
    template:
      '<div class="bngApp hbt-root">' +
        '<div class="hbt" ng-if="f" ng-class="\'step-\' + f.step">' +
          '<div class="hbt-shade"></div>' +

          // Titel ---------------------------------------------------------------
          '<div class="hbt-title" ng-if="f.step == \'title\'">' +
            '<div class="hbt-logo">' +
              '<div class="hbt-logo-a">HASHIRIYA</div>' +
              '<div class="hbt-logo-b">BATTLE</div>' +
              '<div class="hbt-logo-jp">走り屋バトル</div>' +
            '</div>' +
            '<div class="hbt-menu">' +
              '<div class="hbt-mi" ng-click="cmd(\'newGame\')"><span class="hbt-mi-n">01</span>{{ t(\'title.newGame\') }}</div>' +
              '<div class="hbt-mi" ng-class="{\'is-off\': !f.save}" ng-click="f.save && cmd(\'continue\')"><span class="hbt-mi-n">02</span>{{ t(\'title.continue\') }}</div>' +
              '<div class="hbt-save" ng-if="f.save">' +
                '<span>{{ f.save.name }}</span><span>{{ f.save.car }}</span><span class="hbt-yen">{{ f.save.money }}</span>' +
              '</div>' +
              '<div class="hbt-mi hbt-mi-sub" ng-click="cmd(\'quit\')"><span class="hbt-mi-n">03</span>{{ t(\'title.quit\') }}</div>' +
            '</div>' +
            '<div class="hbt-foot">{{ t(\'title.hint\') }}</div>' +
          '</div>' +

          // Neues Spiel -----------------------------------------------------------
          '<div class="hbt-wiz" ng-if="f.step != \'title\'">' +
            '<div class="hbt-wiz-head">' +
              '<div class="hbt-kicker">{{ t(\'title.newGame\') }}</div>' +
              '<div class="hbt-h1">{{ t(\'new.step.\' + f.step) }}</div>' +
              '<div class="hbt-steps"><span ng-repeat="st in steps" ng-class="{\'is-on\': st == f.step, \'is-done\': $index < stepIndex()}">' +
                '<b>{{ ($index + 1) < 10 ? \'0\' + ($index + 1) : ($index + 1) }}</b>{{ t(\'new.tab.\' + st) }}</span></div>' +
            '</div>' +

            '<div class="hbt-wiz-body" ng-if="f.step == \'driver\'">' +
              '<label class="hbt-label">{{ t(\'new.name\') }}</label>' +
              '<input class="hbt-input" type="text" maxlength="16" ng-model="form.name" placeholder="{{ t(\'new.namePh\') }}">' +
              '<div class="hbt-note">{{ t(\'new.nameNote\') }}</div>' +
              '<label class="hbt-label">{{ t(\'new.plate\') }}</label>' +
              '<div class="hbt-plate-row">' +
                '<input class="hbt-input hbt-plate" type="text" maxlength="12" ng-model="form.plate" placeholder="{{ f.plateHint }}">' +
                '<span class="hbt-btn" ng-click="cmd(\'randomPlate\')">{{ t(\'new.random\') }}</span>' +
              '</div>' +
              '<div class="hbt-note">{{ t(\'new.plateNote\') }}</div>' +
            '</div>' +

            '<div class="hbt-wiz-body" ng-if="f.step == \'car\'">' +
              '<div class="hbt-car" ng-repeat="c in f.cars track by c.id" ng-class="{\'is-on\': c.selected}" ng-click="!c.selected && cmd(\'selectCar\', c.id)">' +
                '<span class="hbt-car-n">{{ ($index + 1) < 10 ? \'0\' + ($index + 1) : ($index + 1) }}</span>' +
                '<span class="hbt-car-name">{{ c.name }}</span>' +
                '<span class="hbt-car-tag">{{ c.drivetrain }}</span>' +
              '</div>' +
              '<div class="hbt-specs" ng-if="selectedCar()">' +
                '<div class="hbt-spec" ng-repeat="sp in selectedCar().specs"><span>{{ sp.label }}</span><b>{{ sp.value }}</b></div>' +
              '</div>' +
              '<label class="hbt-label">{{ t(\'new.tab.color\') }}</label>' +
              '<div class="hbt-paints">' +
                '<div class="hbt-paint" ng-repeat="p in f.paints track by p.id" ng-class="{\'is-on\': p.selected}" ng-click="!p.selected && cmd(\'selectPaint\', p.id)" title="{{ p.name }}">' +
                  '<i ng-style="{background: p.swatch}"></i><span>{{ p.name }}</span>' +
                '</div>' +
              '</div>' +
              '<div class="hbt-note" ng-if="!f.paints.length">{{ t(\'new.noPaints\') }}</div>' +
            '</div>' +

            '<div class="hbt-wiz-body" ng-if="f.step == \'confirm\'">' +
              '<div class="hbt-spec"><span>{{ t(\'new.name\') }}</span><b>{{ f.summary.name }}</b></div>' +
              '<div class="hbt-spec"><span>{{ t(\'new.plate\') }}</span><b>{{ f.summary.plate }}</b></div>' +
              '<div class="hbt-spec"><span>{{ t(\'new.tab.car\') }}</span><b>{{ f.summary.car }}</b></div>' +
              '<div class="hbt-spec"><span>{{ t(\'new.tab.color\') }}</span><b><i class="hbt-sw" ng-style="{background: f.summary.swatch}"></i>{{ f.summary.paint }}</b></div>' +
              '<div class="hbt-money"><span>{{ t(\'new.startMoney\') }}</span><b>{{ f.summary.money }}</b></div>' +
              '<div class="hbt-note">{{ t(\'new.confirmNote\') }}</div>' +
            '</div>' +

            '<div class="hbt-busy" ng-if="f.busy">{{ t(\'new.loading\') }}</div>' +
            '<div class="hbt-nav">' +
              '<span class="hbt-btn" ng-click="cmd(\'back\')">{{ t(\'menu.back\') }}</span>' +
              '<span class="hbt-btn hbt-btn-main" ng-class="{\'is-off\': !canNext()}" ng-click="canNext() && next()">' +
                '{{ f.step == \'confirm\' ? t(\'new.start\') : t(\'new.next\') }}</span>' +
            '</div>' +
          '</div>' +

          // Großer Autoname unten rechts (Showroom)
          '<div class="hbt-showname" ng-if="f.step == \'car\' && selectedCar()">' +
            '<div class="hbt-showname-a">{{ selectedCar().brand }}</div>' +
            '<div class="hbt-showname-b">{{ selectedCar().model }}</div>' +
            '<div class="hbt-showname-c">{{ selectedCar().price }}</div>' +
          '</div>' +
        '</div>' +

        '<style>' +
          '.hbt-root{position:absolute;inset:0;width:100%;height:100%;background:transparent;box-shadow:none;pointer-events:none;}' +
          '.hbt{--o:#ff6600;--o2:#ff9a3c;--w:#f4f4f4;--dim:rgba(244,244,244,.55);position:absolute;inset:0;pointer-events:auto;' +
            'font-family:"Overpass","Noto Sans","Segoe UI",sans-serif;color:var(--w);overflow:hidden;}' +
          '.hbt-shade{position:absolute;inset:0;background:linear-gradient(90deg,rgba(10,10,12,.96) 0,rgba(10,10,12,.88) 34%,rgba(10,10,12,.15) 62%,rgba(10,10,12,0) 100%);}' +
          '.step-title .hbt-shade{background:radial-gradient(ellipse at 70% 60%,rgba(10,10,12,.35),rgba(10,10,12,.92) 70%),linear-gradient(90deg,rgba(10,10,12,.9),rgba(10,10,12,.3));}' +
          '.hbt:before{content:"";position:absolute;left:0;top:0;bottom:0;width:6px;background:var(--o);z-index:2;}' +
          '.hbt:after{content:"";position:absolute;right:-80px;top:0;bottom:0;width:260px;transform:skewX(-20deg);z-index:1;' +
            'background:repeating-linear-gradient(90deg,rgba(255,102,0,.10) 0 8px,transparent 8px 22px);pointer-events:none;}' +
          '.hbt-title,.hbt-wiz{position:absolute;z-index:3;}' +
          '.hbt-title{left:7vw;top:16vh;bottom:6vh;display:flex;flex-direction:column;animation:hbtIn .5s ease-out;}' +
          '@keyframes hbtIn{from{opacity:0;transform:translateX(-30px);}to{opacity:1;transform:none;}}' +
          '.hbt-logo-a{font-size:92px;font-weight:900;font-style:italic;letter-spacing:4px;line-height:.9;text-shadow:0 6px 30px rgba(0,0,0,.6);}' +
          '.hbt-logo-b{font-size:92px;font-weight:900;font-style:italic;letter-spacing:4px;line-height:.9;color:var(--o);margin-left:120px;}' +
          '.hbt-logo-jp{font-size:16px;letter-spacing:14px;color:var(--dim);margin:14px 0 0 124px;}' +
          '.hbt-menu{margin-top:9vh;width:440px;}' +
          '.hbt-mi{position:relative;display:flex;align-items:center;padding:12px 18px;font-size:24px;font-weight:800;font-style:italic;letter-spacing:2px;text-transform:uppercase;' +
            'cursor:pointer;transition:padding-left .14s,background .14s;}' +
          '.hbt-mi:hover{padding-left:30px;background:linear-gradient(90deg,rgba(255,102,0,.35),rgba(255,102,0,0));}' +
          '.hbt-mi:hover:before{content:"";position:absolute;left:0;top:6px;bottom:6px;width:5px;background:var(--o);}' +
          '.hbt-mi-n{font-size:13px;color:var(--o);width:42px;flex:none;}' +
          '.hbt-mi-sub{font-size:17px;color:rgba(244,244,244,.7);}' +
          '.hbt-mi.is-off{opacity:.35;cursor:default;} .hbt-mi.is-off:hover{padding-left:18px;background:none;} .hbt-mi.is-off:hover:before{display:none;}' +
          '.hbt-save{display:flex;gap:14px;align-items:baseline;margin:-4px 0 6px 60px;font-size:12px;color:var(--dim);letter-spacing:1px;}' +
          '.hbt-yen{color:var(--o2);font-weight:800;}' +
          '.hbt-foot{margin-top:auto;font-size:11px;letter-spacing:2px;text-transform:uppercase;color:var(--dim);}' +
          '.hbt-wiz{left:0;top:0;bottom:0;width:560px;padding:7vh 48px 6vh 56px;box-sizing:border-box;display:flex;flex-direction:column;animation:hbtIn .35s ease-out;}' +
          '.hbt-kicker{font-size:12px;font-weight:800;letter-spacing:4px;text-transform:uppercase;color:var(--o2);}' +
          '.hbt-h1{font-size:46px;font-weight:900;font-style:italic;letter-spacing:2px;text-transform:uppercase;line-height:1.05;margin:6px 0 18px;}' +
          '.hbt-steps{display:flex;gap:4px;margin-bottom:28px;}' +
          '.hbt-steps span{flex:1;padding:6px 8px;font-size:10px;font-weight:800;letter-spacing:1px;text-transform:uppercase;color:var(--dim);' +
            'background:rgba(255,255,255,.06);transform:skewX(-14deg);white-space:nowrap;overflow:hidden;}' +
          '.hbt-steps span b{color:var(--o);margin-right:6px;}' +
          '.hbt-steps span.is-done{color:var(--w);} .hbt-steps span.is-on{background:var(--o);color:#141414;} .hbt-steps span.is-on b{color:#141414;}' +
          '.hbt-wiz-body{flex:1;min-height:0;overflow-y:auto;overflow-x:hidden;padding-right:6px;}' +
          '.hbt-wiz-body::-webkit-scrollbar{width:4px;} .hbt-wiz-body::-webkit-scrollbar-thumb{background:var(--o);}' +
          '.hbt-label{display:block;font-size:11px;font-weight:800;letter-spacing:3px;text-transform:uppercase;color:var(--o2);margin:6px 0 8px;}' +
          '.hbt-input{width:100%;box-sizing:border-box;height:52px;padding:0 16px;font:900 italic 26px "Overpass",sans-serif;letter-spacing:2px;color:var(--w);' +
            'background:rgba(255,255,255,.06);border:none;border-bottom:3px solid var(--o);outline:none;}' +
          '.hbt-input:focus{background:rgba(255,102,0,.14);}' +
          '.hbt-plate-row{display:flex;gap:8px;align-items:center;}' +
          '.hbt-plate{flex:1;color:#141414;background:#f4f1e6;border:3px solid #2a2a2a;border-radius:4px;font-style:normal;text-align:center;}' +
          '.hbt-plate:focus{background:#fffbe9;}' +
          '.hbt-note{font-size:12px;line-height:1.5;color:var(--dim);margin:8px 0 22px;}' +
          '.hbt-car{display:flex;align-items:center;padding:12px 16px;margin-bottom:4px;cursor:pointer;background:rgba(255,255,255,.04);transition:background .12s,padding-left .12s;}' +
          '.hbt-car:hover{background:rgba(255,102,0,.22);padding-left:24px;}' +
          '.hbt-car.is-on{background:var(--o);color:#141414;cursor:default;padding-left:24px;}' +
          '.hbt-car-n{font-size:12px;font-weight:900;font-style:italic;width:38px;color:var(--o);} .hbt-car.is-on .hbt-car-n{color:#141414;}' +
          '.hbt-car-name{flex:1;font-size:19px;font-weight:800;font-style:italic;letter-spacing:1px;}' +
          '.hbt-car-tag{font-size:11px;font-weight:800;letter-spacing:1px;opacity:.75;}' +
          '.hbt-specs{margin-top:18px;}' +
          '.hbt-spec{display:flex;justify-content:space-between;align-items:baseline;gap:16px;padding:9px 2px;border-bottom:1px solid rgba(255,255,255,.08);}' +
          '.hbt-spec span{font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:var(--dim);}' +
          '.hbt-spec b{font-size:17px;font-weight:800;font-variant-numeric:tabular-nums;text-align:right;display:flex;align-items:center;gap:8px;}' +
          '.hbt-sw{display:inline-block;width:16px;height:16px;border-radius:2px;box-shadow:0 0 0 1px rgba(255,255,255,.4);}' +
          '.hbt-paints{display:grid;grid-template-columns:1fr 1fr;gap:6px;}' +
          '.hbt-paint{display:flex;align-items:center;gap:10px;padding:9px 10px;cursor:pointer;background:rgba(255,255,255,.04);font-size:13px;min-width:0;}' +
          '.hbt-paint i{width:22px;height:22px;flex:none;border-radius:3px;box-shadow:0 0 0 1px rgba(255,255,255,.35);}' +
          '.hbt-paint span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' +
          '.hbt-paint:hover{background:rgba(255,102,0,.22);}' +
          '.hbt-paint.is-on{background:rgba(255,102,0,.85);color:#141414;font-weight:800;}' +
          '.hbt-money{display:flex;justify-content:space-between;align-items:baseline;margin-top:22px;}' +
          '.hbt-money span{font-size:11px;font-weight:800;letter-spacing:3px;text-transform:uppercase;color:var(--o2);}' +
          '.hbt-money b{font-size:38px;font-weight:900;font-style:italic;}' +
          '.hbt-busy{font-size:11px;letter-spacing:2px;text-transform:uppercase;color:var(--o2);margin-bottom:10px;animation:hbtBlink 1s infinite alternate;}' +
          '@keyframes hbtBlink{from{opacity:.4;}to{opacity:1;}}' +
          '.hbt-nav{display:flex;gap:8px;margin-top:18px;}' +
          '.hbt-btn{flex:1;text-align:center;padding:12px 10px;font-size:14px;font-weight:900;font-style:italic;letter-spacing:2px;text-transform:uppercase;cursor:pointer;' +
            'background:rgba(255,255,255,.08);transform:skewX(-14deg);white-space:nowrap;}' +
          '.hbt-btn:hover{background:rgba(255,255,255,.16);}' +
          '.hbt-plate-row .hbt-btn{flex:none;padding:14px 18px;font-size:12px;}' +
          '.hbt-btn-main{flex:2;background:var(--o);color:#141414;} .hbt-btn-main:hover{background:var(--o2);}' +
          '.hbt-btn.is-off{opacity:.35;cursor:default;}' +
          '.hbt-showname{position:absolute;right:6vw;bottom:8vh;z-index:3;text-align:right;text-shadow:0 4px 24px rgba(0,0,0,.7);animation:hbtIn .4s ease-out;}' +
          '.hbt-showname-a{font-size:16px;font-weight:800;letter-spacing:8px;text-transform:uppercase;color:var(--o2);}' +
          '.hbt-showname-b{font-size:64px;font-weight:900;font-style:italic;letter-spacing:2px;line-height:1;text-transform:uppercase;}' +
          '.hbt-showname-c{font-size:20px;font-weight:800;font-style:italic;color:var(--dim);margin-top:6px;}' +
        '</style>' +
      '</div>',
    replace: true,
    link: function (scope) {
      'use strict'
      scope.f = null
      scope.strings = {}
      scope.form = { name: '', plate: '' }
      scope.steps = ['driver', 'car', 'confirm']
      scope.t = function (k) { return scope.strings[k] || k }
      var send = function (action, arg) {
        // Lua-String: Steuerzeichen als \ddd, da Lua kein \uXXXX kennt
        var a = arg === undefined ? 'nil' : '"' + String(arg).replace(/[\\"]/g, '\\$&').replace(/[\u0000-\u001f\u007f]/g, function (ch) { return '\\' + ('00' + ch.charCodeAt(0)).slice(-3) }) + '"'
        bngApi.engineLua('if extensions.hashiriyaBattle_core then extensions.hashiriyaBattle_core.uiAction("' + action + '", ' + a + ') end')
      }
      scope.cmd = function (c, arg) {
        send('flow', c + '|' + (arg === undefined ? '' : String(arg).replace(/\|/g, '')))
      }
      scope.stepIndex = function () { return scope.f ? scope.steps.indexOf(scope.f.step) : 0 }
      scope.selectedCar = function () {
        if (!scope.f || !scope.f.cars) return null
        for (var i = 0; i < scope.f.cars.length; i++) if (scope.f.cars[i].selected) return scope.f.cars[i]
        return null
      }
      scope.canNext = function () {
        var f = scope.f
        if (!f || f.busy) return false
        if (f.step === 'driver') return !!(scope.form.name && scope.form.name.trim())
        if (f.step === 'car') return !!scope.selectedCar()
        return true
      }
      scope.next = function () {
        if (scope.f.step === 'driver') {
          scope.cmd('driver', scope.form.name.trim() + '\u001f' + (scope.form.plate || '').trim())
        } else {
          scope.cmd('next')
        }
      }
      scope.$on('HashiriyaState', function (event, data) {
        scope.$evalAsync(function () {
          scope.strings = data.t || scope.strings
          var prev = scope.f && scope.f.step
          scope.f = data.flow || null
          // Formular einmal aus Lua vorbelegen (z. B. nach "Zurück")
          if (scope.f && scope.f.step === 'driver' && prev !== 'driver') {
            scope.form.name = scope.f.name || scope.form.name
            scope.form.plate = scope.f.plate || scope.form.plate
          }
          if (scope.f && scope.f.platePick) { scope.form.plate = scope.f.platePick }
        })
      })
    }
  }
}]);
