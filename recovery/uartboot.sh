#!/usr/bin/env bash
# Load GL.iNet's fixed 2025-02-24 U-Boot into the GL-MT2500(A)'s RAM over
# UART, then open the serial console (in tmux, see console.sh).
#
#   ./uartboot.sh [-y] [-n] [serial-port]     (default port: /dev/serial0)
#
#   -y   don't wait for Enter before starting the loader (for scripted use;
#        the loader itself waits until the router is powered on)
#   -n   don't stop U-Boot's autoboot (by default "gl" is typed for a few
#        seconds after loading, to get the MT7981> prompt)
#
# Nothing is written to the router's flash by this script: BL2 and the FIP
# only run from RAM. Writing the new U-Boot permanently is a separate,
# deliberate step; see docs/recovery-uart-raspberry-pi.md.

set -euo pipefail

kit_dir=$(cd "$(dirname "$0")" && pwd)
bl2="$kit_dir/bl2-mt7981-bga-ddr4-ram.bin"
fip="$kit_dir/fip-mt2500-20250224.bin"
assume_yes=0
stop_autoboot=1

while getopts "yn" opt; do
	case "$opt" in
		y) assume_yes=1 ;;
		n) stop_autoboot=0 ;;
		*) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
	esac
done
shift $((OPTIND - 1))
port=${1:-/dev/serial0}

case "$(uname -m)" in
	aarch64) loader="$kit_dir/bin/mtk_uartboot-aarch64" ;;
	armv7l | armv8l) loader="$kit_dir/bin/mtk_uartboot-armv7" ;;
	*) echo "Unsupported CPU $(uname -m); need aarch64 or armv7" >&2; exit 1 ;;
esac

for f in "$loader" "$bl2" "$fip" "$kit_dir/console.sh"; do
	[ -f "$f" ] || { echo "Missing $f - is this the unpacked recovery kit?" >&2; exit 1; }
done
if [ -f "$kit_dir/SHA256SUMS" ]; then
	(cd "$kit_dir" && sha256sum -c --quiet SHA256SUMS) || { echo "Kit checksum mismatch" >&2; exit 1; }
fi
[ -e "$port" ] || { echo "Serial port $port not found (did you run pi-setup.sh and reboot?)" >&2; exit 1; }

# The loader needs the port to itself. picocom takes a moment to exit after
# its tmux session is killed, so allow it up to 5 s to release the port.
"$kit_dir/console.sh" stop > /dev/null
if command -v fuser > /dev/null; then
	for _ in $(seq 1 10); do
		fuser "$port" > /dev/null 2>&1 || break
		sleep 0.5
	done
	if fuser "$port" > /dev/null 2>&1; then
		echo "$port is in use by another process; close it first." >&2
		exit 1
	fi
fi

mkdir -p "$kit_dir/logs"
load_log="$kit_dir/logs/uartboot-$(date +%Y%m%d-%H%M%S).log"

cat << EOF
Serial port : $port ($(readlink -f "$port"))
Loader      : $(basename "$loader")
BL2         : $(basename "$bl2")
FIP         : $(basename "$fip")
Log         : $load_log

1. Make sure the router is UNPLUGGED from power.
2. Start the loader; it waits at "Handshake..." for as long as needed.
3. Then plug in the router's USB-C power.
EOF
if [ "$assume_yes" -ne 1 ]; then
	read -r -p "Ready? Press Enter to start the loader... "
fi

"$loader" -s "$port" --aarch64 -p "$bl2" -f "$fip" 2>&1 | tee "$load_log"

"$kit_dir/console.sh" start "$port"
if [ "$stop_autoboot" -eq 1 ]; then
	for _ in $(seq 1 15); do
		tmux send-keys -t mt2500 -l gl
		sleep 0.3
	done
fi

cat << EOF

Loader finished; the console runs in tmux session "mt2500".
  * Watch / type live : $kit_dir/console.sh attach   (detach: Ctrl-B d)
  * Last screen lines : $kit_dir/console.sh show
  * Run a command     : $kit_dir/console.sh send "mmc info"
  * In picocom, Ctrl-A Ctrl-S sends a file with XMODEM.
EOF
