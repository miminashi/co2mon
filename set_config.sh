#!/bin/sh

#
# 使い方:
#   ./set_config.sh TARGET KEY VALUE
#

set -eu

: ${1}
: ${2}
: ${3}

target="${1}"
key="${2}"
value="${3}"

ssh "${target}" "docker run --rm -v /var/local/co2mon:/var/local/co2mon co2mon /workdir/app/set_config.sh \"${key}\" \"${value}\""
