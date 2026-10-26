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
  `initialized`, keeps its timezone, and the new password works for the
  API login, the serial console (`root@GL-MT2500`) and SSH (password
  authentication on 192.168.8.1; a wrong password is refused).

---

## Chapter 11: Inside GL.iNet's firmware (2026-10-24/25)

*Run numbers are GitHub's (`#N` on the Actions page of the workflow).*

With the old unit running again, we turned to the question behind the whole
project: what does GL.iNet's firmware do with the hardware that upstream
OpenWrt doesn't? Four pieces of work, all read-only.

**Recreating 4.2.0 from public sources** (workflow `gl-recreate-4.2.0.yml`).
GL.iNet's firmware is OpenWrt 21.02 plus patches, and the build recipe
survives in a fork, so we tried to rebuild 4.2.0 and compare.

- Run #2 gave the identical OpenWrt version string; 142 of 143 shared
  packages had the same version, 1029 of 1169 shared files were identical.
- Run #3 mirrored the official package set: 360 of 466 packages built. Only 7
  public packages were missing; the rest are GL.iNet's closed or private
  ones. The official kernel carries its configuration (`IKCONFIG`), so we
  extracted it and found GL.iNet built with `ALL_KMODS`.
- Run #4 switched on `DEVEL`, ccache and `ALL_KMODS` (95 minutes). `ALL_KMODS`
  barely changed anything: the generated config already held hundreds of
  explicit "not set" lines for kernel modules, and Kconfig defaults never
  override explicit values. Fixed for run #5, which is still to come.

**Driver analysis, phases A and B.** The running 4.7.4 gave a baseline
(registers, debugfs, eMMC clock); the source comparison covered the WAN PHY,
the SGMII path, hardware NAT and the eMMC. The result, including what
upstream lacks (hardware QoS, tunnel offload) and why the eMMC runs at 26
MHz, is in [driver-analysis.md](driver-analysis.md).

**Sixteen firmware versions side by side.** A script unpacked every
version we have (the 15 published ones, 4.1.1 to 4.9.0_beta3, plus 4.7.13) and compared kernel, config, device
tree and modules. The hardware layer barely moves; 4.6.2 is the big step (the
Airoha PHY, a new reset scheme). One version, 4.5.16, looks wild but only
because its kernel was built with far fewer modules.

**The replacement unit.** Its WAN PHY is an Airoha EN8811H. On GL.iNet's
firmware it answers at MDIO address 5, while upstream's device tree says 13.
That looked like an upstream bug, but forum users confirm that 13 works on
upstream: most likely GL.iNet's driver moves the PHY to 5 (our inference,
see [driver-analysis.md](driver-analysis.md)). Its firmware,
4.7.13, is not published by GL.iNet; we read it from the unit and keep it
private. Details in [firmware-sources.md](firmware-sources.md).

---

## Chapter 12: Decompiling GL.iNet's closed modules (2026-10-25)

With the recreation close to GL.iNet's build, phase D of the driver analysis
started early: what do GL.iNet's closed kernel modules actually do?

**A compiler that matches.** Run #5 of the recreation, with every kernel
module package built (`ALL_KMODS` finally effective), produced kernel
modules **byte-identical** to every one in GL.iNet's official 4.2.0. So our
toolchain and kernel configuration are GL.iNet's. The 17 kernel options
still different come from feeds GL.iNet didn't have; run #6 drops them and
publishes the OpenWrt SDK as a release, so other workflows can build
modules exactly like GL.iNet did. Builds got faster with ccache (95 to 76
minutes).

**A private workbench.** GL.iNet's binaries and anything derived from them
stay out of this public repo, in a private repository with two workflows:
Ghidra turns each module into rough C, and a build-and-compare workflow
compiles our C with the SDK and reports per function whether it matches
byte for byte. Every iteration is its own commit. Subagents write the C;
the method is the "matching decompilation" one (as on decomp.wtf, which
used other tools for console games and has since stopped).

**What the modules turned out to be.** Before any matching, reading the
binaries already answered the main question
([driver-analysis.md](driver-analysis.md), "GL.iNet's closed modules"):

- Only `mtkhnat` (hardware NAT and QDMA QoS) touches hardware, and its 4.2.0
  version is MediaTek's public source plus GL.iNet's public patches; up to
  4.7.4 only 4 of its 76 functions change.
- `mtfwd` and `mtqos`, the two closed MediaTek modules, are Wi-Fi features
  (EasyMesh forwarding, 802.11 QoS management): SDK leftovers on a router
  without Wi-Fi. That corrects our earlier guess that `mtqos` drives the
  hardware queues.
- GL.iNet's own modules (`kmwan`, `gl-mpflow`, `black_white_list`, `tertf`,
  `parental_control`, `hw-info`) are app logic without hardware access.

So the only unpublished hardware knowledge could be in those 4 `mtkhnat`
functions. It isn't: their assembly diff showed one change, a removed
warning message, and once the published SDK's toolchain compiled the
public source the way OpenWrt does (with OpenWrt's `-fno-caller-saves`,
and stripped like `strip-kmod.sh`), all 76 functions came out
byte-identical to GL.iNet's 4.7.4, and the unmodified source to 4.2.0.
**GL.iNet's hardware NAT is MediaTek's public code.**

On the way, run #6 made the kernel configuration fully identical (0 of 2090
options differ) and run #7 published the Ethernet driver sources next to the
SDK. The matching loop itself was tried on `mtfwd` (7 of 28 functions in 12
rounds) and then parked: it is a Wi-Fi leftover.

**The kernel image as well.** That left the kernel image, with the built-in
drivers. Our run #7 image had exactly GL.iNet's size and differed in 8551 of
10.5 million bytes, all for one reason: the kernel banner said
`root@<container>` instead of `glinet@glinet`, 4 characters longer, which
moved all later read-only data by 16 bytes and with it every instruction
pointing there. Run #8 used GL.iNet's build user, host and time (from the
official banner): 40 bytes left, the two GNU build IDs, which hash build
paths in parts of the kernel that are never loaded. The device tree is
identical too. **GL.iNet's 4.2.0 hardware layer (kernel, built-in drivers,
modules, device tree) is reproduced byte for byte from public sources.**

## Chapter 13: Towards a complete 4.2.0 recipe (2026-10-25, in progress)

With the hardware layer reproduced, the goal widened: rebuild all of 4.2.0
as closely as possible. Run #8 left 479 files that differ. A classifier
(now part of the workflow's report) sorted them by cause:

| Group | Files | Cause | Status |
|---|---|---|---|
| opkg package records | 169 | `SourceDateEpoch` = commit date of the applied patches (ours: build day) | run #9: patches applied with GL.iNet's commit date |
| Samba | 171 | GL.iNet's build path compiled in (`/home/glinet/work/_github/mt7981`, ours `/work/gl-infra-builder/mt7981`) | run #9: built in GL.iNet's path |
| ELF build ID only | 95 | build ID hashes the build path | run #9 (path) |
| Python bytecode | 22 | build path | run #9 (path) |
| `/etc/glversion`, `version.type`, `version.date` | 3 | written by `gen_config.py` from a non-public `gl_metadata.yaml` and the clock | run #10 |
| GL.iNet-adjusted scripts | ~16 | overwritten by GL.iNet's closed packages (`gl-sdk4-base-files`, `-ddns`, `-modem`) or modified in their private feeds | only with GL.iNet's packages |

Two more findings:

- `kmod-gl-sdk4-tertf` and `kmod-gl-sdk4-hw-info` are not closed: their
  recipes are public in `gl-feeds` at the recipe's commit, so run #10 builds
  them from source.
- The kernel package's version hash (vermagic, `86cd...` at GL.iNet, ours
  `1198...`) is cosmetic but appears in every kernel module's record. OpenWrt
  hashes `.config.set`, the kernel configuration *before* `oldconfig`, so
  options that never reach the kernel count too. Run #10 keeps that file.

**GL.iNet's closed packages.** A complete image needs GL.iNet's 100 closed
packages. Measured: 463 web interface files, 206 scripts and configuration
files and 18 Lua files (readable as they are), 5 kernel modules (phase D),
AdGuardHome (34 MB; it is AdGuard's own v0.107.8 release binary, same Go
build ID, stripped differently) and 46 programs and libraries of GL.iNet's
own (about 3 MB of compiled code). A generator turns each closed package into
an OpenWrt recipe with its original files and GL.iNet's package record
(version, dependencies, `SourceDateEpoch`), and a full-build workflow uses
them. Both live in the private repository: the result contains GL.iNet's
files and is never built in this public repo. Decompiling the 46 programs
fully is not realistic; behaviour notes, and matching only where it matters.

**Run #9 (GL.iNet's build path and patch commit date): 479 → 404 files.** The
commit date fixed `SourceDateEpoch` for all packages. The rest turned out to
have other causes, found by comparing package records and configure flags:

- 101 kernel module records differ only in the kernel's vermagic hash.
- GL.iNet built **without ccache**: programs that record their compiler,
  such as nginx (`--with-cc=aarch64-openwrt-linux-musl-gcc`), differ when
  ccache is on.
- GL.iNet's **package build options** differ from OpenWrt's defaults: Samba
  with AD DC support (that explains Samba's code differences and its extra
  dependencies), nginx with Lua and ubus but 22 modules off, no naxsi or
  headers-more.
- Our own workflow had a bug: its "deselect what the official image lacks"
  step also switched off build options such as `dnsmasq_full_ipset`, as if
  they were packages.

All four are fixed on the branch for run #10 (which waits for the owner's go),
together with GL.iNet's version files, the LuCI languages en and zh-cn, and
building `kmod-gl-sdk4-tertf` and `-hw-info` from their public source.

**What GL.iNet's 46 compiled programs are** (behaviour notes in the private
repository, read from imports and strings): management logic for the web
interface, VPN, NAS, cloud and modems, none of it in the data path. The one
hardware-related piece is `libgl-utils`, which reads the device's identity
and capabilities from `/proc/gl-hw-info`, provided by the public
`gl-sdk4-hw-info` module. Several are open-source projects, which a recipe
can build from source instead of copying:

| GL.iNet's file | Project, version | Source |
|---|---|---|
| AdGuardHome | AdGuardHome v0.107.8 | AdGuard's release binary, unchanged except OpenWrt's `sstrip` (verified: code and data identical) |
| `sipcalc` | sipcalc 1.1.6 | release; **rebuilt identical** (some `config.h` features off, GL.iNet's link order) |
| `mkfs.exfat`, `fsck.exfat`, `libexfat.so` | relan/exfat 1.2.7 | release; **rebuilt identical** (`libexfat` as a shared library, lazy binding) |
| `fcgiwrap` | gnosek/fcgiwrap, git 99c942c9 | closest build has the same size but different code: GL.iNet's version calls `prctl` and `fwrite`, so it carries a GL.iNet patch |
| `gl_modem` | GL.iNet's `gl-modem-at` | the public repo (2023) builds a 12 KB program; GL.iNet's is 98 KB with more libraries: an internal, larger version |
| `webdav_ser`, `gl_nas_sys` | lighttpd 1.4.48/1.4.49 plus GL.iNet's own modules | partly public |
| `qcm`, `QFirehose` | Quectel QConnectManager V1.6.3.1, QFirehose V1.4 | exact versions not found in public mirrors (V1.6.2/V1.6.4, V1.2.4/V1.4.9 exist) |

Recipes for these live in an `oss` feed in the private repository, built
with the SDK and compared byte for byte (one commit per attempt).

**Smaller builds instead of full runs.** A full recreation takes an hour or
more, so package questions are now checked in isolation: an "SDK package
test" workflow (private repository, because it compares with the official
image) builds just the named packages with GL.iNet's toolchain and given
build options and compares every file. Lessons from the first tests: build
by source package (`dnsmasq-full` comes from `dnsmasq`); OpenWrt's base
packages need the `base` feed, and GL.iNet patches some of them (`dnsmasq`,
`netifd`, `base-files`, ...), so run #10 also publishes the patched
`package/` folder; and the SDK must run at GL.iNet's build path too, or
same-size libraries differ in their build IDs (`libsasl2`). Already
identical from the SDK: 55 packages built along the way, among them
OpenSSL, PCRE, Lua, ncurses, libubox, json-c, ca-certificates, `attr`,
`libexpat`, `libffi`, `liblzma`. GL.iNet's nginx is its own recipe in the
public `gl-feeds` (`gl_feed_common`), which takes priority over OpenWrt's. ccache is now a run option: on while iterating, off
for the final validation run.

More pieces settled by isolated tests and comparisons:

- **nginx** comes out identical with GL.iNet's own recipe (public
  `gl_feed_common`), its build options and GL.iNet's build path.
- **libxml2** is identical in the full build (an earlier SDK difference was
  only the build path).
- **Python bytecode:** OpenWrt compiles `.pyc` files with
  `PYTHONHASHSEED=$SOURCE_DATE_EPOCH`, and frozenset constants are written in
  hash order, so the seed shows up in the bytes. Ours (1678760204) gives a
  different order than GL.iNet's. A seed search with a standard Python 3.9.13
  didn't even reproduce our own `.pyc` (marshal also depends on the
  interpreter build), so it has to run with OpenWrt's own host Python inside
  the build environment. Parked as a later optimization (about 24 files,
  0.8 MB).
- **GL.iNet's web interface** is generated, not source: a webpack build of a
  Vue.js application (`app.<hash>.js`, minified, 40 per-feature views), with
  no source maps. Its original sources are not public, so it can only be
  copied, like GL.iNet's own compiled programs.

**Side question: why Linux 5.4.211 in every release?** All 16 versions
(2022–2026) run the same kernel on OpenWrt 21.02. Not a hardware limit:
upstream OpenWrt supports the MT2500 since November 2023 (first stable in
24.10, kernel 6.6), and MediaTek's own feed has had a kernel 6.6 branch
(`24.10`, `files-6.6`) since at least November 2024, yet its README still
calls 21.02 "the current in-use branch". GL.iNet's whole firmware line is
built on that MediaTek SDK, whose proprietary Wi-Fi driver (`mt_wifi`, not
in the public feed) GL.iNet's firmware uses; GL.iNet's way out for the
MT3000 and MT6000 is separate "op24" firmware on plain OpenWrt 24.10, none
for the MT2500 (as far as found). The MT2500 has no Wi-Fi, so the likely
reason is one shared firmware base for all models (our inference). To be
explored further after the release-by-release comparison.

**Run #10 and what followed.** Run #10 (all fixes so far) brought the public
part to 86.9 % of files identical (70.2 % of all files including GL.iNet's
closed ones). Samba's records now match (AD DC); seven missing VFS modules
showed that GL.iNet also enabled the extended VFS set (VFSX), which changes
how `smbd` and the libraries are linked. `kmod-gl-sdk4-tertf` and
`-hw-info`, built from their public recipes, came out identical. The 86
files that differ only in their build ID turned out to be ccache: OpenWrt's
ccache mode had reused objects compiled at the old build path, and
`libsasl2` and `getdns` are identical when built without it. ccache is now
wrapped around the compiler under its own name, with a cache filled only at
GL.iNet's path; OpenWrt's ccache mode also wrote `ccache_cc` into programs
such as nginx.

**The kernel's vermagic hash** is md5 over the `=y`/`=m` lines of
`.config.set`; our computation reproduces our own hash exactly. Since the
final kernel configurations are identical, GL.iNet's must differ in options
that never reach the kernel. Removing up to three of our 239 such lines
gives no match (2.3 million tries), nor do OpenWrt's `KERNEL_*` switches so
far; the likely source is kernel options requested by GL.iNet's private
kernel module recipes, which are unknown. If so, it stays a known cosmetic
difference (the kernel's version text and the modules' `Depends` line).

**Lessons about the workflows.** Long tests must log progress live and
always save their logs: a Samba test that ran into its 2-hour limit and a
first private full build that probably fell into OpenWrt's single-threaded
retry left nothing to analyse. The recreation now writes a log per package,
a summary of failed packages, and package-level progress to the live log.
And anything that only builds open source belongs in the public repository,
where GitHub Actions minutes are free; the private repository (2,000
minutes a month per account) is only for what contains GL.iNet's files.

**Built as a normal user.** GL.iNet's `libdevmapper.so` is the only
read-only program file in the official image (installed `0555` by lvm2) and
the only one left unstripped, with debug info. OpenWrt's strip step doesn't
make files writable first: as a normal user it fails on that file, as root
(our container) it succeeds. So GL.iNet built as a normal user, which fits
their `/home/glinet` build path; the recreation now installs its tools as
root and then builds as user `glinet`.

**Run #11 (VFSX, invisible ccache): 89.7 % of the public part identical**
(72.6 % of all files). The ccache wrapper works: files differing only in
their build ID went from 82 to none (four more carried that label by
mistake, see run #12). What remains is mostly Samba, and Samba
turns out not to be reproducible by nature: its build system (waf) collects
libraries in Python sets, whose order depends on Python's random hash seed,
which waf doesn't fix. 243 of the 252 differing Samba files differ only in
the order of their `NEEDED` libraries, and GL.iNet's own releases show the
same: between consecutive versions with the same Samba (4.14.12), 45 to 65
Samba libraries come out different every time. Comparing GL.iNet's own
4.2.0 and 4.7.4 (both Samba 4.14.12-1) settles it: their library order
differs in 140 of 213 libraries. Of our 252 differing Samba files, about 130
differ only in the order of the library list, 71 have exactly the same
functions with the same sizes (only addresses and order differ), and 9 link
`libdcerpc-binding` instead of `libndr-samba4` or the other way round, most
likely the same effect (waf drops libraries already pulled in through
another one, and which stays depends on the order). The content is
reproduced; the order is random in GL.iNet's builds too, so GL.iNet 4.2.0's
exact order can't be recovered (its seed came from `/dev/urandom`). Our
build now fixes `PYTHONHASHSEED` so our own runs are repeatable.

**Run #12 (built as a normal user): `libdevmapper` identical.** GL.iNet
built as a normal user, so `libdevmapper` (installed read-only, 0555) stayed
unstripped; built as root, strip could write it anyway. As a normal user it
now comes out identical, and the build step took 89 minutes instead of 109.
The total went from 419 to 498 differing files, all of it Samba reshuffling
its library order again (#12 still ran without the fixed hash seed); outside
Samba the count went from 165 to 161. What is left outside Samba: 15
start-up and network scripts that GL.iNet overwrites (they come from the
private recipe), package records carrying the vermagic hash, Python
bytecode, and four programs.

Those four (`busybox`, `wg`, `ip-full`, `openvpn`) had been labelled
"build ID only" since run #8, and blamed on ccache. Both were wrong: the
binaries are sstripped, so the comparison found no section table and an
empty list of differing sections passed as "build ID only" (fixed in
`classify-diffs.py`), and an SDK build without ccache differs the same way.
Our runs #11 and #12 produce them byte-identical, so our build is
repeatable; the differences from GL.iNet's are real:

- `busybox`: GL.iNet's has five more applets (`addgroup`, `adduser`,
  `chpasswd`, `delgroup`, `deluser`), exactly the seven options in GL.iNet's
  own profiles `glinet_nas.yml` and `glinet_depends.yml`, though not in the
  public MT2500 profile. Added to the recreation; SDK test #3 builds it
  byte-identical.
- `openvpn`: its configure records the build host's `ifconfig`; GL.iNet's
  binary says `/usr/sbin/ifconfig` (net-tools installed), ours plain
  `ifconfig`. net-tools added to the build container; SDK test #3 builds
  it byte-identical.
- `wg`: embeds `git describe` of the OpenWrt tree: GL.iNet's
  `21.02.3-135-gb77ee244f5`, ours `…-g20ebd753f9-dirty`. That hash is the
  tree's top commit after the builder applies GL.iNet's patches with
  `git am`, so it depends on their committer name, e-mail and timestamps,
  which aren't public. (`DISTRIB_REVISION` matches because OpenWrt prints
  the upstream base commit there, not the top.) Accepted.
- `ip-full`: same code and strings; only the order of the dynamic symbol
  names (`*_link_util`, looked up at run time) differs, which shifts string
  addresses. GL.iNet's own builds keep it identical from 4.2.0 to 4.2.3, so
  something in their build environment fixes that order. Not found yet. The cache helped less than it could: the
toolchain is rebuilt every run, so ccache saw a "new" compiler each time;
it now compares the compiler by content.

**Run #13 (BusyBox options, net-tools, iproute2 order): `busybox`,
`openvpn` and `ip-full` identical.** 402 files differ (#12: 498), 155
outside Samba (#12: 161). What remains outside Samba: the scripts GL.iNet
overwrites (private recipe), `wg` (accepted), package records with the
vermagic hash, and about 25 Python bytecode files. Those turned out not to
be a seed question: OpenWrt compiles bytecode with
`PYTHONHASHSEED=$(SOURCE_DATE_EPOCH)` (GL.iNet's value, exported by
`include/toplevel.mk`), yet 600 of 626 files are always identical and 26
vary between our own runs #11 to #13, sometimes matching GL.iNet's by
chance. GL.iNet's own builds do the same: between 4.4.5 and 4.4.6, whose
`python3` packages are identical, 23 `.pyc` files differ. So, like Samba's
library order, this varies by nature (set order and marshal's reference
flags, which depend on the compiling process's state; Python tracks this as
bpo-37596). #13 also published the ImageBuilder and the generated files for
the private assembly.

**The complete image, assembled (assembly runs #1 to #9).** A full build
including GL.iNet's closed packages takes over four hours on the private
repo's 2-core runners (private full #2 ran 3½ hours and then stopped on a
recipe error the assembly had already found). Much quicker: the public
recreation publishes its SDK and ImageBuilder (all public packages
included); the closed packages are packaged with that SDK (each package
Makefile called directly, so their 84 public dependencies aren't compiled)
and the image is put together with the ImageBuilder, in about ten minutes.
Assembly run #3 produced the first complete image (466 packages, like the
official one), and each run since showed what was still off:

- GL.iNet's start-up and network scripts (`rc.local`, `sysupgrade`,
  `20-firewall`, `10-mount`, …), until then put down to "GL.iNet overwrites
  them", are installed by `gl-sdk4-base-files`, `-init-portal` and `-modem`
  under `/rootfs-overlay/`; GL.iNet's (public) `lib/functions.sh` copies
  that over the root and deletes it after installing. The recipe looked for
  them at `/rootfs-overlay/...` in the image and found nothing.
- `gl-sdk4-ddns`'s install script moved six files over `ddns-scripts`'
  paths during GL.iNet's image build (OpenWrt deletes every install script
  afterwards, so it isn't in the image): reconstructed.
- GL.iNet's kernel modules changed because OpenWrt stripped them again; the
  closed recipes now leave GL.iNet's files untouched. Two packages have a
  custom `prerm`; kernel modules' `Version`/`Section`; `Source:` paths.
- `Installed-Size` is not the installed size: OpenWrt's `ipkg-build` writes
  the size of the package's compressed `data.tar.gz`. GL.iNet's original
  `kmod-mtfwd.ipk` is still on their package feed; rebuilt from our recipe
  its `data.tar.gz` is byte-identical once the owner names `root/root` are
  stored. The SDK's portable `tar` can't look up names (fixed with
  `TAR=/bin/tar`), and the container's umask made folders 775.
- `/etc/opkg/keys/`: `base-files` installs the build key's public half;
  GL.iNet's (`06a6bf2ad909388f`) is in the image and now used.
  `distfeeds.conf` lists GL.iNet's own feeds; `/init` comes from the kernel
  build, which the ImageBuilder skips.

**First public assemblies (#1 to #3).** On the free runner, with the
closed part generated in the run, the complete image has 466 packages and
6,071 files like the official one, with no file missing or extra; 404
files differ, all in the accepted classes (Samba, 22 `.pyc`, `wg`, package
records carrying the vermagic hash) plus `/usr/lib/opkg/status`. GL.iNet's
web-interface packages also contain an empty `www/views/img/` (empty in the
image too, owned by no package); with it, 31 of 41 get GL.iNet's exact
`Installed-Size`. 27 records still differ in it: 8 because their contents
differ (Samba, Python, `wireguard-tools`), `base-files` by 15 bytes, and 14
closed packages by 3 to 73 bytes. `status` depends on the install order: a
full build installs by sorted source directory (feeds first, then
`kernel/linux`, then base packages), and anything an earlier package pulls
in is marked `Auto-Installed`; the ImageBuilder installs `libc` and `kernel`
first.

**Complete full builds on the public runner (#15, #16).** With the closed
part generated in the run, the full build (`closed` mode) gives the same
result as the assembly. #15 had two extra packages and one missing:
GL.iNet's `gl-ui4.0/module/adguardhome` clashes with the packages feed's
`adguardhome` (OpenWrt names a source package after its folder, and only
the first gets installed), `SAMBA4_SERVER_WSDD2` defaults to `y` (no
`wsdd2` in the official image), and `LUCI_LANG_en` is only needed without
the closed packages (with them, a closed package pulls in
`luci-i18n-base-en`; the language option adds English translations of
every LuCI app). #16: 466 packages and 6,071 files like the official
image, no file missing or extra, 403 differing files, and
`/usr/lib/opkg/status` identical apart from the accepted fields (vermagic
hash, `python3`'s `Depends` order), including the entry order and all 169
`Auto-Installed` flags.

**`Auto-Installed`, worked out.** opkg marks a package `Auto-Installed`
when an earlier package pulls it in as a dependency before its own turn.
A small simulation of that rule predicts exactly the ImageBuilder's
result (277 flagged), and shows what reproduces the official 169: name
the 297 unflagged packages, each after everything it reaches through its
dependencies, then all others except the six held toolchain packages
(`libc`, `libgcc1`, …), which a full build flags `hold` afterwards
(`opkg flag hold`, replacing `user`). The assembly does that now; only
the entry order of `status` (opkg's hash table, within a bucket the
loading order) still differs there, while the full build gets it right by
itself.

**`Installed-Size`, nearly all explained.** All 40 web-interface packages
match once they carry `www/views/img/`, `www/i18n/` and
`usr/share/oui/menu.d/`, empty where unused (GL.iNet's build creates them
always), and `gl-sdk4-ddns` matches with an empty `etc/ddns/`. Left:
`gl-sdk4-plugins` and `gl-oui-rpc` (several unrelated empty folders fit
the size equally, so size alone can't tell), `gl-sdk4-clients`,
`gl-sdk4-base-files` and `base-files`.

**Validation run without ccache (2026-10-26, on the M5+).** GL.iNet built
without ccache, so this is the formal check: the complete build (`closed`
mode, same workflow steps run locally on a 16-thread mini PC, 81 minutes
instead of about two hours on GitHub). Result: 466 packages and 6,071
files like the official image, nothing missing or extra, 391 differing
files. Outside the accepted classes (Samba's library order, Python
bytecode, the vermagic hash in the kernel package and in 106 kernel-module
records, `wg`'s tree hash) no file differs. `/usr/lib/opkg/status` matches
apart from the kernel's version (vermagic); this time even `python3`'s
`Depends` order matches. `Installed-Size` differs in 15 records: 11 whose
contents differ in the accepted ways (Samba, Python, `wireguard-tools`),
and 4 closed packages still unexplained (`gl-oui-rpc`,
`gl-sdk4-base-files`, `gl-sdk4-clients`, `gl-sdk4-plugins`).

**Repeatable.** A second validation run, built independently from the same
recipe, gives a root file system identical to the first in all 6,078
entries (files, symlinks, modes) and the same kernel; only the sysupgrade
signature block at the end of the image differs (each run signs with a
fresh private build key; GL.iNet's signature can't be reproduced anyway).
Since the hash seed is fixed (`PYTHONHASHSEED=0`), even Samba's library
order and the Python bytecode come out the same every time. With that,
4.2.0 counts as validated: built without ccache like GL.iNet's, repeatable,
and outside the accepted classes no file differs.

**The last four `Installed-Size` values (2026-10-26).** `Installed-Size`
is the size of the package's compressed `data.tar.gz`, so a missing empty
folder or another file mode changes it by a few bytes, while the file
list in the image stays the same. Each hypothesis was checked against the
same package in other releases: it only counts if it gives GL.iNet's exact
size in every release where the package exists (the size computed with the
same GNU tar and gzip options as `ipkg-build`).

| Package | Cause | Checked in |
|---|---|---|
| `gl-sdk4-plugins` | empty `etc/rc.d/` in the package | 3 releases |
| `gl-sdk4-clients` | empty `usr/libexec/rpcd/` | 7 releases |
| `gl-oui-rpc` | empty `etc/oui/` and `etc/oui-httpd/` | 5 of 6 releases |
| `gl-sdk4-base-files` | modes of 7 overlay files that overwrite other packages' files (`cp` keeps the existing file's mode, so the package holds GL.iNet's source modes, not the image's) | 6 releases; exactly 1 of the 128 mode combinations fits all of them |

`gen-closed-feed.py` now creates those folders and sets those modes. Run 9
on the M5+ (closed mode) confirms it: of the `Installed-Size` values only
the 11 accepted ones still differ (Python, Samba, `wireguard-tools`, whose
contents differ in the accepted ways); `status` is identical apart from the
kernel's vermagic.

**"Same code", proven instead of inferred (2026-10-26).** For Samba and the
Python bytecode, "content identical" rested on indirect evidence (same
library set, equal section sizes, same source hash; GL.iNet's own builds
varying the same way). Both are now checked directly, on the official 4.2.0
root and ours:

- **Python bytecode.** In Python 3.9 (the version OpenWrt 21.02 compiles
  with), each differing `.pyc` is loaded with `marshal` and its code
  objects compared recursively: bytecode, constants (sets as sets), names,
  variables, line tables, file names. All 22 differing files: identical
  code objects, identical headers. So the bytes differ only in how
  `marshal` wrote the same objects. Negative controls: two different
  modules, and one module with a single character changed in a nested
  string constant; both are reported as different, at the right spot.
- **Programs and libraries.** All 246 differing ELF files were compared
  with the cross binutils (`aarch64-linux-gnu-objdump`). 174 have
  byte-identical machine code (`.text`), and every other section is
  identical too, except the ones that follow the library list (`.dynamic`,
  `.dynstr`, symbol order); all are Samba. `wg` has no section table (its
  `git describe` hash, see above). The other 71, all Samba, have functions
  and strings in another order: waf's random order applies to the object
  files inside a library, not only to its list of libraries. Those were
  compared function by function, by name: every address an instruction
  uses is turned into what it points to (function or object + offset,
  the text of an unnamed string, the symbol of a GOT or PLT entry), with
  register values followed through the function's branches (value sets at
  merge points, spilled registers on the stack, calls that never return,
  only 64-bit registers carrying addresses), and every named data object
  compared byte for byte with pointers compared by target.

  Result: **35,453 of 35,455 functions and all 12,507 data objects
  identical**, nothing present on one side only. The last 2 functions
  (`cli_session_request_sent`, `nb_connect_connected` in
  `liblibsmb-samba4.so`) call the same `writev_recv`/`writev_send`, but
  bound to another library: two Samba libraries export that function
  (`libsmbconf`, `libsmb-transport`), and the linker takes the first in
  the random library order. Negative controls on `smbpasswd`: one changed
  instruction, one changed character in a string, one changed byte in a
  data object; each is reported, in the right function or object.

  The comparison tool is our own construction (no standard tool does
  this). It found gaps in itself along the way: every remaining
  difference was traced by hand to its cause before the tool was fixed,
  and the negative controls were rerun after each fix. One rule in it is
  a deduction rather than an observation: an immediate added to a
  register that may hold an `adrp` page is treated as that page's
  `:lo12:` offset.

So the accepted Samba and `.pyc` differences are now proven to be order
only: the same machine code, data and bytecode as GL.iNet's.

**The vermagic hash, searched harder.** With 16 threads, a small C program
(OpenSSL MD5, prefix cache) tries billions of `.config.set` variants:
adding up to 4 of the 243 options that are `=y`/`=m` in GL.iNet's final
configuration but missing from our `.config.set` (140 million), dropping
up to 4 of our 255 lines that don't reach the final configuration (130
million), and mixed changes up to 3 (20 million): no match. The likeliest
remaining explanation stays the same: `KCONFIG` lines from GL.iNet's
private kernel-module recipes, possibly for options that don't exist in
this kernel at all (those can't be enumerated).

**Version-by-version comparison, redone (2026-10-26, M5+).** With a new
class `random` in `version-diff.py` (`.pyc` files with the same source hash
but a different body; ELF files with the same `NEEDED` libraries in a
different order and equally sized sections), all 15 releases compared
again. "Changed" files per step, before → now (random):

| Step | changed | | Step | changed |
|---|---|---|---|---|
| 4.1.1 → 4.2.0 | 558 → 534 (24) | | 4.5.0 → 4.5.16 | 261 → 248 (13) |
| 4.2.0 → 4.2.1 | 200 → 166 (34) | | 4.5.16 → 4.6.2 | 495 → 484 (11) |
| 4.2.1 → 4.2.3 | 214 → 167 (47) | | 4.6.2 → 4.6.4 | 136 → 127 (9) |
| 4.2.3 → 4.4.5 | 346 → 305 (41) | | 4.6.4 → 4.6.8 | 95 → 81 (14) |
| 4.4.5 → 4.4.6 | 193 → 149 (44) | | 4.6.8 → 4.7.0 | 457 (0) |
| 4.4.6 → 4.5.0 | 500 → 488 (12) | | 4.7.0 → 4.7.4 | 473 → 458 (15) |
| | | | 4.7.4 → 4.8.2 | 1056 (0) |
| | | | 4.8.2 → 4.9.0 | 685 (0) |

In the 4.2/4.4 range 15 to 25 % of the "changes" are random build
variation; from 4.5.0 on (Python gone: 1,958 files) the effect is small.

**Towards 4.2.1: which builder tag.** Every release was built about an
hour after a builder tag was committed (build time from the firmware file
name, tag commit from the spmadden fork):

| Firmware | Built (UTC) | Builder tag | Tag commit (UTC) |
|---|---|---|---|
| 4.2.0 | 2023-03-14 03:04 | `v4.2.0_mt2500_release4` | 02:01 |
| 4.2.1 | 2023-04-14 12:36 | `v4.2.1_release4` | 11:26 |
| 4.2.3 | 2023-07-06 06:07 | `v4.2.3_release5` | 05:01 |

From 4.2.1 on the tags are generic (no `_mt2500_`), so the MT2500
profiles must be in the generic tag; the fork's tags end at 4.4.1, so
releases after that need another source. What else changes per release:
the official image (URL and SHA256 from GL.iNet's API), the build time
(`SOURCE_DATE_EPOCH` from the kernel banner, `version.date`), the version
in `gl_metadata.yaml`, and the feed commits pinned by the tag.

**Moved to the public runners.** The closed part doesn't need to be stored
anywhere: like the comparison, the run downloads the official image from
GL.iNet and generates the closed packages from it
(`.github/scripts/gen-closed-feed.py`, `openwrt/gl-4.2.0-closed/` with the
three source-built recipes and the image-file paths). The recreation's
`closed` mode builds the complete image, `gl-assemble-4.2.0.yml` assembles
it; both publish only reports, never the image. The private repo keeps the
decompilation.

**A version-by-version comparison** of all 15 published releases (workflow
`gl-versions.yml`) classifies every file per step as new, gone, identical,
metadata-only or really changed, and checks kernel code (build date, build
IDs and initramfs timestamps masked), kernel configuration and device tree.
Kernel code stays the same from 4.2.1 to 4.4.6; it changes with the same
configuration in 4.2.0 → 4.2.1, 4.6.2 → 4.6.4, 4.6.4 → 4.6.8 and
4.6.8 → 4.7.0, so GL.iNet changed kernel source there. That is where the
release-by-release steps will look first.

**What "validated" means for 4.2.0.** The base counts as validated, and the
release-by-release comparison can start, when a run without ccache shows:

1. every public file byte-identical, or its difference explained and
   recorded below;
2. the private full build reproducing GL.iNet's closed packages and image
   files, so the complete image matches;
3. the remaining differences documented as known and accepted.

Known, accepted differences so far (cosmetic or not reproducible from
public sources):

| Difference | Why |
|---|---|
| kernel vermagic hash (kernel version text, kernel modules' `Depends`) | most likely kernel options from GL.iNet's private kernel module recipes; not searchable |
| two GNU build IDs in the kernel image | hash over build details of never-loaded parts |
| order of `python3`'s `Depends` (fixed since), `Installed-Size` of the 11 packages whose contents differ in the accepted ways | GNU make 4.2 doesn't sort file lists; the size follows the contents |
| Python bytecode: about 25 of 626 `.pyc` files (set order, marshal reference flags) | not a seed question: OpenWrt already compiles with `PYTHONHASHSEED=$(SOURCE_DATE_EPOCH)`, yet they vary between our own runs, and between GL.iNet's 4.4.5 and 4.4.6 (identical `python3` packages) 23 differ too |
| GL.iNet's web interface and own programs | generated or closed; taken from the official image in the private recipe |
| `fcgiwrap`, `gl_modem` | GL.iNet's patch / internal version, not public |
| Samba: library and object order in about 250 files (machine code and data proven identical function by function, 2026-10-26) | waf orders libraries via Python sets with a random hash seed; GL.iNet's own 4.2.0 and 4.7.4 builds of the same Samba differ in 140 of 213 libraries |
| `wg` version string (`git describe` hash) | hash of GL.iNet's tree after their `git am`, depends on their committer identity and timestamps |

**Where 4.2.0 stands** (5,451 regular files, 219 MB unpacked, after run #9):
61.6 % of the files and 43 % of the bytes are byte-identical from public
sources, plus the whole kernel layer. Run #10 targets most of the rest
(Samba alone is about 700 files and 66 MB). GL.iNet's closed packages (about
1,100 files, 40.6 MB) come from the private recipe: as originals, except
AdGuardHome, `sipcalc` and the exFAT tools, which are built from source.

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
- [x] Driver analysis phases A and B ([driver-analysis.md](driver-analysis.md)).
- [x] Compare 16 GL.iNet versions (15 published plus 4.7.13).
- [ ] Before upstream on the replacement: boot the Airoha profile's initramfs and check that the EN8811H answers at 13 (GL.iNet's firmware shows 5; upstream's 13 works for forum users).
- [x] Recreation run #5: all kernel modules identical to GL.iNet's 4.2.0.
- [x] Recreation runs #6 and #7: kernel configuration fully identical, SDK and driver sources published.
- [ ] Phase C: the same measurements on upstream OpenWrt, with a fast peer (the GMKtec, next week).
- [x] Phase D, triage: what each closed module does (Chapter 12).
- [x] Phase D: `mtkhnat` 4.7.4 rebuilt byte-identical from public source (one warning removed).
- [x] Kernel image compared (run #8): identical apart from the GNU build IDs; no extra GL.iNet kernel patches.
- [ ] Find out why about 300 libraries and programs still differ in the recreation (Samba, Python, busybox and others).
- [ ] Later optimization: Python bytecode (find GL.iNet's `PYTHONHASHSEED` with OpenWrt's own host Python inside the build).
- [ ] After the release-by-release comparison (4.2.0 → 4.9): why GL.iNet stayed on Linux 5.4 / OpenWrt 21.02 (MediaTek SDK, shared firmware base, op24 builds).
- [x] Find the WAN PHY variant of **each** unit separately: the two units
      have **different** chips (table below).

| Unit | WAN PHY | How determined |
|---|---|---|
| Replacement (working) | **Airoha EN8811H** (PHY ID `03a2:a411`) → `glinet_gl-mt2500-airoha` | Read-only over SSH on GL.iNet 4.7.13 (board name `glinet,mt2500-emmc`), 2026-10-24: Clause 22/45 ID registers, and the kernel log `Airoha EN8811H mdio-bus:05`, which loads the PHY firmware `EthMD32.dm.bin` / `EthMD32.DSP.bin` |
| Old unit (stuck at U-Boot) | **MaxLinear GPY211C0VC** (marking MxL SLNW8) → `glinet_gl-mt2500` | Chip marking on the opened board, 2026-10-23; OpenWrt kernel log (`Maxlinear Ethernet GPY211C`, firmware 8.111), 2026-10-24 |

Note: on GL.iNet's firmware the replacement's EN8811H answers on MDIO
address **5** (address 13 reads 0), while upstream OpenWrt's device tree for
this variant (`mt7981b-glinet-gl-mt2500-v2.dts`) puts it at address **13**.
Read with `mii_mgr -g -p <addr> -r 2|3` and
`mii_mgr_cl45 -g -p <addr> -d 0x1 -r 0x2|0x3` for addresses 5 and 13.
What we know so far:

- Both the vendor driver (MediaTek feed, `air_en8811h_main.c`/`_api.c` in
  [gl-inet/mtk-openwrt-feeds](https://github.com/gl-inet/mtk-openwrt-feeds/tree/master/21.02/files/target/linux/mediatek/files-5.4/drivers/net/phy))
  and the mainline driver (`air_en8811h.c`, `EN8811H_PBUS_ADDR_OFFS 8`)
  use the PHY's own address plus a second MDIO address, **address + 8**, for
  the chip's internal bus. Neither changes the address.
- The kernel log line `PHY(0xd) = 3a2 - a411` doesn't match the public vendor
  driver (it prints `PHY = %x - %x`), so GL.iNet 4.7.13 runs another version.
  0xd = 13 = 5 + 8 fits the internal-bus address, or it is the address where
  the driver found the chip (both our inference; see the update below).
- Upstream added `reg = <13>` in commit
  [8d30e07180](https://github.com/openwrt/openwrt/commit/8d30e07180367cdeb4affd79adead6e1025355c9)
  (2025-05-14), without saying why. The two PHYs share a reset GPIO (pin 14)
  in the common `.dtsi`.
- The address is set by strapping pins on the board; we found no datasheet
  with the default.

Update (2026-10-25): upstream's 13 is right. Users on GL.iNet's forum got
WAN working on upstream builds with `reg = <0xd>`, and the official 24.10.3
works. GL.iNet's firmware most likely moves the PHY to 5 itself (our
inference); details in [driver-analysis.md](driver-analysis.md).

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
| 2026-10-24 | Replacement unit's WAN PHY identified (read-only over SSH, GL.iNet 4.7.13): **Airoha EN8811H** → `glinet_gl-mt2500-airoha`. The two units have different WAN PHYs. On GL.iNet's firmware it sits at MDIO address 5; upstream's device tree says 13 (open question). |
| 2026-10-24 | Driver analysis phases A (read-only baseline on GL.iNet 4.7.4) and B (vendor against mainline source: WAN PHY, SGMII, hardware NAT, eMMC) done; results in `docs/driver-analysis.md`. |
| 2026-10-24 | Recreating GL.iNet 4.2.0 from public sources, runs #2 to #4: identical version string, 360 of 466 packages in run #3; run #4 showed that explicit "not set" kernel module lines defeat `ALL_KMODS`. Run #5 pending. |
| 2026-10-25 | Compared 16 GL.iNet firmware versions (the 15 published ones, 4.1.1 to 4.9.0_beta3, plus 4.7.13): the hardware layer changes mainly in 4.6.2 (Airoha PHY, reset scheme), 4.7.0 (eMMC 26 MHz) and 4.7.4 (eMMC drive strength). |
| 2026-10-25 | Obtained GL.iNet 4.7.13 (not published) by reading the replacement unit; kept private, summary in `docs/firmware-sources.md`. |
| 2026-10-25 | Recreation run #5: every kernel module byte-identical to GL.iNet's 4.2.0; 17 kernel options left, all from feeds GL.iNet didn't have. |
| 2026-10-25 | Phase D started: private decompilation repo with Ghidra and build-and-compare workflows. Only `mtkhnat` touches hardware (public source plus 4 changed functions); `mtfwd` and `mtqos` are Wi-Fi features. |
| 2026-10-25 | Recreation run #6: kernel configuration identical to GL.iNet's (0 of 2090 options differ), SDK published; build time 57 minutes. |
| 2026-10-25 | Phase D result: GL.iNet's 4.7.4 `mtkhnat` rebuilt byte-identical (76/76 functions) from MediaTek's public source minus one warning; GL.iNet's firmware holds no unpublished hardware code. |
| 2026-10-25 | Recreation run #8 (GL.iNet's build user, host and time): kernel image byte-identical to GL.iNet's 4.2.0 apart from the two GNU build IDs; device tree identical. The whole 4.2.0 hardware layer is reproduced from public sources. |
| 2026-10-25 | Recreation run #10: public part 86.9 % of files identical; Samba records match (AD DC), VFSX found missing; build-ID differences traced to ccache (`libsasl2`, `getdns` identical without it). Workflow: invisible ccache, per-package logs, live progress; SDK package test moved to the public repo. |
| 2026-10-25 | GL.iNet built as a normal user (the read-only `libdevmapper` stays unstripped); recreation builds as `glinet` from now on. Validation criteria for the 4.2.0 base written down; `kmod-gl-sdk4-tertf`/`-hw-info` confirmed identical from public source. |
| 2026-10-25 | Recreation run #11: public part 89.7 % identical; ccache wrapper works (build-ID-only differences 82 → 0); Samba shown to be non-reproducible (random library order, also between GL.iNet's own releases). Version-by-version comparison of all 15 releases done. |
| 2026-10-25 | Recreation run #12: built as a normal user, `libdevmapper` now identical; outside Samba 161 differing files left. The four "build-ID-only" programs were mislabelled: real differences, found as BusyBox options, net-tools, `git describe` hash (accepted) and `ip-full` symbol order (open). |
| 2026-10-25 | Recreation run #13: `busybox`, `openvpn`, `ip-full` identical (BusyBox options from GL.iNet's profiles, net-tools, iproute2 directory order); Python bytecode shown to vary by nature, also in GL.iNet's own releases. SDK + ImageBuilder published for the private assembly. |
| 2026-10-25 | Complete 4.2.0 image assembled from the published SDK and ImageBuilder plus the closed packages (assembly runs #1 to #9): rootfs-overlay scripts, the ddns move, unstripped modules, Installed-Size (= size of data.tar.gz; owner names and folder modes), GL.iNet's build key. Complete builds moved to the public runners (closed part generated in the run, reports only). |
| 2026-10-25 | Complete full build on the public runner (#16): 466 packages, 6,071 files, `status` identical apart from accepted fields (order and Auto-Installed included). Fixes: adguardhome folder clash, no wsdd2, LUCI_LANG_en only public-only; empty folders in web-interface packages (Installed-Size). |
| 2026-10-26 | Validation run without ccache (M5+, 81 min): 466 packages, 6,071 files, status identical apart from the kernel's vermagic; outside the accepted classes no file differs; 4 closed packages' Installed-Size open. vermagic brute force (adds/drops up to 4, mixed up to 3): no match. |
| 2026-10-26 | Second validation run: root file system identical in all 6,078 entries, kernel identical; only the image signature differs (fresh build key). 4.2.0 validated. |
| 2026-10-26 | Last four `Installed-Size` values solved (empty folders in three closed packages, GL.iNet's modes for 7 base-files overlay files), each checked across releases; run 9 confirms: only the 11 accepted ones remain. |
| 2026-10-26 | "Same code" proven: all 22 differing `.pyc` files have identical code objects; of the 246 differing ELF files, 174 have identical machine code and Samba's other 71 match function by function (35,453 of 35,455 functions, all 12,507 data objects; the last 2 bind a duplicated symbol to another library). |
