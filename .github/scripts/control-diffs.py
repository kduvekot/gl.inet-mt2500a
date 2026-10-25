#!/usr/bin/env python3
"""Which fields differ in the opkg control records of two root trees.

    control-diffs.py <official_root> <our_root> <out.tsv>

One line per differing package: package, differing fields, then official
and our values of those fields. A Depends that differs only in the kernel
line (the vermagic hash) counts as "vermagic". Prints a count per kind.
"""
import collections, os, re, sys

off, ours, out = sys.argv[1:4]
info = "usr/lib/opkg/info"


def fields(path):
    try:
        return dict(l.split(": ", 1) for l in open(path, errors="replace").read().splitlines() if ": " in l)
    except OSError:
        return {}


kinds, rows = collections.Counter(), []
for f in sorted(os.listdir(os.path.join(off, info))):
    if not f.endswith(".control"):
        continue
    a, b = fields(os.path.join(off, info, f)), fields(os.path.join(ours, info, f))
    if not b:
        continue
    diff = []
    for k in sorted(set(a) | set(b)):
        if a.get(k) != b.get(k):
            strip = lambda v: re.sub(r"kernel \(=[^)]*\)", "kernel", v or "")
            diff.append("vermagic" if k == "Depends" and strip(a.get(k)) == strip(b.get(k)) else k)
    if diff:
        kinds[",".join(diff)] += 1
        vals = [f"{k}: {a.get(k, '')} | {b.get(k, '')}" for k in diff if k != "vermagic"]
        rows.append("\t".join([f[:-8], ",".join(diff), *vals]))
open(out, "w").write("\n".join(rows) + "\n")
for k, n in kinds.most_common():
    print(f"{n:4} {k}")

# /usr/lib/opkg/status: Auto-Installed flags and entry order, with the
# differences already counted above (vermagic hash, Installed-Size) masked
# (Auto-Installed is reported on its own)
def status(root):
    out = []
    for b in open(os.path.join(root, "usr/lib/opkg/status"), errors="replace").read().split("\n\n"):
        f = dict(l.split(": ", 1) for l in b.splitlines() if ": " in l)
        if "Package" in f:
            out.append(f)
    return out
so, sn = status(off), status(ours)
auto = lambda s: {f["Package"] for f in s if f.get("Auto-Installed") == "yes"}
ao, an = auto(so), auto(sn)
print(f"status: Auto-Installed official {len(ao)}, ours {len(an)}, differing {len(ao ^ an)}"
      + (f" ({', '.join(sorted(ao ^ an)[:12])})" if ao ^ an else ""))
po, pn = [f["Package"] for f in so], [f["Package"] for f in sn]
print(f"status: entry order {'same' if po == pn else 'different'} ({len(po)} / {len(pn)} entries)")
mask = lambda f: {k: (re.sub(r"kernel \(=[^)]*\)", "kernel", v) if k == "Depends" else v)
                  for k, v in f.items() if k not in ("Installed-Size", "Auto-Installed")}
mo, mn = {f["Package"]: mask(f) for f in so}, {f["Package"]: mask(f) for f in sn}
other = sorted(p for p in mo if p in mn and mo[p] != mn[p])
print(f"status: other field differences in {len(other)} entries" + (f" ({', '.join(other[:12])})" if other else ""))
