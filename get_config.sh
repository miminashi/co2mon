#!/bin/sh

#
# ターゲットの設定ストアから設定値を読出します
#
# 使い方:
#   ./get_config.sh TARGET KEY
#

set -eu

. ./config

# 引数のチェック
target="${1:?"第1引数にターゲット(ssh接続先)を与えてください"}"
key="${2:?"第2引数に設定キーを与えてください"}"
key_file="${CONF_DIR}"/"${key}"

ssh "${target}" "cat \"${key_file}\""
