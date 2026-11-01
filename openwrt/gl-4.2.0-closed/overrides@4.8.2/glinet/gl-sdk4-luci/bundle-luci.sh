#!/bin/sh
# bundle-luci.sh <package's etc/luci_ipks> <bin/packages/<arch>>: replace
# each ipk the image bundles by the one this build made (all must exist).
for f in "$1"/*.ipk; do
	n=$(basename "$f")
	o=$(find "$2" -name "$n" | head -1)
	[ -n "$o" ] || { echo "gl-sdk4-luci: $n not built" >&2; exit 1; }
	cat "$o" > "$f"
done
