#!/usr/bin/env python3
"""Compare two unpacked OpenWrt root file systems and write a Markdown report.

    compare-firmware.py <official_root> <our_root> <removed-packages.txt> <out_dir>

Used by the GL.iNet 4.2.0 recreation workflow: <official_root> is GL.iNet's
image, <our_root> our rebuild from public sources (may be missing if the
build failed). Compares installed packages (usr/lib/opkg/status), files,
kernel module directories and release files.
"""
import hashlib
import os
import sys
from collections import Counter
from pathlib import Path


def packages(root):
    status = Path(root, "usr/lib/opkg/status")
    pkgs, name = {}, None
    if not status.is_file():
        return pkgs
    for line in status.read_text(errors="replace").splitlines():
        if line.startswith("Package: "):
            name = line.split(": ", 1)[1]
        elif line.startswith("Version: ") and name:
            pkgs[name] = line.split(": ", 1)[1]
    return pkgs


def files(root):
    out = {}
    for dirpath, dirnames, filenames in os.walk(root):
        for f in filenames:
            p = Path(dirpath, f)
            rel = str(p.relative_to(root))
            if p.is_symlink():
                out[rel] = "link:" + os.readlink(p)
            elif p.is_file():
                out[rel] = hashlib.sha256(p.read_bytes()).hexdigest()[:16]
    return out


def read(root, rel):
    p = Path(root, rel)
    return p.read_text(errors="replace").strip() if p.is_file() else "-"


def top(paths, depth=2, n=15):
    c = Counter("/".join(p.split("/")[:depth]) for p in paths)
    return "\n".join(f"| `{k}` | {v} |" for k, v in c.most_common(n))


def main():
    off, ours, removed_file, out = sys.argv[1:5]
    Path(out).mkdir(parents=True, exist_ok=True)
    have_ours = Path(ours).is_dir()
    removed = Path(removed_file).read_text().split("\n") if Path(removed_file).is_file() else []

    po, pu = packages(off), packages(ours) if have_ours else {}
    fo, fu = files(off), files(ours) if have_ours else {}

    only_off = sorted(set(po) - set(pu))
    only_ours = sorted(set(pu) - set(po))
    both = sorted(set(po) & set(pu))
    same_ver = [p for p in both if po[p] == pu[p]]
    diff_ver = [p for p in both if po[p] != pu[p]]

    files_only_off = sorted(set(fo) - set(fu))
    files_only_ours = sorted(set(fu) - set(fo))
    files_both = sorted(set(fo) & set(fu))
    files_same = [f for f in files_both if fo[f] == fu[f]]
    files_diff = [f for f in files_both if fo[f] != fu[f]]

    def mods(root):
        d = Path(root, "lib/modules")
        return ", ".join(sorted(x.name for x in d.iterdir())) if d.is_dir() else "-"

    r = ["# GL.iNet MT2500 4.2.0: official vs. rebuilt from public sources", ""]
    if not have_ours:
        r += ["**Our build produced no sysupgrade image**; see `build.log`. Only the official side is listed.", ""]
    r += ["| | Official 4.2.0 | Our rebuild |", "|---|---|---|",
          f"| `/etc/openwrt_version` | {read(off, 'etc/openwrt_version')} | {read(ours, 'etc/openwrt_version')} |",
          f"| `/etc/glversion` | {read(off, 'etc/glversion')} | {read(ours, 'etc/glversion')} |",
          f"| Kernel modules dir | {mods(off)} | {mods(ours) if have_ours else '-'} |",
          f"| Packages | {len(po)} | {len(pu)} |",
          f"| Files | {len(fo)} | {len(fu)} |", "",
          "## Packages", "",
          f"* In both: **{len(both)}**, same version **{len(same_ver)}**, different version **{len(diff_ver)}**",
          f"* Only in the official image: **{len(only_off)}**",
          f"* Only in our rebuild: **{len(only_ours)}**",
          f"* Left out of our build on purpose (private GL.iNet feeds): **{len([x for x in removed if x])}**", "",
          "### Only in the official image", "", "| Package | Version |", "|---|---|"]
    r += [f"| `{p}` | {po[p]} |" for p in only_off]
    r += ["", "### Only in our rebuild", "", "| Package | Version |", "|---|---|"]
    r += [f"| `{p}` | {pu[p]} |" for p in only_ours]
    r += ["", "### Different versions", "", "| Package | Official | Ours |", "|---|---|---|"]
    r += [f"| `{p}` | {po[p]} | {pu[p]} |" for p in diff_ver]
    r += ["", "## Files", "",
          f"* In both: **{len(files_both)}**, identical content **{len(files_same)}**, different **{len(files_diff)}**",
          f"* Only official: **{len(files_only_off)}**; only ours: **{len(files_only_ours)}**", "",
          "### Where the official-only files are", "", "| Directory | Files |", "|---|---|", top(files_only_off), "",
          "### Where the differing files are", "", "| Directory | Files |", "|---|---|", top(files_diff), "",
          "Full lists: `packages-*.txt`, `files-*.txt` in this artifact."]
    Path(out, "report.md").write_text("\n".join(r) + "\n")
    for name, data in (("packages-official.txt", po), ("packages-ours.txt", pu)):
        Path(out, name).write_text("".join(f"{k} {v}\n" for k, v in sorted(data.items())))
    for name, data in (("files-only-official.txt", files_only_off), ("files-only-ours.txt", files_only_ours),
                       ("files-different.txt", files_diff)):
        Path(out, name).write_text("\n".join(data) + "\n")
    print(f"report written to {out}/report.md")


if __name__ == "__main__":
    main()
