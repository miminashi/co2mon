#!/bin/sh

#
# logtail.sh
#
# 説明:
#   ターゲットホストで実行されているco2monコンテナのジャーナルログを表示します。
#   このスクリプトを実行中にコンテナが停止されると、このスクリプトも停止します。
#
# 使い方:
#   ./logtail.sh TARGET
#

set -eu

# 引数のチェック
target="${1:?"第1引数にターゲット(ssh接続先)を与えてください"}"

ssh -t "${target}" 'docker exec -it co2mon journalctl -f -n 100'
