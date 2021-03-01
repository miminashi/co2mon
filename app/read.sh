#!/bin/sh

echo "read.sh started" >&2

USB_CO2="/dev/serial/by-path/platform-1c1b400.usb-usb-0:1:1.0"
# rotateは別プロセスで
log_dir="/var/local/co2mon/DATA/log/co2"
log="${log_dir}/latest"

mkdir -p "${log_dir}"

stty -F "${USB_CO2}" raw 9600

cat "${USB_CO2}" |
while read -r l; do
  printf '%s %s\n' "$(date +%s)" "${l}"
done >> "${log}"
