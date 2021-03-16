#!/bin/sh

#
# ターゲットのco2monサービスを再起動します
#
# 使い方:
#   ./restart.sh TARGET
#

set -eu

. ./config

target="${1:?"第1引数にターゲット(ssh接続先)を与えてください"}"

ssh -t "${target}" 'screen -d dockerps; screen -r dockerps || screen -S dockerps sh -c "while :; do r=\$(docker ps); clear; echo \"\${r}\"; sleep 5; done"'
