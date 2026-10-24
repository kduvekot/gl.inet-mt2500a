#!/usr/bin/env python3
"""Summarise one collect-baseline.sh run in ~50 lines of Markdown.

    summarize-baseline.py <run-dir>

Only key values: versions, link state per port, driver/firmware, offload
features that are on, PHY identity and status registers, the Clause 45
register values on a few lines, relevant kernel messages, hardware NAT and
eMMC state. The raw files stay next to it for details.
"""
import re
import sys
from pathlib import Path

d = Path(sys.argv[1])


def txt(name):
    p = d / name
    return p.read_text(errors="replace") if p.is_file() else ""


def grab(text, key):
    m = re.search(rf"^\s*{re.escape(key)}:\s*(.+)$", text, re.M)
    return m.group(1).strip() if m else "-"


out = [f"# Baseline `{d.name}` ({d.parent.name})", ""]
sysinfo = txt("a1-system.txt").splitlines()
out += ["**System:** " + " | ".join(l.strip() for l in sysinfo[:1] + sysinfo[2:4]), ""]

out += ["| Port | Link | Speed | Duplex | AN | Driver | Firmware | Pause | Offloads on |", "|---|---|---|---|---|---|---|---|---|"]
for i in ("eth0", "eth1"):
    t = txt(f"a2-ethtool-{i}.txt")
    feats = re.findall(r"^\s*([a-z0-9-]+): on(?! \[fixed\])", t, re.M)
    keep = [f for f in feats if any(k in f for k in ("offload", "gro", "gso", "tso", "checksum", "scatter", "hw-tc", "vlan"))]
    pause = re.search(r"Autonegotiate:\s*(\S+)\s+RX:\s*(\S+)\s+TX:\s*(\S+)", t, re.S)
    out.append(f"| {i} | {grab(t, 'Link detected')} | {grab(t, 'Speed')} | {grab(t, 'Duplex')} | "
               f"{grab(t, 'Auto-negotiation')} | {grab(t, 'driver')} {grab(t, 'version')} | {grab(t, 'firmware-version')} | "
               f"{'/'.join(pause.groups()) if pause else '-'} | {', '.join(keep) or '-'} |")
out.append("")

c22 = dict(re.findall(r"c22 r(\d+) .*?(0x[0-9a-fA-F]+)", txt("a3-phy5-c22.txt")))
if c22:
    out.append(f"**WAN PHY (MDIO 5), Clause 22:** BMCR={c22.get('00','-')} BMSR={c22.get('01','-')} "
               f"ID={c22.get('02','-')}:{c22.get('03','-')} ANAR={c22.get('04','-')} LPA={c22.get('05','-')} "
               f"CTRL1000={c22.get('09','-')} STAT1000={c22.get('10','-')}")
c45 = re.findall(r"c45 mmd(\d+)\s+r(\d+)\s+.*?(0x[0-9a-fA-F]+)", txt("a3-phy5-c45.txt"))
if c45:
    by = {}
    for m, r, v in c45:
        by.setdefault(m, []).append(f"{r}={v}")
    out.append("**WAN PHY, Clause 45** (reg=value):")
    out += [f"- MMD {m}: " + " ".join(v) for m, v in by.items()]
if not c22 and not c45:
    out.append("**WAN PHY:** no register output (see a3-*.txt)")
out.append("")

dm = [l for l in txt("a1-dmesg.txt").splitlines()
      if re.search(r"gpy|maxlinear|phy|sgmii|eth[01]|link is|hnat|ppe|mmc0|en8811|air_", l, re.I)]
out += [f"**Kernel messages** ({len(dm)} relevant, first 20):", "```"] + [l[:150] for l in dm[:20]] + ["```", ""]

mods = [l.split()[0] for l in txt("a1-lsmod.txt").splitlines()[1:] if l.strip()]
key = [m for m in mods if re.search(r"hnat|mtfwd|mtqos|gpy|air|gl_|kmwan|tertf|parental|shortcut|nf_flow", m)]
out += [f"**Modules:** {len(mods)} loaded; relevant: {', '.join(key) or '-'}", ""]

hn = txt("a5-debugfs-hnat.txt")
files = re.findall(r"^== (\S+)", hn, re.M)
out += [f"**Hardware NAT debugfs:** {len(files)} files ({', '.join(Path(f).name for f in files[:15])})"]
params = txt("a5-module-params.txt").strip().splitlines()
out += ["**Module parameters:** " + ("; ".join(p.split("/parameters/")[-1] for p in params[:20]) or "-"), ""]

mmc = txt("a6-mmc.txt")
ios = {k: v for k, v in re.findall(r"^(clock|actual clock|bus width|timing spec|signal voltage):\s*(.+)$", mmc, re.M)}
out += ["**eMMC:** " + (" | ".join(f"{k}: {v}" for k, v in ios.items()) or "no ios output"), ""]

sg = re.findall(r"^== (\S+)", txt("a4-sgmii-regmap.txt"), re.M)
out += [f"**SGMII regmaps found:** {len(sg)} ({', '.join(Path(s).name for s in sg) or '-'})"]
print("\n".join(out))
