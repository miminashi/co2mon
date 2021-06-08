#!/bin/sh

echo "read.sh started" >&2

LOG_DIR="/var/local/co2mon/DATA/log/co2"  # rotateは別プロセスで
LOG="${log_dir}/latest"
DEFAULT_USB_CO2="/dev/serial/by-path/platform-fd500000.pcie-pci-0000:01:00.0-usb-0:1.4:1.0"

usb_co2="$(./app/get_config.sh usb_co2)"
if [ -z "${usb_co2}" ]; then
  usb_co2="${DEFAULT_USB_CO2}"
fi

mkdir -p "${LOG_DIR}"

stty -F "${usb_co2}" raw 9600

cat "${usb_co2}" |
while read -r l; do
  printf '%s %s\n' "$(date +%s)" "${l}"
done >> "${LOG}"
