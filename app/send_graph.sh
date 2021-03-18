#!/bin/sh

set -eu

CONF_DIR="/var/local/co2mon/CONF"

# curlがなぜかca-certificates.crtを読み込んでくれない問題のワークアラウンド
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

on_exit() {
  rm -rf "${tmp}"
}

error_handler() {
  # エラー時の処理
  on_exit
}

cmdname=$(basename "${0}")
error() {
  printf '\e[31m%s: エラー: %s\e[m\n' "${cmdname}" "${1}" 1>&2
  printf '\e[31m%s: 終了します\e[m\n' "${cmdname}" 1>&2
  exit 1
}

trap error_handler EXIT

# ここで通常の処理
tmp="$(mktemp -d)"

date="$(date +%s)"

curl -h > /dev/null 2>&1 || error 'curl が見つかりません'
jq -h > /dev/null 2>&1 || error 'jq が見つかりません'

webhook_url="$(cat "${CONF_DIR}"/webhook_url 2>/dev/null | grep '')"
if [ -z "${webhook_url}" ]; then
  error 'webhook_url が設定されていません'
fi
name="$(cat "${CONF_DIR}"/name 2>/dev/null | grep '')"
if [ -z "${name}" ]; then
  error 'name が設定されていません'
fi
plot_period="$(cat "${CONF_DIR}"/plot_period 2>/dev/null | grep '')"
if [ -z "${plot_period}" ]; then
  plot_period=21600  # デフォルト=6時間
fi

## plot_periodに指定された期間のCO2濃度履歴を取得する(デフォルト: 6時間)
tail -n $((plot_period + 1000)) /var/local/co2mon/DATA/log/co2/latest |
  tr -d '\r' |
  awk -v pt="$((date - plot_period))" '$1 > pt' |
  sed -n 's/\(^[0-9][0-9]*\)\(.*\)\(co2=\)\([0-9][0-9]*\)\(.*$\)/\1 \4/p' > "${tmp}"/co2_last_6h.timet_ppm
cut -d ' ' -f 1 < "${tmp}"/co2_last_6h.timet_ppm | TZ="JST-9" /workdir/app/utconv -r > "${tmp}"/co2_last_6h.jstdate
cut -d ' ' -f 2 < "${tmp}"/co2_last_6h.timet_ppm > "${tmp}"/co2_last_6h.ppm
paste "${tmp}"/co2_last_6h.jstdate "${tmp}"/co2_last_6h.ppm > "${tmp}"/co2_last_6h.jstdate_ppm


## グラフを描画する
tail_date_t="${date}"
head_date_t="$((tail_date_t - plot_period))"
tail_date="$(TZ="JST-9" /workdir/app/utconv -r "${tail_date_t}")"
head_date="$(TZ="JST-9" /workdir/app/utconv -r "${head_date_t}")"
echo "${head_date}" >&2
echo "${head_date_t}" >&2
tail_date_Y="$(echo "${tail_date}" | cut -c 1-4)"
tail_date_m="$(echo "${tail_date}" | cut -c 5-6)"
tail_date_d="$(echo "${tail_date}" | cut -c 7-8)"
tail_date_H="$(echo "${tail_date}" | cut -c 9-10 | sed 's/^0//')"
tail_date_M="$(echo "${tail_date}" | cut -c 11-12)"
title="$(printf '%s のCO2濃度\\n(%s/%s/%s %s:%s現在, 過去6時間)' "${name}" "${tail_date_Y}" "${tail_date_m}" "${tail_date_d}" "${tail_date_H}" "${tail_date_M}")"
gnuplot -p <<EOF
# 共通の設定
#set title "${title}"
set label 1 right at graph 0.96,0.96 "${title}" front
set nokey
set timefmt "%Y%m%d%H%M%S"
# 枠の設定
set lmargin 0
set rmargin 0
set tmargin 0
set bmargin 0
# 軸の共通設定
set tics in front
# x軸の設定
set format x "%m/%d\n%k時"
set xdata time
set xrange ["${head_date}":"${tail_date}"]
set xtics "${head_date}", 3600
set xtics offset 0,graph 0.05
set xtics font "Verdana,8"
# y軸の設定
set ylabel 'CO2濃度(ppm)'
set yrange [250:2000]
set ytics offset graph 0.08
set ytics 400,600,1000
set ytics font "Verdana,24"
# 塗りつぶしの設定
set style fill solid 1.0 noborder
set style function filledcurves y1=0
f1000(x) = 1000
f2000(x) = 2000
# PNGの描画
#set terminal pngcairo size 1024,768 font 'Verdana,8'
set terminal pngcairo size 1280,960 font 'Verdana,8'
set output '${tmp}/graph.png'
#plot '${tmp}/co2_last_6h.jstdate_ppm' using 1:2 with lines lc '#0000ff'
plot f2000(x) fs solid 0.8 lc rgb "pink", f1000(x) fs solid 0.2 lc rgb "green", '${tmp}/co2_last_6h.jstdate_ppm' using 1:2 with lines lc 'grey10' lw 3
EOF

cp "${tmp}"/graph.png /var/local/co2mon/DATA/graph.png

## グラフ画像を送信する
curl -s -w '\n' -X POST -F "file=@${tmp}/graph.png" "${webhook_url}"

# ここで通常の終了処理
on_exit

# 異常終了時ハンドラの解除
trap '' EXIT
