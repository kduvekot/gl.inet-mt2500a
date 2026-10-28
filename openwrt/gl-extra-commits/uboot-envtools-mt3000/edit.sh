#!/bin/sh
# GL.iNet's 4.8.2+ uboot-envtools adds its MT3000's environment location
# (glinet,mt3000-snand: /dev/mtd2) to the mediatek board script, which
# becomes /etc/uci-defaults/30_uboot-envtools. Not in GL.iNet's published
# trees; the script is taken from the official image of this run (as the
# closed packages are), not stored here. Only that entry differs from ours.
set -e
f=package/boot/uboot-envtools/files/mediatek
o=/work/cmp/off_root/etc/uci-defaults/30_uboot-envtools
grep -q "glinet,mt3000-snand" "$o"
cat "$o" > "$f"
