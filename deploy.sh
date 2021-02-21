#!/bin/sh

#
# 使い方:
#   ./deploy.sh <target> <paring_url> <lat> <lng>
#

set -eu

: ${1}
: ${2}
: ${3}
: ${4}

target_host="${1}"
pairing_url="${2}"
lat="${3}"
lng="${4}"

pv --version > /dev/null || (echo "pvが見当たりません" >&2; exit 1)

./docker_build.sh
ssh "${target_host}" "sudo systemctl stop co2mon.service" || echo "co2mon.service not loaded" >&2
cat co2mon.service | ssh "${target_host}" "sudo tee /etc/systemd/system/co2mon.service > /dev/null"
ssh "${target_host}" "sudo systemctl daemon-reload; sudo systemctl enable co2mon.service"
#docker image save co2mon |
#  pv |
#  ssh "${target_host}" docker image load
./send_image.sh "${target_host}"
./pairing.sh "${target_host}" "${pairing_url}"
./set_location.sh "${target_host}" "${lat}" "${lng}"
ssh "${target_host}" "sudo systemctl start co2mon.service"

say 'オワッタヨ'
