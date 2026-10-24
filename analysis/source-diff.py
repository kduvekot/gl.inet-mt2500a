#!/usr/bin/env python3
"""Compact comparison of a vendor (MediaTek SDK) driver with its mainline
counterpart, for phase B of docs/driver-analysis-plan.md.

    source-diff.py <label> <vendor.c> <mainline.c> [more vendor/mainline files]

Pairs are given as vendor:mainline file lists separated by ':'.
Reports, in a few dozen lines: functions only on one side, register
constants (#define NAME value) that differ or exist on one side only, which
register writes each side does (phy_write_mmd/phy_modify_mmd/regmap/mtk_w32
calls with their register argument), and comments that mention workarounds.
"""
import re
import sys
from pathlib import Path

FUNC = re.compile(r"^(?:static\s+)?(?:inline\s+)?[\w\s\*]+?\b(\w+)\s*\([^;]*\)\s*\{", re.M)
DEFINE = re.compile(r"^#define\s+(\w+)\s+(.+?)\s*(?:/\*.*)?$", re.M)
WRITE = re.compile(
    r"\b(phy_write_mmd|phy_modify_mmd|phy_set_bits_mmd|phy_clear_bits_mmd|__phy_write_mmd|"
    r"phy_write|phy_modify|regmap_write|regmap_update_bits|regmap_set_bits|regmap_clear_bits|"
    r"mtk_w32|mtk_m32|mdiobus_write|mtk_mdio_write\w*)\s*\(([^;]*?)\)\s*;", re.S)
NOTE = re.compile(r"(?://|/\*|\*)\s*(.*\b(?:workaround|errata|hack|issue|bug|fix|wait|delay|ms\b|firmware|in-?band|AN\b|autoneg)\b.*)", re.I)


def load(paths):
    return "\n".join(Path(p).read_text(errors="replace") for p in paths)


def writes(src):
    out = set()
    for fn, args in WRITE.findall(src):
        a = [x.strip() for x in re.split(r",(?![^()]*\))", " ".join(args.split()))]
        if fn.endswith("_mmd") and len(a) >= 3:
            out.add(f"{fn}({a[1]}, {a[2]})")
        elif len(a) >= 2:
            out.add(f"{fn}({a[1]})")
    return out


def main():
    label, rest = sys.argv[1], " ".join(sys.argv[2:])
    vend, main_ = (s.split() for s in rest.split(":"))
    v, m = load(vend), load(main_)
    fv, fm = set(FUNC.findall(v)), set(FUNC.findall(m))
    dv, dm = dict(DEFINE.findall(v)), dict(DEFINE.findall(m))
    wv, wm = writes(v), writes(m)
    print(f"## {label}")
    print(f"vendor: {', '.join(Path(p).name for p in vend)} ({len(v.splitlines())} lines); "
          f"mainline: {', '.join(Path(p).name for p in main_)} ({len(m.splitlines())} lines)\n")
    print(f"**Functions only in vendor ({len(fv - fm)}):** " + ", ".join(sorted(fv - fm)[:60]))
    print(f"\n**Functions only in mainline ({len(fm - fv)}):** " + ", ".join(sorted(fm - fv)[:60]))
    same_name = sorted(k for k in dv.keys() & dm.keys() if dv[k] != dm[k])
    print(f"\n**Register/constant defines with different values ({len(same_name)}):** "
          + "; ".join(f"{k}: {dv[k]} vs {dm[k]}" for k in same_name[:25]))
    print(f"\n**Defines only in vendor ({len(dv.keys() - dm.keys())}):** "
          + ", ".join(sorted(dv.keys() - dm.keys())[:50]))
    print(f"\n**Register writes only in vendor ({len(wv - wm)}):**")
    for w in sorted(wv - wm)[:40]:
        print(f"- `{w}`")
    print(f"\n**Register writes only in mainline ({len(wm - wv)}):**")
    for w in sorted(wm - wv)[:40]:
        print(f"- `{w}`")
    notes = sorted({n.strip()[:140] for n in NOTE.findall(v)} - {n.strip()[:140] for n in NOTE.findall(m)})
    print(f"\n**Vendor-only comments about workarounds/timing/AN ({len(notes)}):**")
    for n in notes[:25]:
        print(f"- {n}")
    print()


if __name__ == "__main__":
    main()
