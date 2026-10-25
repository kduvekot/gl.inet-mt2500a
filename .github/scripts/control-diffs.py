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
