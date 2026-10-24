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
  off it, and WiFi is unaffected. Its Ethernet is gigabit (LAN7515) but sits
  on USB 2.0, so about 300 Mbit/s in practice: fine for uploads and backups,
  useless for router speed tests. (Corrected 2026-10-24: earlier versions said
  100 Mbit, which is the Pi 3 Model B without the plus.)
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

## Chapter 6: A power switch for the router (2026-10-23)

The UART loader has to catch the BootROM at power-on, so the router will be
power-cycled many times. Rather than pulling the USB-C plug by hand, the Pi
switches the router's power adapter with a smart plug.

* **Options weighed:** a smart plug with a local API (chosen: no wiring, no
  mains work), a relay on the 5 V side (fiddly with USB-C, needs a relay
  that accepts 3.3 V), or the Pi's own USB ports (rejected: too little
  current for the router's 5 V/3 A, and on a Pi 3 B+ switching them off
  also cuts `eth0`, which sits on the same internal USB hub).
* **The house already had an IKEA DIRIGERA hub.** It wasn't on the network:
  its double-blinking light meant no connection, and the wall socket it was
  plugged into turned out to be dead. On another port it came up at once.
  It announces itself over mDNS (`_ihsp._tcp`, port 8443, plus HomeKit), so
  the Pi finds it by name and its IP may change.
* **Local API:** not documented by IKEA, but the community library
  [Leggin/dirigera](https://github.com/Leggin/dirigera) (MIT) describes it:
  OAuth with PKCE on port 8443. You press the Action button on the bottom of
  the hub (not Reset) to approve. Our `pi/dirigera-token.py` uses only the
  Python standard library and retries the token request for 90 s, so nobody
  has to press Enter on the Pi. The token is stored in `~/.config/dirigera/`
  on the Pi, never in the repo.
* **A second INSPELNING plug just for the router,** named `MT2500A` in the
  IKEA Home smart app. `pi/plug.sh` does `status`, `on`, `off`,
  `cycle [s]` and `startup <on|off|previous|toggle>`, and only ever touches
  the plug with exactly that name. Another plug in the house drives a
  1.8 kW space heater. INSPELNING also reports watts, volts and amps, so
  we can see whether the router is drawing power.
* **Tested:** the heater's plug switched on and off on request and read
  1858 W while on; the empty `MT2500A` plug clicked on and off, and a
  wrong plug name is refused.
* **Public repo, so no secrets in it,** not even encrypted: a public
  repo keeps its history forever, the key would live on the same Pi
  anyway, and the tokens are cheap to replace. Home-specific details (hub
  name, IDs, addresses) stay in local files on the Pi.

## Chapter 7: First contact over the UART (2026-10-24)

* **Wiring:** Pi pin 6 (GND) to J13 GND, pin 10 (RXD) to J13 TX, and pin 8
  (TXD) through three 4.7 kΩ resistors in parallel (about 1.57 kΩ, on a
  breadboard) to J13 RX. The 3.3V hole is taped over. The bought resistors
  turned out to be 4.7 kΩ (yellow-violet-red-gold), not 1 kΩ. The board
  lies on cardboard; black conductive foam is only for storing it unpowered.
* **`pi-setup.sh --download`** ran cleanly: the PL011 UART is on GPIO14/15
  (`/dev/serial0 → ttyAMA0`), Bluetooth is off, the serial console is
  removed, and the `mt2500-lan` profile and the kit are in place. Side effect:
  `apt-get install curl` also upgraded curl to the latest Debian security
  release.
* **First boot log** (console started, then the router switched on with
  `pi/plug.sh on`): BootROM, BL2 and DDR calibration all fine, 1 GiB DRAM,
  then the **old U-Boot**:
  ```
  U-Boot 2022.07-rc3 (Sep 12 2022 - 19:58:08 -0700)
  Loading Environment from MMC... unable to select a mode : -110
  mmc_init: -524, time 73
  *** Warning - No block device, using default environment
  ```
  `-110` is ETIMEDOUT (selecting a bus mode timed out), `-524` is ENOTSUPP
  (no usable mode). It then tried a TFTP "Upgrading Firmware" from
  192.168.1.2 for `openwrt-gl-mt2500.bin`, which timed out (no TFTP server),
  printed `*** Failed to initialize MMC device 0! ***` twice, and stopped at
  the `MT7981>` prompt. The router draws about 1 W there.
* **It matches Irakli's log line for line:** same U-Boot build, same `-110`
  and `-524` (his `time 74`, ours `73`), same "No block device". In his case
  the 2025-02-24 U-Boot loaded over UART then saw the eMMC at "Bus Speed:
  52000000, MMC High Speed (52MHz)" with an EFI partition map. That is the
  strongest sign yet that our plan applies to this unit.
* **Checked against GL.iNet's public source** (`gl-inet/mt798x-boot`, init
  commit of 2024-11):
  * `Model: mt7981-rfb` is the model string in GL's own `gl-mt2500.dtsi`,
    so it's normal.
  * `gpio: pin 12 (gpio 12) value is 0` is the output of `gpio clear 12`
    (`gpio_power_clr` in `cmd/glbtn.c`). The reset button is GPIO 1, and it
    wasn't pressed.
  * The eMMC node: 8-bit bus, `max-frequency` 52 MHz, `cap-mmc-highspeed`,
    HS200 support enabled in the defconfig.
  * The TFTP "Upgrading Firmware" step and the file name
    `openwrt-gl-mt2500.bin` are **not** in that source, nor in Irakli's log,
    so the 2022 binary on this unit differs from the published source.
    `printenv` at the prompt will show where it comes from.
* **Ethernet:** the Pi's eth0 has a 1000 Mb/s link to the port next to J13,
  so that's the LAN port, and a straight cable works.
* **Read-only checks at the `MT7981>` prompt:**
  * `version`: the same Sep 12 2022 build, compiled with Ubuntu 20.04's
    GCC 9.4.
  * `printenv` (the default environment, since it can't read the saved one
    from the eMMC): no `bootcmd`, but two helpers, `lf=mtkupgrade fw
    openwrt-gl-mt2500.bin` and `lu=mtkupgrade fip uboot-gl-mt2500.bin`,
    with `ipaddr=192.168.1.1` and `serverip=192.168.1.2`. The TFTP
    "Upgrading Firmware" at boot is `mtkupgrade fw`, so `lf`. Neither helper
    can help: both write to the eMMC that this U-Boot can't open.
  * `mmc list` shows `mmc@11230000: 0`; `mmc info` and `mmc rescan` give the
    same `-110` / `-524` every time, so the failure is reproducible, not a
    one-off.
  * `help` lists, among others, `loadx`/`loady` (serial download to RAM),
    `go`, `bootm`, `httpd` (the recovery page), `mtkupgrade`, `gpt` and
    `mmc`.
* **Raw logs:** a cleaned copy of this session is in
  [logs/2026-10-24-old-uboot-first-boot.log](logs/2026-10-24-old-uboot-first-boot.log)
  (terminal colour codes removed). The originals stay on the Pi in
  `~/mt2500-recovery-kit/logs/` (one file per
  console session).

## Chapter 8: Plan B, the fixed U-Boot from RAM (2026-10-24)

**Result: GL.iNet's 2025-02-24 U-Boot, loaded over UART into RAM, reads the
eMMC without any problem.** Nothing was written to the router.

* **How:** router off with `pi/plug.sh off` and 10 s wait, then
  `uartboot.sh -y` in its own tmux session (`uartboot`), then
  `pi/plug.sh on`. The first attempt stopped before the loader with
  "/dev/serial0 is in use": `uartboot.sh` checked the port right after
  stopping the console, before picocom had exited. Fixed in
  `recovery/uartboot.sh` (waits up to 5 s); the published kit still has
  the old version until the **Recovery kit** workflow runs again.
* **Loader** (`mtk_uartboot` 0.1.1): handshake with the BootROM
  (`hw code: 0x7981`), our RAM BL2 at 460,800 baud (BL2 v2.10.0-mtk, "EMI:
  Using DDR4 settings", 1024 MB, memory test passed), then the FIP at
  921,600 baud through the ~1.57 kΩ resistors: `Received FIP 0x9c8ed`,
  which is exactly 641,261 bytes, the size of the 2025-02-24 FIP.
* **The new U-Boot:** `U-Boot 2022.07-rc3 (Feb 24 2025 - 15:04:07 +0800)`,
  built with Ubuntu 22.04's GCC 11.4. `Loading Environment from MMC... ***
  Warning - bad CRC, using default environment`: it reads the eMMC (no
  `-110`/`-524`), it just finds no valid saved settings. `uartboot.sh`
  typed `gl` to stop autoboot.
* **`mmc info`:** manufacturer ID 0x15 (Samsung), name `8GTF4R` (matching
  the KLM8G1GETF chip), eMMC 5.1, **MMC High Speed at 52 MHz, 8-bit**,
  7.3 GiB user area, two 4 MiB boot areas (not write-protected), 512 KiB
  RPMB. This matches what Irakli saw.
* **`mmc part`:** the EFI partition table is intact: `log`, `u-boot-env`,
  `rf`, `fip`, `kernel`, `rootfs`. So the eMMC and its contents survived;
  only the old U-Boot couldn't talk to it.
* **Still volatile:** this U-Boot only lives in RAM. A power cycle brings
  back the old one. Writing it permanently (the `fip` partition) is the
  next decision, after a backup of what's on the eMMC now (at least `rf`,
  which probably holds the unit's own data such as MAC addresses; not
  checked yet).
* **Logs:** [loader](logs/2026-10-24-plan-b-uartboot.log) and
  [console](logs/2026-10-24-plan-b-console.log) (cleaned copies).

## Chapter 9: A complete backup of the eMMC (2026-10-24)

**Result: a byte-for-byte copy of the whole eMMC (boot0, boot1 and the
7.3 GiB user area), each checked against a SHA256 that the router computed
itself.** Still nothing written to the router.

* **Can we always get back in?** Yes, as far as we can tell: the UART
  download lives in the MT7981's BootROM, so it works whatever is on the
  eMMC, as long as the chip has no secure boot fused (it accepted our
  unsigned BL2, so it hasn't) and the eMMC is physically intact. What you
  need: a 3.3 V UART (the Pi and 3 wires to J13), `mtk_uartboot`, the RAM
  BL2 (MT7981 + DDR4), a working FIP (all in the recovery kit), and the
  backup images.
* **Why an initramfs:** the RAM U-Boot can read the eMMC but can't send
  files out (its `help` lists no `tftpput` and no USB; only `md` hex dumps
  over serial, far too slow for 7.3 GiB). Loading into the router is easy
  (`tftpboot`, `loady`, the recovery page). So: boot the official **OpenWrt
  25.12.6 initramfs** (8.0 MB, runs from RAM) over TFTP and copy over SSH.
* **TFTP on the Pi:** the packaged `tftpd-hpa`, so others can do the same.
  It listens only on `192.168.1.2:69`, read-only (`--secure`), autostart
  off, started only for the transfer. Images go in a subfolder with a short
  name (`<original name>/initramfs.bin` plus `sha256sum.txt`) and the TFTP
  root stays empty: GL.iNet's U-Boot fetches `openwrt-gl-mt2500.bin` and
  `uboot-gl-mt2500.bin` from the root by itself and would flash them.
* **Boot:** `tftpboot` transferred 8,017,764 bytes (a few timeouts while the
  link came up), U-Boot's `crc32` over RAM matched the file's CRC32
  (`2065cca1`), then `bootm`. The kernel log shows `Machine model: GL.iNet
  GL-MT2500 (MaxLinear PHY)` and `Maxlinear Ethernet GPY211C ... Firmware
  Version: 8.111`, so the WAN PHY is now confirmed in software too.
  `mmcblk0` 7.28 GiB with p1–p6, plus `mmcblk0boot0`/`boot1` (4 MiB) and
  RPMB.
* **GPT quirk:** `GPT:Primary header thinks Alt. header is not at the end
  of the disk` (`1 != 15269887`): GL.iNet's table points to sector 1 for
  its backup copy instead of the last sector. A factory quirk, not damage;
  all partitions are found. Left as is: correcting it would mean writing.
* **Copy:** `cat /dev/mmcblk0bootN` and `cat /dev/mmcblk0` over SSH into
  `~/mt2500-backup/2026-10-24/` on the Pi (mode 700, files read-only).
  7,818,182,656 bytes (15,269,888 sectors) in about 25 minutes. The Pi's SD
  card was the bottleneck at 4.5–9 MB/s; both CPUs and the network were
  mostly idle. The router's `sha256sum /dev/mmcblk0` took 11 minutes and
  matched the copy, as did boot0 and boot1. The full image is then
  compressed with `zstd`.
* **What's where on this unit:**
  * **boot0:** BL2, the first-stage loader the chip boots from
    (`mmc partconf`: `BOOT_PARTITION_ENABLE: 0x1`).
  * **boot1:** this unit's own data: MAC address (from GL.iNet's
    `94:83:c4` block, at offset `0xa`, where OpenWrt reads it), serial
    number and a backup copy, DDNS ID, country code. **This is the
    irreplaceable part**, so it never goes into this public repo.
  * `rf`, `log` and `u-boot-env` are empty. I had guessed `rf` held the MAC
    addresses; it doesn't (probably WiFi calibration, and the MT2500 has no
    WiFi).
  * `fip` holds the old 2022 U-Boot (its hash differs from the 2025 FIP).
* **Correction:** the Pi 3 B+'s Ethernet is gigabit over USB 2.0 (about
  300 Mbit/s), not 100 Mbit as chapter 5 said; fixed there and in the
  checklist.
* **The checklist** (`recovery-uart-raspberry-pi.md`) has a new step 3b with
  the exact TFTP setup, the warning about the TFTP root, and the backup
  commands, for anyone repeating this.

## Chapter 10: The fixed U-Boot on the eMMC, and a clean 4.7.4 (2026-10-24)

**Result: the old MT2500A boots by itself again.** BootROM → the old BL2
in boot0 → GL.iNet's **2025-02-24 U-Boot from the eMMC** → GL.iNet
firmware **4.7.4**, reset to factory settings and set up again. Only the
`fip` partition and the settings volume were written.

* **Method chosen:** `dd` from the running OpenWrt initramfs, not GL.iNet's
  route. GL.iNet's official way is the U-Boot recovery page, which on this
  unit is exactly what never wrote anything, and which GL.iNet itself says
  "may cause the uboot flashing failure on MT2500". `mtkupgrade fip` (the
  debrick write-up's route) was the fallback. `dd` was the only route where
  we could check the target before and verify the result after.
* **Preparation:** the 2025 FIP (SHA256 `90b28ab5…`, MD5 `74286e77…` as in
  GL.iNet's file name) padded with zeros to the partition's 2 MiB
  (`d1c62731…`), copied to the router's RAM and checked there. Target check:
  `mmcblk0p4` is `PARTNAME=fip`, start 13312, 4096 sectors, and its content
  equalled the backup's old FIP; `rf` ends at 13311 and `kernel` starts at
  17408, so nothing could spill over.
* **Write:** `dd ... of=/dev/mmcblk0p4 oflag=direct conv=fsync`, 0.18 s, no
  kernel messages. Read back with the caches dropped: exactly `d1c62731…`;
  `kernel` and `rf` unchanged. Commands and output:
  [logs/2026-10-24-uboot-write-commands.log](logs/2026-10-24-uboot-write-commands.log).
* **Boot test** (power-cycled with the plug, no UART loader): `U-Boot
  2022.07-rc3 (Feb 24 2025 - 15:04:07 +0800)` from the eMMC reads it ("bad
  CRC, using default environment"), tries its automatic TFTP firmware fetch
  (nothing there), then boots GL.iNet's Linux 5.4.211. Full console:
  [logs/2026-10-24-uboot-write-and-reset-console.log](logs/2026-10-24-uboot-write-and-reset-console.log).
* **Version naming:** both U-Boots say `2022.07-rc3`; that's the upstream
  U-Boot source they're based on. The fix is in GL.iNet's build of
  **24 Feb 2025** (the old one was built 12 Sep 2022).
* **The firmware was fine all along.** The eMMC still held GL.iNet **4.7.4**
  (`/etc/glversion`, built 2025-03-28): the `kernel` and `root` inside
  GL.iNet's official 4.7.4 sysupgrade file match the start of p5 and p6 byte
  for byte. Its settings (98 files, all dated 26 May 2025, `inited 1`, root
  password set) show the router was set up that day and never changed again,
  consistent with it getting stuck at the next reboot because the old
  U-Boot couldn't open the eMMC.
* **Failsafe findings:** `- failsafe_and_factory_reset` is just a heading in
  `/etc/banner.failsafe`; the `ssh-rsa ... root@(none)` line is a temporary
  1024-bit host key that failsafe generates in RAM. Failsafe SSH doesn't
  work on the MT2500 (its preinit network uses `lan1`, which this router
  hasn't got), so failsafe is console-only. `/sbin/mtk_failsafe.sh` is
  missing (a MediaTek SDK leftover). The old settings were inspected
  read-only (`losetup -r` at offset 0x3090000 into p6, `mount -t f2fs -o
  ro,norecovery`); GL.iNet's kernel also exposes that volume as a virtual
  `mmcblk0p7` (`rootfs_data`, start 182400).
* **The factory reset took three tries.** `firstboot -y` in failsafe without
  `mount_root` only writes a `deadc0de` mark that this firmware ignores on
  its f2fs settings volume. The first try also lacked a `sync` before
  `reboot -f`; the second had the mark verifiably on the eMMC and still
  changed nothing. GL.iNet's own reset (`/etc/rc.button/reset` →
  `factory_reset` in `gl_util.sh`) runs `firstboot -y; reboot` on the
  **mounted** volume, so the working sequence is `mount_root; firstboot -y;
  sync; reboot -f` ("only erasing files", 98 → 0 files). After that the
  router reported `initialized: false`.
* **First-time setup without a browser:** the router's own web UI showed
  the calls: `ui.init` with language, timezone, `root` and a password
  (10–63 characters with `security_rule: 1`), then `challenge`/`login`
  with an MD5-crypt hash. Set up with English and Europe/Amsterdam; login
  and `system.get_info` (4.7.4 `release6`, kernel 5.4.211) work. The
  password was generated on the Pi and is kept there, outside the repo.
  The internet step is left for when WAN gets connected.
* **Power-cycle test** after the setup: the 2025 U-Boot and 4.7.4 come up
  by themselves, the web API answers 40 s after power-on, the router stays
  `initialized`, keeps its timezone, and both the API login and the serial
  console login (`root@GL-MT2500`) work with the new password.

---

## Next steps

- [x] Run the **Build OpenWrt** workflow on GitHub and check the artifacts.
- [x] Run the **Recovery kit** workflow with *publish* ticked.
- [ ] Run it again so the published kit gets the `uartboot.sh` port fix.
- [x] Test Claude Code on the Pi 3 (64-bit OS, Remote Control from phone and Chromebook).
- [x] Clone this repo on the Pi and continue this conversation there
      (`claude --teleport`), with `/remote-control`.
- [x] Run `pi-setup.sh --download` on the Pi; join WiFi; cable eth0 to the router's LAN port.
- [x] Plan B: load the 2025-02-24 U-Boot into RAM over UART; it reads the eMMC.
- [x] Back up the whole eMMC (boot0, boot1, user area) before writing anything; verified by SHA256.
- [x] Keep a second copy of the backup somewhere private, off the Pi (on the home NAS, verified).
- [x] Write the 2025-02-24 U-Boot permanently (`fip` partition): `dd` from the initramfs, verified.
- [x] Boot from the eMMC without UART; factory-reset 4.7.4 and set it up.
- [ ] Connect WAN and finish GL.iNet's internet setup; check `dmesg` for the WAN PHY.
- [ ] Decide: keep stock 4.7.4, or flash our upstream OpenWrt build (`glinet_gl-mt2500`).
- [ ] Find the WAN PHY variant of **each** unit separately. The replacement
      may well have a different chip than the broken one. Running unit:
      `dmesg | grep -iE 'en8811|airoha|gpy|maxlinear'`. Broken unit: chip
      marking next to the WAN port, then `dmesg` once stock firmware is back.

| Unit | WAN PHY | How determined |
|---|---|---|
| Replacement (working) | _unknown_ | |
| Old unit (stuck at U-Boot) | **MaxLinear GPY211C0VC** (marking MxL SLNW8) → `glinet_gl-mt2500` | Chip marking on the opened board, 2026-10-23; OpenWrt kernel log (`Maxlinear Ethernet GPY211C`, firmware 8.111), 2026-10-24 |

The old unit's board (2026-10-23 photos): **MT2500-V1.1**, dated 2022/11/1, chips from weeks 46–47 of 2022. RAM is one Nanya NT5AD512M16C4-JR, **DDR4** 8 Gbit = 1 GB, which matches the kit's DDR4 BL2. The eMMC is a Samsung KLM8G1GETF-B041, 8 GB eMMC 5.1. The SoC is hidden under a thermal pad.

- [ ] Baseline speed test on the working unit with stock firmware (iperf3, WAN↔LAN;
      needs a gigabit peer, so not the Pi 3).
- [ ] ~~Plan A on the broken unit~~: skipped. The UART log showed that the old
      U-Boot can't open the eMMC at all, so its recovery page can't write.

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
| 2026-10-23 | Opened the old unit. Its UART is **J13**: four open through-holes next to the RJ45 port, labelled 3.3V (square pad), RX, TX, GND, so no soldering needed (angled header, male jumpers or a pogo clip). Its external Ethernet PHY carries the MaxLinear logo, so it's very likely the original `glinet_gl-mt2500` variant. |
| 2026-10-23 | Power switching for the router: the IKEA DIRIGERA hub (back online after a dead wall socket) and a second INSPELNING plug named `MT2500A`, switched from the Pi through the hub's undocumented local API. Added `pi/dirigera-token.py` and `pi/plug.sh`; tokens stay on the Pi, out of the public repo. |
| 2026-10-23 | Old unit's chips read from photos: WAN PHY MaxLinear GPY211C0VC (`glinet_gl-mt2500` confirmed), RAM Nanya DDR4 1 GB (matches the kit's DDR4 BL2), eMMC Samsung KLM8G1GETF 8 GB. Board MT2500-V1.1, 2022/11/1. |
| 2026-10-24 | `pi-setup.sh` done; first UART contact. The old U-Boot (Sep 12 2022) fails the eMMC with `unable to select a mode : -110` / `mmc_init: -524`, matching Irakli's log line for line. Ethernet link 1000 Mb/s on the LAN port. Raw log kept on the Pi. |
| 2026-10-24 | Plan B works: GL.iNet's 2025-02-24 U-Boot loaded over UART into RAM reads the eMMC (Samsung 8 GB, eMMC 5.1, 52 MHz 8-bit) and its intact partition table. Nothing written yet. Fixed a port-release race in `uartboot.sh`. |
| 2026-10-24 | Complete eMMC backup: OpenWrt 25.12.6 initramfs booted over TFTP (packaged `tftpd-hpa`, eth0 only, TFTP root kept empty), boot0, boot1 and the 7.3 GiB user area copied over SSH, all SHA256-verified against the router. MAC and serial live in boot1; `rf` is empty. Backup kept on the Pi, outside the repo. |
| 2026-10-24 | The old MT2500A boots by itself again: 2025-02-24 U-Boot written to `fip` with `dd` from the initramfs (verified), boots GL.iNet 4.7.4 from the eMMC. That firmware was an untouched official 4.7.4; only its settings (from 26 May 2025) were wiped. Factory reset in failsafe needs `mount_root` first. First-time setup done over the JSON-RPC API. |
