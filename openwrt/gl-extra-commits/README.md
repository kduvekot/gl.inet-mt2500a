# Extra commits in the OpenWrt tree

GL.iNet's builder applies its patches as git commits; from 4.5.0 on the
builder isn't public, so a few of those commits are missing from the public
patch set. Each folder here recreates one, for the releases whose
`extra_commits` value (openwrt/gl-releases.tsv) names it. The recreation
copies `files/` into the tree, runs `edit.sh` there if present, and commits
with the release's patch date and the subject in `message`.

| Folder | Source | Evidence in the official image |
|---|---|---|
| `opkg-injection-fix` | GL.iNet's own patch, published in gl-inet/gl-image (branch gl-mt3600be, commit 617e1f1d, `versions/4.8.7/package/system/opkg/patches/`) | `opkg` has `is_illegal_string` and "Illegal file name" from 4.5.0 on |
| `lua5.3-archindependent-bytecode` | GL.iNet's own patch, same source (`package/utils/lua5.3/patches{,-host}/`) | `liblua5.3` has "bad size" / "format mismatch in"; its `SourceDateEpoch` is the patch date |
| `mtkhnat-no-unknown-dp-warning` | our construction: removes the "Unknown case of dp" warning from MediaTek's public hnat source | the string is gone from GL.iNet's `mtkhnat.ko`; the analysis of 4.7.4 found this the only change (journey, chapter 12) |
| `unidentified-commit` | our construction: an empty commit | 4.5.x has one GL.iNet patch commit more than the public set plus the three above, with no trace in the image except the revision count (r15812+885). The count is compiled into the toolchain's version string ("OpenWrt GCC 8.4.0 r15812+885-46b6ee7ffc" in every binary's `.comment`, and so in build IDs), so it changes real files. This commit reproduces only the count, not GL.iNet's change. |
| `airoha-en8811h` | MediaTek's feed at 3d921e1 (GL.iNet's mirror; fetched and checked at build time, not stored here): driver v1.2.5, kernel patch, PHY firmware; package definition of MediaTek's 004da0a; our construction: the package installs the firmware | 4.6.2+: `kmod-phy-air_en8811h` (Source package/kernel/linux) with `air_en8811h.ko` v1.2.5 and `EthMD32.*.bin` (byte-identical to MediaTek's); kernel options `AIROHA_EN8811H_PHY=m`, `_DEBUGFS=y` |
| `ppp-pppoe-retry-delay` | GL.iNet's published 4.8.6 tree (gl-inet/gl-image, branch gl-be10000, commit bfe99df8): `ppp.sh` (with ppp 2.4.8's plugin name `rp-pppoe.so`) and `ppp6-up` | 4.6.2: `ppp.sh` with the PPPoE retry delay (FAIL_COUNT) is exactly this; `ppp6-up` identical |
| `opkg-remove-once` | GL.iNet's published 4.8.6 tree (gl-inet/gl-image, branch gl-be10000, commit bfe99df8): `0001-opkg_remove-avoid-remove-pkg-repeatly...patch` (upstream cherry-pick) | 4.6.2: `opkg` 477 bytes larger than 4.5.x (candidate, to be confirmed) |
| `uci-lua-iteration` | GL.iNet's published 4.8.6 tree (gl-inet/gl-image, branch gl-be10000, commit bfe99df8): `001-lua-support-for-iteration.patch` | 4.6.2: uci/libuci-lua dated at the patch date, `uci.so` differs (candidate, to be confirmed) |
| `mptcp-backport` | GL.iNet's MPTCP backport for kernel 5.4 as published in gl-inet/gl-image (gl-be10000, bfe99df8, versions/4.8.6): 25 files under `target/linux/mediatek/files-5.4`, patch `999-9999-2-compat-mptcp-proto.patch`, `kmod-mptcp` definition; fetched and checked at build time (`files.sha256`) | 4.6.2+: `MPTCP=y`, `MPTCP_IPV6=y`; 4.7.0+: package `kmod-mptcp` (4.7.0's preflight). The backport differs slightly between GL.iNet's trees: the MT2500's may be older. Plus our backport of upstream's `__tcp_close()` split for 5.4.211 (`files/`, patch 999-9999-1b): GL.iNet's MPTCP calls it, and 5.4 stable only got it after 5.4.211 (job 59b: link error without it) |
| `mt7981-ubifs-zstd` | our construction: `CONFIG_UBIFS_FS_ZSTD=y` in the MT7981 target config | 4.6.2+: the only zstd option that changes on its own (4.5.0: not set); it selects `CRYPTO_ZSTD`, `ZSTD_COMPRESS`/`DECOMPRESS` and `XXHASH`, built in from 4.6.2 on; zstd built in only on MT7981 models |
| `mt2500-dts-phy-reset` | our construction: the MT2500 device tree as GL.iNet's 4.6.2 (decompiled, source order) | 4.6.2+: one device tree for both WAN PHYs: reset on the MDIO bus (GPIO 14, 100 ms/100 ms), PHY node `ethernet-phy-ieee802.3-c45` (see docs/driver-analysis.md) |
| `base-files-tz-revert` | GL.iNet's published 4.8.6 tree (gl-inet/gl-image, branch gl-be10000, commit bfe99df8): `package/base-files/files/etc/init.d/system` | 4.7.0+: `/etc/init.d/system` byte-identical to this file; it lacks upstream's `rm -f /tmp/TZ` (OpenWrt 3d62b5d5c6, "fix /tmp/TZ when zoneinfo not installed"), which 4.6.8 still had |
| `iwinfo-mediatek-not-public` | our construction: an empty, labelled commit | 4.6.2+: GL.iNet's `iwinfo` has newer MediaTek support (HE rate table, HT mode, country) found in no public source (gl-feeds, the fork, gl-image, MediaTek's feed). Reproduces only the revision count; `iwinfo` itself will differ |
| `usbnet-rm500u-not-public` | our construction: an empty, labelled commit | 4.6.2+: `usbnet.ko` has an RM500U 5G modem entry (`rm500u_5gnet`) found in no public source. Reproduces only the revision count; `usbnet.ko` will differ |

In 4.6.2 `unidentified-commit` is used six times: GL.iNet's 4.6.2 is
r15812+899, the public set plus the folders above give 893, and the rest
most likely only touches other boards built from the same tree (MT3000,
X3000, MT6000).

The placeholders stay until there is a good reason to remove them, or until
the content of GL.iNet's actual commits is found (owner's decision,
2026-10-27).
