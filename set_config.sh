#!/bin/sh

#
# ターゲットの設定ストアに設定値を書込します
#
# 使い方:
#   ./set_config.sh TARGET KEY VALUE
#

set -eu

. ./config

# 引数のチェック
target="${1:?"第1引数にターゲット(ssh接続先)を与えてください"}"
key="${2:?"第2引数に設定キーを与えてください"}"
value="${3:?"第3引数に設定値を与えてください"}"

key_file="${CONF_DIR}"/"${key}"

ssh "${target}" "sudo mkdir -p \"${CONF_DIR}\" && echo \"${value}\" | sudo tee \"${key_file}\" > /dev/null && cat \"${key_file}\""
