#!/bin/sh

USB_7SEG="/dev/serial/by-path/platform-1c1c400.usb-usb-0:1:1.0"

set -eu

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

stty -F "${USB_7SEG}" raw 9600

co2="$(tail -n 1 /var/local/co2mon/DATA/log/co2/latest |
  cut -d ' ' -f 2 |
  tr -d '\r' |
  sed -n 's/\(^.*\)\(co2=\)\([0-9][0-9]*\)\(.*$\)/\3/p')"
if [ -n "${co2}" ]; then
  echo $co2 > "${USB_7SEG}"
fi

# ここで通常の終了処理
on_exit

# 異常終了時ハンドラの解除
trap '' EXIT
