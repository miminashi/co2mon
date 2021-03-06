#!/bin/sh

LOG="/var/local/co2mon/DATA/log/co2/latest"
DEFAULT_USB_7SEG="/dev/serial/by-path/platform-fd500000.pcie-pci-0000:01:00.0-usb-0:1.2:1.0"

set -eux

on_exit() {
  :
}

# エラー時の処理
error_handler() {
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
usb_7seg="$(./app/get_config.sh usb_7seg)" || usb_7seg=""
if [ -z "${usb_7seg}" ]; then
  usb_7seg="${DEFAULT_USB_7SEG}"
fi

stty -F "${usb_7seg}" raw 9600

co2="$(tail -n 1 "${LOG}" |
  cut -d ' ' -f 2 |
  tr -d '\r' |
  sed -n 's/\(^.*\)\(co2=\)\([0-9][0-9]*\)\(.*$\)/\3/p')"
if [ -n "${co2}" ]; then
  echo "${co2}" > "${usb_7seg}"
fi

# ここで通常の終了処理
on_exit

# 異常終了時ハンドラの解除
trap '' EXIT
