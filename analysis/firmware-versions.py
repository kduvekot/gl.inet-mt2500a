#!/usr/bin/env python3
"""Which drivers changed between GL.iNet MT2500 firmware versions.

    firmware-versions.py <firmware-dir> <out-dir>

<firmware-dir> holds GL.iNet's sysupgrade images (*-4.x.y-*.bin, tar files
with kernel + root) and optionally sub-directories with a loose
kernel-<ver>.itb + rootfs-<ver>.squashfs pair (such as 4.7.13, read from a
unit). Per version it unpacks only lib/modules, lib/firmware, the opkg
status and /etc/glversion (needs unsquashfs), reads the kernel image (FIT):
kernel version, embedded kernel config, device tree, and writes:

  <out-dir>/summary.md    a short table per version and per driver
  <out-dir>/files.tsv     version, path, sha256 of every module/firmware file
  <out-dir>/kconfig-<ver>.txt, dtb-<ver>.dtb

Nothing of the firmware itself goes to <out-dir> besides the kernel config
and device tree. Unpacked trees are removed after each version.
"""
import gzip
import hashlib
import lzma
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import zlib
from pathlib import Path

KEEP = ["lib/modules", "lib/firmware", "usr/lib/opkg/status", "etc/glversion"]
# Modules worth naming in the summary (network/storage hardware and GL.iNet's own).
FOCUS = re.compile(r"hnat|mtk|mt7|air_|en88|gpy|mxl|phy|eth|sgmii|mmc|nf_nat|nf_conntrack|"
                   r"kmwan|mtfwd|mtqos|parental|black_white|tertf|hw_info|mpflow|gl_|shortcut|fast", re.I)


def vkey(v):
    return [int(x) if x.isdigit() else x for x in re.split(r"[._-]", v)]


def fit_images(data):
    """{node name: {prop: bytes}} for /images/* of a FIT."""
    off_s, off_str = struct.unpack(">II", data[8:16])
    strs = data[off_str:]
    p, path, out = off_s, [], {}
    while p < len(data):
        tok = struct.unpack(">I", data[p:p + 4])[0]
        p += 4
        if tok == 1:
            e = data.index(b"\0", p)
            path.append(data[p:e].decode())
            p = (e + 4) & ~3
        elif tok == 2:
            path.pop()
        elif tok == 3:
            ln, no = struct.unpack(">II", data[p:p + 8])
            p += 8
            name = strs[no:strs.index(b"\0", no)].decode()
            if len(path) >= 2 and path[-2] == "images":
                out.setdefault(path[-1], {})[name] = data[p:p + ln]
            p = (p + ln + 3) & ~3
        elif tok == 4:
            continue
        else:
            break
    return out


def kernel_info(fit):
    imgs = fit_images(fit)
    k = next(v for n, v in imgs.items() if n.startswith("kernel"))
    comp = k.get("compression", b"none").rstrip(b"\0").decode()
    raw = k["data"]
    raw = lzma.decompress(raw, format=lzma.FORMAT_ALONE) if comp == "lzma" else \
        gzip.decompress(raw) if comp == "gzip" else raw
    m = re.search(rb"Linux version (\S+)", raw)
    i = raw.find(b"IKCFG_ST")
    cfg = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(raw[i + 8:]).decode() if i >= 0 else ""
    dtb = next((v["data"] for n, v in imgs.items() if n.startswith("fdt")), b"")
    return {"kver": m.group(1).decode() if m else "-",
            "kernel": hashlib.sha256(raw).hexdigest()[:12],
            "kconfig": cfg, "dtb": dtb}


def packages(status):
    out, name = {}, None
    if status.is_file():
        for line in status.read_text(errors="replace").splitlines():
            if line.startswith("Package: "):
                name = line[9:]
            elif line.startswith("Version: ") and name:
                out[name] = line[9:]
    return out


def unpack(kernel, root, tmp):
    shutil.rmtree(tmp, ignore_errors=True)
    subprocess.run(["unsquashfs", "-q", "-n", "-d", str(tmp), str(root)] + KEEP,
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    files = {}
    for top in ("lib/modules", "lib/firmware"):
        for p in sorted((tmp / top).rglob("*")):
            if p.is_file() and not p.is_symlink():
                rel = str(p.relative_to(tmp))
                rel = re.sub(r"^lib/modules/[^/]+/", "lib/modules/", rel)
                files[rel] = hashlib.sha256(p.read_bytes()).hexdigest()[:12]
    gv = tmp / "etc/glversion"
    info = kernel_info(Path(kernel).read_bytes())
    info.update(files=files, pkgs=packages(tmp / "usr/lib/opkg/status"),
                glversion=gv.read_text().strip() if gv.is_file() else "-")
    shutil.rmtree(tmp, ignore_errors=True)
    return info


def sources(fwdir, tmp):
    for b in fwdir.glob("*.bin"):
        m = re.search(r"-(4\.\d+\.\d+(?:_beta\d+)?)-", b.name)
        if not m:
            continue
        t = tmp.with_name(tmp.name + "-tar")
        shutil.rmtree(t, ignore_errors=True)
        t.mkdir(parents=True)
        with tarfile.open(b) as tf:
            for mem in tf.getmembers():
                if mem.isfile() and mem.name.rsplit("/", 1)[-1] in ("kernel", "root"):
                    mem.name = mem.name.rsplit("/", 1)[-1]
                    tf.extract(mem, t, filter="data")
        yield m.group(1), t / "kernel", t / "root", t
    for d in fwdir.iterdir():
        k, r = list(d.glob("kernel-*.itb")) if d.is_dir() else [], list(d.glob("rootfs-*.squashfs")) if d.is_dir() else []
        if k and r:
            yield re.search(r"kernel-(.+)\.itb", k[0].name).group(1), k[0], r[0], None


def main():
    fwdir, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    tmp = out / "tmp"
    data = {}
    for ver, kernel, root, cleanup in sources(fwdir, tmp):
        print("unpacking", ver, flush=True)
        data[ver] = unpack(kernel, root, tmp)
        if cleanup:
            shutil.rmtree(cleanup, ignore_errors=True)
        (out / f"kconfig-{ver}.txt").write_text(data[ver]["kconfig"])
        (out / f"dtb-{ver}.dtb").write_bytes(data[ver]["dtb"])
    vers = sorted(data, key=vkey)
    with open(out / "files.tsv", "w") as f:
        for v in vers:
            for p, h in sorted(data[v]["files"].items()):
                f.write(f"{v}\t{p}\t{h}\n")

    def kcfg(v):
        return {l.split("=", 1)[0]: l.split("=", 1)[1] for l in data[v]["kconfig"].splitlines()
                if l.startswith("CONFIG_") and "=" in l}

    r = ["# GL.iNet MT2500 firmware versions: what changed in the hardware layer", "",
         "Each row compares with the previous version. Kernel = decompressed kernel image "
         "(includes the built-in drivers: Ethernet, GPY211 PHY, eMMC); kconfig = embedded "
         "kernel configuration; DT = device tree.", "",
         "| Version | Kernel | Kernel image | kconfig changes | DT | Modules +/-/changed | Firmware files changed | Changed modules (selection) |",
         "|---|---|---|---|---|---|---|---|"]
    prev = None
    for v in vers:
        d = data[v]
        if prev is None:
            r.append(f"| {v} | {d['kver']} | `{d['kernel']}` | (first) | `{hashlib.sha256(d['dtb']).hexdigest()[:8]}` "
                     f"| {sum(p.startswith('lib/modules') for p in d['files'])} modules | "
                     f"{sum(p.startswith('lib/firmware') for p in d['files'])} files | |")
        else:
            p = data[prev]
            ka, kb = kcfg(prev), kcfg(v)
            kch = [k for k in set(ka) | set(kb) if ka.get(k) != kb.get(k)]
            mods = lambda x: {k: h for k, h in x["files"].items() if k.startswith("lib/modules")}
            fw = lambda x: {k: h for k, h in x["files"].items() if k.startswith("lib/firmware")}
            ma, mb = mods(p), mods(d)
            add = sorted(set(mb) - set(ma))
            rem = sorted(set(ma) - set(mb))
            chg = sorted(k for k in set(ma) & set(mb) if ma[k] != mb[k])
            fa, fb = fw(p), fw(d)
            fch = sorted(k for k in set(fa) | set(fb) if fa.get(k) != fb.get(k))
            names = [Path(x).name for x in add + chg + rem]
            focus = [n for n in names if FOCUS.search(n)]
            dt = "same" if p["dtb"] == d["dtb"] else f"**changed** `{hashlib.sha256(d['dtb']).hexdigest()[:8]}`"
            r.append(f"| {v} | {d['kver']} | {'same' if p['kernel'] == d['kernel'] else '`' + d['kernel'] + '`'} | "
                     f"{len(kch) or 'none'}{': ' + ', '.join(sorted(kch)[:6]) if 0 < len(kch) <= 6 else ''} | {dt} | "
                     f"+{len(add)} / -{len(rem)} / ~{len(chg)} | {', '.join(Path(x).name for x in fch[:5]) or 'none'}"
                     f"{' …' if len(fch) > 5 else ''} | {', '.join(focus[:14])}{' …' if len(focus) > 14 else ''} |")
        prev = v

    # Timeline per focus module: versions in which its file changed.
    r += ["", "## Per driver: versions in which the file changed", "",
          "| Module / firmware | Present | Changed in |", "|---|---|---|"]
    allfiles = sorted({p for v in vers for p in data[v]["files"]})
    for p in allfiles:
        n = Path(p).name
        if not (FOCUS.search(n) or p.startswith("lib/firmware")):
            continue
        hist, last, present = [], None, []
        for v in vers:
            h = data[v]["files"].get(p)
            if h:
                present.append(v)
            if h != last and last is not None:
                hist.append(v + ("" if h else " (removed)"))
            last = h
        if present:
            r.append(f"| `{n}` | {present[0]}–{present[-1]} | {', '.join(hist) or 'never'} |")
    r += ["", "## GL.iNet/MediaTek driver packages per version", ""]
    keys = sorted({k for v in vers for k in data[v]["pkgs"]
                   if re.search(r"^kmod-(gl|mt|hnat|air|en88)|mtkhnat|mtk-base|fwdd|^kmod-.*(hnat|mtfwd|mtqos)", k)})
    r += ["| Package | " + " | ".join(vers) + " |", "|---" * (len(vers) + 1) + "|"]
    for k in keys:
        row, last = [], None
        for v in vers:
            val = data[v]["pkgs"].get(k, "")
            short = re.sub(r"^5\.4\.\d+\+", "", val)[:22]
            row.append("·" if val == last and val else (short or "–"))
            last = val
        r.append(f"| `{k}` | " + " | ".join(row) + " |")
    r += ["", "`·` = same as the previous version, `–` = not installed."]
    (out / "summary.md").write_text("\n".join(r) + "\n")
    print(f"summary: {out / 'summary.md'}")


if __name__ == "__main__":
    main()
