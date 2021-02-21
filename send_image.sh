#!/bin/sh

: ${1}

target_host="${1}"

#L="-L 14K"
L=""

docker image save co2mon |
  gzip -9c |
  pv ${L} |
  ssh "${target_host}" 'gunzip -c | docker image load'
