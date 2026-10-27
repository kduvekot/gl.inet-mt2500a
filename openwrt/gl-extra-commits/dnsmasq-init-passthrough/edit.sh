#!/bin/sh
# GL.iNet's dnsmasq passthrough mode (4.7.4+): its init script with the
# passthrough-mode DHCP range, and (files/) their published patch 304, the
# mark for outgoing packets. One commit: 4.7.4's dnsmasq is release 13 (=
# 10 + 302 + 303 + this). The init script
# (4.7.4+): taken from the official image of this run (as the closed
# packages are), not stored here. Only that block differs from ours.
set -e
f=package/network/services/dnsmasq/files/dnsmasq.init
o=/work/cmp/off_root/etc/init.d/dnsmasq
grep -q "passthrough.passthrough.enable" "$o"
cat "$o" > "$f"
