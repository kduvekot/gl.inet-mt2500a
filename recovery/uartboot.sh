#!/usr/bin/env bash
# Load GL.iNet's fixed 2025-02-24 U-Boot into the GL-MT2500(A)'s RAM over
# UART, then drop into a logged serial console.
#
#   ./uartboot.sh [serial-port]        (default: /dev/serial0)
#
# Nothing is written to the router's flash by this script: BL2 and the FIP
# only run from RAM. Writing the new U-Boot permanently is a separate,
# deliberate step; see docs/recovery-uart-raspberry-pi.md.
#
# Run it from the unpacked recovery kit directory (or anywhere: it finds the
# kit files next to itself).

set -euo pipefail

kit_dir=$(cd "$(dirname "$0")" && pwd)
port=${1:-/dev/serial0}
bl2="$kit_dir/bl2-mt7981-bga-ddr4-ram.bin"
fip="$kit_dir/fip-mt2500-20250224.bin"

case "$(uname -m)" in
	aarch64) loader="$kit_dir/bin/mtk_uartboot-aarch64" ;;
	armv7l | armv8l) loader="$kit_dir/bin/mtk_uartboot-armv7" ;;
	*) echo "Unsupported CPU $(uname -m); need aarch64 or armv7" >&2; exit 1 ;;
esac

for f in "$loader" "$bl2" "$fip"; do
	[ -f "$f" ] || { echo "Missing $f - is this the unpacked recovery kit?" >&2; exit 1; }
done
if [ -f "$kit_dir/SHA256SUMS" ]; then
	(cd "$kit_dir" && sha256sum -c --quiet SHA256SUMS) || { echo "Kit checksum mismatch" >&2; exit 1; }
fi
[ -e "$port" ] || { echo "Serial port $port not found (did you run pi-setup.sh and reboot?)" >&2; exit 1; }
if command -v fuser > /dev/null && fuser "$port" > /dev/null 2>&1; then
	echo "$port is in use by another process; close it first." >&2
	exit 1
fi

mkdir -p "$kit_dir/logs"
stamp=$(date +%Y%m%d-%H%M%S)
load_log="$kit_dir/logs/uartboot-$stamp.log"
console_log="$kit_dir/logs/console-$stamp.log"

cat <<EOF
Serial port : $port ($(readlink -f "$port"))
Loader      : $(basename "$loader")
BL2         : $(basename "$bl2")
FIP         : $(basename "$fip")
Logs        : $kit_dir/logs/

1. Make sure the router is UNPLUGGED from power.
2. Press Enter here; the loader starts waiting ("Handshake...").
3. Then plug in the router's USB-C power.
EOF
read -r -p "Ready? Press Enter to start the loader... "

"$loader" -s "$port" --aarch64 -p "$bl2" -f "$fip" 2>&1 | tee "$load_log"

cat <<EOF

Loader finished. Opening the serial console at 115200 8N1.
  * Type "gl" quickly during U-Boot's countdown to stop autoboot.
  * picocom: Ctrl-A Ctrl-X quits, Ctrl-A Ctrl-S sends a file with XMODEM.
  * Everything is logged to $console_log
EOF
exec picocom -b 115200 --send-cmd "sx -vv" --logfile "$console_log" "$port"
