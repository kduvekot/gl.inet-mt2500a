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

The placeholder stays until there is a good reason to remove it, or until
the content of GL.iNet's actual commit is found (owner's decision,
2026-10-27).
