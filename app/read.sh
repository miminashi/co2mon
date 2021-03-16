#!/bin/sh

echo "read.sh started" >&2

CONF_DIR="/var/local/co2mon/CONF"
USB_CO2_CONF="${CONF_DIR}/usb_co2"
USB_CO2="$(cat "${USB_CO2_CONF}")"
test -z "${USB_CO2}" && echo "usb_co2 の設定が空です" >&2 && exit 1

# rotateは別プロセスで
log_dir="/var/local/co2mon/DATA/log/co2"
log="${log_dir}/latest"

mkdir -p "${log_dir}"

stty -F "${USB_CO2}" raw 9600

cat "${USB_CO2}" |
while read -r l; do
  printf '%s %s\n' "$(date +%s)" "${l}"
done >> "${log}"
