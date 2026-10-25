# Firmware sources for the GL-MT2500 / GL-MT2500A

Reference material gathered on 2026-10-22. Everything here was checked
directly against the source (git refs, download APIs, file hashes) unless it
is marked as a forum report.

## Hardware at a glance

| Item | Value |
|---|---|
| SoC | MediaTek MT7981B (Filogic 820), 2× Cortex-A53 @ 1.3 GHz |
| RAM / storage | 1 GB DDR4 / 8 GB eMMC |
| LAN | 1 GbE (SoC built-in PHY) |
| WAN | 2.5 GbE: **MaxLinear GPY211C** (original) or **Airoha EN8811H** (newer revision) |
| Serial | 4-pin header near the LAN port, 3.3 V, 115200 8N1 |

The WAN PHY decides which image you need. On a running unit:

```sh
dmesg | grep -iE 'en8811|airoha|gpy|maxlinear'
```

## 1. GL.iNet stock firmware (binaries)

GL.iNet's download centre is backed by a JSON API:
`https://firmware-api.gl-inet.com/cloud-api/model/info?model=mt2500`

| Version | Stage | Released | SHA256 |
|---|---|---|---|
| 4.9.0_beta3 | testing | 2026-07-04 | `fc1e641c1fda38efee35c86645215defb651b6df12fbc6f7997d2346702da86a` |
| 4.8.2 | testing | 2025-09-12 | `67e723d0e9bde0d47feeb984c90cd173e1a2037f56ec437991d615971e9b2231` |
| **4.7.4** | **stable** | 2025-03-28 | `3de78f88a2cc204c089cd1c262346786796d43a223564b1f792f3e8515cc8904` |
| 4.7.0 | stable | 2024-12-05 | `201ec244f73c6f49a85a1e1622d3136d65f0a2c58279c3cb94e1ecd7b017c6f0` |
| 4.6.8 | stable | 2024-10-17 | `7d28e9f3520412a59842d56d7113ae856a7addd5d7708cd718c1c71e34fc43e6` |
| 4.6.4 | stable | 2024-09-04 | `ceddb30e95c569d5799071796814b67d2a77d49a8937b8e2a0da2164207994e3` |
| 4.6.2 | stable | 2024-06-28 | `c9ad8ac3fa189cfd4e20384adb54c5b0994606cb9bb3a30b2099de7742c8328a` |
| 4.5.16 | stable | 2024-03-30 | `6254250bbe3c4cf33c61a7de683e6a4e1db6bdbb1b8146144aed46744077e6dc` |
| 4.5.0 | stable | 2024-01-23 | `f0c5b0343cc561ad725226d548189e907ed15f29881222d03698244341863175` |
| 4.4.6 | stable | 2023-10-08 | `26f67e3f231f9b7cffb2686ed5af315a3210eee01d97bfa0f8cb7144e324ac15` |
| 4.4.5 | stable | 2023-08-11 | `e124880e4399dbd74a96ff2228122818b84a62ccc2ee049618243f47435c8643` |
| 4.2.3 | stable | 2023-07-06 | `bc65bcd6c5c4b1c4703c60827bb88482c02876cba43363906fd18f6fe3daaa5d` |
| 4.2.1 | stable | 2023-04-14 | `977dbc05b88673f7b9e19676ed4c4c01374216abdc88906050f271378a809480` |
| 4.2.0 | stable | 2023-03-14 | `3c13b26fbfe9fe1710b42f90c80a47fe000dd98d899fec2d0ed3b8053ac69348` |
| 4.1.1 | stable | 2022-11-05 | `2e1615486c4d505e2f55b8ad6a006212e06af758001051aed7d7fcca10fd4f45` |

Download URLs follow
`https://fw.gl-inet.com/firmware/mt2500/<release|testing>/<file name>`; the
API returns the exact file name. The 4.7.4 image was downloaded and checked:
it is an OpenWrt sysupgrade tar (`BOARD=glinet_gl-mt2500`) with a FIT kernel,
**Linux 5.4.211** and an xz squashfs root, based on OpenWrt 21.02 with the
MediaTek SDK.

## 2. GL.iNet source code

GL.iNet moved its firmware to closed source in 2023. What is still public:

| Repository | Contents | MT2500 status |
|---|---|---|
| `gl-inet/gl-infra-builder` | Former full firmware build system | **Removed (Aug 2023).** Unofficial forks stop around 4.2. |
| [`gl-inet/gl-image`](https://github.com/gl-inet/gl-image) | GPL "Complete Corresponding Source" releases | Branches only for MT3600BE, BE10000, BE14000. **No MT2500.** Proprietary UI/apps excluded even there. |
| [`gl-inet/gl-feeds`](https://github.com/gl-inet/gl-feeds) | GL's open-source package feeds | Tags `MT2500-4.9.0_BETA3-*-GL_FEED_{21_02,COMMON,SMSTOOLS3}` |
| [`gl-inet/glinet4.x`](https://github.com/gl-inet/glinet4.x) | Prebuilt GL packages (`.ipk`, no source) | Last updated for 4.2.1 (2023-03) |
| [`gl-inet/sdk`](https://github.com/gl-inet/sdk), [`gl-inet/imagebuilder`](https://github.com/gl-inet/imagebuilder) | Package SDK / image builder | Stale (2022–23), no MT7981 |
| [`gl-inet/mt798x-boot`](https://github.com/gl-inet/mt798x-boot) | ATF + U-Boot source and binaries | `gl_mt2500_defconfig`, `gl_mt2500_en8811h_defconfig`, `gl_mt2500_wan_defconfig`; binary `bin/uboot-mt2500-20250224-md5-74286e770cfb041b611d80d4adaef189.bin` |

The GL.iNet download centre names `gl-image` as the GPLv2 corresponding
source for its firmware. Nothing has been published there for the MT2500 so
far; a request to support@gl-inet.com is the formal route.

### What the firmware is built from

Checked 2026-10-24/25 by unpacking the firmware images and by recreating
4.2.0 from public sources (see
[journey.md](journey.md), Chapter 11).

* **Base:** OpenWrt `openwrt-21.02` at commit `bcaabe6d` (r16649,
  2022-09-04, "kernel: bump 5.4 to 5.4.211") plus GL.iNet patches. All MT2500
  firmwares from 4.1.1 to 4.9.0_beta3 run Linux 5.4.211.
* **Version string:** `r15812+878` (4.2.0) and `r15812+912` (4.7.4).
  `r15812` is the merge base with master (`46b6ee7ffc`, the 21.02 branch
  point); `+N` counts the commits on top: 837 upstream 21.02 commits plus
  GL.iNet's patches (41 patches in the 4.2.0 recipe).
* **Recipe:** GL.iNet's `gl-infra-builder` (removed by GL.iNet; the fork
  [spmadden/gl-infra-builder](https://github.com/spmadden/gl-infra-builder)
  survives) with `configs/config-mt798x-7.6.6.1.yml`,
  `patches-mt798x-7.6.6.1/` and per-version tags such as
  `v4.2.0_mt2500_release4`.
* **MediaTek feed:** `git01.mediatek.com`, which now needs a login. The same
  commit (`df3fc79`) is on GL.iNet's mirror
  [gl-inet/mtk-openwrt-feeds](https://github.com/gl-inet/mtk-openwrt-feeds).
* **Private feeds:** GL.iNet's GitLab feeds (`gl-sdk4-collect`,
  `mt7981-feeds`) are not public.

### Rebuilding it ourselves

The workflow `gl-recreate-4.2.0.yml` rebuilds 4.2.0 from these public
sources and compares it with GL.iNet's image. State after six runs
(2026-10-25):

| | Result |
|---|---|
| OpenWrt version string | identical (`r15812+878-46b6ee7ffc`) |
| Kernel configuration | identical (0 of 2090 options differ) |
| Kernel modules | all byte-identical |
| Kernel image | not compared yet (package checksum differs) |
| Packages | 363 of 466 (GL.iNet's closed and private packages can't be built) |
| Other files | about 300 libraries and programs differ, not investigated yet |

Each successful run publishes release `gl-4.2.0-sdk`: the OpenWrt SDK
(GL.iNet's GCC 8.4.0 toolchain and the prepared kernel tree) and
`mtk-eth-driver-src.tar.gz` (the Ethernet/PPE driver folder as compiled,
which the SDK leaves out). Open-source code only; it lets other workflows
build kernel modules exactly like GL.iNet did. Matching GL.iNet's modules
also needs OpenWrt's `KCFLAGS=-fno-caller-saves` and stripping like
`scripts/strip-kmod.sh`.

### Closed kernel modules

Their declared licenses come from `modinfo`. Most claim a GPL license, yet
only some have public source.

| Module | Declared license | Public source |
|---|---|---|
| `gl-sdk4-hw-info` | GPL | yes: `gl-inet/gl-feeds`, branch `v4.7` |
| `gl-sdk4-tertf` | GPL | yes: `gl-inet/gl-feeds`, branch `fix-nginx` |
| `parental_control` | GPL | yes: [gl-inet/parental-control](https://github.com/gl-inet/parental-control) (2023) |
| `mtkhnat` | GPL v2 | yes, in effect: MediaTek's source plus GL.iNet's public patches rebuilds 4.2.0 byte-identical; 4.7.4 is the same with one warning removed (see driver-analysis.md) |
| `kmwan`, `black_white_list`, `gl-mpflow` | GPL | not found |
| `mtfwd`, `mtqos` | Dual BSD/GPL | not found (both are Wi-Fi features; see driver-analysis.md) |

Also not found: the `fwdd` daemon and the `mtk-base-files` package. What
these modules do is in [driver-analysis.md](driver-analysis.md).

### 4.7.13 (unpublished)

GL.iNet's API lists 4.7.4 as the latest release and 4.8.2 / 4.9.0 as
testing, but the replacement unit runs **4.7.13**, which is not offered
anywhere. We read its kernel and read-only squashfs from the unit (no
settings, no MAC address, no serial number), verified the copy by SHA256 and
keep it private; it is not in this repo. Against 4.7.4: identical kernel
config, identical EN8811H driver and PHY firmware; among the modules only
`kmwan`, `parental_control` and `nf_nat` differ (`nf_nat` changed without a
config change, so the kernel source changed). Updated packages include curl
7.83 to 8.12, dropbear 2020.81 to 2024.86 and samba 4.14 to 4.18. LuCI is
removed (19 `luci*` packages) and the OpenWrt revision string is empty.

### The fixed U-Boot (FIP)

`uboot-mt2500-20250224-md5-74286e770cfb041b611d80d4adaef189.bin` in
`gl-inet/mt798x-boot` (commit `8f73dd1`) is the FIP that GL.iNet published
after its U-Boot defect notice:

* MD5 `74286e770cfb041b611d80d4adaef189` (matches its name)
* SHA256 `90b28ab596783e8cab09e1e38d77a37cdbc1e3b9fba855847bc8248b213a40be`
* 641,261 bytes, the same size and SHA256 as the `fip-mt2500-20250224.bin`
  used in the published UART debrick.

## 3. Upstream OpenWrt

Support landed in Nov 2023 (`mediatek/filogic`, commit `1239668`). The newer
Airoha PHY revision was added in Oct 2025 and backported to 24.10.

| Release | Kernel | Profiles | Images |
|---|---|---|---|
| **25.12.6** (stable) | 6.12.112 | `glinet_gl-mt2500`, `glinet_gl-mt2500-airoha` | MaxLinear: sysupgrade, factory, initramfs, `emmc-preloader.bin`, `emmc-bl31-uboot.fip`. Airoha: sysupgrade, initramfs |
| 24.10.8 (old stable) | 6.6.144 | same two | sysupgrade, initramfs |

Open performance report: [openwrt/openwrt#17421](https://github.com/openwrt/openwrt/issues/17421)
(about 35 Mbit/s instead of 310 Mbit/s, after hours of uptime, one reporter,
no root cause yet). A separate OpenWrt forum report traced WAN packet loss on
an MT2500A to the SoC overheating (~50 °C) with the board outside its
aluminium case.

## 4. Recovery tooling

| Tool | Source | Notes |
|---|---|---|
| `mtk_uartboot` | [981213/mtk_uartboot](https://github.com/981213/mtk_uartboot) | BootROM UART loader (Rust). Releases ship no Linux ARM build, so the recovery kit workflow builds static aarch64/armv7 binaries. |
| RAM BL2 | [981213/tf-a-mtk](https://github.com/981213/tf-a-mtk) release `v2.10.0-mtk` | `bl2-mt7981-bga-ddr4-ram.bin`, built from `configs/mt7981_bga_ddr4_ram_defconfig` with UART download support |
| Community U-Boot | [hanwckf/bl-mt798x](https://github.com/hanwckf/bl-mt798x) and forks | Newer ATF/U-Boot; not used here |

## Sources

* GL.iNet: [firmware versions](https://www.gl-inet.com/support/firmware-versions/),
  [download centre](https://dl.gl-inet.com/?model=mt2500),
  [U-Boot defect notice](https://forum.gl-inet.com/t/critical-problem-notification-for-gl-mt2500-gl-x3000-gl-xe3000/56261),
  [builder removal](https://forum.gl-inet.com/t/removed-gl-infra-builder-repository/32828),
  [closed-source statement](https://forum.gl-inet.com/t/formal-statement-on-gl-inet-software-going-closed-source/33288),
  [gl-infra-builder 404](https://forum.gl-inet.com/t/github-gl-infra-builder-404/53881)
* OpenWrt: [initial support commit](https://github.com/openwrt/openwrt/commit/12396686484a488dff1c4a1ee8b5197c552572fe),
  [patch](https://patchwork.ozlabs.org/project/openwrt/patch/20231126151232.2244760-1-mrkiko.rs@gmail.com/),
  [hardware revision fix](https://lists.infradead.org/pipermail/lede-commits/2025-October/027330.html),
  [forum thread](https://forum.openwrt.org/t/gl-inet-brume-2-gl-mt2500-2500a-discussions/202091),
  [release metadata](https://downloads.openwrt.org/releases/25.12.6/targets/mediatek/filogic/)
* Recovery: [UART debrick of a GL-MT2500A](https://iraklijani.com/blog/debricking-a-gl-mt2500a-brume-2-with-uart/),
  [UART guide on the GL.iNet forum](https://forum.gl-inet.com/t/gl-mt2500-and-gl-mt2500a-bricked-after-update-to-4-5-0/43530)
