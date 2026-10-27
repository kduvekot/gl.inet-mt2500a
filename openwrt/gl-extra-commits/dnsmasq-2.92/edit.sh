#!/bin/sh
# dnsmasq 2.92 as GL.iNet's 4.9.0 has it: their published package folder
# (gl-inet/gl-image, branch gl-mt3600be, versions/4.9.0; files/ here), whose
# build is byte-identical to the MT2500's 4.9.0 dnsmasq; release 6 as there
# (the published Makefile says 4). files/ is already copied when this runs:
# remove what our folder has and GL.iNet's doesn't.
set -e
p=package/network/services/dnsmasq
n="$(dirname "$0")/files/$p"
(cd "$p" && find . -type f) | while read -r f; do [ -e "$n/$f" ] || git rm -q "$p/$f"; done
sed -i 's/^PKG_RELEASE:=4$/PKG_RELEASE:=6/' "$p/Makefile"
grep -q '^PKG_RELEASE:=6$' "$p/Makefile"
grep -q '^PKG_UPSTREAM_VERSION:=2.92$' "$p/Makefile"
