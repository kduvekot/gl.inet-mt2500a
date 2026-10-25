#!/usr/bin/env python3
"""Classify why files differ between two root trees (GL.iNet recreation).

    classify.py <off_root> <our_root> <list> <out.tsv>

Per file: elf-buildid-only (identical after dropping build-id notes),
elf-sstripped (no section table to compare),
elf-code (.text differs), elf-data (code same, other sections differ),
pyc-mtime-only, text (shows first differing line), binary, size.
Prints a Markdown section: counts per class and per package (via opkg
.list files); the per-file table goes to <out.tsv>.
"""
import collections, os, re, subprocess, sys, tempfile
from pathlib import Path

off, ours, lst, out = sys.argv[1:5]
own = {}
for l in Path(off, "usr/lib/opkg/info").glob("*.list"):
    for line in l.read_text(errors="replace").splitlines():
        own[line.strip().lstrip("/")] = l.stem


def sections(p):
    r = subprocess.run(["readelf", "-SW", p], capture_output=True, text=True).stdout
    return {m.group(1): (int(m.group(2), 16), int(m.group(3), 16))
            for m in re.finditer(r"\]\s+(\S+)\s+\S+\s+[0-9a-f]+\s+([0-9a-f]+)\s+([0-9a-f]+)", r)}


def sec_bytes(p, off_size):
    o, s = off_size
    with open(p, "rb") as f:
        f.seek(o)
        return f.read(s)


def classify(a, b):
    A, B = open(a, "rb").read(), open(b, "rb").read()
    if A[:4] == b"\x7fELF" and B[:4] == b"\x7fELF":
        sa, sb = sections(a), sections(b)
        if not sa or not sb:
            # sstripped (no section table): nothing to tell code from metadata
            return "elf-sstripped", "size" if len(A) != len(B) else "same-size"
        diff = [n for n in set(sa) | set(sb)
                if n not in sa or n not in sb or sec_bytes(a, sa[n]) != sec_bytes(b, sb[n])]
        diff = [n for n in diff if n not in (".shstrtab",)]
        if set(diff) <= {".note.gnu.build-id"}:
            return "elf-buildid-only", ""
        if ".text" in diff:
            return "elf-code", ",".join(sorted(diff))[:80]
        return "elf-data", ",".join(sorted(diff))[:80]
    if a.endswith(".pyc") and len(A) == len(B) and A[:8] == B[:8] and A[16:] == B[16:]:
        return "pyc-mtime-only", ""
    if len(A) != len(B):
        kind = "size"
    else:
        kind = "same-size"
    try:
        ta, tb = A.decode().splitlines(), B.decode().splitlines()
        for x, y in zip(ta, tb):
            if x != y:
                return "text-" + kind, f"{x[:70]!r} | {y[:70]!r}"
        return "text-" + kind, f"lines {len(ta)} vs {len(tb)}"
    except UnicodeDecodeError:
        return "binary-" + kind, ""


rows, cls, bypkg = [], collections.Counter(), collections.defaultdict(collections.Counter)
for f in Path(lst).read_text().split():
    a, b = os.path.join(off, f), os.path.join(ours, f)
    if not (os.path.isfile(a) and os.path.isfile(b)):
        continue
    c, note = classify(a, b)
    rows.append((own.get(f, "-"), f, c, note))
    cls[c] += 1
    bypkg[own.get(f, "-")][c] += 1
with open(out, "w") as fh:
    for r in rows:
        fh.write("\t".join(r) + "\n")
md = ["## Why the remaining files differ", "",
      "Classes: " + ", ".join(f"{k} **{v}**" for k, v in cls.most_common()), "",
      "| Package (official owner) | Files | Classes |", "|---|---|---|"]
md += [f"| `{p}` | {sum(c.values())} | {', '.join(f'{k} {v}' for k, v in c.most_common())} |"
       for p, c in sorted(bypkg.items(), key=lambda x: -sum(x[1].values()))[:30]]
print("\n".join(md))
