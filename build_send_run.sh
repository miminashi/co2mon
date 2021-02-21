#!/bin/sh

#
# pvのインストール:
#   brew install pv
#

set -eu

TARGET_HOST="${1}"
CONTAINER_NAME="co2mon"

pv --version > /dev/null || (echo "pvが見当たりません" >&2; exit 1)

./docker_build.sh &&
  ./send_image.sh "${TARGET_HOST}" &&
  ssh "${TARGET_HOST}" '
    sudo systemctl stop co2mon.service;
    docker stop '"${CONTAINER_NAME}"';
    docker run -d --privileged --rm -v /dev:/dev -v /var/local/co2mon:/var/local/co2mon --name '"${CONTAINER_NAME}"' co2mon /sbin/init'
