#!/bin/sh

set -eu

CONF_DIR="/var/local/co2mon/CONF"

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

# ここから通常の処理

key="${1}"

key_file="${CONF_DIR}"/"${key}"
cat "${key_file}"

# ここで通常の終了処理
on_exit

# 異常終了時ハンドラの解除
trap '' EXIT
