#!/bin/sh

set -eu

DATA="/var/local/co2mon/DATA"
ENDPOINT_INFO="${DATA}/endpoint_info"

on_exit() {
  :
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
pairing_url="${1}"

mkdir -p "${DATA}"
/workdir/app/get_endpoint_info.sh "${pairing_url}" > "${ENDPOINT_INFO}"
cat "${ENDPOINT_INFO}"

# ここで通常の終了処理
on_exit

# 異常終了時ハンドラの解除
trap '' EXIT
