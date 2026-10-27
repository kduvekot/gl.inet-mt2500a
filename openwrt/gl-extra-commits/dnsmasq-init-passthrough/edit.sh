#!/bin/sh
# GL.iNet's dnsmasq init script with its passthrough-mode DHCP range
# (4.7.4+): taken from the official image of this run (as the closed
# packages are), not stored here. Only that block differs from ours.
set -e
f=package/network/services/dnsmasq/files/dnsmasq.init
o=/work/cmp/off_root/etc/init.d/dnsmasq
grep -q "passthrough.passthrough.enable" "$o"
cat "$o" > "$f"
