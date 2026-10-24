#!/usr/bin/env bash
# Phase A of docs/driver-analysis-plan.md: read-only hardware/driver dumps
# from the router over SSH, stored raw on the Pi, plus a short summary.
#
#   analysis/collect-baseline.sh <label>     e.g. gl474-wan-unplugged
#
# Read only: mii_mgr/mii_mgr_cl45 with -g only, cat/ls of debugfs/proc/sys.
# Needs SSH access to the router (ROUTER, default root@192.168.8.1); the
# password is taken from ~/.config/mt2500/askpass.sh if present.
# Output: ~/mt2500-analysis/<date>/<label>/ (raw) and summary.md there.

set -euo pipefail

label=${1:?usage: $0 <label>}
router=${ROUTER:-root@192.168.8.1}
out="$HOME/mt2500-analysis/$(date +%F)/$label"
mkdir -p "$out"

if [ -x "$HOME/.config/mt2500/askpass.sh" ]; then
	export SSH_ASKPASS="$HOME/.config/mt2500/askpass.sh" SSH_ASKPASS_REQUIRE=force
fi
r() {
	setsid -w ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-o LogLevel=ERROR -o ConnectTimeout=5 "$router" "$1" 2>&1 || true
}

# A1 system
r 'uname -a; cat /proc/cmdline; cat /etc/glversion 2>/dev/null; cat /etc/openwrt_version 2>/dev/null' > "$out/a1-system.txt"
r 'dmesg' > "$out/a1-dmesg.txt"
r 'lsmod' > "$out/a1-lsmod.txt"
r 'cat /sys/firmware/fdt' > "$out/a1-fdt.dtb" || true
r 'zcat /proc/config.gz 2>/dev/null' > "$out/a1-kconfig.txt" || true

# A2 Ethernet ports
for i in eth0 eth1; do
	r "ethtool $i; ethtool -i $i; ethtool -k $i; ethtool -a $i; ethtool -S $i" > "$out/a2-ethtool-$i.txt"
done
r 'ip -d link; ip -s link' > "$out/a2-iplink.txt"
r 'for f in /proc/mtketh/*; do echo "== $f"; cat $f 2>&1 | head -200; done' > "$out/a2-proc-mtketh.txt"
r 'for f in $(find /sys/kernel/debug/mtketh -type f); do echo "== $f"; cat $f 2>&1 | head -200; done' > "$out/a2-debugfs-mtketh.txt"

# A3 WAN PHY (address 5): Clause 22 regs 0-31, Clause 45 key MMD registers
r 'for n in $(seq 0 31); do printf "c22 r%02d " $n; mii_mgr -g -p 5 -r $n 2>&1 | tail -1; done' > "$out/a3-phy5-c22.txt"
r 'for dr in 1:0 1:1 1:2 1:3 1:4 1:5 1:6 1:7 1:8 1:11 1:129 3:0 3:1 3:2 3:3 3:4 3:5 3:6 3:8 3:32 3:33 7:0 7:1 7:2 7:3 7:16 7:19 7:32 7:33 30:0 30:1 30:2 30:3 30:4 30:8 30:9 30:10 30:11 30:12 30:13 30:14 30:15 30:24 30:25 30:26 30:30 31:0 31:1 31:2 31:3 31:4 31:5 31:6 31:7 31:8 31:9 31:10 31:24; do d=${dr%%:*}; g=${dr##*:}; printf "c45 mmd%-2s r%-4s " $d $g; mii_mgr_cl45 -g -p 5 -d $(printf 0x%x $d) -r $(printf 0x%x $g) 2>&1 | tail -1; done; for g in 0 1 2 3 4 5 9 10 19 24 25 26; do printf "c22-via-mmd0 r%-3s " $g; mii_mgr -g -p 5 -r $(printf 0x%x $g) 2>&1 | tail -1; done' > "$out/a3-phy5-c45.txt"

# A4 SGMII / PCS (regmap debugfs)
r 'for d in /sys/kernel/debug/regmap/*; do case "$d" in *sgmii*|*SGMII*|*1006*|*1007*) echo "== $d"; cat $d/name 2>/dev/null; cat $d/registers 2>/dev/null | head -120;; esac; done' > "$out/a4-sgmii-regmap.txt"

# A5 hardware NAT
r 'for f in $(find /sys/kernel/debug/hnat -type f); do echo "== $f"; cat $f 2>&1 | head -60; done' > "$out/a5-debugfs-hnat.txt"
r 'for m in mtkhnat mtfwd mtqos; do for p in /sys/module/$m/parameters/*; do [ -f "$p" ] && echo "$p = $(cat $p)"; done; done' > "$out/a5-module-params.txt"

# A6 eMMC
r 'for f in /sys/kernel/debug/mmc0/ios /sys/kernel/debug/mmc0/clock /sys/kernel/debug/mmc0/mmc0:0001/ext_csd; do echo "== $f"; cat $f 2>&1 | head -40; done' > "$out/a6-mmc.txt"

# Redact this unit's MAC (and +1..+3) and serial numbers if the boot1 backup is here
b1=$(ls "$HOME"/mt2500-backup/*/mmcblk0boot1.bin 2>/dev/null | head -1 || true)
if [ -n "$b1" ]; then
	python3 -I - "$b1" "$out" << 'PY'
import sys, pathlib, re
b1 = open(sys.argv[1], "rb").read()
base = int.from_bytes(b1[0xa:0x10], "big")
subs = []
for d in range(4):
    m = (base + d).to_bytes(6, "big")
    for s in {m.hex(":"), m.hex("-"), m.hex()}:
        subs += [(s, f"<UNIT-MAC+{d}>"), (s.upper(), f"<UNIT-MAC+{d}>")]
for off in (0x10, 0x20, 0x30):
    s = b1[off:off+16].split(b"\0")[0].strip(b"\xff").decode(errors="ignore")
    if len(s) >= 4:
        subs.append((s, "<UNIT-ID>"))
for f in pathlib.Path(sys.argv[2]).glob("*.txt"):
    t = f.read_text(errors="replace")
    for a, b in subs:
        t = t.replace(a, b)
    f.write_text(t)
PY
fi

python3 -I "$(dirname "$0")/summarize-baseline.py" "$out" > "$out/summary.md"
echo "raw: $out"
