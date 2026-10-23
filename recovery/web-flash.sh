#!/usr/bin/env bash
# Flash a GL-MT2500(A) through its U-Boot recovery web page, from the
# command line instead of a browser.
#
#   ./web-flash.sh fip                  upload the fixed U-Boot from the kit
#   ./web-flash.sh firmware <image.bin> upload a sysupgrade firmware image
#
# Options (before the subcommand):
#   -H <host>   recovery page address (default 192.168.1.1)
#   -y          do not ask for confirmation before writing
#
# This mirrors what the recovery page's own JavaScript does:
#   1. POST /upload, multipart field "fip" or "firmware"
#      -> the device answers "<size> <md5>" or "fail"
#   2. GET /flashing.html, then GET /result
#      -> the device writes the image, answers, and reboots
#
# The same U-Boot also has bl2.html and gpt.html pages, which overwrite the
# first-stage loader and the partition table. This script refuses to use
# them on purpose.

set -euo pipefail

FIP_SHA256=90b28ab596783e8cab09e1e38d77a37cdbc1e3b9fba855847bc8248b213a40be

kit_dir=$(cd "$(dirname "$0")" && pwd)
host=192.168.1.1
assume_yes=0

usage() {
	sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
	exit 1
}

while getopts "H:y" opt; do
	case "$opt" in
		H) host=$OPTARG ;;
		y) assume_yes=1 ;;
		*) usage ;;
	esac
done
shift $((OPTIND - 1))

kind=${1:-}
case "$kind" in
	fip)
		file=${2:-$kit_dir/fip-mt2500-20250224.bin}
		;;
	firmware)
		file=${2:-}
		[ -n "$file" ] || usage
		;;
	bl2 | gpt)
		echo "Refusing to write '$kind': that overwrites the boot loader stage or partition table." >&2
		exit 1
		;;
	*)
		usage
		;;
esac

[ -f "$file" ] || { echo "File not found: $file" >&2; exit 1; }
size=$(stat -c %s "$file")
md5=$(md5sum "$file" | cut -d' ' -f1)
sha256=$(sha256sum "$file" | cut -d' ' -f1)

if [ "$kind" = fip ]; then
	if [ "$sha256" != "$FIP_SHA256" ]; then
		echo "Refusing: $file is not GL.iNet's 2025-02-24 MT2500 FIP (SHA256 mismatch)." >&2
		exit 1
	fi
	what="GL.iNet U-Boot/FIP 2025-02-24"
else
	board=$({ tar -tf "$file" 2> /dev/null || true; } | sed -n 's|^sysupgrade-\([^/]*\)/CONTROL$|\1|p' | head -1)
	case "$board" in
		# GL.iNet's stock images use this board name for both hardware
		# revisions; for upstream OpenWrt it is the MaxLinear profile.
		glinet_gl-mt2500) what="sysupgrade image for $board (GL.iNet stock, or OpenWrt MaxLinear PHY)" ;;
		glinet_gl-mt2500-airoha) what="sysupgrade image for $board (OpenWrt Airoha PHY)" ;;
		*)
			echo "Refusing: $file is not a GL-MT2500 sysupgrade image (found board '${board:-none}')." >&2
			exit 1
			;;
	esac
fi

base="http://$host"
curl_opts=(--silent --show-error --fail --noproxy '*')

echo "Target : $base ($kind page)"
echo "File   : $file"
echo "What   : $what"
echo "Size   : $size bytes"
echo "MD5    : $md5"

version=$(curl "${curl_opts[@]}" --max-time 5 "$base/version" 2>/dev/null) || {
	echo "No recovery page at $base. Is the router in U-Boot recovery mode and is this host on 192.168.1.x?" >&2
	exit 1
}
echo "Device : ${version:-unknown U-Boot version}"

echo "Uploading..."
resp=$(curl "${curl_opts[@]}" --max-time 300 -F "$kind=@$file" "$base/upload")
if [ "$resp" = fail ]; then
	echo "Device rejected the upload (\"fail\")." >&2
	exit 1
fi
read -r dev_size dev_md5 _ <<< "$resp"
echo "Device received: size $dev_size, MD5 $dev_md5"
if [ "$dev_size" != "$size" ] || [ "$dev_md5" != "$md5" ]; then
	echo "Mismatch between local file and what the device received; not flashing." >&2
	echo "Power-cycle the router to discard the upload." >&2
	exit 1
fi

if [ "$assume_yes" -ne 1 ]; then
	read -r -p "Upload verified. Write it to the router now? [y/N] " answer
	case "$answer" in
		y | Y) ;;
		*) echo "Not written. Power-cycle the router to discard the upload."; exit 0 ;;
	esac
fi

echo "Starting the write..."
curl "${curl_opts[@]}" --max-time 30 -o /dev/null "$base/flashing.html"
result=$(curl "${curl_opts[@]}" --max-time 600 "$base/result" || true)
echo "Device answered: ${result:-<no answer>}"
if [ "$result" = failed ]; then
	echo "UPDATE FAILED. With the 2022 U-Boot this is the known eMMC problem: use the UART procedure." >&2
	exit 1
fi
echo "Done. The router should now reboot by itself; watch the serial console."
