#!/bin/sh

target="${1}"
pairing_url="${2}"

set -eu
: ${target}
: ${pairing_url}

ssh "${target}" "docker run --rm -v /var/local/co2mon:/var/local/co2mon co2mon /workdir/app/pairing.sh \"${pairing_url}\""
