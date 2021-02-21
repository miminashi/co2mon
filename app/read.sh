#!/bin/sh

echo "read.sh started" >&2

# rotateは別プロセスで
log_dir="/var/local/co2mon/DATA/log/co2"
log="${log_dir}/latest"

mkdir -p "${log_dir}"

stty -F "/dev/serial/by-path/platform-fd500000.pcie-pci-0000:01:00.0-usb-0:1.4:1.0" raw 9600

cat "/dev/serial/by-path/platform-fd500000.pcie-pci-0000:01:00.0-usb-0:1.4:1.0" |
while read -r l; do
  printf '%s %s\n' "$(date +%s)" "${l}"
done >> "${log}"
