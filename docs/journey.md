# Our journey into the wonderful world of the MT2500A

A running log of what we set out to do, what we found, and what we decided.
Newest chapters go at the bottom; the logbook at the end has the short version.

**The goal:**

1. Run a recent, upstream OpenWrt on the GL.iNet Brume 2 (GL-MT2500A), with
   networking that performs properly. Build it with GitHub workflows.
2. Bring back an older MT2500A that is stuck at its U-Boot recovery page. GL.iNet
   already replaced it under warranty, so this one is ours to experiment on.

---

## Chapter 1: Can we build the official firmware? (2026-10-22)

We started by asking whether GL.iNet's own firmware can be rebuilt from
source. The short answer is **no**.

* **The binaries are fully available.** GL.iNet's download API lists 15
  builds, from 4.1.1 (2022) to **4.7.4 stable** (2025-03-28), plus testing
  builds 4.8.2 and 4.9.0_beta3 (2026-07-04). Each has a direct URL and SHA256.
  We downloaded 4.7.4 and the hash matched. It is OpenWrt 21.02 with the
  MediaTek SDK and Linux 5.4.211.
* **The source is not.** The build system (`gl-infra-builder`) was taken
  offline in 2023. GL.iNet's new GPL source repository (`gl-image`) has no
  MT2500 branch, and even for other models it leaves out the GL.iNet UI and
  apps. The public SDK and image builder repos predate the MT7981 chip.
* **What is useful:** `gl-inet/mt798x-boot` has the MT2500 U-Boot source,
  including a configuration for the Airoha WAN chip, and the fixed
  2025-02-24 U-Boot binary.
* **Upstream OpenWrt supports the board well.** 25.12.6 has profiles for both
  hardware revisions. The original MaxLinear one even comes with OpenWrt's
  own preloader and U-Boot.

All details, hashes and links are in [firmware-sources.md](firmware-sources.md).

## Chapter 2: Choosing the path (2026-10-22)

**Decision:** build **upstream OpenWrt 25.12.6** with the official
ImageBuilder, for both WAN PHY variants:

| Profile | WAN PHY | When |
|---|---|---|
| `glinet_gl-mt2500` | MaxLinear GPY211C | original hardware |
| `glinet_gl-mt2500-airoha` | Airoha EN8811H | newer units |

**Why ImageBuilder?** It uses OpenWrt's own signed release packages and
kernel, so it finishes in minutes. It still lets us choose packages and add
our own config files. A full source build only becomes worthwhile if we need
kernel or driver changes.

**About "properly working network":** one open report
([openwrt/openwrt#17421](https://github.com/openwrt/openwrt/issues/17421))
describes about 35 Mbit/s instead of 310 Mbit/s, appearing after hours of
uptime. It has no root cause yet. Another user traced WAN packet loss to the
SoC overheating (~50 °C) with the board out of its case. So the image
includes `iperf3`, `ethtool-full`, and temperature and traffic graphs
(`luci-app-statistics` with `collectd-mod-thermal`). That way we measure
this rather than guess.

**Verified before committing:** both profiles were built locally with the
same commands the workflow runs. Each produced a ~9 MB sysupgrade image. The
MaxLinear profile also produced the factory image, preloader and U-Boot FIP.

What was added:

* [`.github/workflows/build-openwrt.yml`](../.github/workflows/build-openwrt.yml):
  builds both profiles; tag `v*` to publish a release.
* [`openwrt/packages.txt`](../openwrt/packages.txt): extra packages, one per
  line. Config files can go in `openwrt/files/` (optional).

## Chapter 3: The patient (2026-10-22)

The older MT2500A shows the U-Boot page for updating the bootloader, but an
upload never takes effect. Other owners report the same on the GL.iNet forum.

**Diagnosis (likely):** GL.iNet acknowledged a U-Boot defect on the
MT2500/X3000/XE3000 and published a fixed U-Boot dated 2025-02-24. On some
early units, the September 2022 U-Boot cannot initialise the eMMC. Its web
page still accepts the upload, then fails when writing. In one documented
recovery the eMMC itself was fine: the fixed U-Boot, loaded into RAM over
the serial port, read it without trouble.

**Plan:**

* **A:** try the fixed U-Boot via `uboot.html` in Chrome. It costs nothing,
  but probably fails for the same reason.
* **B:** open the case, connect the 3.3 V serial header to a Raspberry Pi,
  and load the fixed U-Boot into RAM with `mtk_uartboot`. Then write it
  permanently and reflash.

What was added:

* [`docs/recovery-uart-raspberry-pi.md`](recovery-uart-raspberry-pi.md): the
  step-by-step checklist.
* [`recovery/pi-setup.sh`](../recovery/pi-setup.sh): prepares the Pi's UART.
* [`recovery/uartboot.sh`](../recovery/uartboot.sh): RAM-loads the fixed
  U-Boot and opens a logged console.
* [`.github/workflows/recovery-kit.yml`](../.github/workflows/recovery-kit.yml):
  builds a checksummed kit. It contains `mtk_uartboot` for the Pi (aarch64 and
  armv7, static; upstream ships no Linux ARM build), the RAM BL2, the fixed
  FIP and stock 4.7.4. All inputs are pinned to commits or hashes.

## Chapter 4: How Claude can reach the Pi (2026-10-22)

The idea was a VPN from the Claude cloud session to the Pi, for SSH access.
We checked, and it doesn't work from here: the cloud container blocks
outbound SSH, can't accept incoming connections, and is thrown away after
the session.

Options that do work:

1. **Claude Code on a machine in the home network**, either your own computer
   (Desktop app, or `claude remote-control` in a terminal) or the Pi itself.
   That session can SSH into the Pi and drive the serial console directly.
   Whether Claude Code runs comfortably on a Pi 3 (1 GB RAM, needs the
   64-bit OS) is untested.
2. **Semi-manual:** you run the scripts. They log everything under
   `logs/`; commit or paste the logs, and we analyse them here.

## Chapter 5: The Pi becomes the workbench (2026-10-23)

The only hardware available is the Raspberry Pi 3 and a phone, so the Pi
does everything: Irakli's procedure, but with the Pi's own UART instead of
a Mac with a CP2102 adapter.

* **Is a Pi 3 enough?** Yes, for the recovery. It's small, light work. The
  Pi's PL011 UART handles the loader's 921,600 baud once Bluetooth is moved
  off it, and WiFi is unaffected. Its 100 Mbit Ethernet is fine for uploads
  but useless for router speed tests.
* **Three connections:** WiFi goes to the home network, for internet and the
  phone. Ethernet goes to the router's LAN port, with fixed 192.168.1.2 and
  192.168.8.2 and no gateway, so it can stay plugged in permanently. The
  UART pins go to the router's serial header, ideally with 1 kΩ in series on
  the Pi's TX line against back-powering.
* **No browser needed:** we extracted the recovery page's HTML and
  JavaScript from GL.iNet's fixed U-Boot. The flow is `POST /upload` (field
  `fip` or `firmware`) → `"<size> <md5>"`, then `/flashing.html` →
  `/result`. `recovery/web-flash.sh` copies it with curl. It only accepts
  the known FIP (by SHA256) or a GL-MT2500 sysupgrade image, refuses the
  `bl2` and `gpt` pages, and checks the size and MD5 the router reports
  before writing. Tested against a simulated server.
* **A console both of us can use:** `recovery/console.sh` runs picocom in
  tmux. The user watches with `attach`; Claude reads and types with `show`
  and `send`. `uartboot.sh` now uses it, and types `gl` to stop autoboot.
  Tested over a virtual serial port.
* **Claude on the Pi 3: it works.** Officially Claude Code wants 4 GB RAM
  and ARM64; the Pi 3 has 1 GB. On Raspberry Pi OS Lite 64-bit (Trixie) on
  a Pi 3 Model B+:
  * `curl -fsSL https://claude.ai/install.sh | bash` installed 2.1.309 for
    `linux-arm64`. `~/.local/bin` had to be added to `PATH` by hand, and
    `claude doctor` reported no issues.
  * `claude auth login` worked over SSH: open the link on the phone, paste
    the code back.
  * A first question that ran a shell command was answered in **7 s**, with
    about 360 MiB used, about 545 MiB still available, and **no swap used**.
  * `/remote-control` made the session visible and usable at claude.ai/code
    on the Chromebook, and in the Claude app on the phone.
* **Swap on Trixie** is not `dphys-swapfile` any more. It is **rpi-swap**:
  compressed swap in RAM (zram, here 904 MiB) plus a backing file at
  `/var/swap`, configured in `/etc/rpi/swap.conf` or drop-ins under
  `/etc/rpi/swap.conf.d/`. The default was enough. If Claude ever runs out
  of memory, double the zram with `[Zram]` `FixedSizeMiB=2048` in a drop-in,
  then reboot.
* **First-boot oddities, all harmless:**
  * "Failed to start userconfig.service": cloud-init masks Raspberry Pi's
    first-user wizard.
  * `cloud-init status` says "degraded done" because of a missing optional
    `cc_netplan_nm_patch` module. `errors: []`, and WiFi came up fine.

---

## Next steps

- [x] Run the **Build OpenWrt** workflow on GitHub and check the artifacts.
- [ ] Run the **Recovery kit** workflow with *publish* ticked.
- [x] Test Claude Code on the Pi 3 (64-bit OS, Remote Control from phone and Chromebook).
- [ ] Clone this repo on the Pi and continue this conversation there
      (`claude --teleport`), with `/remote-control`.
- [ ] Run `pi-setup.sh --download` on the Pi; join WiFi; cable eth0 to the router's LAN port.
- [ ] Find the WAN PHY variant of **each** unit separately. The replacement
      may well have a different chip than the broken one. Running unit:
      `dmesg | grep -iE 'en8811|airoha|gpy|maxlinear'`. Broken unit: chip
      marking next to the WAN port, then `dmesg` once stock firmware is back.

| Unit | WAN PHY | How determined |
|---|---|---|
| Replacement (working) | _unknown_ | |
| Old unit (stuck at U-Boot) | _unknown, likely MaxLinear_ | |

- [ ] Baseline speed test on the working unit with stock firmware (iperf3, WAN↔LAN;
      needs a gigabit peer, so not the Pi 3).
- [ ] Plan A on the broken unit (`./web-flash.sh fip` from the Pi); record the result.

## Logbook

| Date | What happened |
|---|---|
| 2026-10-22 | Researched official firmware availability; GL.iNet firmware is binary-only, upstream OpenWrt 25.12.6 supports both MT2500 revisions. |
| 2026-10-22 | Chose upstream OpenWrt via ImageBuilder; verified both profiles build locally; added build workflow. |
| 2026-10-22 | Diagnosed the stuck unit as the known 2022 U-Boot eMMC defect (likely); prepared Raspberry Pi UART recovery kit and checklist. |
| 2026-10-22 | VPN from the cloud session ruled out; remote access via a local Claude Code session instead. |
| 2026-10-22 | The kit's aarch64 `mtk_uartboot` is now built and run on a native GitHub ARM runner (`ubuntu-24.04-arm`). armv7 stays cross-built and is tested under qemu, because the ARM runners cannot run 32-bit code. |
| 2026-10-22 | PR #1 merged. Each unit's WAN PHY has to be identified separately. Checked that GL.iNet's fixed U-Boot only drives the internal LAN PHY, so recovery doesn't depend on the WAN chip. The OpenWrt compatibility check probably won't catch a wrong-variant image when flashing from stock firmware. |
| 2026-10-23 | The Pi 3 becomes the workbench: WiFi for access, Ethernet to the router's LAN, UART pins to its serial header. Added `web-flash.sh` (browser-free recovery uploads) and `console.sh` (shared tmux console). Testing Claude Code on the Pi 3. |
| 2026-10-23 | The Chromebook Recovery Utility can't write `.img.xz`, so a manual workflow repackages the official Raspberry Pi OS Lite 64-bit (2026-10-06, Trixie) as a verified `.zip`. First boot is configured with cloud-init files on the boot partition. 16 GB SD is enough. |
| 2026-10-23 | The Pi 3 B+ runs Raspberry Pi OS Lite 64-bit (Trixie), configured by cloud-init. Claude Code 2.1.309 runs on it (7 s answers, no swap needed) and is reachable through Remote Control from the phone and Chromebook. Swap on Trixie is rpi-swap (zram), not dphys-swapfile. |
| 2026-10-23 | `recovery-kit` release published (run 39948369152; aarch64 and armv7 `mtk_uartboot` built, kit 55.7 MB). Next: cables for the UART, then `pi-setup.sh`. |
| 2026-10-23 | First reboot test of `claude-rc.service` passed: Remote Control back online about 30 s after boot, and the served session came back with its history. The interactive tmux session `claude` does not survive a reboot (not a service). |
