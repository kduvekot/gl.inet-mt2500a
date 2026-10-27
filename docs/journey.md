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

**4.8.2 was built without git.** Its revision is empty everywhere
(`DISTRIB_REVISION=''`, `base-files` version `1446-`, the toolchain's
version string "OpenWrt GCC 8.4.0 " in every binary): OpenWrt's `getver.sh`
returns nothing outside a git repository, so GL.iNet built 4.8.2 from an
exported tree, like the offline tree in `gl-image`; its CI build number is
in the new `/etc/version.build` (845; 4.9.0: 1048). The 222 OpenWrt-tree
packages share the build second as `SourceDateEpoch`, and missing patch
commits no longer show in the revision. AdGuardHome is built from source
from 4.8.2 on (`adguardhome-conntrack` in gl_feed_common). To do for 4.8.2:
a release value that removes the tree's git metadata before the build.

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
| 2026-10-27 | 4.6.2 at GL.iNet's revision (job 68b); musl `pthread_getname_np` backport found (identical code), two unidentified placeholders left. |
| 2026-10-27 | MDIO `reset-post-delay-us` backported (kernel side of GL.iNet's PHY reset on the MDIO bus); exact sizes, validated. |
| 2026-10-27 | 4.7.0 at GL.iNet's Jenkins path (job 69b): no build-path differences left, kernel configuration identical; busybox/dnsmasq/odhcpd carry GL.iNet patches (4.8.6 tree has them). |
