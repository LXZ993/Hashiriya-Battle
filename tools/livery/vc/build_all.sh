#!/bin/bash
# build_all.sh <model> [styles...] : SVG -> PNG/PSD/.vectorcraft je Stil
cd "$(dirname "$0")"; VC=../vcdl/x/vectorcraft-0.19.0-linux-x86_64/bin/vectorcraft-cli; m=$1; shift
ST=${@:-streetdrift_a streetdrift_b factorysports_a bosozoku_a kaido_a twotone_a raceteam_a tech_a tech_b tech_c tech_d sponsor_a d1drift_a shopdemo_a rally_a company_a wa_a manga_a splinter_a groupc_a jgtc_a kanjo_a}
mkdir -p build
for s in $ST; do
  [ -f bx_$s.py ] || continue
  python bx_$s.py $m >/dev/null || { echo "FAIL $m $s"; continue; }
  n=${m}_$s
  rm -f build/${n}_fix.png; [ -f ${n}_fix.svg ] && $VC convert ${n}_fix.svg build/${n}_fix.png --scale 1.5 >/dev/null
  $VC convert ${n}_key.svg build/$n.png --scale 1.5 >/dev/null && $VC convert $n.svg build/${n}_full.png --scale 1.5 >/dev/null && $VC convert $n.svg build/$n.psd --hidden-objects layer >/dev/null && $VC convert $n.svg build/$n.vectorcraft >/dev/null && $VC convert ${n}_guide.svg build/${n}_prev.png >/dev/null
  rm -f $n.svg ${n}_guide.svg ${n}_key.svg ${n}_fix.svg; echo "ok $n"
done
