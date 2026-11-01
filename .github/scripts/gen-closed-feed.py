#!/usr/bin/env python3
"""Generate OpenWrt package recipes for GL.iNet's closed packages from an
unpacked official image, so a full build can reproduce them.

    gen-closed-feed.py <official_root> <out_dir> <closed_dir> [--private-now="pkg ..."] [package ...]

<closed_dir> (openwrt/gl-4.2.0-closed in the public repo) holds what isn't
taken from the image: built-from-public.txt (packages built from public
source instead) and overrides/<feed>/<path>/Makefile (recipes that build
their programs from source; files/ still comes from the image and the
built programs are installed over it; overrides/<feed>/<path>/build.mk
instead only adds build steps and Package/<name>/install-built to the
generated recipe, which keeps its metadata). overrides@<release>/ holds recipes
for that release and later (overrides@<from>..<to>/: for that range only;
--release=<this release>; the newest one at or below it wins, other files
in the recipe folder, e.g. src/, are copied along). Run inside the workflow only: the
output contains GL.iNet's files and is never stored or published.

For every closed package (default: all whose control file names a source in
feeds/glinet, feeds/mt7981 or mt798x, or a gl-/oui-/libgl prefix) it writes
<out_dir>/<feed>/<path>/ with
  Makefile      PKG_NAME/VERSION/RELEASE, DEPENDS, SECTION, TITLE and
                description from the official control file; installs files/
  version.date  the official SourceDateEpoch (OpenWrt's
                get_source_date_epoch.sh reads it per package directory)
  files/        the package's files from the image (modes and symlinks kept)
Kernel modules become KernelPackages, so Depends gets the kernel line.
"""
import os
import re
import shutil
import struct
import sys
from pathlib import Path

CLOSED_PREFIX = ("gl-sdk4", "gl-", "oui-", "kmod-gl-sdk4", "libgl")
CLOSED_EXTRA = {"fwdd", "kmod-mtfwd", "kmod-mtqos", "mtk-base-files"}
CLOSED_FEEDS = {"glinet", "mt7981", "mt798x"}   # GL.iNet's private feeds
# Files a package's postinst moved at image build (OpenWrt's rootfs.mk runs
# and then deletes every postinst, so the script itself isn't in the image):
# package -> {listed path: final path}. Our reconstruction of the effect.
MOVED = {
    "gl-sdk4-ddns": {
        "etc/95-ddns": "etc/hotplug.d/iface/95-ddns",
        "etc/ddns.init": "etc/init.d/ddns",
        "etc/dynamic_dns_functions.sh": "usr/lib/ddns/dynamic_dns_functions.sh",
        "etc/dynamic_dns_updater.sh": "usr/lib/ddns/dynamic_dns_updater.sh",
        "etc/ddns_services": "etc/ddns/services",
        "etc/ddns_services_ipv6": "etc/ddns/services_ipv6",
    },
}


def control(path):
    t = path.read_text(errors="replace")
    f, key = {}, None
    for line in t.splitlines():
        m = re.match(r"^([A-Za-z-]+): ?(.*)$", line)
        if m:
            key = m.group(1)
            f[key] = m.group(2)
        elif key:
            f[key] += "\n" + line
    return f


def ko_exports(path):
    """(symbols, gpl) a kernel module exports: the names in __ksymtab_strings;
    gpl is True if it has a __ksymtab_gpl section (then the kind of each
    symbol isn't known from the strings alone)."""
    d = path.read_bytes()
    shoff, = struct.unpack_from("<Q", d, 0x28)
    shentsize, shnum, shstrndx = struct.unpack_from("<HHH", d, 0x3A)
    secs = [struct.unpack_from("<IIQQQQ", d, shoff + i * shentsize) for i in range(shnum)]
    stro = secs[shstrndx][4]
    names = {d[stro + s[0]:d.index(b"\0", stro + s[0])].decode(): s for s in secs}
    st = names.get("__ksymtab_strings")
    syms = [x.decode() for x in d[st[4]:st[4] + st[5]].split(b"\0") if x] if st else []
    return syms, "__ksymtab_gpl" in names


def split_version(v, kmod):
    if kmod:
        if not re.match(r"^\d+\.\d+\.\d+\+", v):  # 5.4.211-1: no PKG_VERSION
            return "", v.rpartition("-")[2]
        v = re.sub(r"^\d+\.\d+\.\d+\+", "", v)     # KernelPackage adds LINUX_VERSION+
    base, _, rel = v.rpartition("-")
    return base, rel


def mk_escape(s):
    return s.replace("$", "$$")


def main():
    root, out, closed = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    opts = [a for a in sys.argv[4:] if a.startswith("--private-now=")]
    # --skip-override=<package>: generate it from the image like the others
    # (gl-sdk4-adguardhome from 4.8.2 on: AdGuardHome is its own package)
    skip = {a.split("=", 1)[1] for a in sys.argv[4:] if a.startswith("--skip-override=")}
    # --release=<release>: picks overrides@<release>/ recipes (see above)
    relarg = [a.split("=", 1)[1] for a in sys.argv[4:] if a.startswith("--release=")]
    vkey = lambda v: tuple(int(x) for x in re.findall(r"\d+", v))
    ovdirs = [closed / "overrides"]
    if relarg:
        # overrides@<from>..<to>/: only for releases in that range
        rng = lambda d: (d.name.split("@", 1)[1].split("..") + [None])[:2]
        ovdirs += [d for d in sorted(closed.glob("overrides@*"), key=lambda d: vkey(rng(d)[0]))
                   if vkey(rng(d)[0]) <= vkey(relarg[0]) and (rng(d)[1] is None or vkey(relarg[0]) <= vkey(rng(d)[1]))]
    # --umask=<umask>: GL.iNet's builder umask for this release (002 from 4.7.0)
    umask = ([a.split("=", 1)[1] for a in sys.argv[4:] if a.startswith("--umask=")] or ["-"])[0]
    # --i18n=<table>: translations to take from GL.iNet's public language
    # repository instead of the image (openwrt/gl-4.2.0-closed/i18n/<release>.md)
    i18n = ([a.split("=", 1)[1] for a in sys.argv[4:] if a.startswith("--i18n=")] or [None])[0]
    opts_all = opts + [a for a in sys.argv[4:] if a.startswith(("--skip-override=", "--release=", "--umask=", "--i18n="))]
    only = set(a for a in sys.argv[4:] if a not in opts_all)
    # recipes share the download folder: a file name two recipes use must be
    # the same file, or a build takes the other recipe's cached copy unchecked
    # (2026-10-29: 4.9.0's parental-control got 4.8.2's sources)
    dl_hash = {}
    for bm in sorted(closed.glob("overrides*/**/build.mk")):
        for f, h in re.findall(r"FILE:=(\S+)\n\s*HASH:=(\S+)", bm.read_text()):
            assert dl_hash.setdefault(f, (h, bm))[0] == h, f"download name {f} in {bm} and {dl_hash[f][1]} with different hashes"
    # packages verified identical from public source: not part of this feed
    pub = closed / "built-from-public.txt"
    public = {l.strip() for l in pub.read_text().splitlines() if l.strip() and not l.startswith("#")} if pub.exists() else set()
    # packages of that list this release's public feeds no longer have
    # (release value PRIVATE_NOW): taken from the image like the others
    for o in opts:
        public -= set(o.split("=", 1)[1].split()) - {"-"}
    info = root / "usr/lib/opkg/info"
    generated, shared, versions = {}, [], {}   # folder -> first package; shared folders
    # ABI-versioned names (jansson4) -> the name DEPENDS uses (jansson)
    abi = {}
    for f in info.glob("*.control"):
        c = control(f)
        if c.get("ABIVersion") and f.stem.endswith(c["ABIVersion"]):
            abi[f.stem] = f.stem[: -len(c["ABIVersion"])]
    for cf in sorted(info.glob("*.control")):
        name = cf.stem
        if only and name not in only:
            continue
        # closed: by name, or built from one of GL.iNet's private feeds (4.9.0's
        # kmod-dpi, kmod-mt_wifi, ... don't follow the naming)
        src_feed = (control(cf).get("Source", "").split("/") + ["", ""])[1]
        if not only and not (name.startswith(CLOSED_PREFIX) or name in CLOSED_EXTRA
                             or src_feed in CLOSED_FEEDS):
            continue
        if name in public:
            print(f"{name:40} -> built from public source, skipped")
            continue
        c = control(cf)
        src = c["Source"]                       # feeds/<feed>/<path>
        parts = src.split("/")
        d = out / parts[1] / "/".join(parts[2:]) if parts[0] == "feeds" else out / "misc" / name
        versions[name] = c["Version"]
        if d in generated:                     # a second package from the same folder:
            shared.append((d, name))           # generated on its own, merged below
            d = out / ".shared" / name
        else:
            generated[d] = name
        if d.exists():
            shutil.rmtree(d)
        (d / "files").mkdir(parents=True)
        kmod = name.startswith("kmod-")
        ver, rel = split_version(c["Version"], kmod)
        deps = [x.strip() for x in c.get("Depends", "").split(",") if x.strip()]
        deps = [abi.get(x, x) for x in deps if x != "libc" and not x.startswith("kernel")]
        desc = c.get("Description", "").strip()
        title = desc.splitlines()[0].strip() if desc else name
        conffiles = (info / f"{name}.conffiles")
        conf = conffiles.read_text().split() if conffiles.exists() else []

        # files, in the order of the .list (modes and symlinks preserved)
        for line in (info / f"{name}.list").read_text().splitlines():
            rel_path = line.strip().lstrip("/")
            if not rel_path:
                continue
            s, t = root / rel_path, d / "files" / rel_path
            # GL.iNet's lib/functions.sh copies rootfs-overlay/ over the root
            # after a package installs and then deletes it: the content is in
            # the image at the path without the prefix.
            if rel_path.startswith("rootfs-overlay/"):
                s = root / rel_path[len("rootfs-overlay/"):]
            if rel_path in MOVED.get(name, {}):
                s = root / MOVED[name][rel_path]
            t.parent.mkdir(parents=True, exist_ok=True)
            if s.is_symlink():
                os.symlink(os.readlink(s), t)
            elif s.is_file():
                shutil.copy2(s, t)

        # GL.iNet's web-interface packages always contain www/views/img/,
        # www/i18n/ and usr/share/oui/menu.d/, empty when they have nothing
        # there (www/views/img is empty in the image, owned by no package).
        # With them all 40 such packages get GL.iNet's exact Installed-Size,
        # the size of their compressed data.tar.gz.
        if (d / "files/www/views").is_dir():
            for e in ("www/views/img", "www/i18n", "usr/share/oui/menu.d"):
                (d / "files" / e).mkdir(parents=True, exist_ok=True)
        # Empty folders GL.iNet's packages ship (empty in the image too). Each
        # was found by rebuilding the package archive and checked against the
        # package's other versions in other releases (same rule, exact
        # Installed-Size every time):
        #   gl-sdk4-ddns     etc/ddns (its postinst moves two files into it)
        #   gl-sdk4-plugins  etc/rc.d          (4.1.1, 4.2.0, 4.2.1)
        #   gl-sdk4-clients  usr/libexec/rpcd  (7 versions, 4.1.1 to 4.7.4)
        #   gl-oui-rpc       etc/oui, etc/oui-httpd (4.1.1 to 4.6.2)
        EMPTY = {"gl-sdk4-ddns": ["etc/ddns"], "gl-sdk4-plugins": ["etc/rc.d"],
                 "gl-sdk4-clients": ["usr/libexec/rpcd"],
                 "gl-oui-rpc": ["etc/oui", "etc/oui-httpd"]}
        for e in EMPTY.get(name, []):
            (d / "files" / e).mkdir(parents=True, exist_ok=True)
        # rootfs-overlay files whose path another package also installs: the
        # overlay copy (cp -R onto an existing file) keeps that file's mode, so
        # the image doesn't show GL.iNet's. Their modes, found as the only one
        # of all 128 combinations that gives GL.iNet's exact Installed-Size in
        # six releases (4.1.1 to 4.5.0):
        MODES = {"gl-sdk4-base-files": {
            "etc/uci-defaults/99-firewall": 0o644, "etc/hotplug.d/iface/20-firewall": 0o644,
            "sbin/sysupgrade": 0o755, "lib/netifd/ppp6-up": 0o644,
            "etc/hotplug.d/block/10-mount": 0o755, "etc/rc.local": 0o644,
            "etc/rc.button/reset": 0o755}}
        for f, m in MODES.get(name, {}).items():
            t = d / "files/rootfs-overlay" / f
            if t.is_file():
                t.chmod(m)
        # With umask 002 (GL.iNet's Jenkins, 4.7.0 on) the package holds its
        # executable overlay files group-writable (775), while the image shows
        # the mode of the file they replace: gl-sdk4-modem and gl-line-graph
        # get GL.iNet's exact 4.7.4 Installed-Size with it (gl-sdk4-base-files
        # keeps MODES).
        if umask == "002" and name not in MODES:
            for t in (d / "files/rootfs-overlay").rglob("*"):
                if t.is_file() and not t.is_symlink() and t.stat().st_mode & 0o100:
                    t.chmod(0o775)
        (d / "version.date").write_text(c.get("SourceDateEpoch", "") + "\n")
        pkg = name[5:] if kmod else name
        lines = ["include $(TOPDIR)/rules.mk", ""]
        if kmod:
            lines += ["include $(INCLUDE_DIR)/kernel.mk"]
        lic = [f"PKG_LICENSE:={c['License']}"] if c.get("License") else []
        # from 4.7.0 on some closed packages also name license files and a
        # maintainer (gl-sdk4-arp-scan)
        lic += [f"PKG_LICENSE_FILES:={c['LicenseFiles']}"] if c.get("LicenseFiles") else []
        lic += [f"PKG_MAINTAINER:={c['Maintainer']}"] if c.get("Maintainer") else []
        lines += [f"PKG_NAME:={c.get('SourceName', name)}", *([f"PKG_VERSION:={ver}"] if ver else []), f"PKG_RELEASE:={rel}", *lic,
                  "", "include $(INCLUDE_DIR)/package.mk", ""]
        dep = " ".join("+" + x for x in deps)
        if kmod:
            ko = [str(p.relative_to(d / "files")) for p in (d / "files").rglob("*.ko")]
            lines += [f"define KernelPackage/{pkg}",
                      f"  SUBMENU:=GL.iNet (closed, from the official image)",
                      f"  SECTION:={c.get('Section', 'kernel')}",
                      f"  TITLE:={mk_escape(title)}",
                      f"  DEPENDS:={dep}",
                      "  FILES:=",
                      "endef", "",
                      f"define KernelPackage/{pkg}/description", mk_escape(desc), "endef", ""]
            if conf:
                lines += [f"define KernelPackage/{pkg}/conffiles", *conf, "endef", ""]
            # Exported symbols, so modules built against this one record it in
            # depends= (shortcut-fe uses tertf's term_update). Written as the
            # module's build would leave them, in $(PKG_BUILD_DIR)/Module.symvers
            # with the module path in the build dir: OpenWrt's
            # collect_module_symvers hook (after Build/Compile of every
            # KernelPackage) keeps those lines and writes
            # $(PKG_SYMVERS_DIR)/$(PKG_NAME).symvers, so a file placed there
            # directly is overwritten (empty). No CONFIG_MODVERSIONS: no checksums.
            syms = []
            for k in ko:
                e, gpl = ko_exports(d / "files" / k)
                if gpl:
                    print(f"{name}: {k} has GPL exports, no symvers written", file=sys.stderr)
                    syms = []
                    break
                mod = "@PKG_BUILD_DIR@/" + Path(k).name[:-3]   # only the base name counts
                syms += [f"0x00000000\t{x}\t{mod}\tEXPORT_SYMBOL\t" for x in e]
            if syms:
                (d / "Module.symvers").write_text("\n".join(syms) + "\n")
            lines += ["# GL.iNet's files are final: don't strip them again", "RSTRIP:=:", "",
                      "define Build/Compile",
                      *(["\tmkdir -p $(PKG_BUILD_DIR)",
                         "\tsed 's#@PKG_BUILD_DIR@#$(PKG_BUILD_DIR)#' ./Module.symvers > $(PKG_BUILD_DIR)/Module.symvers"]
                        if syms else []),
                      "endef", "",
                      f"define KernelPackage/{pkg}/install",
                      *(["\t$(CP) ./files/* $(1)/"] if any((d / "files").iterdir()) else ["\t$(INSTALL_DIR) $(1)"]),
                      "endef", "",
                      f"$(eval $(call KernelPackage,{pkg}))"]
        else:
            lines += [f"define Package/{name}",
                      # an empty release ("1-", 4.9.0's mtk-base-files and
                      # wifi-profile) would otherwise become plain "1"
                      *([f"  VERSION:={c['Version']}"] if c["Version"].endswith("-") else []),
                      f"  SECTION:={c.get('Section', 'base')}",
                      "  CATEGORY:=GL.iNet (closed, from the official image)",
                      f"  TITLE:={mk_escape(title)}",
                      f"  DEPENDS:={dep}",
                      "endef", "",
                      f"define Package/{name}/description", mk_escape(desc), "endef", ""]
            if conf:
                lines += [f"define Package/{name}/conffiles", *conf, "endef", ""]
            # GL.iNet's own maintainer scripts, verbatim (prerm is OpenWrt's default)
            for script in ("preinst", "postinst", "postrm"):
                sp = info / f"{name}.{script}"
                if sp.exists():
                    lines += [f"define Package/{name}/{script}", mk_escape(sp.read_text().rstrip("\n")), "endef", ""]
            # a custom prerm: OpenWrt keeps its body as .prerm-pkg next to the
            # default .prerm wrapper
            sp = info / f"{name}.prerm-pkg"
            if sp.exists():
                lines += [f"define Package/{name}/prerm", mk_escape(sp.read_text().rstrip("\n")), "endef", ""]
            # only the moves of files this release's package lists (4.6.2's
            # gl-sdk4-ddns ships none of them: ddns-scripts is gone)
            listed = {l.strip().lstrip("/") for l in (info / f"{name}.list").read_text().splitlines()}
            moves = {a: b for a, b in MOVED.get(name, {}).items() if a in listed}
            if moves:
                mv = [f'mv -f "$${{IPKG_INSTROOT}}/{a}" "$${{IPKG_INSTROOT}}/{b}"' for a, b in moves.items()]
                lines += [f"define Package/{name}/postinst", "#!/bin/sh",
                          *sorted({f'mkdir -p "$${{IPKG_INSTROOT}}/{b.rsplit("/", 1)[0]}"' for b in moves.values()}),
                          *mv, "endef", ""]
            lines += ["# GL.iNet's files are final: don't strip them again", "RSTRIP:=:", "",
                      "define Build/Compile", "endef", "",
                      f"define Package/{name}/install",
                      *(["\t$(CP) ./files/* $(1)/"] if any((d / "files").iterdir()) else ["\t$(INSTALL_DIR) $(1)"]),
                      "endef", "",
                      f"$(eval $(call BuildPackage,{name}))"]
        (d / "Makefile").write_text("\n".join(lines) + "\n")
        ov = closed / "overrides" / "-"
        for od in ovdirs:                # the newest applicable recipe
            for f in ("Makefile", "build.mk"):
                if (od / d.relative_to(out) / f).exists():
                    ov = od / d.relative_to(out) / f
        if name in skip:
            ov = closed / "overrides" / "-"     # (none)
        if ov.name == "build.mk":        # build steps only: the generated recipe
            mk = (d / "Makefile").read_text()  # keeps its metadata (conffiles, ...);
            # (a kmod recipe's Build/Compile may write Module.symvers: the
            # real build makes its own)
            compile_ = re.search(r"^define Build/Compile\n(?:.*\n)*?endef\n", mk, re.M)
            assert compile_ and "\t$(CP) ./files/* $(1)/\n" in mk, name
            mk = mk.replace(compile_[0], ov.read_text(), 1)                        # its programs
            mk = mk.replace("\t$(CP) ./files/* $(1)/\n",                         # go over files/
                            f"\t$(CP) ./files/* $(1)/\n\t$(call Package/{name}/install-built,$(1))\n", 1)
            (d / "Makefile").write_text(mk)
            for x in ov.parent.iterdir():
                if x.name != "build.mk":
                    (shutil.copytree if x.is_dir() else shutil.copy2)(x, d / x.name)
            print(f"{name:40} -> {d.relative_to(out)} (build steps: {ov.parent.relative_to(closed).parts[0]})")
            continue
        if ov.exists():                  # built from source (files/ from the image)
            m = ov.read_text()           # with this release's version
            if ver:
                m = re.sub(r"^PKG_VERSION:=.*$", f"PKG_VERSION:={ver}", m, count=1, flags=re.M)
            m = re.sub(r"^PKG_RELEASE:=.*$", f"PKG_RELEASE:={rel}", m, count=1, flags=re.M)
            # an override without dependencies of its own gets the official
            # ones (gl-sdk4-adguardhome: zoneinfo-* from 4.6.4 on)
            m = re.sub(r"^  DEPENDS:=$", "  DEPENDS:=" + " ".join("+" + x for x in deps),
                       m, count=1, flags=re.M)
            (d / "Makefile").write_text(m)
            for x in ov.parent.iterdir():  # the recipe's own sources (src/)
                if x.name != "Makefile":
                    (shutil.copytree if x.is_dir() else shutil.copy2)(x, d / x.name)
        print(f"{name:40} -> {d.relative_to(out)}{' (override: built from source, ' + ov.parent.relative_to(closed).parts[0] + ')' if ov.exists() else ''}")
    if i18n:
        public_i18n(out, i18n)
    merge_shared(out, generated, shared, versions)


def public_i18n(out, table):
    """Replace the image's translation files with the same files downloaded
    from gl-inet/router-sdk-languages at the commit the table names, each
    checked against its SHA256 (a failed download or check stops the run)."""
    import hashlib, time, urllib.request
    n = 0
    for l in open(table):
        m = re.match(r"^\| `(/[^`]+)` \| `([0-9a-f]{40})` \| `([^`]+)` \| `([0-9a-f]{64})` \|$", l.strip())
        if not m:
            continue
        path, commit, rpath, sha = m.groups()
        targets = [t for t in out.glob("**/files" + path)] + [t for t in out.glob("**/files-*" + path)]
        if not targets:
            continue                    # not part of a package taken from the image
        url = f"https://raw.githubusercontent.com/gl-inet/router-sdk-languages/{commit}/{urllib.request.quote(rpath)}"
        for attempt in range(5):              # waits 2, 4, 8, 16 s (DNS hiccups)
            try:
                data = urllib.request.urlopen(url, timeout=60).read()
                break
            except OSError:
                if attempt == 4:
                    raise
                time.sleep(2 ** (attempt + 1))
        if hashlib.sha256(data).hexdigest() != sha:
            sys.exit(f"i18n: {url} doesn't match {sha}")
        for t in targets:
            t.write_bytes(data)         # keeps the file's mode
        n += 1
    print(f"i18n: {n} translation files from gl-inet/router-sdk-languages ({table})")


def merge_shared(out, generated, shared, versions):
    """GL.iNet builds some packages from one folder (4.9.0: gl-sdk4-dpi and
    kmod-dpi in glinet/gl-sdk4-dpi, Source: the same for both). OpenWrt reads
    one Makefile per folder, so the packages are merged into one: each keeps
    its own files (files-<package>) and gets its exact official version
    (VERSION:= in its definition; their PKG_VERSION/PKG_RELEASE split differs)."""
    def pin(text, name):
        head = f"define Package/{name}\n" if not name.startswith("kmod-") else f"define KernelPackage/{name[5:]}\n"
        assert text.count(head) == 1, (name, head)
        return text.replace(head, head + f"  VERSION:={versions[name]}\n")
    for d, name2 in shared:
        name1 = generated[d]
        mk = (d / "Makefile").read_text()
        if (d / "files").exists():
            (d / "files").rename(d / f"files-{name1}")
            mk = pin(mk.replace("./files/", f"./files-{name1}/"), name1)
        t = out / ".shared" / name2
        m2 = (t / "Makefile").read_text()
        body = m2[m2.index("\ndefine ") + 1:].replace("./files/", f"./files-{name2}/")
        (t / "files").rename(d / f"files-{name2}")
        if name2.startswith("kmod-") and "/kernel.mk" not in mk:   # KernelPackage needs it
            mk = mk.replace("include $(TOPDIR)/rules.mk\n", "include $(TOPDIR)/rules.mk\n\ninclude $(INCLUDE_DIR)/kernel.mk\n", 1)
        if (t / "Module.symvers").exists() and not (d / "Module.symvers").exists():
            (t / "Module.symvers").rename(d / "Module.symvers")
        (d / "Makefile").write_text(mk.rstrip("\n") + "\n\n" + pin(body, name2))
        print(f"{name2:40} -> merged into {d.relative_to(out)} (folder shared with {name1})")
    shutil.rmtree(out / ".shared", ignore_errors=True)


if __name__ == "__main__":
    main()
