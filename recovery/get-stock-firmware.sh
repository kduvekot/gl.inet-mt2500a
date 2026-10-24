#!/usr/bin/env bash
# Download GL.iNet's stock firmware for the GL-MT2500(A) from GL.iNet's own
# server and check it against a pinned SHA256. The firmware is not part of
# the recovery kit: it contains GL.iNet's closed-source components, so we
# don't redistribute it; this fetches the original instead.
#
#   ./get-stock-firmware.sh [target-dir]     (default: the kit's folder)
#
# Version and hash come from GL.iNet's download API
# (https://firmware-api.gl-inet.com/cloud-api/model/info?model=mt2500);
# see docs/firmware-sources.md for all versions.

set -euo pipefail

STOCK_URL="https://fw.gl-inet.com/firmware/mt2500/release/openwrt-mt2500-4.7.4-0328-1743128340.bin"
STOCK_SHA256="3de78f88a2cc204c089cd1c262346786796d43a223564b1f792f3e8515cc8904"

dir=${1:-$(cd "$(dirname "$0")" && pwd)}
file="$dir/$(basename "$STOCK_URL")"

if [ -f "$file" ] && echo "$STOCK_SHA256  $file" | sha256sum -c --quiet 2>/dev/null; then
	echo "Already present and verified: $file"
	exit 0
fi

echo "Downloading $(basename "$STOCK_URL") from GL.iNet..."
curl -fL -o "$file.part" "$STOCK_URL"
if ! echo "$STOCK_SHA256  $file.part" | sha256sum -c --quiet; then
	rm -f "$file.part"
	echo "SHA256 mismatch: download removed. Check docs/firmware-sources.md." >&2
	exit 1
fi
mv "$file.part" "$file"
echo "Verified: $file"
