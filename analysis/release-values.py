#!/usr/bin/env python3
"""Collect the per-release recipe values (openwrt/gl-releases.tsv) from
GL.iNet's official MT2500 images, for many releases in one run.

    release-values.py <list.tsv> <roots dir> <kernels dir> <gl-feeds clone> <out dir> [release ...]

<list.tsv>: release, image URL, SHA256 (one line per release);
<roots dir>/<release>/: the unpacked root file system;
<kernels dir>/<release>.itb: the kernel FIT image.

Writes <out dir>/summary.md (compact, one section per release) and
<out dir>/rows.tsv (draft table rows; "?" where a value needs a build or a
human decision). Read-only on its inputs.
"""
import calendar, collections, glob, gzip, lzma, os, re, struct, subprocess, sys, time, zlib

lst, roots, kernels, feeds, out = sys.argv[1:6]
only = sys.argv[6:]
SUBMODULES = {"wifidog-ng"}   # gl-feeds submodules (own repository and dates)
AGH_SHA = {   # AdGuardHome release tarballs already in the table
    "v0.107.8": "77a678e8beaa7978b950d3d8dff9e54c9bd50ae43495a9ad478f59ef73bced67",
    "v0.107.26": "709eefbefe18ca8d2bd3578eb9923a8ea7382c59920e6565f386898f0c64b91e",
    # 4.6.2: GL.iNet's binary = this release binary after sstrip -z (checked 2026-10-27)
    "v0.107.46": "5011096bae383e27db9f0de063caeea9ec4b0e0bcac6728409d223dc51c8c0d0",
    "v0.107.52": "86ae7a7c2db9c158b9db9f350568485e3ccc43e7039624d1a5bc50bb1dee1048",
}


def fit_kernel(path):
    """Decompressed kernel image and ikconfig text from a FIT image."""
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
    i = raw.find(b"IKCFG_ST")
    cfg = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(raw[i + 8:]).decode() if i >= 0 else ""
    return raw, cfg


def build_time(raw):
    """GL.iNet's build time from UTS_VERSION ("#0 SMP Tue Mar 14 02:16:44 2023",
    printed with gmtime by OpenWrt)."""
    m = re.search(rb"#\d+ SMP(?: PREEMPT)? [A-Z][a-z]{2} ([A-Z][a-z]{2} +\d{1,2} \d\d:\d\d:\d\d)(?: [A-Z]{2,5})? (\d{4})", raw)
    if not m:
        return None, ""
    s = f"{m.group(1).decode()} {m.group(2).decode()}"
    return calendar.timegm(time.strptime(re.sub(" +", " ", s), "%b %d %H:%M:%S %Y")), s


def controls(root):
    out = {}
    for c in glob.glob(f"{root}/usr/lib/opkg/info/*.control"):
        out[os.path.basename(c)[:-8]] = dict(
            l.split(": ", 1) for l in open(c, errors="replace").read().splitlines() if ": " in l)
    return out


def read(root, rel):
    try:
        return open(os.path.join(root, rel), errors="replace").read().strip()
    except OSError:
        return ""


# Feeds outside gl-feeds that GL.iNet added later: name -> (clone next to the
# gl-feeds clone, URL for feed_revs' name=url^commit)
OTHER_FEEDS = {"mptcp_feeds": ("mptcp-feeds", "https://github.com/gl-inet/mptcp-feeds.git"),
               "gl_feed_ovpn_with_dco": ("vpn-extra-feeds", "https://github.com/gl-inet/vpn-extra-feeds.git")}
REPO = feeds


def git(*a):
    return subprocess.run(["git", "-C", REPO, *a], capture_output=True, text=True).stdout


def feed_pins(ctl, built):
    """For each gl_feed_* feed: the commits at which every installed package's
    directory was last changed exactly at its SourceDateEpoch."""
    want = collections.defaultdict(dict)
    for c in ctl.values():
        src = c.get("Source", "")
        if (src.startswith("feeds/gl_feed") or src.split("/")[1:2] and src.split("/")[1] in OTHER_FEEDS) \
                and "SourceDateEpoch" in c and src.count("/") >= 2:
            _, feed, d = src.split("/", 2)
            want[feed][d] = int(c["SourceDateEpoch"])
    res = {}
    global REPO
    for feed, pk in want.items():
        REPO = os.path.join(os.path.dirname(os.path.abspath(feeds)), OTHER_FEEDS[feed][0]) if feed in OTHER_FEEDS else feeds
        # a git submodule in the feed (wifidog-ng) dates from its own repository
        sub = {d for d in pk if d.split("/")[0] in SUBMODULES}
        pk = {d: t for d, t in pk.items() if d not in sub}
        if not pk:
            continue
        # fetched by branch (depth-1 clone): every package has the head's time
        times = set(pk.values())
        if len(times) == 1:
            heads = git("log", "--all", "--format=%H %ct").split()
            hs = [heads[i] for i in range(0, len(heads), 2) if heads[i + 1] == str(next(iter(times)))]
            if hs and (len(pk) > 1 or not any(
                    git("log", "-1", "--format=%ct", h, "--", d).strip() == str(t)
                    for h in hs for d, t in pk.items())):
                res[feed] = (len(pk), len(pk), [(h[:10], "shallow", git("branch", "-r", "--contains", h).split()[:3]) for h in hs],
                             sorted(sub), hs[-1] + "~shallow")
                continue
        newest = max(pk.values())
        cands = [l.split() for l in git("log", "--all", "--format=%H %ct",
                                         f"--since={newest - 1}", f"--until={built}").splitlines()]
        best, rows = -1, []
        for h, ct in cands:
            names = git("ls-tree", "-r", "--name-only", h).splitlines()
            ok, bad = 0, []
            for d, sde in pk.items():
                p = d if f"{d}/Makefile" in names else next(
                    (n[:-9] for n in names if n.endswith("/Makefile") and n.split("/")[-2] == d.split("/")[-1]), None)
                t = git("log", "-1", "--format=%ct", h, "--", p).strip() if p else ""
                if t == str(sde): ok += 1
                else: bad.append(d)
            rows.append((ok, int(ct), h, bad))
        if rows:
            best = max(r[0] for r in rows)
            top = sorted((r for r in rows if r[0] == best), key=lambda r: r[1])
            res[feed] = (len(pk), best, [(h[:10], time.strftime("%Y-%m-%d", time.gmtime(ct)),
                                          git("branch", "-r", "--contains", h).split()[:3]) for _, ct, h, _ in top],
                         top[0][3], top[-1][2])
        else:
            res[feed] = (len(pk), 0, [], list(pk), "")
    REPO = feeds
    return res


rel_rows = [l.rstrip("\n").split("\t") for l in open(lst) if l.strip()]
os.makedirs(out, exist_ok=True)
md, tsv = [], []
prev = None
for rel, url, sha in rel_rows:
    if only and rel not in only:
        continue
    root, itb = os.path.join(roots, rel), os.path.join(kernels, rel + ".itb")
    if not os.path.isdir(root) or not os.path.exists(itb):
        md.append(f"## {rel}\n\nmissing root or kernel\n"); continue
    ctl = controls(root)
    raw, cfg = fit_kernel(itb)
    built, uts = build_time(raw)
    # OpenWrt-tree packages: commit date of the applied patches, and who is off by a second
    tree = {n: int(c["SourceDateEpoch"]) for n, c in ctl.items()
            if c.get("Source", "").startswith("package/") and "SourceDateEpoch" in c}
    gcd = collections.Counter(tree.values()).most_common(1)[0][0]
    early = sorted(n for n, t in tree.items() if t == gcd - 1)
    late = sorted(n for n, t in tree.items() if t == gcd + 1)
    owv = read(root, "etc/openwrt_version")
    agh_bin = next((p for p in (f"{root}/etc/AdGuardHome/AdGuardHome", f"{root}/usr/bin/AdGuardHome") if os.path.exists(p)), None)
    agh = ""
    if agh_bin:
        s = subprocess.run(["strings", "-n6", agh_bin], capture_output=True, text=True).stdout
        agh = next(iter(re.findall(r"^v0\.\d+\.\d+$", s, re.M)), "")
    tertf = ctl.get("kmod-gl-sdk4-tertf", {}).get("Source", "")
    bb = sorted(os.path.basename(l.strip()) for l in open(f"{root}/usr/lib/opkg/info/busybox.list")) \
        if os.path.exists(f"{root}/usr/lib/opkg/info/busybox.list") else []
    curl_dep = ctl.get("curl", {}).get("Depends", "")
    abi_names = "libcurl4" in curl_dep
    pins = feed_pins(ctl, built or 2**31)
    kcfg = {l for l in cfg.splitlines() if l.startswith("CONFIG_") or l.startswith("# CONFIG_")}
    tertf_public = any("tertf" in n for n in git("ls-tree", "-r", "--name-only",
                                                    pins.get("gl_feed_common", (0, 0, [], [], "HEAD"))[4] or "HEAD").splitlines())

    md.append(f"## {rel}\n")
    md.append(f"- image: {url.rsplit('/', 1)[-1]}; openwrt_version `{owv or '(empty)'}`; "
              f"version.build `{read(root, 'etc/version.build') or '-'}`; sdk.version `{read(root, 'etc/sdk.version') or '-'}`")
    md.append(f"- build time (UTS): {uts} = {built}; patch commit date (mode of {len(tree)} OpenWrt-tree packages): "
              f"{gcd} ({built - gcd if built else '?'} s before the build)")
    md.append(f"- one second early: {', '.join(early) or 'none'}; late: {', '.join(late) or 'none'}")
    md.append(f"- version.date `{read(root, 'etc/version.date')}`, type `{read(root, 'etc/version.type')}`; "
              f"packages {len(ctl)}; AdGuardHome {agh or '-'}"
              + ("" if not agh or agh in AGH_SHA else " (**tarball SHA256 needed**)"))
    md.append(f"- tertf: {tertf or 'not installed'}; in gl_feed_common at the pin: {tertf_public}; "
              f"curl Depends ABI names: {abi_names}")
    for feed, (n, best, top, bad, _) in pins.items():
        md.append(f"- {feed}: {best}/{n} packages match; candidates {top[:4]}{' …' if len(top) > 4 else ''}"
                  + (f"; unmatched {bad[:6]}" if bad else ""))
    if prev:
        pbb, pk = prev
        add, rem = sorted(set(bb) - set(pbb)), sorted(set(pbb) - set(bb))
        if add or rem:
            md.append(f"- busybox applets vs previous: +{add} -{rem}")
        dk = sorted(kcfg ^ pk)
        md.append(f"- kernel config lines changed vs previous: {len(dk)}" + (f" {dk[:10]}" if dk else ""))
    md.append(f"- busybox has usleep: {'usleep' in bb}\n")
    prev = (bb, kcfg)

    common = pins.get("gl_feed_common", (0, 0, [], [], ""))[4]
    tsv.append("\t".join([
        rel, "?", url, sha, str(built or "?"), str(gcd), read(root, "etc/version.date"),
        read(root, "etc/version.type"), agh or "?", AGH_SHA.get(agh, "?"),
        f"? ({len(early)} pkgs early)" if early else "0",
        "package/libs/toolchain package/feeds/packages/curl" if abi_names else "-",
        "kmod-gl-sdk4-tertf" if tertf and not tertf_public else "-",
        f"? ({len(late)} pkgs late)" if late else "0", "?",
        "CONFIG_BUSYBOX_CONFIG_USLEEP=y" if "usleep" in bb else "-",
        " ".join(f"{f}={OTHER_FEEDS[f][1] + '^' if f in OTHER_FEEDS else ''}{v[4]}" for f, v in pins.items() if v[4])]))
    print(f"{rel} done", flush=True)

open(os.path.join(out, "summary.md"), "w").write("\n".join(md) + "\n")
open(os.path.join(out, "rows.tsv"), "w").write("\n".join(tsv) + "\n")
