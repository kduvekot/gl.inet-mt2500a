#!/usr/bin/env python3
"""Compare two unpacked GL.iNet firmware root file systems a level deeper
than checksums.

    version-diff.py <old_root> <new_root> <old_kernel_fit> <new_kernel_fit> <label> <out.md> [<out.tsv>]

Every regular file falls in one class:
  new, gone, identical,
  meta-only   different bytes, same substance: ELF files (programs, libraries,
              kernel modules) whose code and data sections are identical (only
              build ID, .comment, .modinfo version stamps etc. differ); text
              files where only version/date/hash lines changed; opkg records
              where only Version/Installed-Size/SourceDateEpoch changed; .pyc
              files whose body is identical
  changed     real change: code, data or content (ELF: which sections)
The report groups changed files by package (from the opkg .list files of the
new image) and lists package version changes, plus the kernel image (code),
kernel configuration and device tree.
"""
import collections, gzip, hashlib, lzma, os, re, struct, subprocess, sys, zlib

ELF_SUBSTANCE = (".text", ".rodata", ".data", ".init.text", ".exit.text", ".init.data",
                 ".data.rel.ro", ".plt", ".got", ".init_array", ".fini_array")
META_RE = re.compile(r"(version|release|revision|date|time|epoch|build|installed-size|"
                     r"r\d{4,}|\b\d{4}-\d{2}-\d{2}\b|\b[0-9a-f]{7,40}\b|git-\d{4})", re.I)


def owners(root):
    out = {}
    d = os.path.join(root, "usr/lib/opkg/info")
    if os.path.isdir(d):
        for f in os.listdir(d):
            if f.endswith(".list"):
                for l in open(os.path.join(d, f), errors="replace"):
                    out[l.strip().lstrip("/")] = f[:-5]
    return out


def packages(root):
    p, out, name = os.path.join(root, "usr/lib/opkg/status"), {}, None
    if os.path.exists(p):
        for l in open(p, errors="replace"):
            if l.startswith("Package: "): name = l[9:].strip()
            elif l.startswith("Version: ") and name: out[name] = l[9:].strip()
    return out


def sections(path):
    r = subprocess.run(["readelf", "-SW", path], capture_output=True, text=True).stdout
    out = {}
    for m in re.finditer(r"\]\s+(\S+)\s+(\S+)\s+[0-9a-f]+\s+([0-9a-f]+)\s+([0-9a-f]+)", r):
        name, typ, off, size = m.group(1), m.group(2), int(m.group(3), 16), int(m.group(4), 16)
        if typ == "NOBITS": continue
        with open(path, "rb") as f:
            f.seek(off); out[name] = hashlib.sha1(f.read(size)).hexdigest()
    return out


def classify(a, b, rel):
    A, B = open(a, "rb").read(), open(b, "rb").read()
    if A == B: return "identical", ""
    if A[:4] == b"\x7fELF" and B[:4] == b"\x7fELF":
        sa, sb = sections(a), sections(b)
        if not sa or not sb:   # sstripped: no section table; compare loadable bytes roughly
            return "changed", "no section table"
        diff = sorted(n for n in set(sa) | set(sb) if sa.get(n) != sb.get(n))
        subst = [n for n in diff if n.startswith(ELF_SUBSTANCE) or n in ("__ksymtab", "__ksymtab_strings")]
        if not subst:
            return "meta-only", ",".join(diff)[:80]
        return "changed", ",".join(subst)[:80]
    if rel.endswith(".pyc") and len(A) > 16 and A[16:] == B[16:]:
        return "meta-only", "pyc header"
    try:
        ta, tb = A.decode().splitlines(), B.decode().splitlines()
    except UnicodeDecodeError:
        return "changed", "binary"
    if rel.startswith("usr/lib/opkg/info/") and rel.endswith(".control"):
        fa = dict(l.split(": ", 1) for l in ta if ": " in l)
        fb = dict(l.split(": ", 1) for l in tb if ": " in l)
        diff = [k for k in set(fa) | set(fb) if fa.get(k) != fb.get(k)]
        if set(diff) <= {"Version", "Installed-Size", "SourceDateEpoch"}:
            return "meta-only", "control: " + ",".join(sorted(diff))
        return "changed", "control: " + ",".join(sorted(diff))
    sa, sb = set(ta), set(tb)
    changed = list(sa ^ sb)
    if changed and all(META_RE.search(l) for l in changed) and len(ta) == len(tb):
        return "meta-only", "version/date lines"
    return "changed", f"{len(sa - sb)} lines out, {len(sb - sa)} in"


def fit_kernel(path):
    """(kernel code sha, ikconfig text, dtb sha) from a FIT image."""
    try:
        d = open(path, "rb").read()
        off_s, off_str = struct.unpack(">II", d[8:16]); strs = d[off_str:]
        p, path_, props = off_s, [], {}
        while p < len(d):
            tok = struct.unpack(">I", d[p:p + 4])[0]; p += 4
            if tok == 1:
                e = d.index(b"\0", p); path_.append(d[p:e].decode()); p = (e + 4) & ~3
            elif tok == 2: path_.pop()
            elif tok == 3:
                ln, no = struct.unpack(">II", d[p:p + 8]); p += 8
                nm = strs[no:strs.index(b"\0", no)].decode()
                if len(path_) >= 2 and path_[-2] == "images": props.setdefault(path_[-1], {})[nm] = d[p:p + ln]
                p = (p + ln + 3) & ~3
            elif tok == 4: continue
            else: break
        k = next(v for n, v in props.items() if n.startswith("kernel"))
        comp = k.get("compression", b"none").rstrip(b"\0").decode()
        raw = lzma.decompress(k["data"], format=lzma.FORMAT_ALONE) if comp == "lzma" else \
            gzip.decompress(k["data"]) if comp == "gzip" else k["data"]
        # build metadata, not code: the build date (banner and UTS_VERSION, uname -v),
        raw_nb = raw
        # UTS_VERSION ("#0 SMP Tue Mar 14 02:16:44 2023", uname -v) is stored separately
        raw_nb = re.sub(rb"#\d+ SMP(?: PREEMPT)? [A-Z][a-z]{2} [A-Z][a-z]{2} +\d{1,2} \d\d:\d\d:\d\d(?: [A-Z]{2,5})? \d{4}", b"#UTS", raw_nb)
        # built-in initramfs: cpio "newc" headers carry each file's mtime
        raw_nb = re.sub(rb"(070701(?:[0-9A-Fa-f]{8}){5})[0-9A-Fa-f]{8}", rb"\1MTIMEXXX", raw_nb)
        # GNU build-ID notes (20-byte hashes over build details) are metadata too
        raw_nb = re.sub(rb"(\x04\x00\x00\x00\x14\x00\x00\x00\x03\x00\x00\x00GNU\x00).{20}", rb"\1", raw_nb, flags=re.S)
        # ... and the zero padding after strings whose length changed with the date
        raw_nb = re.sub(rb"\x00+", b"\x00", raw_nb)
        i = raw.find(b"IKCFG_ST")
        cfg = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(raw[i + 8:]).decode() if i >= 0 else ""
        dtb = next((v["data"] for n, v in props.items() if n.startswith("fdt")), b"")
        return hashlib.sha1(raw_nb).hexdigest(), len(raw), cfg, hashlib.sha1(dtb).hexdigest()
    except Exception as e:
        return f"error {e}", 0, "", ""


def walk(root):
    out = {}
    for dp, dn, fn in os.walk(root):
        for n in fn:
            p = os.path.join(dp, n)
            if os.path.isfile(p) and not os.path.islink(p):
                out[os.path.relpath(p, root)] = p
    return out


def main():
    old, new, kold, knew, label, out = sys.argv[1:7]
    tsv = sys.argv[7] if len(sys.argv) > 7 else None
    fo, fn = walk(old), walk(new)
    own = owners(new); own_old = owners(old)
    rows, cls = [], collections.Counter()
    for rel in sorted(set(fo) | set(fn)):
        if rel not in fn: c, note = "gone", ""
        elif rel not in fo: c, note = "new", ""
        else: c, note = classify(fo[rel], fn[rel], rel)
        cls[c] += 1
        rows.append((own.get(rel) or own_old.get(rel) or "-", rel, c, note))
    po, pn = packages(old), packages(new)
    ko, kn = fit_kernel(kold), fit_kernel(knew)
    cfg_o = {l.split("=")[0]: l for l in ko[2].splitlines() if l.startswith("CONFIG_")}
    cfg_n = {l.split("=")[0]: l for l in kn[2].splitlines() if l.startswith("CONFIG_")}
    cfg_d = sorted(k for k in set(cfg_o) | set(cfg_n) if cfg_o.get(k) != cfg_n.get(k))
    r = [f"## {label}", "",
         "Files: " + ", ".join(f"{k} **{cls[k]}**" for k in ("identical", "meta-only", "changed", "new", "gone")), "",
         f"Kernel code: {'**same**' if ko[0] == kn[0] else '**changed**'} (banner excluded); "
         f"kernel config: {len(cfg_d) or 'same'}{' (' + ', '.join(x.replace('CONFIG_','') for x in cfg_d[:8]) + ')' if 0 < len(cfg_d) <= 8 else ''}; "
         f"device tree: {'same' if ko[3] == kn[3] else '**changed**'}", "",
         f"Packages: {len(set(pn) - set(po))} new, {len(set(po) - set(pn))} gone, "
         f"{sum(1 for p in set(po) & set(pn) if po[p] != pn[p])} with a new version", ""]
    changed = collections.defaultdict(list)
    for pkg, rel, c, note in rows:
        if c in ("changed", "new", "gone"): changed[pkg].append((c, rel, note))
    r += ["| Package | Really changed / new / gone files |", "|---|---|"]
    for pkg, items in sorted(changed.items(), key=lambda x: -len(x[1]))[:40]:
        cc = collections.Counter(c for c, _, _ in items)
        ex = ", ".join(f"`{os.path.basename(rel)}`" for c, rel, _ in items if c == "changed")[:150]
        r.append(f"| `{pkg}` | {', '.join(f'{k} {v}' for k, v in cc.items())}{'; ' + ex if ex else ''} |")
    if len(changed) > 40: r.append(f"| ... {len(changed) - 40} more packages | |")
    newp = sorted(set(pn) - set(po)); gonep = sorted(set(po) - set(pn))
    if newp: r += ["", "New packages: " + ", ".join(f"`{p}`" for p in newp[:60])]
    if gonep: r += ["", "Gone packages: " + ", ".join(f"`{p}`" for p in gonep[:60])]
    r.append("")
    open(out, "w").write("\n".join(r) + "\n")
    if tsv:
        with open(tsv, "w") as f:
            for row in rows:
                if row[2] != "identical": f.write("\t".join(row) + "\n")
    print("\n".join(r[:4]))


if __name__ == "__main__":
    main()
