#!/usr/bin/env bash
# Prepare a Raspberry Pi to act as the serial (UART) console and BootROM
# loader for a GL.iNet GL-MT2500(A).
#
#   sudo ./pi-setup.sh             configure UART, install tools
#   sudo ./pi-setup.sh --download  also fetch and unpack the recovery kit
#
# What it changes (originals are backed up next to the files as *.mt2500.bak):
#   * config.txt : enable_uart=1, and route the full PL011 UART to GPIO14/15
#                  (dtoverlay=disable-bt on Pi 3/4, dtparam=uart0=on on Pi 5).
#                  The mini-UART cannot hold 921600 baud, which mtk_uartboot
#                  uses after the BootROM handshake.
#   * cmdline.txt: removes the Linux serial console, so the port is free.
#   * services   : disables the serial getty and, on Pi 3/4, hciuart.
# A reboot is needed afterwards.

set -euo pipefail

REPO="kduvekot/gl.inet-mt2500a"
KIT_URL="https://github.com/${REPO}/releases/download/recovery-kit/mt2500-recovery-kit.tar.gz"

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as root: sudo $0 $*" >&2
	exit 1
fi

boot_dir=/boot/firmware
[ -f "$boot_dir/config.txt" ] || boot_dir=/boot
config="$boot_dir/config.txt"
cmdline="$boot_dir/cmdline.txt"
if [ ! -f "$config" ] || [ ! -f "$cmdline" ]; then
	echo "config.txt/cmdline.txt not found in /boot or /boot/firmware" >&2
	exit 1
fi

model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo unknown)
echo "Board: $model"
echo "Boot partition: $boot_dir"

backup() {
	[ -f "$1.mt2500.bak" ] || cp -a "$1" "$1.mt2500.bak"
}

ensure_line() {
	grep -qxF "$1" "$config" || echo "$1" >> "$config"
}

backup "$config"
backup "$cmdline"

ensure_line "enable_uart=1"
case "$model" in
	*"Raspberry Pi 5"*)
		ensure_line "dtparam=uart0=on"
		;;
	*)
		ensure_line "dtoverlay=disable-bt"
		systemctl disable --now hciuart.service 2>/dev/null || true
		;;
esac

sed -i -E 's/[[:space:]]*console=(serial0|ttyAMA0|ttyS0),[0-9]+//g' "$cmdline"
for unit in serial-getty@ttyAMA0.service serial-getty@serial0.service serial-getty@ttyS0.service; do
	systemctl disable --now "$unit" 2>/dev/null || true
done

echo "Installing picocom (serial terminal) and lrzsz (XMODEM)..."
apt-get update -q
apt-get install -y -q picocom lrzsz curl

if [ "${1:-}" = "--download" ]; then
	target_user=${SUDO_USER:-root}
	target_home=$(getent passwd "$target_user" | cut -d: -f6)
	cd "$target_home"
	echo "Downloading recovery kit to $target_home ..."
	curl -fL -o mt2500-recovery-kit.tar.gz "$KIT_URL"
	curl -fL -o mt2500-recovery-kit.tar.gz.sha256 "$KIT_URL.sha256"
	sha256sum -c mt2500-recovery-kit.tar.gz.sha256
	tar -xzf mt2500-recovery-kit.tar.gz
	(cd mt2500-recovery-kit && sha256sum -c --quiet SHA256SUMS)
	chown -R "$target_user": mt2500-recovery-kit mt2500-recovery-kit.tar.gz*
	echo "Kit unpacked in $target_home/mt2500-recovery-kit"
fi

cat <<EOF

Done. Reboot the Pi now (sudo reboot). After the reboot:
  * /dev/serial0 should point to ttyAMA0:  ls -l /dev/serial0
  * Wiring (Pi header -> router UART header, 3.3 V logic, NO 3V3 wire):
      pin 6  GND         -> GND
      pin 8  GPIO14 TXD  -> RX
      pin 10 GPIO15 RXD  -> TX
EOF
