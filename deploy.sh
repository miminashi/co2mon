#!/bin/sh

#
# 使い方:
#   ./deploy.sh <target> <name> <webhook_url>
#

set -eu

cmdname=$(basename "${0}")

# 正常終了時の終了処理
on_exit() {
  printf '\e[32m%s: 正常終了\e[m\n' "${cmdname}" 1>&2
}

# エラー時の終了処理
on_error_exit() {
  printf '\e[31m%s: エラー終了\e[m\n' "${cmdname}" 1>&2
}

error() {
  printf '\e[31m%s: エラー: %s\e[m\n' "${cmdname}" "${1}" 1>&2
  printf '\e[31m%s: 終了します\e[m\n' "${cmdname}" 1>&2
  exit 1
}

trap on_error_exit EXIT

# ここから通常の処理

# 引数のチェック
target_host="${1:?"第1引数にターゲットを与えてください"}"
name="${2:-""}"
webhook_url="${3:-""}"
#usb_co2="${4:-""}"
#usb_7seg="${5:-""}"

# コマンドの存在確認
pv --version > /dev/null || (echo "pvが見当たりません" >&2; exit 1)
which say > /dev/null || (echo "sayが見当たりません" >&2; exit 1)

./docker_build.sh
./send_image.sh "${target_host}"
ssh "${target_host}" "sudo systemctl stop co2mon.service" || echo "co2mon.service not loaded" >&2
ssh "${target_host}" "sudo tee /etc/systemd/system/co2mon.service > /dev/null" < co2mon.service
ssh "${target_host}" "sudo systemctl daemon-reload; sudo systemctl enable co2mon.service"
test -n "${name}"        && ./set_config.sh "${target_host}" name "${name}"
test -n "${webhook_url}" && ./set_config.sh "${target_host}" webhook_url "${webhook_url}"
#test -n "${usb_co2}"     && ./set_config.sh "${target_host}" usb_co2 "${usb_co2}"
#test -n "${usb_7seg}"    && ./set_config.sh "${target_host}" usb_7seg "${usb_7seg}"
ssh "${target_host}" "sudo systemctl start co2mon.service"

say 'オワッタヨ'

# ここで通常の終了処理
on_exit

# 異常終了時ハンドラの解除
trap '' EXIT
