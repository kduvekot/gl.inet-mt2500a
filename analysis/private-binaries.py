#!/usr/bin/env python3
"""Report the binaries of GL.iNet's MT2500 releases that we can't build
byte-identical from public source (docs/closed-binaries/).

    sudo private-binaries.py <repo> <roots dir> <kernels dir> <fw dir> <results dir> <queue.log> <out dir> [<private dir>]

<repo>: this repository (openwrt/gl-releases.tsv, openwrt/gl-4.2.0-closed,
.github/scripts/gen-closed-feed.py); <roots dir>/<release>/: the unpacked root
file systems; <kernels dir>/<release>.itb: the kernel FIT images; <fw dir>:
the official images (<release>-<name>.bin); <results dir>, <queue.log>: the
local build runner's results. Writes <out dir>/<release>.md, README.md (one
row per binary, one column per release). Metadata only: paths,
sizes, hashes and what the files say about themselves; never file contents.

A binary is "private" when it is
  - part of a closed package that the recipe copies from the official image
    (gen-closed-feed.py's own selection for that release, so packages built
    from GL.iNet's published source or from public source are left out), or
  - a file of a public package that still differs in the release's best
    complete comparison (outside the accepted classes: Samba, Python
    bytecode, wg, kernel version fields), or
  - the kernel image, when its code differs function by function.
Text files are left out (scripts, configuration, Lua source, web files, also
when gzip-compressed); everything else is listed with its type.

Each binary's strings are also scanned for sensitive-looking data (PEM keys
and certificates, credential-like assignments, URLs with a password, long
high-entropy strings). The public report only flags the kind and count; the
matches themselves go to <private dir>/<release>.md when given (meant for
the private decompilation repository, never for this one).
"""
import collections, gzip, hashlib, os, re, subprocess, sys, tempfile

repo, roots, kernels, fwdir, results, qlog, out = sys.argv[1:8]
private = sys.argv[8] if len(sys.argv) > 8 else None
BUNDLE = "sysupgrade-glinet_gl-mt2500"
ACCEPTED = re.compile(r"samba|\.pyc|libndr|libdcerpc|libsmb|libsamba|libnetapi|libsamdb|/smb|nmblookup|ntlm_auth"
                      r"|pdbedit|sharesec|testparm|mvxattr|oLschema|^usr/bin/wg$|^usr/lib/opkg/")
INTERESTING = re.compile(r"(?i)(version[ :=]|\bv\d+\.\d+|copyright|\(c\) |licen[sc]e|gl\.inet|glinet|"
                         r"mediatek|airoha|quectel|build|compiled)")


SENSITIVE = [
    ("PEM private key", re.compile(rb"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("PEM certificate", re.compile(rb"-----BEGIN CERTIFICATE-----")),
    ("PEM public key", re.compile(rb"-----BEGIN [A-Z ]*PUBLIC KEY-----")),
    ("URL with credentials", re.compile(rb"[a-z][a-z0-9+.-]*://[^/\s:@\x00]+:[^/\s@\x00]+@[^\s\x00]+")),
    ("credential assignment", re.compile(rb"(?i)\b(passw(or)?d|passwd|secret|api[_-]?key|access[_-]?key|token|auth[_-]?key)"
                                          rb"\s*[=:]\s*['\"]?[A-Za-z0-9+/=_\-!@#$%^&*.]{6,}")),
]
B64ISH = re.compile(rb"[A-Za-z0-9+/_\-]{32,}={0,2}")


def entropy(b):
    import math
    c = collections.Counter(b)
    return -sum(n / len(b) * math.log2(n / len(b)) for n in c.values())


def scan_sensitive(data):
    """[(kind, offset, match)] for sensitive-looking data in a binary"""
    hits = []
    for kind, rx in SENSITIVE:
        for m in rx.finditer(data):
            hits.append((kind, m.start(), m.group(0)[:200]))
    for m in B64ISH.finditer(data):
        t = m.group(0)
        if len(t) >= 40 and entropy(t) > 4.8 and not re.fullmatch(rb"[A-Za-z_]+", t) \
                and not any(o <= m.start() < o + len(x) for _, o, x in hits):
            hits.append(("high-entropy string", m.start(), t[:200]))
    return hits


def run(*a, **k):
    return subprocess.run(a, capture_output=True, text=True, errors="replace", **k).stdout


def releases():
    rows = [l.rstrip("\n").split("\t") for l in open(f"{repo}/openwrt/gl-releases.tsv") if l.strip()]
    hdr = rows[0]
    return [dict(zip(hdr, r)) for r in rows[1:]]


def best_job(rel):
    """the newest complete comparison of this release, runs without ccache first"""
    done = {}
    for l in open(qlog):
        m = re.match(r"\S+ \S+ done\s+(\S+) in \d+ min: (.*)$", l)
        if m and m.group(2).split("[")[0].strip() == "exit 0 exit 0 exit 0 exit 0":
            done[m.group(1)] = l[:16]
    cands = []
    for name, when in done.items():
        args = next((open(os.path.join(d, f)).read() for d in (os.path.join(os.path.dirname(qlog), "queue"), os.path.join(os.path.dirname(qlog), "queue2"))
                     for f in os.listdir(d) if f.startswith(name + ".args")), "")
        words = args.split()
        if not any(w.startswith("release=") for w in words):
            words.append("release=4.2.0")    # jobs before the release value built 4.2.0
        if f"release={rel}" in words and "dry=true" not in words and "closed=true" in words and \
                os.path.exists(f"{results}/{name}/report/files-different-classes.tsv"):
            cands.append(("ccache=false" in args.split(), when, name))
    return max(cands)[2] if cands else None


def closed_from_image(r):
    """packages gen-closed-feed.py copies from the image for this release"""
    with tempfile.TemporaryDirectory() as t:
        a = [sys.executable, "-I", f"{repo}/.github/scripts/gen-closed-feed.py", f"{roots}/{r['release']}", t,
             f"{repo}/openwrt/gl-4.2.0-closed", f"--private-now={r['private_now']}", f"--release={r['release']}",
             f"--umask={r['umask']}"]
        if r["agh_version"] == "-":
            a.append("--skip-override=gl-sdk4-adguardhome")
        txt = run(*a)
    pk = {}
    for l in txt.splitlines():
        m = re.match(r"^(\S+)\s+-> (\S+)(.*)$", l)
        if m:
            pk[m.group(1)] = "built from source" if "override" in m.group(3) else "from the image"
    return pk


def is_text(data):
    if data[:2] == b"\x1f\x8b":
        try:
            data = gzip.decompress(data)
        except Exception:
            return False
    head = data[:65536]
    if b"\0" in head:
        return False
    try:
        head.decode("utf-8")
        return True
    except UnicodeDecodeError:
        return sum(32 <= c < 127 or c in (9, 10, 13) for c in head) > 0.95 * max(len(head), 1)


def elf_meta(p):
    m = {}
    h = run("readelf", "-hW", p)
    for k, f in (("Type:", "elf_type"), ("Machine:", "machine")):
        g = re.search(rf"{k}\s+(.*)", h)
        if g: m[f] = g.group(1).strip()
    m["interp"] = (re.search(r"Requesting program interpreter: (\S+)\]", run("readelf", "-lW", p)) or [None, ""])[1]
    d = run("readelf", "-dW", p)
    m["needed"] = " ".join(re.findall(r"\(NEEDED\).*\[(.*?)\]", d))
    m["soname"] = " ".join(re.findall(r"\(SONAME\).*\[(.*?)\]", d))
    m["build_id"] = (re.search(r"Build ID: (\w+)", run("readelf", "-nW", p)) or [None, ""])[1]
    syms = run("readelf", "--dyn-syms", "-W", p)
    m["exported_symbols"] = str(sum(1 for l in syms.splitlines()
                                    if re.search(r"\s(FUNC|OBJECT)\s+GLOBAL\s+DEFAULT\s+\d+\s", l)))
    m["symtab"] = "yes" if ".symtab" in run("readelf", "-SW", p) else "no"
    m["comment"] = "; ".join(sorted(set(re.findall(r"\]\s+(.+)", run("readelf", "-p", ".comment", p)))))[:200]
    if p.endswith(".ko"):
        info = dict(re.findall(r"\]\s+(\w+)=(.*)", run("readelf", "-p", ".modinfo", p)))
        for k in ("license", "author", "description", "version", "srcversion", "depends", "vermagic", "name"):
            if k in info:
                m["modinfo_" + k] = info[k].strip()
    strs = []
    for s in run("strings", "-n", "8", p).splitlines():
        if INTERESTING.search(s) and len(s) <= 140 and s not in strs:
            strs.append(s)
        if len(strs) >= 8:
            break
    m["strings"] = " | ".join(strs)
    return m


def file_meta(path, data):
    m = {"size": str(len(data)), "md5": hashlib.md5(data).hexdigest(), "sha256": hashlib.sha256(data).hexdigest(),
         "mode": oct(os.stat(path).st_mode & 0o7777)[2:], "type": run("file", "-b", path).strip()[:120]}
    hits = scan_sensitive(data)
    if hits:
        kinds = collections.Counter(k for k, _, _ in hits)
        m["sensitive"] = ", ".join(f"{k} ({n})" for k, n in sorted(kinds.items()))
        m["_hits"] = hits
    if data[:4] == b"\x7fELF":
        m.update(elf_meta(path))
    elif data[:4] == b"\x1bLua":
        m["lua_bytecode"] = f"version byte 0x{data[4]:02x}"
    return m


def main():
    os.makedirs(out, exist_ok=True)
    rows, per_rel = [], collections.OrderedDict()
    for r in releases():
        rel = r["release"]
        root = f"{roots}/{rel}"
        if not os.path.isdir(root):
            continue
        info = f"{root}/usr/lib/opkg/info"
        owner = {}
        for lf in os.listdir(info):
            if lf.endswith(".list"):
                for l in open(f"{info}/{lf}"):
                    owner.setdefault(l.strip().lstrip("/"), lf[:-5])
        pk = closed_from_image(r)
        files = {}                                   # path -> (package, origin)
        for name, how in pk.items():
            if how != "from the image" or not os.path.exists(f"{info}/{name}.list"):
                continue
            for l in open(f"{info}/{name}.list"):
                p = l.strip().lstrip("/")
                if p.startswith("rootfs-overlay/"):
                    p = p[len("rootfs-overlay/"):]
                files[p] = (name, "closed package (from the image)")
        job = best_job(rel)
        kernel_diff = ""
        if job:
            for l in open(f"{results}/{job}/report/files-different-classes.tsv"):
                f = l.rstrip("\n").split("\t")
                if len(f) >= 3 and not ACCEPTED.search(f[1]) and not ACCEPTED.search(f[0]) and f[2].startswith(("elf", "binary")):
                    files.setdefault(f[1], (owner.get(f[1], f[0]), "public package, differs in our build"))
            kf = f"{results}/{job}/report/kernel-functions.txt"
            if os.path.exists(kf):
                k = open(kf).read()
                names = re.findall(r"^  (\S+) \d+ -> \d+", k, re.M)
                code = re.search(r"code differs \(masked\): \d+\n  (.*)", k)
                names += code.group(1).split() if code else []
                kernel_diff = " ".join(names)
        fw = next((f for f in os.listdir(fwdir) if f.startswith(rel + "-")), "")
        fwname = fw[len(rel) + 1:] if fw else "?"
        recs = []
        for p in sorted(files):
            full = f"{root}/{p}"
            if os.path.islink(full) or not os.path.isfile(full):
                continue
            data = open(full, "rb").read()
            if is_text(data):
                continue
            pkg, origin = files[p]
            ver = (re.search(r"^Version: (.*)$", open(f"{info}/{pkg}.control").read(), re.M) or [None, "?"])[1] \
                if os.path.exists(f"{info}/{pkg}.control") else "?"
            m = {"release": rel, "path": "/" + p, "package": pkg, "package_version": ver, "origin": origin,
                 "bundle_path": f"{fwname} > {BUNDLE}/root (squashfs) > /{p}"}
            m.update(file_meta(full, data))
            recs.append(m)
        if kernel_diff:
            itb = f"{kernels}/{rel}.itb"
            data = open(itb, "rb").read() if os.path.exists(itb) else b""
            recs.append({"release": rel, "path": "(kernel)", "package": "kernel", "package_version": "5.4.211",
                         "origin": "kernel, code differs", "bundle_path": f"{fwname} > {BUNDLE}/kernel (FIT image)",
                         "size": str(len(data)), "md5": hashlib.md5(data).hexdigest() if data else "",
                         "sha256": hashlib.sha256(data).hexdigest() if data else "", "type": "FIT image (kernel-1: arm64 Image, LZMA)",
                         "kernel_functions": kernel_diff})
        per_rel[rel] = {"job": job or "none yet", "fw": fwname, "fw_sha256": r["official_sha256"], "recs": recs}
        rows += recs
        print(f"{rel}: {len(recs)} binaries (job {job})", flush=True)
    write(per_rel, rows)


FIELDS = ["release", "path", "package", "package_version", "origin", "bundle_path", "type", "size", "mode", "md5", "sha256",
          "elf_type", "machine", "interp", "soname", "needed", "build_id", "exported_symbols", "symtab", "comment",
          "modinfo_name", "modinfo_license", "modinfo_author", "modinfo_description", "modinfo_version", "modinfo_srcversion",
          "modinfo_depends", "modinfo_vermagic", "lua_bytecode", "kernel_functions", "sensitive", "strings"]


def md(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def write(per_rel, rows):
    rels = list(per_rel)
    for rel, d in per_rel.items():
        L = [f"# Private binaries in GL.iNet {rel}", "",
             "Generated by `analysis/private-binaries.py` (see [README](README.md)); metadata only.", "",
             f"- Official image: `{d['fw']}` (SHA256 `{d['fw_sha256']}`)",
             f"- Our comparison used: job {d['job']}",
             f"- Binaries we can't build identically: **{len(d['recs'])}** "
             f"({sum(r['origin'].startswith('closed') for r in d['recs'])} from closed packages, "
             f"{sum(r['origin'].startswith('public') for r in d['recs'])} from public packages, "
             f"{sum(r['origin'].startswith('kernel') for r in d['recs'])} kernel)", ""]
        if d["job"] == "none yet":
            L += ["No complete comparison yet: public packages with unpublished changes aren't listed for this release.", ""]
        nsens = sum(1 for r in d["recs"] if r.get("sensitive"))
        L += [f"- Binaries with sensitive-looking data (kind and count only; details in the private repository): **{nsens}**", ""]
        L += ["| Path | Package | Origin | Type | Size | MD5 | Sensitive |", "|---|---|---|---|---|---|---|"]
        for r in d["recs"]:
            L.append(f"| `{md(r['path'])}` | {md(r['package'])} | {md(r['origin'])} | {md(r['type'][:60])} | {r['size']} | `{r['md5']}` | {md(r.get('sensitive', ''))} |")
        if private:
            P = [f"# Sensitive-looking data in GL.iNet {rel} (PRIVATE: never in the public repository)", "",
                 f"Image `{d['fw']}`; generated by the public repo's `analysis/private-binaries.py`.", ""]
            for r in d["recs"]:
                if r.get("_hits"):
                    P += [f"## `{r['path']}` ({r['package']}, md5 `{r['md5']}`)", ""]
                    P += [f"- {k} at 0x{o:x}: `{x.decode('latin1').replace('`', chr(39))}`" for k, o, x in r["_hits"][:40]]
                    if len(r["_hits"]) > 40:
                        P.append(f"- … {len(r['_hits']) - 40} more")
                    P.append("")
            os.makedirs(private, exist_ok=True)
            open(f"{private}/{rel}.md", "w").write("\n".join(P) + "\n")
        L += ["", "## Details", ""]
        for r in d["recs"]:
            L += [f"### `{md(r['path'])}`", ""]
            L += [f"- {k}: `{md(r[k])}`" for k in FIELDS[2:] if r.get(k)]
            L.append("")
        open(f"{out}/{rel}.md", "w").write("\n".join(L) + "\n")
    # overview: one row per binary path, one column per release (short MD5)
    by_path = collections.OrderedDict()
    for r in sorted(rows, key=lambda r: (r["path"] != "(kernel)", r["package"], r["path"])):
        by_path.setdefault((r["path"], r["package"]), {})[r["release"]] = r["md5"][:8] + (" ⚠" if r.get("sensitive") else "")
    L = ["# Private binaries: what we can't build from source", "",
         "Generated by `analysis/private-binaries.py` from GL.iNet's official MT2500 images and our latest complete "
         "comparison per release. Metadata only: no file from GL.iNet's images is stored here.", "",
         "A binary is listed when it belongs to a closed package that the recipe copies from the official image "
         "(packages built from GL.iNet's published source or from public source are left out), when a public "
         "package's file still differs in our best complete build (outside the accepted classes: Samba, Python "
         "bytecode, `wg`, kernel version fields), or, for the kernel, when its code differs function by function. "
         "Text files (scripts, configuration, Lua source, web files, also gzip-compressed) are left out.", "",
         "Each cell holds the first 8 hex digits of the file's MD5 in that release (`·`: not in that release or "
         "not private there); a value repeated along a row means the binary didn't change; ⚠ marks a binary with sensitive-looking data (keys, certificates, credentials, high-entropy strings), detailed only in the private repository. Full hashes, paths in "
         "the firmware bundle and all other metadata are in the per-release files.", "",
         "| Release | Image | Comparison | Private binaries |", "|---|---|---|---|"]
    for rel, d in per_rel.items():
        L.append(f"| [{rel}]({rel}.md) | `{d['fw']}` | {d['job']} | {len(d['recs'])} |")
    L += ["", "| Path | Package | " + " | ".join(rels) + " |", "|---|---|" + "---|" * len(rels)]
    for (p, pkg), h in by_path.items():
        L.append(f"| `{md(p)}` | {md(pkg)} | " + " | ".join(f"`{h[r]}`" if r in h else "·" for r in rels) + " |")
    open(f"{out}/README.md", "w").write("\n".join(L) + "\n")


main()
