#!/bin/sh

#
# ターゲットのco2monサービスを再起動します
#
# 使い方:
#   ./restart.sh TARGET
#

set -eu

. ./config

#target="${1}"
target="${1:?"第1引数にターゲット(ssh接続先)を与えてください"}"

ssh "${target}" "sudo systemctl restart co2mon"
