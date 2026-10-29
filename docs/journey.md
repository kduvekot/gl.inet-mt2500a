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
| `qcm`, `QFirehose` | Quectel QConnectManager V1.6.3.1, QFirehose V1.4 | exact versions not found in public mirrors (V1.6.2/V1.6.4, V1.2.4/V1.4.9 exist; 2026-10-28 search: QConnectManager V1.6.7 in Quectel's own `quectel-open-source` org, V1.6.4/V1.6.8 in mirrors and ImmortalWrt's `quectel-cm`; QFirehose V1.4.9/V1.4.15/V1.4.17 in mirrors; still no V1.4.7, V1.4.13 or V1.6.3.1) |
| `tailscale`, `tailscaled` (4.5.16 only, in `gl-sdk4-tailscale`) | Tailscale 1.58.2 | Tailscale's official static arm64 release after OpenWrt's `sstrip -z`: **identical** (2026-10-28); the other releases use the public `tailscale` package |

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
| ~~two GNU build IDs in the kernel image~~ | only with ccache: without it the kernel is byte-identical (2026-10-26, chapter 14) |
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

## Chapter 14: Release by release, 4.2.1 (2026-10-26)

**One recipe, a row per release.** Everything that differs between releases
is a row of `openwrt/gl-releases.tsv`; the recreation's input `release`
selects it (default 4.2.0). The first step writes the row to
`work/release.env`, which the later steps and the build container read:
builder tag, official image, build time, patch commit date, `version.date`,
release type, the AdGuardHome release, and two values about GL.iNet's build
environment (below). Built again with the new mechanism, 4.2.0 gives a root
file system and kernel identical to the previous run.

**4.2.1, four rounds on the M5+.** The first complete build already matched
in package set, file list, install order and `Auto-Installed`. What
remained, and what it was:

- **AdGuardHome**: GL.iNet's 4.2.1 file is AdGuard's official v0.107.26
  release binary after OpenWrt's `sstrip -z`, byte for byte (4.2.0 was
  v0.107.8 the same way). Upstream names the tarball the same for every
  version, so the local download name now carries the version.
- **`uboot-envtools`' `SourceDateEpoch`** one second before the other 115
  packages from the OpenWrt tree: GL.iNet's `git am` crossed a second
  boundary. `uboot-envtools` was last touched by patch 2, every other one by
  patch 9 or later, so the first 2 patch commits get the earlier date
  (`early_patches`; any boundary from 2 to 8 gives the same image).
- **`curl` and `libc` depending on `libcurl4`/`libgcc1`** instead of
  `libcurl`/`libgcc`: OpenWrt's `GetABISuffix` (`include/feeds.mk`) uses a
  sibling's ABI name once its `BuildPackage` has been read, and otherwise
  the sibling's `staging_dir/pkginfo/<name>.version`. `curl` and `libc` are
  defined before their sibling, so a clean build writes the plain name; the
  ABI name appears only if the sibling was built before. Across all 15
  releases: plain in 4.1.1–4.2.0 and 4.5.0–4.8.2, ABI names in 4.2.1–4.4.6
  and 4.9.0, so GL.iNet's build trees in those periods held earlier builds.
  Reproduced by building those packages once and cleaning them (clean keeps
  `pkginfo`) before the main build (`rebuilt_packages`).

Run 14 (4.2.1): 466 packages, every file present, `status` identical apart
from the kernel's vermagic, and of the package records only the vermagic
hash and the 10 accepted `Installed-Size` values differ. The same checks as
for 4.2.0 hold: all 22 differing `.pyc` files have identical code objects;
of 274 differing ELF files 210 have identical machine code and Samba's
other 62 match function by function (the 4 functions that differ bind a
symbol exported by two Samba libraries to the other one); `wg` carries
GL.iNet's tree hash. GL.iNet's vermagic hash is the same in 4.2.0 and 4.2.1,
and so is ours.

**4.2.3, two more release values.** Values from the official image: build
time 1688620184 (kernel banner, two seconds after the patch commit date
this time), patch commit date 1688620182, `release5`, AdGuardHome v0.107.26,
builder tag `v4.2.3_release5`. Two new effects:

- **`kmod-gl-sdk4-tertf` left the public feed.** gl-feeds at 4.2.3's
  revision (`4fd97cf`, "remove parental-control and tertf") no longer has it,
  so the module wasn't selectable and `gl-sdk4-clients`, which depends on
  it, couldn't be installed. The release value `private_now` lists packages
  of `built-from-public.txt` that a release's public feeds no longer have;
  those come from the image like the other closed packages. (To find this,
  the build now keeps opkg's error lines when `package/install` fails: that
  step writes no log.)
- **The second boundary at the end.** `dnsmasq` and `odhcpd` (last touched
  by patches 18 and 19 of 42) have `SourceDateEpoch` 1688620183, every other
  OpenWrt-tree package (patch 16 or earlier) 1688620182: the mirror image of
  4.2.1. Release value `late_patches` (the last 25 patch commits one second
  later; a boundary at 17 or 18 gives the same image).

Run 20 (4.2.3): every file present, `status` identical apart from the
kernel's vermagic, and of the package records only the vermagic hash and
the accepted `Installed-Size` values differ, as for 4.2.0 and 4.2.1. The deeper checks on run 21 (without ccache) hold as well: all 23 differing
`.pyc` files have identical code objects; of 266 differing ELF files 190
have identical machine code and Samba's other 75 match function by function,
apart from 115 functions that call a symbol two Samba libraries export and
bind it to the other one (114 in the `dcerpc` Python binding), and one
instruction the comparison tool labels differently (`mov x3, x5` on both
sides).

**The kernel is byte-identical without ccache.** The validation run
without ccache (run 16, 43 minutes) gives a root file system identical to
run 14's, but a kernel image of exactly GL.iNet's size. Decoded property by
property, its FIT image differs from GL.iNet's only in the root file
system's size and hashes, which the image records; the kernel itself and
the device tree are byte-identical. The same holds for 4.2.0 (the
validation run without ccache); with ccache the kernel data differs. So the
"two GNU build IDs" accepted since run #8 were a ccache effect, not a
difference from GL.iNet's build.

## Chapter 15: 4.4.x from a release branch, 4.5.0 without a public builder (2026-10-26/27)

The work moved to the M5+: builds run from a job queue there, values are
collected by one script over all releases, and each finished job is
summarised in one screen (`~/brief.sh`), so the Pi only reads verdicts.

**4.4.5 and 4.4.6 came from a release branch, not from `main`.** With the
builder at `main` (`36bdcbf`, the last commit before 4.4.5's build time)
five kernel modules still differed. Their strings tell why: GL.iNet's
`nf_nat`/`iptable_nat` have no `ip_nat_route_input` (kmwan, `6f64f8b`,
26 July 2023), its `qmi_wwan` still has the Quectel RawIP `tx_fixup` that
the modem rework (`bd1944e`, 13 July) replaced, and its `wireguard.ko` has
no `is_retry_count_wg` (REKEY fix, `bcc27ad`, 14 July). So 4.4.5 has
profiles and feeds of early August but the MT798x patch folder as it was
before 13 July (`1fab67d`, 25 June). The patch count agrees: `bd1944e`
removes one patch and kmwan adds one, so both give r15812+879. With that
patch set, the four packages one second early in the image (uboot-envtools,
gpio-button-hotplug, fstools, block-mount) are exactly those whose last
patch is among the first ten: `early_patches` 10. busybox's `usleep`
applet is in no public MT2500 profile (only the S200's), so it is an extra
option from GL.iNet's private profile (release value `extra_config`).
4.4.6 (October) has the same patch set plus the wireguard fix: GL.iNet
picked `bcc27ad` onto the release branch (`patches_rev` takes single patch
files from another commit), while the modem rework and kmwan stayed out.

Job 28 (4.4.5): all kernel modules, busybox, the kernel configuration,
every `SourceDateEpoch` and the file count (6,142) match. Besides the
accepted classes (chapter 13: `.pyc`, `python3`'s `Depends` order, vermagic)
two files differ, both directory-order effects already fixed for 4.2.x
(chapter 13, run #13): `ip-full` (`990-static-syms-glinet-order.patch`) and
`sipcalc` (link order in the closed-package recipe). In 4.4.x GL.iNet's
order is a different one, so the 4.2.x fixes don't fit: GL.iNet built 4.4.x
on another machine or filesystem. Read from the images (the `*_link_util`
strings in `ip-full`), 4.4.5, 4.4.6 and 4.5.0 share one order and 4.7.4's
is sorted; this reproduces 4.2.0's known order except three names the
linker merged into longer strings (`vlan_link_util` inside
`macvlan_link_util`, etc.). `.github/scripts/link-order.py` now reads the order in
every run from the official `ip-full` (the code that loads each name's
address, so merged names are found too; it reproduces the 4.2.0 list of
chapter 13 exactly), and the iproute2 patch uses it. For `sipcalc` it reads
the order of `sub-output` and `sub-func` from their strings (swapped in
4.4.x); `interface.c` has too few strings, so `interface` and `sub` keep the
4.2.x order until a build confirms it.

**4.5.0 and later: same builder, no longer public.** GL.iNet removed
`gl-infra-builder` in August 2023 ("For some reasons, we are not
publicizing this tool anymore", forum threads 32754, 32828, 53881); no
later copy exists on GitHub, Software Heritage or the Wayback Machine. But
they kept using it: every release up to 4.9.0 is OpenWrt r15812
(`46b6ee7ffc`) with kernel 5.4.211, only GL.iNet's patch count grows (879
in 4.4.x, 885 in 4.5.0, 899–901 in 4.6.x, 912 in 4.7.4), and 4.5.0's
`/etc/sdk.version` (`429ad772`) is the `mt7981` feed revision of the
fork's last profile. The public `gl-feeds` repository continues, with
branches per release. `analysis/release-values.py` reads every release's
recipe values from the images in one run and pins the `gl-feeds`
revisions: a feed package's `SourceDateEpoch` is the commit time of the
last commit to its folder, so the pinned revision is the one where all of
them match (4.5.0: `gl_feed_common` `7941d11`, 19 of 19, unique). New
release value `feed_revs`. The fork's last state gives r15812+881, so four
of 4.5.0's patch commits are not public; the first builds show where they
act. (`kmod-gl-sdk4-fan`, new in gl_feed_common in 2024, needs headers of
GL.iNet's closed `gl-sdk4-utils` and is in no MT2500 image: left out.)

**4.5.0, job 33.** The first complete builds (jobs 29 and 31) showed that
most of 4.5.0's differences are configuration, not code: GL.iNet's Samba
lost AD DC and the extended VFS modules (so the image has no Python; 36
packages and 1,573 files fewer), `kmod-dm` and `kmod-dax` are gone (with
`DAX=m` the kernel can only build device mapper as a module, so the target
config's built-in `DM_INIT`/`DM_VERITY` came back once both were left out),
and libcurl lost HTTP/2. Three of the four missing patch commits were
found: GL.iNet published two of them for its newer BE-series routers in
`gl-inet/gl-image` (`opkg` "fix injection vulnerability", `lua5.3`
"archindependent bytecode"), and the third is the `mtkhnat` warning removal
of chapter 12, recreated on MediaTek's public source. New release value
`extra_commits` (`openwrt/gl-extra-commits/`, README with sources). Job 33:
419 packages and 4,321 files as in the image, `status` order and
`Auto-Installed` identical, kernel configuration identical, `opkg`,
`liblua5.3`, `mtkhnat` and `ext4` identical, r15812+884. Left: the 885th
commit (no trace in the image), `shortcut-fe.ko`'s module info
(`depends=gl-sdk4-tertf`: GL.iNet built it with the tertf module present),
`sipcalc` (order fix queued), and build IDs/data sections of `libelf` and
the Go programs.

**The revision count reaches the binaries.** Without ccache (job 36) `libelf`'s
build ID and the Go programs still differed, so not the ccache class of
chapter 14: OpenWrt's toolchain carries the revision in its version string
("OpenWrt GCC 8.4.0 r15812+885-46b6ee7ffc"), which every binary's
`.comment` holds and build IDs cover. GL.iNet's one unidentified patch
commit therefore matters; an empty, labelled placeholder commit
(`openwrt/gl-extra-commits/unidentified-commit`, our construction)
reproduces the count, not GL.iNet's change. **4.5.16** turned off
`ALL_KMODS` (923 kernel options GL.iNet no longer builds) and has LuCI's
English translations again.

**`sipcalc`'s order, a make pitfall.** Reading the order inside the
package recipe failed twice: OpenWrt expands package targets with
`$(eval)` when it reads the recipe, so a `$(shell)` there runs before the
sources are unpacked. `link-order.py marks` needs no sources: it orders
the objects by the position of one known string from each in GL.iNet's
`sipcalc` (4.2.x `sub-output` first, 4.4.5 to 4.7.4 `sub-func` first).

**Feeds fetched by branch, and feeds outside gl-feeds.** Some releases'
feed packages all carry one commit's time: GL.iNet fetched those feeds by
branch, which OpenWrt's feeds script clones with depth 1, so `git log` on
any package folder returns the head (4.6.2's `shortcut-fe` has the time of
gl_feed_21_02's `02702ea`, a commit that doesn't touch it). Writing the
pinned head into the feed's `.git/shallow` reproduces that offline (tested:
1716438772 as in the image, 1691135655 from a full clone); release value
suffix `~shallow`. `release-values.py` now pins every feed of 4.5.0 to
4.8.2: gl-feeds (by branch for 4.6.x/4.7.0), `mptcp-feeds` (4.7.0 on),
4.8.2's OpenVPN feed (`gl-inet/vpn-extra-feeds`) and MediaTek's feed
(unchanged since 2022 except in 4.7.0: November 2024). `wifidog-ng` is a
submodule of gl-feeds with its own dates. GL.iNet's private MediaTek feed
is called `mt798x` from 4.6.2 on, and `ddns-scripts` is gone there (our
reconstructed `gl-sdk4-ddns` install script now only moves files the
release's package lists). Only 4.5.16 was built without all kernel modules;
4.6.2 to 4.7.4 again with them (about 910 options as modules), 4.8.2/4.9.0
without LuCI English.

**`shortcut-fe` and tertf's exports.** `shortcut-fe` (from 4.5.0) uses
tertf's exported `term_update`, so GL.iNet's module has
`depends=gl-sdk4-tertf`; ours takes tertf from the image. Placing a
`.symvers` in `$(PKG_SYMVERS_DIR)` didn't help: OpenWrt's
`collect_module_symvers` hook runs after every kernel package's compile and
rewrites that file from `$(PKG_BUILD_DIR)/Module.symvers` (empty for a
prebuilt module). The closed recipe now writes the exports there, with the
module path in the build directory, and the hook carries them over.

**4.8.2 was built with `SDK=1`, not without git** (corrected; first
taken for a tree without git). Its revision is empty everywhere
(`DISTRIB_REVISION=''`, `base-files` version `1446-`, the toolchain's
version string "OpenWrt GCC 8.4.0 " in every binary), the same in 4.9.0,
and `/etc/version.build` (845; 4.9.0: 1048) is GL.iNet's CI build number.
But its packages still carry git dates: of 222 OpenWrt-tree packages 114
have the build second, 16 are from February 2021, 13 from July 2021 and so
on, exactly as in 4.7.4, and 12 are one second early, the familiar
early-patch group (fstools: `fstools`, `block-mount`; iwinfo: `iwinfo`,
`libiwinfo20210430`, `libiwinfo-lua`, `libiwinfo-data`; uci: `uci`,
`libuci20130104`, `libuci-lua`; `netifd`; `opkg`;
`kmod-gpio-button-hotplug`), the same six source packages in 4.7.4 and
4.9.0. So the tree had git. `getver.sh` (unchanged and executable in
GL.iNet's published trees, no `version` file) always prints something in
a git tree; the empty revision comes from `include/toplevel.mk`: with
`SDK=1` it doesn't run `getver.sh` but includes `include/version.mk`, where
`REVISION` and the global `SOURCE_DATE_EPOCH` are commented out ("Substituted
by SDK"). GL.iNet's CI evidently builds with `SDK=1` set from 4.8.2 on.
In a full tree `SDK=1` also ignores the `linux` package when scanning
package information, downloads only for `package/`, runs `prereq` and
`conf --defconfig` before every target and drops `package/compile`'s
dependency on the host opkg; the first build will show whether any of that
matters. The release value is now `sdk_mode` (instead of the earlier
`no_git`, which removed `.git` and would have given the git-dated packages
the build time): the build exports `SDK=1` and this release's
`SOURCE_DATE_EPOCH`, which then sets the kernel's build time. AdGuardHome
is built from source from 4.8.2 on (`adguardhome-conntrack` in
gl_feed_common).

**4.6.2's kernel commits, and the sibling models.** Compared with 4.5.0
(both with all kernel modules), 4.6.2's kernel config changes in only ten
options: the Airoha EN8811H PHY, MPTCP and zstd. The EN8811H driver
(GL.iNet's module reports v1.2.5) is MediaTek's: v1.2.5 was in MediaTek's
feed from 1 April 2024, with the PHY firmware byte-identical; extra commit
`airoha-en8811h` fetches it (SHA256-checked; MediaTek's Makefile hunk needed
our 2022 SDK tree's context). MPTCP is GL.iNet's backport of upstream MPTCP
to 5.4, published in their BE10000 GPL tree (25 files, one kernel patch,
`kmod-mptcp`); written for 5.4.281, three hunks needed 5.4.211's context
(`mptcp-backport`). GL.iNet's 4.8.6 tree also had 4.6.2's `ppp.sh` (PPPoE
retry delay; byte-identical with ppp 2.4.8's plugin name) and candidate
opkg/uci patches. GL.iNet's firmware for its other MT798x routers, built
with the same builder, shows: the MT3000 (Beryl AX) is the MT2500's twin
(same patch count and kernel features every release; 4.2.3 to 4.4.6 even
built in the same second, so both models came from one build run); the
X3000/XE3000 stayed on the 4.4 release branch until late 2024 (+879, +880,
+882); the MT6000 (MT7986) had EN8811H by April 2024 but MPTCP only from
4.6.2, and zstd is built in only on MT7981 models.

**4.6.2: 10 of 18 missing commits.** GL.iNet's 4.6.2 is r15812+899; the
fork's last state gives 881. Recreated: the three of 4.5.0, Airoha, MPTCP,
ppp, opkg (remove once), uci (lua iteration), `UBIFS_FS_ZSTD=y` in the
MT7981 target config (the only zstd option that changes by itself; it
selects the others, which is why they are built in despite
`kmod-lib-zstd`), and the device tree (decompiled: only the WAN PHY's reset
moves to the MDIO bus and its compatible becomes generic C45, as
driver-analysis.md describes; our edit keeps GL.iNet's property order).
Found but not public: GL.iNet's newer MediaTek iwinfo support (HE rate
table, HT mode, country) and an RM500U 5G modem entry in `usbnet.ko`
(`rm500u_5gnet`); neither is in gl-feeds, the fork, gl-image or MediaTek's
feed. The rest most likely touches only other boards built from the same
tree (MT3000, X3000, MT6000) and shows only in the revision count.

**`shortcut-fe` solved, and the bpftools race.** Job 57 (4.5.0): tertf's
exports reach `shortcut-fe` through OpenWrt's own symvers hook, `depends=`
matches. The same job hit the bpftools race again; the new retry saved it
but changed the result: its second `make` reads the recipes with more
packages built, so `curl` and `libc` got ABI names in `Depends` (the
mechanism of `rebuilt_packages`). The race itself is gone now: host Python
is built before the parallel build.

**Fewer wasted builds.** Most failed jobs could have been caught early or
were races. `DRY_RUN=1` (local `dry=true`) stops after the configuration
(builder, patches, extra commits, feeds, closed feed, defconfig) and fails
if official packages can't be selected; a package that fails is built once
more single-threaded before the build gives up; the end of the build log is
kept with every result. A second job worker uses the M5+'s idle cores, and
each worker keeps its last tree for single-package rebuilds.

**4.5.0 and 4.5.16 recreated.** The final jobs (61, 62; with the
placeholder commit, `sipcalc` order, tertf exports and host Python first)
leave only the accepted classes: Samba (library order, so also the
`Installed-Size` of its three packages), `wg`/`wireguard-tools` (tree hash),
and the vermagic hash in the kernel and kmod entries. Packages (419 and 423),
files (4321 and 4353), `Auto-Installed` and the `status` order are as
official, kernel config identical, revision r15812+885 in both.

**4.7.0's iproute2 comes from the MPTCP feed.** From 4.7.0 on, the
official configuration has `CONFIG_OVERRIDE_PKGS="iproute2"`: GL.iNet's
builder installs every profile feed with `feeds install -a -f`, so
`gl-inet/mptcp-feeds`' iproute2 6.3.0 replaces OpenWrt's 5.11 (`ip-full`
6.3.0-1 in 4.7.0, 5.11.0-3 in 4.6.8). Our recipe got that right, but our
static-syms order patch only reached OpenWrt's copy. It now goes to every
iproute2 under `package/` and `feeds/`; generating `static-syms.h` from
6.3.0 with the build container's make 4.2.1 gives official 4.7.4's order
(47 of 47 names) with the patch and a different one without. Also from the
official images: 4.6.4 → 4.6.8 changes no kernel code (only the revision
string and build date). 4.6.2 → 4.6.4 first looked like a code change
without a visible string, configuration or device-tree change; the
function-by-function comparison below shows it isn't one.

**Kernels function by function.** `vmlinux-to-elf` (in its own Python
environment on the M5+) rebuilds a symbol table from a kernel's built-in
kallsyms; `analysis/kernel-functions.py` then compares two kernels per function, by
size and by machine code with PC-relative address fields masked. 4.6.2,
4.6.4 and 4.6.8: all 30,806 functions identical; only the data behind two
section-end markers differs (the embedded initramfs's timestamps and the
version string). The earlier "code change" was that data. 4.6.8 → 4.7.0
shows real changes (cross-check that the method sees them): new USB hub
functions (`disable_show`/`disable_store`, a sysfs switch to disable a hub
port, plus `usb_hub_port_status`, `usb_port_is_power_on`), changed
`mptcp_recvmsg`, `mtk_pcie_probe` and USB link power management. Checked
against our 4.7.0 build (job 65b's `vmlinux`): MPTCP already matches (our
backport is GL.iNet's newer one); the USB changes are GL.iNet's published
`hack-5.4/963-usb-hub-port-add-sysfs-entry-to-switch-port-power.patch`
(4.8.6 tree), now an extra commit for 4.7.0+; `mtk_pcie_probe` is still
open (GL.iNet's 4.8.6 PCIe driver is a much newer one for another chip).
And the 4.6.x kernels have a `power_ctl` sysfs switch in the USB port code
(`power_ctl_store`) that's in no public source and that the 963 patch
replaced in 4.7.0: one of 4.6.2's placeholders is now labelled for it. Our
brief compares kernel configuration and modules but not the kernel's own
code, which is how this went unnoticed.

**4.6.2 and 4.7.0 complete builds (jobs 64b, 65b).** Both have every
package and file of the official image (4.6.2: 427 / 4358, 4.7.0: 463 /
5302). 4.6.2's kernel configuration is identical; what differs is the
revision (+891 instead of +899), `iwinfo` and `usbnet.ko` (not public),
`opkg` (ours 480 bytes smaller: the remove-once candidate isn't all of it),
`air_en8811h.ko` (code and package description) and a few sizes (ppp,
gl-sdk4-tethering, tor). The 8 missing commits are now placeholders: two
labelled ones for iwinfo and usbnet, six unidentified (owner's decision;
they reproduce only the count and can be removed from the row at any
time). 4.7.0 showed three recipe gaps, all fixed: the ppp, opkg and uci
commits were missing from the 4.6.4–4.7.4 draft rows (identical in all
official images from 4.6.2 to 4.7.4); 19 IPsec kernel options were off
because the mirror step switched "extra" packages off entirely, while
GL.iNet's configuration has them (`kmod-ipsec`, `kmod-crypto-echainiv`, ...)
as `=m`, built but not installed, so such packages now go to `=m`; and from
4.7.0 on GL.iNet's `/etc/init.d/system` lacks upstream's `rm -f /tmp/TZ`
(OpenWrt 3d62b5d5c6), byte-identical to the file in GL.iNet's published 4.8.6
tree (extra commit `base-files-tz-revert`). Also new in 4.7.0:
`libstdc++.so.6.0.25-gdb.py` holds GL.iNet's build path
(`/work2/jenkins/workspace/router_mt2500/mt7981/...`). `wireguard.ko` is
64 bytes larger than 4.6.8's with every function the same size: one more
entry in the peer netlink policy, exactly what GL.iNet's published
`hack-5.4/952-wireguard-support-punch.patch` (4.8.6 tree) does by adding
`WGPEER_A_PUNCH`; extra commit `wireguard-punch-attribute`. And GL.iNet changed build machines at 4.7.0: up to 4.6.8 the official
images hold `/home/glinet/work/_github/mt7981` (201 files in 4.6.8, our path
since run #9), from 4.7.0 to 4.9.0 none do, and 211 files (nginx, Samba,
Python, build IDs, the gdb helper) hold `/work2/jenkins/workspace/
router_mt2500/mt7981` instead: a Jenkins job named `router_mt2500`. New
release value `build_dir` (the builder checkout's path); the host-tools
cache key now includes the path.

**Two more GL.iNet changes that aren't public (4.6.2+).** `air_en8811h.ko`
reports MediaTek's v1.2.5, like ours, but GL.iNet changed it: two messages
(`air_buckpbus_reg_write fail.`, `PHY(0x%x) = %x - %x` instead of
`PHY = %x - %x`), a flag set in one function (disassembly; every function
has the same size), and its own package description ("Supports the Airoha
EN8811H PHY."). None of it is in MediaTek's feed history (v1.1.3 to
v1.2.7), gl-feeds, the fork, mptcp-feeds, vpn-extra-feeds or gl-image.
`opkg` (from 4.6.2 to 4.9.0) has an option that calculates the size a
package and its dependencies need (`opkg_recurse_okgs_size`,
`uninstall_pkg_total_size`), also in no public source; GL.iNet's published
4.8.6 opkg patches don't have it. Our `opkg` is exactly 4.5.16's size, so
the remove-once candidate leaves the binary unchanged and stays unconfirmed.

**4.6.4 and 4.7.4 complete builds (jobs 66b, 67b).** 4.6.4: all 436
packages and 4905 files, kernel configuration identical. New: GL.iNet's
`firewall` is release 1.2 from 4.6.4 on, and `fw3` differs from 4.6.2's in
exactly two instructions, the timeouts of its two `ubus_invoke` calls (2000
→ 20000 ms), in no public source (our construction `firewall-ubus-timeout`);
GL.iNet's `gl-sdk4-adguardhome` depends on `zoneinfo-*` from 4.6.4 on, which
our source-built override lacked (it now takes the official dependencies,
which also fixes Auto-Installed and the `status` order); and the lua5.3 and
uci commits are among the one-second-early ones in 4.6.4 (new suffix
`@early` for extra commits). 4.7.4: all 458 packages and 5255 files; its
kernel configuration adds ChaCha20-Poly1305 (`kmod-crypto-chacha20poly1305`,
GL.iNet's package definition from the published 4.8.6 tree) and built-in
pstore (`PSTORE_RAM`, `_CONSOLE`, `_PMSG`). `kmod-ramoops` stays `=m` there,
yet `PSTORE_RAM=y`: OpenWrt merges the module packages' options with
`kconfig.pl 'm+'`, which never turns a target config's `y` into `m`, so
three lines in the MT7981 target config give exactly GL.iNet's result. The
4.6.4–4.6.8 rows now carry 4.6.2's eight placeholders, plus the firewall
commit (r15812+900 expected for 4.6.4).

**The kernel's own code, now in every verdict.** `kernel-functions.py` now
compares only the function names both kernels have, each up to the next of
those, reading across sections (4.6.2 vs 4.6.4: 0 of 30,774 differ), and
the local runner runs it after every build against GL.iNet's kernel of
that release (`~/versions/kelf/`, all 15 releases converted with
vmlinux-to-elf); `brief.sh` shows the counts. Our 4.6.4 and 4.7.0 kernels
against GL.iNet's show the same groups beyond the ones fixed today:
IPv4 routing (`fib_create_info`, `fib_sync_down_dev`, `fib_sync_up`,
`ip_fib_check_default`, ...): our tree has GL.iNet's route-failover and
kmwan patches in older versions (`953`/`954`; GL.iNet's 4.8.6 tree has
`922`/`923` plus `924-kmwan-fix-multicast-route-dead-marking`, for kernel
5.4.281, 329 and 22 changed lines); MDIO/PHY (`of_mdiobus_register`,
`get_phy_device`, `__mdiobus_register`, `phylink_fixed_state`); MediaTek
Ethernet (`ethsys_reset`, in 4.7.0 also `mtk_mac_link_up`,
`mtk_rx_irq_disable`); MPTCP (`tcp_collapse`, `__tcp_close`,
`subflow_v4_init_req`: GL.iNet's backport in these releases isn't quite the
4.8.6 one); and `mtk_pcie_probe` in 4.7.0. These go into kernel test builds
(candidate patch versions, compared function by function) once the queue
is through. The releases already counted as recreated hold up: our 4.5.0 and
4.5.16 kernels (jobs 61, 62) match GL.iNet's in every shared function
(30,232 and 28,925), once the mask also covers sign-extending loads
(`ldrsw`; one global variable's address had looked like a code change). First result of the kernel groups: from 4.6.2 on GL.iNet's kernels have
`fib_info_devhash_bucket` as a real function (4.5.16's don't), which is
GL.iNet's published `999-5002-export-fib-info-devhash-bucket.patch`: an
exported function isn't inlined, so five routing functions change code at
the same size. Extra commit `fib-devhash-export`; in 4.6.2–4.6.8 it takes
the place of one unidentified placeholder (four left). The rest of the routing group: GL.iNet's published 922 does apply to
5.4.211 once one context line is adapted (`RT_SCOPE_HOST`, where 5.4.281
has `RT_SCOPE_LINK`; GL.iNet's change itself is untouched), and 923 applies
as is. Which version 4.6.2 used was settled by compiling only the routing
objects on a copy of the kernel source, with OpenWrt's flags
(`-fno-caller-saves`; without them even the unchanged source doesn't
reproduce our own vmlinux, so a first round of this test was void): 922/923
plus `fib-devhash-export` match every routing function of GL.iNet's 4.6.2
kernel, our 953/954 don't (`fib_sync_down_dev`). The devhash export alone
explains `fib_create_info`. Extra commit `route-failover-kmwan-update`; in
4.6.2–4.6.8 it takes another unidentified placeholder's place (three left).
924 (IPv6) isn't in 4.6.x. Job 70b (4.6.4) then showed that GL.iNet's
version is a mix: `fib_table_lookup` and `nf_nat.ko` differed with 922.
Compiling each file where 922 and 953 differ, in both versions: GL.iNet's
4.6.2-4.7.4 kernels have 953's `fib_trie.c` part (`fib_table_lookup` 976
bytes) and 953's `nf_nat_masquerade.c` part (`nf_nat_masquerade_ipv4` 420
bytes; 922 doesn't touch that file), with 922's `fib_semantics.c`;
`fib_frontend.c` and `route.c` compile the same either way (their remaining
differences, `ip_valid_fib_dump_req` and a few in `route.c`, have another
cause, still open). The extra commit now carries that combination, applied
cleanly in the right order on a copy of the kernel source. 4.8.2 has 922's
`nf_nat_masquerade` (344 bytes) but still 953's `fib_trie`. (A first attempt at this test changed an
archived tree in place and damaged its kernel source; experiments now run
on a copy, each step checked.)

**"Not public", checked again.** After the routing patches turned out to
be public after all, every remaining "not public" claim was searched again
the same way: all four of GL.iNet's published source trees (gl-image:
4.8.6 for the BE10000, 4.8.7 and 4.9.0 for the MT3600BE, 4.9.1 for the
BE14000), including the complete patched kernel sources they carry
(`offline-sources/linux-5.4.281`), MediaTek's feed history, all gl-feeds
branches and the fork, with fixed-string searches for the exact strings of
GL.iNet's binaries. All five still hold, some more precisely now:
`usbnet`'s `rm500u_5gnet` interface name (GL.iNet's modem patch 960 touches
`qmi_wwan`, `option`, `qcserial`, `usb_wwan`, not `usbnet`); the 4.6.x USB
port `power_ctl`; the EN8811H driver changes (in none of the trees' driver
copies, v1.0.5 to v1.3.3); opkg's size option (GL.iNet's other opkg
patches, database and conffile output, are already in our build since
4.4.x); and iwinfo, whose upstream version is the same in every release
(`2022-04-26-dc6847eb`): GL.iNet extended its MediaTek patch (HE rate
table, `htmode`, `@wifi-device` lookups); the MT3600BE's published htmode
patch is a different one, for `nl80211`.

**MPTCP: GL.iNet's `__tcp_close()` split.** Of the MPTCP group, `__tcp_close`
is 8 bytes larger in our kernel. Its machine code differs in exactly two
instructions: ours stores `SHUTDOWN_MASK` into `sk->sk_shutdown` at the
start, GL.iNet's has no such store anywhere in the function (nor in
`tcp_close()`), although upstream's split (77c3c95637, also in 5.4.281)
keeps that line. Without it, the single-object compile (validated against
our vmlinux) gives exactly GL.iNet's sizes for `__tcp_close` and
`tcp_close`. Our split patch now leaves the line out, as GL.iNet's does.
`tcp_collapse` is 68 bytes larger in GL.iNet's kernel: it moves the
MPTCP skb extension (`active_extensions`, `extensions`, a WARN), upstream
MPTCP's `mptcp_skb_ext_move()` call, which GL.iNet's later published compat
patch no longer has. Adding that one line gives exactly GL.iNet's size,
with no other function in `tcp_input.o` changing (patch `999-9999-3`). Our MPTCP files
(GL.iNet's 4.8.6 backport) are Linux 5.15's with GL.iNet's compat changes
(30, 149 and 27 lines differ in `subflow.c`, `protocol.c`, `protocol.h`;
every other upstream version from 5.7 to 6.1 differs far more).
`subflow_v4_init_req` in GL.iNet's 4.6.2 to 4.8.2 kernels is a stub: it
sets `is_mptcp` and calls `printk(KERN_ERR "MPTCP: mptcp need to implement
this function: %s,%s,%d", __FILE__, __func__, __LINE__)` with line 1791,
nothing else (the message is in every kernel from 4.6.2 to 4.8.2, gone in
4.9.0). Replacing the function's two calls with that line puts it exactly
on line 1791 of our file, and the compiled function is GL.iNet's
instruction for instruction (patch `999-9999-4`). `mptcp_stream_accept`
differs only in data addresses. `mptcp_recvmsg`: GL.iNet's 4.6.2 version
is larger, not smaller; it keeps two values on the stack, which a call
inside the inlined `mptcp_rcv_space_adjust()` loop forces, and our file has
exactly one call there commented out: `mptcp_event(MPTCP_EVENT_SUB_PRIORITY,
...)` after GL.iNet's `is_set_backup_for_rx()`. Active, it gives GL.iNet's
`mptcp_recvmsg` instruction for instruction (578); `mptcp_finish_join` is
identical too. Only 4.6.2-4.6.8 have it (2312 bytes; 2256 from 4.7.0 on,
like ours), so the 4.6.x rows use `mptcp-backport-4.6x`, the same commit
with that patch (`999-9999-5`). With that, every MPTCP difference is
explained; GL.iNet's 4.8.7 MPTCP files differ
from 4.8.6's only in `compat.h`, the `Makefile` and a compat patch that
also exports `fib_info_devhash_bucket`.

**4.6.2 at r15812+899 (job 68b), and musl's `pthread_getname_np`.** With
the placeholders, 4.6.2's revision is GL.iNet's, and what still differs is
almost only the not-public set (`iwinfo`, `usbnet`, `air_en8811h`, opkg's
size option), plus `libc.so`: GL.iNet's exports `pthread_getname_np`,
which musl only got in 1.2.3. GL.iNet's published 4.8.6 tree has musl
1.2.3's tarball in its downloads (checked against their `dl.sha256`); its
`pthread_getname_np.c`, compiled in a copy of our musl 1.1.24 build with
its own flags, is identical to the function in GL.iNet's libc (addresses
masked; an existing function compiled the same way is identical too).
Extra commit `musl-pthread-getname-np` (patch `910`), 4.6.2+; in 4.6.x it
takes the place of another unidentified placeholder (two left). (The first version of
that patch lacked the new file, because `diff` writes nothing for a file
whose folder is missing on the old side; job 70b built musl without the
function. The patch now creates it from `/dev/null` and was test-applied.)

**MDIO: the kernel side of the PHY reset.** GL.iNet's `__mdiobus_register`
waits after releasing the MDIO bus reset: `__udelay()` with a field after
`reset_delay_us` in `struct mii_bus`, if it is greater than 0, which is the
`reset-post-delay-us` property their 4.6.2 device tree sets (100 ms). Linux
got that in 5.9 ("net: mdiobus: add reset-post-delay-us handling"; there
with `fsleep()`, which 5.4 lacks). Our backport for 5.4 (field, reading the
property in `of_mdio.c`, the wait) gives exactly GL.iNet's sizes for
`__mdiobus_register` and `of_mdiobus_register` (single-object compiles of
`mdio_bus.o`, `of_mdio.o`, `phy_device.o`, `phylink.o`, all 170 functions
validated against our vmlinux first). It goes with the device tree in
`mt2500-dts-phy-reset`. `get_phy_device`: GL.iNet's does one more register
read in the clause-45 identification (the Airoha PHY's path); upstream
5.4.211 and 5.4.281 have the same code there, and no published patch
(GL.iNet's four trees, MediaTek's feed history) touches it, so it is not
public either, probably part of GL.iNet's Airoha support. `phylink_fixed_state`
turned out to be GL.iNet's own function in the MediaTek Ethernet driver
(the fork's patch `3003`, polling the GPY211's state register): in 4.6.2
it is 712 bytes with 16 MDIO reads and writes instead of 176 with one
read, extended for the Airoha EN8811H after the fork went private, and in
no public source. One of 4.6.x's last two unidentified placeholders now
carries that label (one left).
Two MediaTek Ethernet "differences" (`mtk_mac_link_up`,
`mtk_rx_irq_disable`) were artifacts of compiler-generated names, and the
driver's larger functions (`mtk_open`, `mtk_hw_init`, `mtk_pending_work`,
`mtk_stop`) differ only in data addresses; apart from GL.iNet's link
polling (below), only `ethsys_reset` differs: one load scheduled a few
instructions later, with the same instructions otherwise.

**4.7.0 at GL.iNet's Jenkins path (job 69b).** The first build at
`/work2/jenkins/workspace/router_mt2500` leaves no build-path differences
at all (417 differing files, 430 in 65b, nearly all from the revision
string), and the kernel configuration is now identical (extra packages
GL.iNet built as modules stay `=m`). New: GL.iNet's `busybox` (1.33.2-3,
dated at 4.7.0's patch time), `dnsmasq-full` (2.85-12) and `odhcpd`
(bc9d317f-6) have higher `AUTORELEASE` numbers than ours (-2, -10, -4):
their folders had more commits. GL.iNet's published 4.8.6 tree has extra
patches for exactly these three (odhcpd 2, dnsmasq 5 plus its init script,
busybox 2); of them, only dnsmasq's `302-support-log-level-config` leaves
strings, and those are in 4.7.0 and not in 4.6.8. Package rebuilds on a copy of
69b's tree (each package built directly with its own Makefile and
OpenWrt's `SOURCE_DATE_EPOCH`, first validated to give 69b's own binary)
settle it: busybox with GL.iNet's 531 (crond log line) and dnsmasq with 302
and 303 are byte-identical to GL.iNet's 4.7.0 binaries, odhcpd with 01 and
the `odhcpd.c` half of 02; 4.7.4's odhcpd has the whole 02 (one byte,
`LOG_ERR` to `LOG_DEBUG`, at the same release number: GL.iNet's builder
recreates its patch commits, so a patch can change in place). Busybox's 531
is already in 4.6.8 (release 3). The commits per package now give exactly
GL.iNet's release numbers (busybox 3, dnsmasq 12/13, odhcpd 6). PCIe in 4.7.0:
GL.iNet's `mtk_pcie_probe` sleeps twice after enabling the clocks, ours
once. Every historical version of `pcie-mediatek-gen3.c` in MediaTek's
feed, compiled the validated way, fits GL.iNet's 4.7.0 worse than or as
badly as ours (the closest still differ in `mtk_pcie_probe` and
`mtk_msi_bottom_domain_free`; MediaTek's 2024 file in eight functions), so
it is GL.iNet's own change to the 2022 SDK driver, not public. And one closed package, `gl-sdk4-arp-scan`, names `LicenseFiles` and a
`Maintainer` from 4.7.0 on; the closed-feed generator now carries both
fields over (before, only `License`).

**4.6.4 at GL.iNet's revision, 4.7.4 complete (jobs 70b, 71b), the first
verdicts with the kernel comparison.** 4.6.4 comes out at r15812+900, the
official revision, with every package, file and `status` field as
official and an identical kernel configuration; the kernel comparison
confirms today's firewall, MDIO, `__tcp_close` and `tcp_collapse` fixes in
a full build. It also showed that GL.iNet's 4.6.x routing code is a mix:
the FIB core matches their 922/923, but `fib_table_lookup`,
`ip_valid_fib_dump_req` and `nf_nat.ko` matched our older 953/954 (66b);
to be looked into. And `libc.so` still differed: the musl patch had lost
its new file (fixed, see above). 4.7.4 builds completely (458 packages,
5255 files, kernel configuration identical); new there, only noted so far:
a group of reboot functions (`psci_sys_reset`, `emergency_restart`, the
restart handlers), `copy_creds`, `partition_split`, and `libpcre`'s
Auto-Installed flag. The reboot group is a GL.iNet change in 4.7.4:
`emergency_restart()` sets a flag and `psci_sys_reset()` asks for it
through a new `get_reboot_emergency()`; it is in none of GL.iNet's
published trees nor MediaTek's history, so not public. (Rebuilding its
logic from the machine code would be decompilation, which belongs in the
private repository, not here.)

**4.8.2 prepared (not built yet: 4.7.4 first).** Its row combines the
values collected this morning with what the builds since have taught us:
`sdk_mode` (see below: its revision is empty, so commit counts don't
show and the placeholders are left out), GL.iNet's Jenkins path, feeds pinned as
collected (including the new OpenVPN feed `gl_feed_ovpn_with_dco` and
MediaTek's feed at `964926c`), no LuCI English, and 4.7.4's recreated
commits. Two things change for 4.8.2: AdGuardHome is a package of its own
(`adguardhome-conntrack` 0.107.56, built from `gl_feed_common`), so
`gl-sdk4-adguardhome` holds only its configuration and is generated from
the image (new generator option `--skip-override`, used when `agh_version`
is `-`); and `nf_nat_masquerade_ipv4` is 344 bytes there, without 953's
change, while `fib_trie` is still 953's (`route-failover-kmwan-update-4.8`).
The 42 kernel options that differ from 4.7.4 turn out to be two GL.iNet
changes, both in their published tree: 21 crypto options (AES, SHA and
GHASH with the ARMv8 crypto extensions, ChaCha20/Poly1305 with NEON, built
in; exactly the ones their MT7987 target config sets), and their hardware
check (`security/gl-hw-check`, source and patch published; the patch
applies cleanly here). Extra commits `mt7981-arm64-crypto` and
`gl-hw-check`. dnsmasq is release 14, one commit more than 4.7.4: GL.iNet's
published patch 305 (31 August 2025, a leak fix for the connection mark).
With their published 302 to 305, built on a copy of job 71b's tree (the
as-built rebuild first equal to 71b's), `dnsmasq` is byte-identical to the
MT2500's 4.8.2 one: extra commit `dnsmasq-ct-mark-leak-fix`. This also
explains 4.7.4's open dnsmasq layout: the published 304 is GL.iNet's later
version (every 2.85 folder in gl-image, 4.8.6, 4.8.7 and 4.9.1, has the same
one), and 4.7.4 was built with an earlier one, which is not public. (The
same build had already been compared with 4.7.4 at 17:52; it differed from
4.7.4 in exactly as many bytes as 4.8.2 does, which pointed here.)

**4.9.0 (beta3), values collected for later.** Built 4 July 2026 at
GL.iNet's Jenkins path with `SDK=1` (empty revision, CI build 1048), patch
commits one second before the build; early: the same six source packages
as before plus `busybox` and `firewall`, late: `uboot-envtools`; `curl`
gets ABI names in `Depends` again (as in 4.2.1-4.4.6: `rebuilt_packages`).
483 packages (4.8.2: 461). Feeds: `gl_feed_common` `0bd8fb4` (branch
`common_v4.9`), `mptcp-feeds` `612196d`, a new `gl_feed_smstools3`
(`08b281f`), no OpenVPN feed any more; `gl_feed_21_02` and MediaTek's feed
as before. Package changes against 4.8.2: dnsmasq 2.85 to **2.92** and AdGuardHome
0.107.73. dnsmasq 2.92 is already settled: GL.iNet's published 4.9.0 tree
(for the MT3600BE) has its dnsmasq 2.92 package folder (six 2026 CVE fixes
and their patches 300-305 ported), and built on a copy of job 71b's tree it
gives a `dnsmasq` byte-identical to the MT2500's 4.9.0 one, with every other
file of the package the same; only the release differs (published 4,
official 6). And no extra commit is needed: in 4.9.0 dnsmasq comes from
`gl_feed_common` (`Source: feeds/gl_feed_common/dnsmasq`), whose 4.9.0 pin
has the same folder with `$(AUTORELEASE)`, so release 6 from the feed's
history, replacing OpenWrt's like iproute2 from the MPTCP feed in 4.7.0.
Of 4.9.0's package changes, only two are in the OpenWrt tree itself:
`base-files` (1447, one commit more) and `ubus` (release 3, one more); the
rest are new packages (nftables, NFQUEUE, CAKE, `kmod-loop`, ...), which the
official package list selects, and 159 feed packages, which the pins cover. Kernel: wireless as modules (`CFG80211=m` with the
signed regulatory database, RSA and asymmetric keys built in), although the
MT2500 has no Wi-Fi of its own, and `NET_SCH_PRIO` built in; the MPTCP stub
in `subflow_v4_init_req` is gone (implemented, as in GL.iNet's published
4.8.6 backport).
`base-files` 1447: of the files the package installs, official 4.8.2 and
4.9.0 differ in `sysupgrade`, `rc.local` and `lib/functions/system.sh`
(plus `passwd`/`group`/`shadow`, which follow the installed packages:
chrony in, stubby out). `sysupgrade` (a UBI split for the BE3600) and
`rc.local` (`drop_caches`) are GL.iNet's overlay copies from
`gl-sdk4-base-files`, which the closed part already takes from the official
image. `system.sh` gains `guest_wifi_macaddr_add` in the package itself, and
GL.iNet's published 4.9.0 file is byte-identical to the MT2500's: extra
commit `base-files-guest-wifi-macaddr` (prepared; whether it gives 1447 shows
once 4.9.0 is built).
`ubus` release 3: GL.iNet's published 4.9.0 patch
`0001-Add-auto-subscribe-support.patch` (7 April 2026, client side:
`libubus-io.c`, `libubus-sub.c`, `libubus.c`, `libubus.h`) with
`PKG_RELEASE:=3`, built on a copy of job 71b's tree (the as-built rebuild
first equal to 71b's), gives `libubus`, the `ubus` tool and the Lua module
byte-identical to the MT2500's 4.9.0 ones: extra commit
`ubus-auto-subscribe`. `ubusd` does not match: GL.iNet's has 48 bytes more
code in two places, while ours stays 4.8.2's, and no `ubusd` source
includes `libubus.h`. So 4.9.0 also has a server-side ubus change that
GL.iNet hasn't published; it goes on the list of not-public parts.

Job 72b, 4.6.8's first complete build, comes out at r15812+901, the
official revision, with 440 packages and 5020 files as official, an
identical kernel configuration and the same Auto-Installed flags. It
started before the routing mix was fixed, so `fib_table_lookup` and
`nf_nat.ko` still differ as in 70b; the rest are the known not-public parts
(iwinfo, `usbnet.ko`, the Airoha PHY and link polling, `opkg`'s size option)
and the `Installed-Size` values of `ppp` and `gl-sdk4-tethering`, in every
release from 4.6.2 on with every file identical. `ppp` is solved: GL.iNet's
`ppp` package still has upstream's `ppp6-up`; their own `ppp6-up` reaches
the image only through the `gl-sdk4-base-files` overlay (it is one of the
seven overlay files whose modes were found earlier). Repacked the way
`ipkg-build` packs, our package with upstream's `ppp6-up` comes out at
GL.iNet's size (136512 plus the repack's 9-byte offset; official 136518 to
136520 by release), so `ppp-pppoe-retry-delay` now changes only `ppp.sh`. Job 74b (4.6.4) then confirms the routing mix in a full
build (`fib_table_lookup` and `nf_nat.ko` as GL.iNet's) except for
`ip_valid_fib_dump_req`, whose only difference is a constant: the line
number of the `ASSERT_RTNL()` warning, 928 in GL.iNet's kernel, 930 in
ours. GL.iNet's 922 and 953 have the same `fib_frontend.c` change, but 922
adds two blank lines in `__fib_validate_source`; GL.iNet's kernels have
953's version without them (as job 66b did). Our 922 now takes 953's
`fib_frontend.c` section (both routing variants); test-applied on copies of
74b's patched files with 5002 and 923 undone and redone: it applies
without offset there, and the result differs from 74b's source in exactly
those two lines, which puts `ASSERT_RTNL()` on line 928. (Job 74b also still had the old
commit: the local runner reuses `work/`, and `cp -r` of the extra-commit
folders kept the removed `ppp6-up`. The workflow now copies them fresh;
the first full builds with the fix are 78b, 80b and 81b.)
`gl-sdk4-tethering` (ours 72 bytes smaller in 4.6.x, 18 in 4.7.x) is still
open: no mode change fits, and of all 234 folders of the image as an empty
folder only `lib` fits both 4.6.x versions, while for 4.7.x four others fit
but not `lib` (nor `lib` plus any other): no rule across releases, and
single-folder fits are weak evidence, since a few bytes of gzip noise
decide them.

Job 77b (4.7.0 with every fix before the routing mix and the placeholders)
has 463 packages and 5302 files as official, an identical kernel
configuration and the same Auto-Installed flags; its revision is +903, so
the five placeholders of the current row should give +908 (job 80b). Its
kernel list holds only known items: the pre-mix routing functions,
`mtk_pcie_probe` (not public), the Airoha link polling, `get_phy_device`,
`ethsys_reset`. New to look at: `base-files`' `Installed-Size` is 50 to 63
bytes smaller than GL.iNet's in every 4.7.x job, while 4.6.x matches. The
files in the image are identical (or are GL.iNet's overlay copies), and
the TZ revert accounts for only 4 bytes. The likely place is
`etc/opkg/distfeeds.conf`: `base-files` writes one line per feed of the
build tree, and the image shows GL.iNet's overlay copy instead, so the
package's own version shows only in its size. GL.iNet's grew 73 bytes from
4.6.8 to 4.7.0, ours 11 (the `mptcp_feeds` line). One more feed line adds
only 5 to 18 bytes, so GL.iNet's 4.7.0 tree had several more feeds, or
other feed URLs, without any of their packages in the image. Sizes alone
can't tell which; open.

Job 79b (4.7.4 with every fix up to the routing mix) comes out at
r15812+912, GL.iNet's revision, with 458 packages and 5255 files as
official and an identical kernel configuration; busybox, odhcpd, libc and
the revision-carrying packages now match. Left besides the known parts:
`libpcre`, which GL.iNet's 4.7.4 has from OpenWrt's `package/libs/pcre`
and ours from `gl_feed_common` (hence also its Auto-Installed flag). Our
pin was `16b1e75`, the commit that adds `pcre` to that feed (12 March
2025, "due to nginx"); the newest package the official image has from the
feed is nginx at `e422ba9` (17 February), the commit before. A feed
package overrides OpenWrt's own of the same name, so GL.iNet's 4.7.4 tree
can't have had `16b1e75`: 4.7.4 is now pinned to `e422ba9`.
`release-values.py` had picked the latest of the equally fitting commits;
it now drops commits that add a package the image takes from `package/`
(rerun for 4.6.8 to 4.8.2: only 4.7.4's pin changes). And about 100
packages differ in `Installed-Size` by a few bytes in every 4.7.x job (not
in 4.6.x), with identical files: the package archives' owner fields. Our
`luci-mod-status` repacked without owner names gives exactly the size of
GL.iNet's 2022 copy of it in their package repository (29087), so the
headers explain sizes to the byte. No owner or group name or id fits
eight packages at once, nor does another tar version or format. What fits
is the folder modes: GL.iNet's Jenkins builds with umask 002. The official
images have 1 group-writable folder up to 4.6.8, 60 in 4.7.0 and 4.7.4, 26
in 4.8.2 and 23 in 4.9.0. Rebuilt on a copy of 79b's tree, `luci-mod-status`
goes from 29098 (umask 022) to 29103 (umask 002) and 29110 (umask 002 with
its source folders 775, as a checkout under umask 002 leaves them; GL.iNet:
29108), with every non-shared folder's mode as in the image. Which mode the
shared folders (`usr`, `usr/bin`, ...) had depends on the whole build, so
the umask is now a release value (`umask`, 002 for 4.7.0 to 4.8.2), set in
the build script before anything is checked out, and also for the copy of
the closed feeds; job 82b is the first build with it.
 The 4.8.2 preflight 73p failed
in the fetch step because it ran on an old checkout: a commit had included
Python bytecode (`__pycache__`) by accident, and the worker's `git pull`
then stopped on its own local copies (logged as a warning, but the job ran
anyway). Removed; a fetch-only run on the current recipe passes (461
official packages, 112 closed packages, AdGuardHome skipped), and 73q
repeats the preflight. The local runner now keeps a failed step's log with
the results. 73q passes: all 461 official packages are available
from the 4.8.2 pins (only `kernel`, which is never a selectable package,
is listed, as in every release). Its `revision` line is `getver.sh`'s
(+908), which SDK=1 doesn't affect; the build itself gets an empty one.
A point to watch in the full 4.8.2 build: SDK=1 sets
`IGNORE_PACKAGES = linux`, which would remove every `kmod-*` (all defined
in `package/kernel/linux`). It only takes effect when
`tmp/.config-package.in` is regenerated, i.e. when `.packageinfo` is newer
(`include/toplevel.mk`). Our build script scans and configures before it
exports SDK=1, so the kmods stay. GL.iNet's 4.8.2 has kmods too, so their
CI must also have set SDK=1 only after the scan; a rescan during the build
would drop them.

**Not public so far (kept current; for the source request once all
firmwares are done).** Each is in the official binaries but in none of
GL.iNet's published trees, gl-feeds, the fork, gl-image or MediaTek's
feeds; in the recipe it is a labelled placeholder commit or simply left
different.

| Part | Releases | Where it shows |
|---|---|---|
| MediaTek iwinfo support (HE rate table, HT mode, country) | 4.6.2+ | `iwinfo`, `libiwinfo`, the Lua module |
| RM500U 5G modem entry (`rm500u_5gnet`; from 4.7.4 also `simonet`) | 4.6.2+ | `usbnet.ko` (privately bridged 2026-10-28) |
| USB port power control (`power_ctl`) | 4.6.x | `usb_port_shutdown` |
| EN8811H (Airoha) PHY driver changes (probe at MDIO address \| 8, one PBUS write) | 4.6.2+ | `air_en8811h.ko` (privately bridged 2026-10-28) |
| Airoha link-state polling | 4.6.2+ | `phylink_fixed_state`, `mtk_mac_link_up`, `mtk_rx_irq_disable` |
| C45 read in `get_phy_device` | 4.6.2+ | `get_phy_device` |
| opkg size option (`uninstall_pkg_total_size`) | 4.6.2+ | `opkg` (privately bridged 2026-10-29; GL.iNet's binary is one file in 4.6.2–4.9.0 and lacks the remove-once patch) |
| PCIe probe (one more sleep) | 4.7.0+ | `mtk_pcie_probe` |
| Emergency-reboot flag | 4.7.4 | `psci_sys_reset`, `emergency_restart`, restart handlers |
| Earlier version of dnsmasq patch 304 | 4.7.4 | `dnsmasq` layout (size and strings equal) |
| ~~Server side of ubus auto-subscribe~~ public after all: three upstream ubus fixes of October 2025 | 4.9.0 | `ubusd` (identical since 2026-10-28) |
| sipcalc output with spaces instead of tabs (66 literals) | 4.7.4+ | `sipcalc` in `gl-sdk4-ipv6` (privately bridged 2026-10-28) |
| Unidentified commits (count only) | 4.5.x: 1, 4.6.x: 2, 4.7.x: 1 | the revision number |
| `ipheth` from the upstream CDC NCM work (11 of 15 commits, small 5.4 adaptations) | 4.9.0 | `ipheth.ko` (privately bridged 2026-10-28) |
| MediaTek warp newer than 5f71ec, built without `-fno-caller-saves` | 4.9.0 | `mtk_warp.ko` (privately bridged 2026-10-28) |

Re-checked on 2026-10-27 with a wider net: key strings of every item
searched in all 70 `gl-feeds` branches (not only the pinned ones, e.g.
`support_rm500u`, `mtk-wifi-7.6.7.0`), every `gl-image` branch (now also
gl-be14000's 4.9.1) and MediaTek's feed history. Nothing new turned up:
RM500U appears only in the serial `option` driver of GL.iNet's 5.4.281
kernels, not in `usbnet`; 4.9.1's ubus patch is the same file as 4.9.0's
(no `ubusd` part); the named gl-feeds branches hold no iwinfo, usbnet or
kernel changes. The MT3600BE tree's MediaTek SDK backports (`999-1600`
MDIO C45, `999-17xx` phylink) were tried for `get_phy_device` and the
link polling on a validated copy of 68b's kernel: the key ones don't apply
to 5.4.211, and those that do change nothing there. The link polling is
`phylink_fixed_state` in `mtk_eth_soc.c`: our version (from the 4.2.0-era
fork) reads the GPY211's status register at MDIO address 5; GL.iNet's 4.6.2+
version is four times larger, presumably handling the EN8811H too, and
this polling code appears nowhere in MediaTek's history or gl-image: GL.iNet's
own code. Third-party copies of GL.iNet's old builder checked too: of the
seven GitHub forks of `gl-infra-builder` the newest (zongceng, July 2024)
has the `patches-mt798x-7.6.6.1` set with third-party additions; its iwinfo
and modem patches differ from GL.iNet's 2023 ones only by refreshing, a
small Lua change and Quectel's own qmi_wwan code for kernel 5.4.188: no HE
rate table, no RM500U `usbnet` entry. A web search for `rm500u_5gnet` finds
nothing: GL.iNet's own name. Not searched yet: Airoha's EN8811H driver
releases outside MediaTek's feed.

Second search for public sources (2026-10-28 evening), for every closed
binary still copied from the official images:
- **String provenance against 95 more repositories:** all public
  repositories of `gl-inet` and of oui's author (zhaojh329). The closed
  binaries' strings were scored against them as well as the earlier
  source pool. No new origins: the matches are libraries embedded in the
  binaries (Mongoose in `gl_nas_sys`/`webdav_ser`, the already known `qcm`
  sources, MediaTek's MT7615 SoftAP 5.0.4.0 driver for `mt_wifi.ko`, an
  older generation than the MT7981's driver).
- **Web search on fingerprints:** a fingerprint per binary (exported
  functions, libraries, distinctive strings; symbol tables and strings
  only). Nothing found for any of the 79 binaries.
  - `gl-inet/glinet4.x` has GL.iNet's own prebuilt `gl-sdk4-*` ipks
    (binaries only).
  - `gl-inet/gl-modem-at` is an older, smaller relative of `gl_modem`, not
    its source.
- **iwinfo's HE rate table:** GL.iNet's `he_mcs_phyrate_mapping_table`
  (4.6.2+) is MediaTek SDK code. hanwckf's `immortalwrt-mt798x`
  (`iwinfo_mtk_rate.c`) has the same 192 values. GL.iNet's library is
  still the 2023 `iwinfo_mtk.c` lineage with this table added (hanwckf's
  `l1util`/country code is not in it), so there is still no unmodified
  public build.
- **MT7981 Wi-Fi firmware (4.9.0 `kmod-mt_wifi`/`kmod-warp`):** only
  `MT7981_ePAeLNA_EEPROM.bin` is public. It is linux-firmware's and
  MediaTek's `mt7981_eeprom_mt7976_dbdc.bin`, byte for byte. The other
  firmware files are not in linux-firmware, MediaTek's feed history or the
  MT798x community trees (hanwckf, padavanonly, lgs2007m's list, which
  goes up to 2024-08-23):
  - the WM, WA and ROM patch are MediaTek builds of 2024-09-24;
  - the WO is a build of 2023-06-28.
  The recipe still copies the EEPROM from the image: taking it from
  linux-firmware would add a download for one file.
- **`conninfra.ko` (4.9.0) is public:** MediaTek's conninfra driver
  `bbf588`, as padavanonly's `immortalwrt-mt798x` (21.02 tree, commit
  015af9e3) publishes it, built unmodified against our kernel. The options:
  APSOC MT7981, EMI support, auto-up and EEPROM name `e2p`. The result is
  byte-identical (targeted compile). The function sizes told the versions
  apart: hanwckf's later `f2fa25` adds four register writes and a chip
  revision check (152 bytes). The recipe downloads the 47 files by commit
  with hashes (`overrides@4.9.0..4.9.0/mt798x/drivers/connectivity/conninfra/build.mk`).
- `mtk_warp.ko` (4.9.0): 48 test builds (four public warp versions,
  chipset and memory options). Closest is `5f71ec` with chipset `colgin`
  and no leak debugging: `.text` 40 bytes larger, `.data` identical.
  GL.iNet's has two bounds checks (`ring_id(%d) or cell_idx(0x%x) out of
  range`, `invalid length (len1:%d)`) and no `LogLevel` message, which are
  in no public warp source. It is a newer MediaTek release than 5f71ec
  (2023-12; GL.iNet's package date is 2024-09-27). Not public; a
  candidate for a private bridge.
- Not public: `mt_wifi.ko` and `mtk_warp_proxy.ko` are SDK 7.6.7.1. The
  public sources are 7.6.6.1, 7.6.7.2 and 7.6.7.3. `mtfwd`, `mtqos` and
  `fwdd` are in none of the community trees.

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
- [x] Find out why about 300 libraries and programs still differ in the recreation (Samba, Python, busybox and others). Done (chapters 13 and 15): the public part is identical for every release apart from the accepted classes; what remains is the not-public list (chapter 15) and the closed packages (`docs/closed-binaries/`).
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
| 2026-10-26 | Recipe per release (`openwrt/gl-releases.tsv`); 4.2.1 recreated to 4.2.0's level (run 14): AdGuardHome v0.107.26 release binary, `early_patches` (patch commits crossing a second), `rebuilt_packages` (ABI names in `Depends` when GL.iNet's tree held earlier builds). |
| 2026-10-26 | Kernel image byte-identical to GL.iNet's (4.2.0 and 4.2.1) when built without ccache; the build-ID difference was ccache. |
| 2026-10-26 | 4.2.3 recreated to the same level (run 20): release values `private_now` (tertf left gl-feeds) and `late_patches`; opkg errors kept on a failed install. |
| 2026-10-26 | 4.2.3 validated without ccache (run 21): root file system identical to run 20, kernel byte-identical to GL.iNet's. 4.4.5 queued with builder `main` at 233a758 (no fork tag after 4.4.1). |
| 2026-10-26 | 4.4.5's differing kernel modules traced to three July changes on `main` that the image lacks: GL.iNet built 4.4.x from a release branch with the patch folder of 25 June (`patches_rev`), `early_patches` 10, busybox `usleep` (`extra_config`). 4.4.6 adds the picked wireguard fix. |
| 2026-10-27 | Job 28: 4.4.5 matches in every kernel module, busybox, kernel config, `SourceDateEpoch` and file count; besides the accepted classes only `ip-full` and `sipcalc` differ: directory-order effects fixed for 4.2.x, but GL.iNet's 4.4.x order is another one (other build machine). |
| 2026-10-27 | 4.5.0+: the builder went private in August 2023 but stayed the same (r15812, kernel 5.4.211 up to 4.9.0). `release-values.py` reads all releases' values and pins `gl-feeds` by `SourceDateEpoch` (`feed_revs`); 4.5.0 queued. |
| 2026-10-27 | Build-machine orders read per release from the official binaries (`link-order.py`): iproute2's table order (reproduces 4.2.0's hand-derived list) and part of `sipcalc`'s link order; 4.5.0 settings from job 29: Samba without AD DC/VFSX (no Python), no `kmod-dm`, libcurl without nghttp2. |
| 2026-10-27 | 4.5.0 job 33: kernel config, `opkg`, `liblua5.3`, `mtkhnat`, `ext4` identical, counts and `status` as official, r15812+884; GL.iNet's opkg/lua5.3 patches found in `gl-inet/gl-image`, release value `extra_commits`. 4.4.5 `ip-full` identical with the per-release order. |
| 2026-10-27 | Revision count compiled into every binary (toolchain version string): labelled placeholder commit for 4.5.x's unidentified 885th commit. 4.5.16: no `ALL_KMODS`, LuCI English again. `sipcalc` order via marker strings (OpenWrt evaluates package recipes before unpacking). |
| 2026-10-27 | 4.4.5 recreated to the level of 4.2.x (job 40): only the accepted classes remain (`.pyc`, `python3` Depends order, `wg`, vermagic). `sipcalc`: from 4.4.x on GL.iNet's link order is the sorted one (byte-identical by direct compilation). 4.5.0 (job 39): r15812+885 with the placeholder, `sipcalc`, `libelf`, Go programs identical; closed kernel modules now provide their exports (`.symvers`) for `shortcut-fe`. |
| 2026-10-27 | 4.4.6 recreated to the level of 4.2.x (job 41): only the accepted classes remain. Second job worker on the M5+ (one build leaves ~90 % of the CPU idle); each worker keeps its last tree for single-package rebuilds. `gl-inet/gl-image` holds GL.iNet's complete 4.8.6 GPL tree for the BE10000. |
| 2026-10-27 | 4.5.16 at 4.5.0's level (r15812+885). All feeds of 4.5.0-4.8.2 pinned, incl. depth-1 feeds (`~shallow`) and those outside gl-feeds; 4.6.2: `mt798x` feed, no `ddns-scripts`. tertf exports via OpenWrt's symvers hook. Preflight (`dry=true`) and a single-package retry. |
| 2026-10-27 | `shortcut-fe` matches (tertf exports via OpenWrt's symvers hook). 4.6.2 kernel: Airoha EN8811H from MediaTek's feed, MPTCP from GL.iNet's published 5.4 backport (both as extra commits). Sibling firmware: MT3000 is the MT2500's twin, X3000/XE3000 on the 4.4 branch until late 2024. Host Python built first (bpftools race). |
| 2026-10-27 | 4.6.2: zstd (`UBIFS_FS_ZSTD`) and device tree recreated; iwinfo and the `usbnet` RM500U entry found but not public; about 6 commits probably only for other boards. |
| 2026-10-27 | 4.5.0 and 4.5.16 recreated to the level of 4.2.x (jobs 61, 62): only Samba order, `wg` tree hash and vermagic remain. |
| 2026-10-27 | 4.7.0+: iproute2 6.3.0 from the MPTCP feed replaces OpenWrt's (`OVERRIDE_PKGS`); the static-syms order patch now reaches it (official 4.7.4 order reproduced). 4.6.4 → 4.6.8 leaves kernel code unchanged. |
| 2026-10-27 | 4.6.2 and 4.7.0 build completely (all packages and files). 4.6.2: placeholders for its 8 missing commits (owner's choice). 4.7.0: ppp/opkg/uci in the later rows, extra packages GL.iNet built as modules stay `=m` (IPsec kernel options), `base-files-tz-revert`, `wireguard-punch-attribute` (GL.iNet's 952 patch). |
| 2026-10-27 | From 4.7.0 on GL.iNet built in a Jenkins job (`/work2/jenkins/workspace/router_mt2500`, up to 4.9.0); release value `build_dir`. |
| 2026-10-27 | Not public (4.6.2+): GL.iNet's changes to the EN8811H driver v1.2.5 (two messages, one flag) and opkg's package-size option. |
| 2026-10-27 | Kernels compared function by function (`vmlinux-to-elf` + `analysis/kernel-functions.py`): 4.6.2, 4.6.4 and 4.6.8 have identical kernel code; 4.7.0 adds USB hub port disabling and changes MPTCP, PCIe and USB power management. |
| 2026-10-27 | 4.7.0+: GL.iNet's USB hub port power patch (963, published) as an extra commit; 4.6.x: USB port `power_ctl` not public (labelled placeholder). |
| 2026-10-27 | 4.6.4 and 4.7.4 build completely. 4.6.4+: firewall ubus timeouts (2 → 20 s), AdGuardHome's zoneinfo dependencies, `@early` extra commits. 4.7.4: ChaCha20-Poly1305 package and built-in pstore. |
| 2026-10-27 | Kernel code compared in every verdict (function by function against GL.iNet's kernel); open groups in 4.6.x/4.7.x: MDIO/PHY, MediaTek Ethernet, MPTCP version, PCIe. |
| 2026-10-27 | 4.6.2+ routing solved: GL.iNet's published 922/923 (one context line adapted to 5.4.211) plus the devhash export match every routing function; validated single-object compiles with OpenWrt's flags. |
| 2026-10-27 | All five remaining "not public" claims re-checked against GL.iNet's four published trees (incl. full kernel sources), MediaTek's feed history and gl-feeds: they hold. |
| 2026-10-27 | MPTCP: GL.iNet's `__tcp_close()` split doesn't set `sk_shutdown`, and their `tcp_collapse()` moves the MPTCP skb extension; both now match (validated single-object compiles). |
| 2026-10-27 | MPTCP: our backport is Linux 5.15's; GL.iNet's 4.6.2-4.8.2 `subflow_v4_init_req` is a "need to implement this function" stub, now reproduced instruction for instruction. |
| 2026-10-27 | MPTCP complete: 4.6.x's receive path still reported subflow priority events (`mptcp_recvmsg` identical with that call active); `mptcp-backport-4.6x` for the 4.6.x rows. |
| 2026-10-27 | busybox (531, 4.6.8+), dnsmasq (302, 303) and odhcpd (01, 02) from GL.iNet's published tree, byte-identical to GL.iNet's 4.7.0 binaries; release numbers match. |
| 2026-10-27 | 4.6.4 at GL.iNet's revision r15812+900 (job 70b); 4.7.4 complete (71b); first verdicts with the kernel comparison. |
| 2026-10-27 | GL.iNet's 4.6.2-4.7.4 route-failover is 922 with 953's `fib_trie.c` and `nf_nat_masquerade.c` parts (validated compiles); extra commit updated. |
| 2026-10-27 | 4.7.x placeholders as for 4.6.x: iwinfo, usbnet, Airoha link polling, PCIe (4.7.0+), emergency reboot (4.7.4), one unidentified each (to +908 and +912). |
| 2026-10-27 | 4.8.2 prepared (row, AdGuardHome as its own package, routing variant); built once 4.7.4 is validated. |
| 2026-10-27 | 4.8.2/4.9.0 were built with `SDK=1` (empty revision via `version.mk`), not without git: packages keep git dates. Release value `no_git` replaced by `sdk_mode`. 4.8.2's 42 kernel options: ARMv8 crypto and GL.iNet's hardware check, both published. |
| 2026-10-27 | 4.9.0's values collected (feeds incl. a new smstools3 feed, dnsmasq 2.92, wireless modules in the kernel); built after 4.8.2. |
| 2026-10-27 | 4.6.2 at GL.iNet's revision (job 68b); musl `pthread_getname_np` backport found (identical code), two unidentified placeholders left. |
| 2026-10-27 | MDIO `reset-post-delay-us` backported (kernel side of GL.iNet's PHY reset on the MDIO bus); exact sizes, validated. |
| 2026-10-27 | 4.7.0 at GL.iNet's Jenkins path (job 69b): no build-path differences left, kernel configuration identical; busybox/dnsmasq/odhcpd carry GL.iNet patches (4.8.6 tree has them). |
| 2026-10-27 | 4.6.8 at the official revision (job 72b): all packages and files, kernel configuration identical; 4.9.0's `base-files` change found (`guest_wifi_macaddr_add`, GL.iNet's published file). |
| 2026-10-27 | 4.7.0 with all fixes (job 77b): all packages and files, kernel configuration identical; `ppp` size solved (upstream `ppp6-up` in the package); `base-files` size in 4.7.x traced to `distfeeds.conf` (GL.iNet's feed list, open). |
| 2026-10-27 | Worker fix: a commit with `__pycache__` files had blocked w1's `git pull`, so 73p/74a ran on an old checkout; files removed, and a failed pull now puts the job back instead of building. |
| 2026-10-27 | 4.9.0 `ubus`: GL.iNet's published auto-subscribe patch gives `libubus`, `ubus` and the Lua module byte-identical; `ubusd` has an unpublished server-side change. |
| 2026-10-27 | 4.8.2 `dnsmasq` byte-identical with GL.iNet's published 302-305 (extra commit for 305); 4.7.4's had an earlier, unpublished 304. |
| 2026-10-27 | 4.6.4 with complete MPTCP and the routing mix (job 74b): revision +900, all packages and files, `nf_nat.ko` and `fib_table_lookup` now as GL.iNet's; left: not-public parts, `ethsys_reset`, `ip_valid_fib_dump_req`. |
| 2026-10-27 | `ip_valid_fib_dump_req` explained: GL.iNet's `fib_frontend.c` part is 953's (two blank lines fewer than 922's, so `ASSERT_RTNL()`'s line number is 928, not 930); our 922 now has it, test-applied. |
| 2026-10-27 | 4.7.4 with all fixes (job 79b): r15812+912 as GL.iNet's, all packages and files; `libpcre` traced to a feed pin one commit too late (fixed, and `release-values.py` now avoids such pins). |
| 2026-10-27 | GL.iNet's Jenkins builds (4.7.0+) use umask 002 (group-writable folders in the images, ~100 `Installed-Size` values); new release value `umask`. |
| 2026-10-27 | Not-public list re-checked across all gl-feeds and gl-image branches and MediaTek's history, plus the MT3600BE tree's PHY backports on a validated kernel copy: all items hold. |
| 2026-10-27 | 4.6.2 with every fix (job 78b): r15812+899, all packages and files, kernel configuration identical, `ppp` and `ip_valid_fib_dump_req` now as GL.iNet's; left: the not-public parts, `ethsys_reset`, `gl-sdk4-tethering` and `gl-sdk4-base-files` sizes (2 bytes). |
| 2026-10-27 | 4.7.0 with the placeholders (job 80b): r15812+908 as GL.iNet's, all packages and files; new: `nginx-mod-lua` built with HTTP/2 here, GL.iNet's config has `CONFIG_NGINX_HTTP_V2` off (4.7.0 is the only release with the module): `extra_config`. |
| 2026-10-27 | 4.1.1 (r15812+865, Nov 2022, the oldest published release) prepared: builder tag `v4.1.1_mt2500_release1`, profile feed pins confirmed by `release-values.py` (gl_feed_common `7a2b21a2`), `early_patches` 11 (any of 11-20 gives the same dates); queued as 83c/83d. |
| 2026-10-27 | M5+ runner keeps every job's full logs (`results/<job>/report/logs/`: build, progress, config, run log); overnight queue to ~06:30: 4.7.0/4.7.4 with umask, 4.6.4/4.6.8 with every fix, 4.1.1 first build, 4.8.2 first build, validation runs without ccache for 4.4.5, 4.4.6, 4.5.0, 4.5.16, 4.6.2. |
| 2026-10-28 | 4.1.1's first preflight (83c) stopped with exit 255: `kmod-gl-sdk4-edgerouter-status` (4.1.1 only) was treated as closed, and its feed folder `gl_feed_common` clashed with the public feed of that name. Its source is public at the pin: now in `built-from-public.txt`; rerun as 91a/91b. |
| 2026-10-28 | Overnight: validation runs without ccache for 4.4.5 and 4.4.6 complete; 4.5.0, 4.5.16 and 4.6.2 stopped at host `expat` ("cmake: command not found"): the host-Python step added on 2026-10-27 ran before the host tools, which without ccache nothing had built yet. Fixed (tools first); the runner now also keeps the per-package logs. Requeued as 92-94. |
| 2026-10-28 | **4.4.5, 4.4.6, 4.5.0 and 4.5.16 validated** without ccache (jobs 84, 85, 92, 93): kernel code identical function by function, only the accepted classes differ (Samba, Python bytecode and `Depends` order, `wireguard-tools`). Seven releases proved. 4.6.2 without ccache (94) = its ccache build 78b. |
| 2026-10-28 | umask 002 confirmed: 4.7.0 (83b) and 4.7.4 (82b) go from ~105 differing `Installed-Size` values to 19 and 25; 4.7.4's `libpcre` now as GL.iNet's (pin fix). 4.6.4 (88b) and 4.6.8 (81b) with every fix at 4.6.2's level. |
| 2026-10-28 | 4.1.1's first build (91b): `kmod-dm` can't be packaged (device mapper built in, no `dm-mod.ko`); GL.iNet's 4.1.1 has neither `kmod-dm` nor `kmod-dax`: `extra_config` as for 4.5.0. 4.8.2's first build (90b): GL.iNet's `dropbear` 2024.86 (`gl_feed_common`, `PKG_FIXUP:=autoreconf`) fails in configure: with 21.02's autoconf 2.69 its late `AC_CONFIG_AUX_DIR([src])` isn't honoured; GL.iNet's build must have used another autoconf (open). New in 4.7.x with umask: `netifd`'s `udhcpc` script (4.7.4) and `tc-tiny` differ (open). |
| 2026-10-28 | 4.7.4's `netifd` `udhcpc` script: GL.iNet's has a cable-passthrough block (masquerade address, proxy ARP), new in 4.7.4 like the dnsmasq one; now part of the passthrough commit, taken from the official image. Repacked, `netifd` gets GL.iNet's exact `Installed-Size` (101228). |
| 2026-10-28 | 4.7.x `tc-tiny`: GL.iNet's action/qdisc/filter table is in sorted file order (their Jenkins runs GNU make 4.3+, which sorts `$(wildcard)`; 4.6.x's builder didn't). Patch `iproute2@mptcp_feeds/991` sorts tc's static-syms for the MPTCP feed's iproute2 only: direct build byte-identical to GL.iNet's 4.7.4 `tc-tiny`. |
| 2026-10-28 | 4.7.4's `sipcalc` (`gl-sdk4-ipv6`, package of March 2025): GL.iNet replaced tabs with four spaces in 33 of its 56 tabbed output strings (200 bytes more code); not in upstream (Debian 1.1.6 or git) nor any published tree: not public. 4.7.4's exfat (`gl-sdk4-nas-exfat`) uses `strncpy` where 4.7.0 used `strcpy`: GL.iNet's full recipe and source are published in gl-image (4.8.6), being tested. |
| 2026-10-28 | 4.7.4's exfat solved: GL.iNet's own recipe and source for `gl-sdk4-nas-exfat` (published in gl-image 4.8.6, reformatted exfat with `strncpy`) give `fsck.exfat`, `mkfs.exfat` and `libexfat.so` byte-identical to their 4.7.4 ones; used from 4.7.4 on (`overrides@4.7.4/`, picked by `gen-closed-feed.py --release`). |
| 2026-10-28 | Worker race: two jobs starting at once collided on dpkg's lock (`apt-get install squashfs-tools`, job 95a); the install is now skipped when present and otherwise waits for the lock. |
| 2026-10-28 | 4.8.2's `dropbear` solved: GL.iNet's (gl_feed_common 2024.86) is built with the tarball's own configure (autoconf 2.71) and the options ASKPASS, ECC, ECC_FULL, ECDSA_SK, ZLIB; our build with both is byte-identical. OpenWrt's autoreconf (2.69) breaks its configure, and fixing `configure.ac` instead gives another binary, so the build script drops `PKG_FIXUP` for that recipe; the options are 4.8.2 `extra_config`. 4.6.8 without ccache (96) = its ccache build. |
| 2026-10-28 | 4.7.x closed packages' sizes: under umask 002 their executable rootfs-overlay files are 775 in GL.iNet's packages (the image shows the replaced file's mode); repacked, `gl-sdk4-modem` (−181) and `gl-line-graph` (−4) get GL.iNet's exact size; now in `gen-closed-feed.py --umask`. 775 folders fit `gl-oui-rpc` and `mtk-base-files`, but other packages need a mix (folders from `INSTALL_DIR` vs. copied sources), which only GL.iNet's Makefiles can tell: open. |
| 2026-10-28 | 4.9.0 row added (beta3, SDK=1, Jenkins path, umask 002; feeds incl. `gl_feed_smstools3`; `curl` as a rebuilt package; extra commits as 4.8.2 plus `base-files-guest-wifi-macaddr` and `ubus-auto-subscribe`). Open until its first build: the 14 one-second-early packages (as 4.8.2's 12) and the MPTCP version without the `subflow_v4_init_req` stub. |
| 2026-10-28 | 4.6.x reproducible without ccache: 4.6.2 (94), 4.6.4 (97) and 4.6.8 (96) each equal their ccache builds; left only the not-public parts and `ethsys_reset`. |
| 2026-10-28 | 4.1.1's first build (95d): r15812+865, all 423 packages and 5765 files, kernel configuration and kernel code identical. GL.iNet built 4.1.1 on a GitHub Actions runner (`/home/glinet/work/actions-runner/_work/gl-infra-builder/gl-infra-builder`, in nginx's configure string and libstdc++'s gdb helper): `build_dir` set, rerun queued. |
| 2026-10-28 | 4.8.2/4.9.0 early packages (fstools, iwinfo, uci, netifd, opkg, gpio-button-hotplug; 4.9.0 also busybox, firewall) aren't a prefix of the builder patches (uboot-envtools, patch 2, isn't early): `early_patches` now takes a range (4.8.2/4.9.0: 10-16) and the extra commits last touching opkg, uci, netifd (and busybox, firewall) get `@early`. To be checked against 99b's SourceDateEpoch differences. |
| 2026-10-28 | `gl-sdk4-uci` (4.7.4–4.9.0, version 7e5f319) built from GL.iNet's own source in gl-image (4.8.6): `libguci.so` byte-identical, package size exact. GL.iNet's README says no license is assigned yet, so the source is downloaded from their repository at build time (pinned commit, SHA256), not stored here (`overrides@4.7.4/`). Same versions published: `mpflow_statistics` (4.7.4+), `kmwan` (4.9.0): next. |
| 2026-10-28 | `kmod-gl-sdk4-mpflow_statistics` (4.7.4–4.9.0, ddc056a) built from GL.iNet's published GPL-2.0 source: `gl-mpflow.ko` identical apart from vermagic. It calls `fib_info_devhash_bucket`, which explains GL.iNet's devhash export; their 999-5000/5001 (declaration, not static) are now in `fib-devhash-export` too, and change no kernel function (validated compile). |
| 2026-10-28 | 4.8.2's second build (99b): every package compiles (dropbear too), but the image step found no opkg: with SDK=1 OpenWrt drops `package/compile`'s dependency on the host opkg (`package/Makefile`, `ifndef SDK`). The build script now builds the host opkg first when `sdk_mode` is 1. |
| 2026-10-28 | 4.7.4 with today's fixes (98b): `netifd`, `tc-tiny`, exfat, `gl-sdk4-modem` and `gl-line-graph` now as GL.iNet's; differing files left are only the not-public ones (dnsmasq 304, sipcalc, iwinfo, usbnet, Airoha PHY, opkg), plus a few closed-package folder-mode sizes; kernel: the not-public reboot/PCIe groups. `copy_creds` and `partition_split` only look different in size: instruction by instruction they are identical (only moved addresses); the comparison measures a function as the gap to the next shared symbol, which here includes padding or a neighbour only one kernel lists. |
| 2026-10-28 | 4.9.0's first preflight (99c): 8 packages missing. `amneziawg-tools`, `kmod-amneziawg`, `kmod-ovpn-dco-v2` come from GL.iNet's public `vpn-extra-feeds` under a new feed name, `gl_vpn_extra` (pinned at `ca1c315`, 4/4 packages; `release-values.py` knows the name now). `kmod-conninfra`, `kmod-mt_wifi`, `kmod-warp`, `wifi-profile` (MediaTek Wi-Fi drivers, in a router without Wi-Fi) and `kmod-dpi` are from GL.iNet's private feeds but don't follow the closed-package names: `gen-closed-feed.py` now also selects by source feed (`glinet`, `mt7981`, `mt798x`); only 4.9.0 is affected. |
| 2026-10-28 | Report of what we can't build from source: `docs/closed-binaries/` (overview with one row per binary and a column per release holding a short MD5, plus one file per release with full path in the firmware bundle, package, hashes, ELF and module information and identifying strings; metadata only), generated by `analysis/private-binaries.py`. From 53 binaries in 4.2.0 to 231 in 4.9.0 (mostly closed packages' Lua bytecode and programs); 4.8.2/4.9.0 still without their public-package part. |
| 2026-10-28 | The report now flags sensitive-looking data per binary (kind and count only; ⚠ in the overview): PEM private keys in `gl-sdk4-hw-info.ko` (4.7.4+) and 4.9.0's `mt_wifi.ko`, a credential URL in `gl-sdk4-ddns`'s `ddns.so`, credential-like and high-entropy strings elsewhere (4–9 binaries per release, 52 in 4.9.0). The matches themselves are in the private decomp repository (`notes/sensitive/`) for further work there. |
| 2026-10-28 | Per-binary notes for the binaries we can't build (in the private repository): each binary's evolution across the releases (size, functions, imports, exports, strings added or removed per step) and per version everything the file says about itself, as material for finding open-source equivalents. `private-binaries.py` writes its selection for that (`binaries.json`, private output only). |
| 2026-10-28 | Leads to public source among the binaries we can't build: 4.5.16's `tailscaled` is Tailscale 1.58.2 (Go 1.21.5, a possible Go rebuild); `QFirehose` (V1.4.7, V1.4.13) and `qcm` (QConnectManager) are Quectel's modem tools, whose source Quectel distributes; GL.iNet's Go programs (`gl-arp-scan`, `gl-p2p-daemon`) are their own modules on public libraries; `kmwan.ko` and `parental_control.ko` embed cJSON. |
| 2026-10-28 | 4.8.2's first complete build (99h): empty revision as GL.iNet's, all 461 packages; `opkg`, `uci`, `netifd` dated as GL.iNet's (`@early` works), but fstools/iwinfo/gpio-button-hotplug still one second late (the patch range didn't take), `zlib` and `uboot-envtools` changed by GL.iNet (new commits), `/etc/version.build` (CI build number) missing, `gl-sdk4-ipv6` needs `kmod-ipt-raw6`, `openvpn-openssl` built with DCO, `libc` differs: to work through. The mpflow recipe from GL.iNet's tree lacked the package's three scripts (fixed: package now GL.iNet's exact size). |
| 2026-10-28 | 4.9.0's second preflight (99l): `gl-sdk4-dpi` and `kmod-dpi` come from one folder (`glinet/gl-sdk4-dpi`); `gen-closed-feed.py` now merges packages sharing a folder into one recipe (own files folder and exact version each). Output for all other releases unchanged (checked 4.2.0, 4.6.8, 4.7.4, 4.8.2). |
| 2026-10-28 | 4.8.2/4.9.0 fixes: OpenVPN with DCO (`CONFIG_OPENVPN_openssl_ENABLE_DCO=y`, GL.iNet's config), `/etc/version.build` (GL.iNet's CI build number, owned by no package) taken from the image, and `gl-sdk4-ipv6` with the official dependencies per release (4.8.2+ adds `kmod-ipt-raw6`). |
| 2026-10-28 | 4.8.2/4.9.0: GL.iNet's `zlib` has their published `006-minizip-check-zip-file.patch` (extra commit `zlib-minizip-check`, test-applied); `uboot-envtools` release 17 is one more board entry, for GL.iNet's MT3000, not published (`uboot-envtools-mt3000`, script from the image). In 4.9.0 that commit is the one dated a second late: new `@late` suffix for extra commits, `late_patches` back to 0. |
| 2026-10-28 | Why 4.8.2's early range didn't apply: the step's guard tested `EARLY_PATCHES -gt 0`, which a range like `10-16` fails, so it was skipped (only the `awk` part had been tested). Now compared with `0`; the whole step tested on a throwaway repository (exactly commits 10-16 dated a second earlier). |
| 2026-10-28 | 4.8.2's `libc.so` (12 KB larger than ours, same exports): GL.iNet's config sets `CONFIG_MUSL_DISABLE_CRYPT_SIZE_HACK=y` from 4.8.2 on (full `crypt` code); now in 4.8.2/4.9.0's `extra_config`. All eight 4.8.2 items from 99h are handled; 99r/99s will show. |
| 2026-10-28 | 4.5.16's `tailscale`/`tailscaled` are Tailscale's official static arm64 release 1.58.2 after OpenWrt's `sstrip -z` (same build info, 2 header bytes and the stripped tail differ before stripping; identical after). `gl-sdk4-tailscale` gets a recipe that downloads that release (SHA256-checked) in `overrides@4.5.16..4.5.16`; the generator now takes a release range. Queued as 99t. |
| 2026-10-28 | 4.7.0 without ccache (99o): 463/463 packages, 5302/5302 files, kernel config identical; differing files only the not-public ones (iwinfo, `usbnet`, Airoha PHY, `opkg`) and Samba's accepted order; small Installed-Size differences in closed `gl-*` packages left (folder modes, open). Same level as 4.7.4. |
| 2026-10-28 | Quectel sources (subagent search, public GitHub): QConnectManager V1.6.7 in Quectel's own org (GPL-2.0+), V1.6.4/V1.6.8 in mirrors; QFirehose V1.4.9/V1.4.15/V1.4.17 in mirrors. GL.iNet's versions (V1.6.3.1; V1.4.7, V1.4.13) still not found. |
| 2026-10-28 | 4.9.0's preflight failed again (99p): the merged `gl-sdk4-dpi`/`kmod-dpi` recipe lacked `include $(INCLUDE_DIR)/kernel.mk`, so OpenWrt didn't know `kmod-dpi`. Fixed; a new check on the M5+ (`recipecheck.sh`) has OpenWrt parse every generated closed recipe in about a minute (it shows the old generator's bug, and 4.5.16/4.7.4/4.8.2/4.9.0 pass now). Requeued as 99u/99v. |
| 2026-10-28 | M5+ worker w1 lost almost two hours: its `git pull` hung from 13:49 to 15:39, and the old worker script (from before the pull guard) then started 99f on a stale checkout. That run was stopped after 13 s and w1 restarted with the current script plus `timeout 300` on the pull; w2 gets the same at its next restart. |
| 2026-10-28 | Public origins among the binaries we can't build. (1) The `.ipk` files `gl-sdk4-luci` bundles in 4.8.2/4.9.0 (`/etc/luci_ipks/`) are normal OpenWrt 21.02 LuCI builds (each archive dated to its own SourceDateEpoch): 16 of 24 contain exactly the files of OpenWrt's packages-21.02 build, the other 8 are older commits of the same public branch. (2) `oui/system.so` of 4.1.1–4.7.0 is zhaojh329/oui `lsystem.c` at d6a4a00125, unchanged, built with `-O1`: byte-identical (4.7.4 and 4.8.2+ versions match no oui commit). (3) A string scan of all 992 file versions against our local public sources (281 source archives, feeds, kernel, the three gl-image branches) points GL.iNet's kernel modules `hw-info`, `black_white_list`, `parental_control`, `port_forward` and `kmwan` at their own sources in gl-image (other models, kernel 5.4); a build of each against our release kernels is running. The RPC plugins and Lua files (534 versions, Lua bytecode with GL.iNet's chunk names) have no source in gl-image. |
| 2026-10-28 | Recipes from the new public origins: 4.1.1–4.7.0 `oui/system.so` built from oui `lsystem.c` (new override form `build.mk`: build steps added to the generated recipe, which keeps its metadata); 4.8.2/4.9.0 `gl-sdk4-luci` bundles our own LuCI builds (feed at the same commit as GL.iNet's, selected as modules in `extra_config`) instead of the image's. A test on an archived tree copy failed (archives lack the download cache and toolchain libraries), so the full runs check them: 99j (4.7.0), 99w (4.8.2), 99v (4.9.0). gl-image kernel-module sources built against our kernels: none identical (closest `black_white_list` for 4.5.16: same section sizes, one function differs). |
| 2026-10-28 | GL.iNet's published kernel-module sources (gl-image) built against our kernels, 9 releases × 19 sources: `black_white_list.ko` of 4.7.4/4.8.2 (one file) is byte-identical from the 4.8.6/4.8.7 source, `parental_control.ko` of 4.8.2 from MT3600BE 4.8.7's; recipes download that source at a fixed commit (build steps in `overrides@<range>`), checked by 99k and 99w. Other versions differ (older code than the published trees); 4.9.0 is tested once its tree exists. |
| 2026-10-28 | **4.1.1 at GL.iNet's build path (99f, GitHub Actions runner path):** 423/423 packages, 5765/5765 files, no file differing in size or code; left only the accepted classes (vermagic hash in kernel and module packages, Python bytecode and Samba order, `wg`'s tree hash). Validation without ccache is queued (99n). |
| 2026-10-28 | New search areas for the binaries we can't build. **Compiled Lua** (396 versions, never searched before): every public `.lua` with the same file name (gl-image branches, gl-feeds' full history, the git feeds, oui, lua-eco, gl-inet/parental-control, mptcp-feeds, vpn-extra-feeds, gli-pub; 5254 sources for 48 of 209 names) compiled with OpenWrt's `luac5.1` and Lua 5.3.5/5.4.7 with OpenWrt's and GL.iNet's patches, under the original chunk names: 4.9.0's `rpc/black_white_list`, `rpc/kmwan`, `apps_domain_list.lua` and the parental-control validator are byte-identical from gl-image's 4.9.1 sources (recipes in `overrides@4.9.0..4.9.0`). **`oopslog`**: gl-image publishes it (GPL-2.0, unmodified from GL.iNet's `gl-sdk4-logread`); built against `libguci` with GL.iNet's build time as `SOURCE_DATE_EPOCH` (it carries `__DATE__`/`__TIME__`), byte-identical for 4.7.4, 4.8.2 and 4.9.0; 4.1.1–4.7.0 used an older source (`%d` for `%u` in two messages: 4.7.0 differs in exactly those 2 bytes). **Wi-Fi firmware** (4.9.0): only `MT7981_ePAeLNA_EEPROM.bin` is in a public tree (padavanonly/immortalwrt-mt798x-6.6); the firmware images are newer than any public set. GL.iNet's other public repositories listed (gl-inet org, zhaojh329) for further sources. |
| 2026-10-28 | Worker w2 was dead from 15:40 to 17:01: restarting w1 with `tmux kill-session -t queue` (w1's session had already ended) matched `queue2` by prefix and killed 99s mid-build. 99s requeued, w2 restarted; rule in CLAUDE.md (exact tmux targets, check both workers at every check-in). |
| 2026-10-28 | `docs/closed-binaries/` corrected and regenerated (338 → 299 rows): the report counted packages the recipe builds from the public feed (`hw-info`, `edgerouter-status`, `tertf` where public) as taken from the image; packages with build steps now leave out only the files the steps replace. Gone also: 4.1.1's public-package differences (99f), Tailscale (4.5.16), 4.9.0's compiled Lua; the bundled LuCI ipks are left out pending 99s. New rows: 4.8.2's `libc.so` and `openvpn` (fixes in the recipe, checked by 99s). |
| 2026-10-28 | What the recipe still copies from GL.iNet's images, per release: 49–63 binaries (2.7–3.3 MB) and 600–710 text files in 4.1.1–4.5.16, up to 198 binaries (33 MB, mostly MediaTek's Wi-Fi driver) in 4.9.0. Largest closed binaries in the proved releases: `gl-sdk4-nas-utils` and `gl-sdk4-webdav` (lighttpd 1.4.x with GL.iNet's own modules, which aren't published anywhere: no identical build possible) and `gl-sdk4-modem` (QFirehose: public sources are 1.2.4, 1.4.8, 1.4.9, 1.4.15 and 1.4.17, GL.iNet ships V1.4, V1.4.13 and V1.4.7; `qcm` is public V1.6.3.1 plus GL.iNet's changes). **Translations:** the largest group of copied text files (252–280 `/www/i18n/*.json` per release) is in GL.iNet's public `gl-inet/router-sdk-languages` (37 069 commits, no licence file): all of them byte for byte for 4.5.0–4.9.0, 85–90 % for 4.1.1–4.4.6. |
| 2026-10-28 | **4.8.2 with all recipes (99s):** 461/461 packages, 5189/5189 files. The new recipes held: all 26 bundled LuCI ipks, `black_white_list.ko`, `parental_control.ko` and `oopslog` identical. Left (outside the not-public list): `libc.so` (our `CONFIG_MUSL_DISABLE_CRYPT_SIZE_HACK` was dropped by defconfig: GL.iNet's `toolchain/musl/Config.in` in gl-image makes it `default y` without `TOOLCHAINOPTS`, now extra commit `musl-crypt-default`), the `dnsmasq_vpn` user (GL.iNet's published dnsmasq Makefile; added inside the 4.8.2+ dnsmasq commit so AUTORELEASE stays GL.iNet's), `/etc/sysupgrade.conf` (byte-identical to gl-image 4.9.1's; in `base-files-tz-revert-4.8` for the same reason), mpflow's `License` field (GL.iNet's packages have none). 99j (4.7.0): `system.so` compiled from oui's source confirmed identical. Next full runs for 4.8.2/4.9.0 wait for 99v's results (batch rule). |
| 2026-10-28 | Translations: `/www/i18n` files now come from GL.iNet's public `gl-inet/router-sdk-languages` (`openwrt/gl-4.2.0-closed/i18n/<release>.md`, generated by `analysis/i18n-sources.py`; downloaded and SHA256-checked by `gen-closed-feed.py --i18n`; tested for 4.2.0, 4.5.16 and 4.9.0: every file identical to the image's). |
| 2026-10-28 | Kernel modules from gl-feeds' full history (48 source versions) and gl-inet/parental-control (18) against 8 release kernels: new is 4.1.1's `parental_control.ko` from gl-inet/parental-control ea80343 (recipe in `overrides@4.1.1..4.1.1`); gl-image's `dns-mark`/`tertf` match no release; the `hw-info`/`tertf` matches are versions our build already makes from the public feed. |
| 2026-10-28 | Small reconstructions started (owner's go-ahead), kept in the private repository per release (`reconstructed/<release>/<package>/`, our own work, not public source): `oopslog` 4.1.1–4.7.0 (published source with `%d` for `%u`, and for 4.1.1–4.6.8 the older `guci_get` call) and oui's `rpc/iwinfo` and `rpc/uci` for 4.4.5–4.6.8 (a few lines each), all byte-identical. A bug in the Lua scans (candidates for build-path chunk names were looked up without `.lua`) is fixed; both scans rerun. |
| 2026-10-28 | Private reconstructions continued: `rpc/ubus` 4.4.5–4.6.8 written from GL.iNet's bytecode (19 lines, no public source close), and 85 data-only Lua file versions (validators and similar, all releases) regenerated from their bytecode listings by a small converter: all byte-identical; 106 reconstructed files in the private repository in all. Lua files with code: decompiling with unluac (open source) and recompiling was the next step; running that downloaded tool was stopped by the session's safety check, pending the owner. |
| 2026-10-28 | Lua reconstructions with code (owner-approved unluac): OpenWrt's Lua 5.1 bytecode uses the LNUM patch (integer constants with type 9, header byte = sizeof(lua_Integer)), which unluac can't read; a converter rewrites it to standard 5.1 only for decompiling, and a re-layout step moves each decompiled line to the line the bytecode records. Recompiled with OpenWrt's `luac5.1` under the original chunk names, 72 of 157 file versions are byte-identical (private repository, per release); the others need a decompiled line split over several original lines (multi-line calls and tables), next step. |
| 2026-10-28 | **4.1.1 validated** without ccache (99n): 423/423 packages, 5765/5765 files, only the accepted classes, the same as with ccache (99f): 4.1.1 is proven. 99k (4.7.4 without ccache) released as the 4.7.4 batch run. |
| 2026-10-28 | **All compiled Lua 5.1 of the closed packages reconstructed** (private repository): the 157 file versions with code (4.4.5–4.9.0) recompile byte-identical after decompiling (unluac), re-layout to the recorded line numbers (with token-level line splits and equivalent forms GL.iNet's source used: `M.x = function`, `if not x then x = y end`), and restoring LNUM double constants written as `N.0`; together with the 85 data-only files and earlier ones, 281 reconstructed files. Left in compiled Lua: GL.iNet's Lua 5.3/5.4 cloud scripts. |
| 2026-10-28 | **4.9.0's first full build (99v):** 483/483 packages, 4960/4966 files. Kernel configuration: 20 options differ, all following from `CONFIG_CFG80211=m` and `CONFIG_NET_SCH_PRIO=y` (an `olddefconfig` test with just these two gives GL.iNet's configuration exactly; no cfg80211 module is shipped, only the built-in signed-regdb crypto changes the kernel): extra commit `mt7981-cfg80211`. Also fixed: busybox without `ntpd`, `smstools3` from its own feed `gl_feed_smstools3` (packages several feeds have now come from the feed GL.iNet's control file names), empty-release versions (`1-`), `/usr/lib/lua/zoneinfo.lua` (no owner) from the image. Not public: `wireguard.ko` (GL.iNet's hotplug patch now passes the peer's public key, `peerpubkey=%s` with base64, as their published AmneziaWG patch `103-awneziawg-support-hotplug` does; no kernel version published) and `ipheth.ko` (617 bytes more). Batch run 99x queued. |
| 2026-10-28 | Lua 5.3/5.4 cloud scripts (private reconstructions): OpenWrt's arch-independent patch writes one endianness byte where standard Lua has the LUAC_INT/LUAC_NUM check values; restoring them lets unluac read the files. 88 of 143 file versions (4.7.0–4.9.0) recompile byte-identical with our patched 5.3.5/5.4.7 under the original chunk names; 54 (4.8.2/4.9.0, Lua 5.4) stop inside unluac 1.2.3.530 (a 5.4 construct it can't print), 3 need a line split. 369 reconstructed files in the private repository. |
| 2026-10-28 | Lua 5.3/5.4 with the newer unluac (2025-12-23, owner-approved): 136 of 145 release entries byte-identical, none fail in unluac; 9 left where unluac's code differs from GL.iNet's (one function each, e.g. a local's scope). 417 reconstructed files in the private repository. |
| 2026-10-28 | **4.7.4 without ccache (99k), the 4.7.4 batch run:** 458/458 packages, 5255/5255 files, kernel configuration identical; the new recipes (`black_white_list.ko`, `oopslog`, translations) identical; left only the not-public list (dnsmasq 304, `sipcalc`, iwinfo, `usbnet`, Airoha PHY, `opkg`, the known kernel functions). 4.7.4 is at 4.6.x's level, reproducible without ccache. |
| 2026-10-28 | **All of GL.iNet's compiled Lua reconstructed** (private repository, 426 files): the last 9 Lua 5.3/5.4 cloud scripts needed GL.iNet's control flow back where unluac prints other structures that compile differently or on other lines: `goto` exits (5.3), `break` inside `repeat … until true` (5.4 shortcuts only `if … then break`), `goto continue` loops printed as if/else or if/elseif chains, and `if … else … end break` (Lua chains the true branch's jump straight out of the loop). The re-layout tool now tries these forms itself and keeps the candidate that leaves the fewest conflicting lines. |
| 2026-10-28 | 4.9.0's `wireguard.ko` is public after all: GL.iNet's published AmneziaWG hotplug patch (gl-image 4.9.1, `103-awneziawg-support-hotplug`) carried over to the kernel's WireGuard (its `hotplug.c`/`.h`, the peer's static key at the three call sites) gives identical code and data (module test; only `intree=Y` differs from building out of tree): extra commit `wireguard-hotplug-peer-key` (patch `954`, test-applied after 950–953). Also from 99w (4.8.2): `libc` and mpflow now identical; `sysupgrade.conf` needs the MediaTek target's own copy changed too (it overrides the package's), fixed; 4.8.2 rerun 99y queued. |
| 2026-10-28 | 99x (4.9.0 batch) stopped in the kernel: with the cfg80211 config the kernel builds its host tool `extract-cert` against OpenWrt's static host libcrypto (LibreSSL), which needs `pthread_once`; GL.iNet's build machine has glibc 2.34+ (pthread in libc), our Ubuntu 20.04 container glibc 2.31. Build-machine patch `openwrt/gl-4.2.0-patches/linux-kernel/999-extract-cert-link-pthread.patch` (`-lpthread`), applied only when the target config has `CONFIG_CFG80211=m`; the tool embeds nothing, so the kernel is unchanged. 4.9.0 batch requeued (99z). |
| 2026-10-28 | 99z (4.9.0) stopped after 2 minutes: a short DNS outage on the M5+ during the translation downloads (the failed `git pull` at 18:21 was probably the same). The downloads now retry with waits of 2–16 s; requeued as 99za. |
| 2026-10-28 | **4.8.2 at the not-public-only level (99y):** 461/461 packages, 5189/5189 files, kernel configuration identical; `sysupgrade.conf` and the `1-` versions now as GL.iNet's; left only `sipcalc`, iwinfo, Airoha PHY, `usbnet`, `opkg` and the known kernel functions. Validation without ccache queued (99zb). C decompilation of the closed binaries (started at the owner's request with `glc`) stopped again by the safety classifier, as in the earlier attempt; nothing was produced or committed. |
| 2026-10-28 | The 176 remaining compiled Lua 5.1 files named `./files/...` (218 release entries, 4.1.1–4.9.0) recompile byte for byte after unluac and re-layout. Private repository: 644 reconstructed files (280a81b), so now really all of GL.iNet's compiled Lua (the 426 of the line above didn't include these). |
| 2026-10-28 | Second public-source search (chapter 15): 95 gl-inet/zhaojh329 repositories and a web search on 79 binary fingerprints: no new unmodified sources. iwinfo's HE table is MediaTek SDK code (hanwckf, same 192 values), but GL.iNet's library is still its own merge of it. Of the 4.9.0 MT7981 firmware only `MT7981_ePAeLNA_EEPROM.bin` is public (linux-firmware); the 2024-09-24 WM/WA/patch builds and the 2023-06-28 WO build are not. |
| 2026-10-28 | 4.9.0 `conninfra.ko` built unmodified from MediaTek's public conninfra (padavanonly 21.02 tree), byte-identical in a targeted compile. Recipe `build.mk` with 47 hashed downloads (all verified); `gen-closed-feed.py` now merges `build.mk` into kmod-only recipes too. It joins the next 4.9.0 batch. |
| 2026-10-28 | **4.9.0 batch (99za):** 483/483 packages, 4960/4960 files, kernel configuration identical; left are the known not-public parts (`opkg`, `ubusd`, iwinfo, `sipcalc`, `wg`, `usbnet`, `ipheth`, EN8811H) plus one cache effect. GL.iNet's AdGuardHome 0.107.73 embeds the web frontend of 0.107.56. The recipe downloads the frontend under an unversioned name and copies it to the versioned one only when that is missing, so GL.iNet's download cache, still holding 4.8.2's frontend, gave the old one. 99v had the same effect by chance (w2's cache) and was identical; 99za, with a fresh download, wasn't. The workflow now puts 0.107.56's release frontend (hash-checked) under 0.107.73's name. 99zc queued with this and conninfra. |
| 2026-10-28 | 4.9.0 `mtk_warp.ko`: none of 48 builds from the four public warp sources is identical; closest `5f71ec` (colgin, no leak debugging), 40 bytes of code and two bounds-check messages apart: a newer, unpublished MediaTek release. |
| 2026-10-28 | **4.8.2 validated without ccache (99zb):** 461/461 packages, 5189/5189 files, kernel configuration identical; left only the not-public parts (iwinfo, opkg, `usbnet`, EN8811H, `sipcalc`, the known kernel functions), as in 99y. |
| 2026-10-28 | **4.9.0 `mtk_warp.ko` bridged to byte-identical** (private reconstruction, owner-approved function-by-function comparison, 8 commits): MediaTek's public warp 5f71ec with chipset `mt7981` and `MTK_MEMORY_SHRINK`, built **without** OpenWrt's `-fno-caller-saves` (GL.iNet's private-feed recipe doesn't pass the KCFLAGS: 18 of the 25 differing functions were only register allocation), plus four small source changes (a second `fifo_left` query, two bounds checks with their messages, `msleep_interruptible` in the SER thread). Not public source, so it stays out of the public recipe. |
| 2026-10-28 | **`air_en8811h.ko` bridged to byte-identical** (one file in 4.6.2–4.9.0; private reconstruction, 3 commits). GL.iNet's change to the v1.2.5 driver: the probe reads the PHY IDs at MDIO address \| 8 (the device tree's 5 becomes 13, upstream's address for this PHY; message `PHY(0x%x) = %x - %x`), writes 0x180000 to PBUS register 0xcf998, then restores the original address. The bridge tool now also builds in-tree drivers as such (`intree=Y`). Still not public source, so the public recipe keeps GL.iNet's file. |
| 2026-10-28 | **`usbnet.ko` (both versions) and `ipheth.ko` bridged to byte-identical** (private reconstructions). `usbnet`: `usbnet_probe` names Quectel 2c7c:0900 `rm500u_5gnet` (4.6.2+) and from 4.7.4 also MediaTek 0e8d:2010 or product 0x2005 `simonet`. `ipheth` (4.9.0): 5.4.211's driver with 11 of the 15 upstream ipheth commits of 2023–2025 (the CDC NCM support and its fixes), without the probe error-label fix, transmit without padding, the close-order change and the carrier-modes fix, plus small 5.4 adaptations; the upstream commits are public, the selection and adaptations are GL.iNet's. 99zc failed on the new conninfra recipe (headers found through `SUBDIRS`, which the `build.mk` didn't pass); fixed, the recipe test-built in a tree copy (package identical), 99zd running. |
| 2026-10-28 | **`ubusd` (4.9.0) public after all:** GL.iNet's build carries, besides its published auto-subscribe patch, three upstream ubus security fixes of October 2025 (`d31effb`, `aa4a7ee`, `60e0404`, found by cherry-picking the later upstream `ubusd` commits one by one and in combination). Added to the `ubus-auto-subscribe` extra commit as patches 0002–0004 (test-applied with `patch -p1`): byte-identical. Privately bridged as well: `sipcalc` 4.7.4–4.9.0 (66 output literals with spaces for tabs). The not-public table now marks what's bridged. |
| 2026-10-29 | **4.9.0 (99zd):** 483/483 packages, 4960/4960 files, kernel configuration identical; AdGuardHome (0.107.56's frontend) and `conninfra.ko` (public MediaTek source) identical. Left: the not-public parts and `ubusd`, whose fix (three upstream ubus commits) came after 99zd started. 99ze: validation without ccache with that fix. |
| 2026-10-29 | **`opkg` bridged to byte-identical** (one file in 4.6.2–4.9.0; private reconstruction): GL.iNet's new command `uninstall_pkg_total_size` (sums the `Size` of a package and its not-installed dependencies, `total_size: %d`), and **no** remove-once check: their published `0001-opkg_remove-avoid-remove-pkg-repeatly…` patch is not in the binary. The same file in every release from 4.6.2 to 4.9.0, SDK-mode builds included, says GL.iNet built `opkg` once and reused it. Our recipe keeps the `opkg-remove-once` extra commit (it counts towards 4.6.2's revision); the binary differs either way until the command is public. |
| 2026-10-29 | **4.9.0 reproducible without ccache (99ze):** 483/483 packages, 4960/4960 files, kernel configuration identical, `ubusd` identical; left only the not-public parts (`opkg`, iwinfo, `sipcalc`, `usbnet`, `ipheth`, EN8811H, and the kernel functions: the Airoha link polling, `get_phy_device`, `mtk_pcie_probe`, the restart handlers, and new in 4.9.0 `spinand_probe`, not yet looked at). Every release from 4.1.1 to 4.9.0 is now at least at this level. |
