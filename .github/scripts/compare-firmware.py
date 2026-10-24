#!/usr/bin/env python3
"""Compare two unpacked OpenWrt root file systems and write a Markdown report.

    compare-firmware.py <official_root> <our_root> <removed-packages.txt> <out_dir>
                        [<official_kconfig> <our_kconfig>]

Used by the GL.iNet 4.2.0 recreation workflow: <official_root> is GL.iNet's
image, <our_root> our rebuild from public sources (may be missing if the
build failed). Compares installed packages (usr/lib/opkg/status), files,
kernel module directories and release files; maps differing files to the
package that installs them (usr/lib/opkg/info/*.list) and, when both kernel
configurations are given (fit-ikconfig.py), compares those too.
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


def owners(root):
    """file -> package, from the opkg file lists."""
    out = {}
    for lst in Path(root, "usr/lib/opkg/info").glob("*.list"):
        for line in lst.read_text(errors="replace").splitlines():
            out[line.strip().lstrip("/")] = lst.stem
    return out


def kconfig(path):
    """CONFIG_X -> value; '# CONFIG_X is not set' counts as absent."""
    out = {}
    if path and Path(path).is_file():
        for line in Path(path).read_text(errors="replace").splitlines():
            if line.startswith("CONFIG_") and "=" in line:
                k, v = line.split("=", 1)
                out[k] = v
    return out


def kconfig_section(ko, ku):
    if not ko or not ku:
        return ["## Kernel configuration", "", "Not compared (configuration missing on one side).", ""]
    keys = set(ko) | set(ku)
    diff = sorted(k for k in keys if ko.get(k) != ku.get(k))
    mod_off = [k for k in diff if ko.get(k) == "m" and k not in ku]
    mod_on = [k for k in diff if ku.get(k) == "m" and k not in ko]
    rest = [k for k in diff if k not in mod_off and k not in mod_on]
    r = ["## Kernel configuration", "",
         f"* Options set: official **{len(ko)}**, ours **{len(ku)}**; different **{len(diff)}**",
         f"* Module in official, off in ours: **{len(mod_off)}**; module in ours, off in official: **{len(mod_on)}**",
         f"* Other differences (built-in or values): **{len(rest)}**", "",
         "| Option | Official | Ours |", "|---|---|---|"]
    r += [f"| `{k}` | {ko.get(k, '-')} | {ku.get(k, '-')} |" for k in rest[:80]]
    if len(rest) > 80:
        r.append(f"| ... {len(rest) - 80} more in `kconfig-diff.txt` | | |")
    return r + [""]


def read(root, rel):
    p = Path(root, rel)
    return p.read_text(errors="replace").strip() if p.is_file() else "-"


def top(paths, depth=2, n=15):
    c = Counter("/".join(p.split("/")[:depth]) for p in paths)
    return "\n".join(f"| `{k}` | {v} |" for k, v in c.most_common(n))


def main():
    off, ours, removed_file, out = sys.argv[1:5]
    ko, ku = (kconfig(sys.argv[5]), kconfig(sys.argv[6])) if len(sys.argv) > 6 else ({}, {})
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

    own = owners(off)
    by_pkg = Counter(own.get(f, "(no package)") for f in files_diff)

    def mods(root):
        d = Path(root, "lib/modules")
        return ", ".join(sorted(x.name for x in d.iterdir())) if d.is_dir() else "-"

    def pkg_reason(p):
        if p.startswith(("gl-sdk4", "gl-", "oui-", "kmod-gl-sdk4", "libgl")):
            return "GL.iNet closed (UI/apps/modules)"
        if any(p == x.split(": ")[-1].strip() for x in removed if x):
            return "private GL.iNet feed"
        return "public, but not in our build"

    def file_reason(f):
        if f.startswith("lib/modules/"):
            return "kernel modules"
        if f.startswith(("etc/opkg", "usr/lib/opkg/")):
            return "opkg metadata"
        if f.startswith("etc/"):
            return "files in /etc"
        if f.startswith(("bin/", "sbin/", "usr/bin/", "usr/sbin/")):
            return "programs"
        return "libraries/other"

    r = ["# GL.iNet MT2500 4.2.0: official vs. rebuilt from public sources", ""]
    if not have_ours:
        r += ["**Our build produced no sysupgrade image**; see `build.log`. Only the official side is listed.", ""]
    r += ["| | Official 4.2.0 | Our rebuild |", "|---|---|---|",
          f"| `/etc/openwrt_version` | {read(off, 'etc/openwrt_version')} | {read(ours, 'etc/openwrt_version')} |",
          f"| `/etc/glversion` | {read(off, 'etc/glversion')} | {read(ours, 'etc/glversion')} |",
          f"| Kernel modules dir | {mods(off)} | {mods(ours) if have_ours else '-'} |",
          f"| Packages | {len(po)} | {len(pu)} |",
          f"| Files | {len(fo)} | {len(fu)} |", "",
          "## What's still different, and why", "",
          f"* Kernel package: official `{po.get('kernel', '-')}`, ours `{pu.get('kernel', '-')}`"
          + (" (**same kernel configuration**)" if po.get("kernel") == pu.get("kernel") else " (kernel configuration differs)"),
          "* Packages only in the official image: " + ", ".join(
              f"{v} {k}" for k, v in Counter(pkg_reason(p) for p in only_off).most_common()),
          "* Files that differ: " + ", ".join(
              f"{v} {k}" for k, v in Counter(file_reason(f) for f in files_diff).most_common()),
          "* Programs and libraries that differ: " + (", ".join(
              f"`{f}`" for f in files_diff if file_reason(f) in ("programs", "libraries/other")) or "none"),
          "* Public packages not in our build: " + (", ".join(
              f"`{p}`" for p in only_off if pkg_reason(p) == "public, but not in our build") or "none"), "",
          "### Differing files per package (official owner, top 30)", "",
          "| Package | Files |", "|---|---|"]
    r += [f"| `{p}` | {n} |" for p, n in by_pkg.most_common(30)]
    r += [""] + kconfig_section(ko, ku)
    r += ["## Packages", "",
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
          "Full lists: `packages-*.txt`, `files-*.txt`, `kconfig-diff.txt` in this artifact."]
    Path(out, "report.md").write_text("\n".join(r) + "\n")
    for name, data in (("packages-official.txt", po), ("packages-ours.txt", pu)):
        Path(out, name).write_text("".join(f"{k} {v}\n" for k, v in sorted(data.items())))
    for name, data in (("files-only-official.txt", files_only_off), ("files-only-ours.txt", files_only_ours),
                       ("files-different.txt", files_diff)):
        Path(out, name).write_text("\n".join(data) + "\n")
    Path(out, "kconfig-diff.txt").write_text("".join(
        f"{k} {ko.get(k, '-')} {ku.get(k, '-')}\n" for k in sorted(set(ko) | set(ku)) if ko.get(k) != ku.get(k)))
    Path(out, "files-different-by-package.txt").write_text("".join(
        f"{own.get(f, '(no package)')} {f}\n" for f in files_diff))
    print(f"report written to {out}/report.md")


if __name__ == "__main__":
    main()
