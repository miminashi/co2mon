#!/bin/sh

#
# 使い方:
#   ./get_config.sh TARGET KEY
#

set -eu

: "${1}"
: "${2}"

target="${1}"
key="${2}"

ssh "${target}" "docker run --rm -v /var/local/co2mon:/var/local/co2mon co2mon /workdir/app/get_config.sh \"${key}\""
