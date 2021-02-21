#!/bin/sh

set -eu

DATA="/var/local/co2mon/DATA"
LOCATION="${DATA}/location"

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
lat="${1}"
lng="${2}"

mkdir -p "${DATA}"
echo "${lat},${lng},0" > "${LOCATION}"
cat "${LOCATION}"

# ここで通常の終了処理
on_exit

# 異常終了時ハンドラの解除
trap '' EXIT
