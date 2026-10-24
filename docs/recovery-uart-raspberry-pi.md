# Recovering a GL-MT2500(A) over UART with a Raspberry Pi

Checklist for the unit whose U-Boot recovery page accepts a file but never
manages to write it. Tick the boxes as we go and note results in
[`journey.md`](journey.md).

> **Status:** prepared, not yet carried out on our unit. The procedure
> follows one documented successful recovery and GL.iNet's own guidance; our
> board may differ in details (header, timing, U-Boot prompts).

## Why this should work

The September 2022 U-Boot on early units cannot initialise the eMMC on some
boards (`Failed to initialize MMC device 0`). Its web page still runs, takes
the upload and computes an MD5, but fails when writing. In the documented case
the eMMC was fine: GL.iNet's fixed 2025-02-24 U-Boot, loaded into RAM over
UART, read the eMMC and booted Linux.

The MT7981 BootROM can receive code over UART before anything is read from
flash. So we:

1. load a RAM-only BL2 plus the fixed U-Boot into RAM (`mtk_uartboot`),
2. use that working U-Boot to write itself to the eMMC,
3. flash firmware through the now-working recovery page.

## Plan A: try first, without opening the case

This only needs the Pi prepared as in Plan B step 1: kit downloaded, and
eth0 cabled to the router's **LAN** port. Nothing goes in WAN or USB.

- [ ] Router unplugged. Hold reset, plug in power, keep holding until the LED
      has flashed about 5 times and then stays on.
- [ ] On the Pi: `cd ~/mt2500-recovery-kit && ./web-flash.sh fip`. This
      uploads the fixed U-Boot
      (`uboot-mt2500-20250224-md5-74286e770cfb041b611d80d4adaef189.bin`
      from [gl-inet/mt798x-boot](https://github.com/gl-inet/mt798x-boot/tree/main/bin)).
      With a PC instead: give it a static `192.168.1.2/24`, then open
      `http://192.168.1.1/uboot.html` in Chrome or Edge (not Firefox).
- [ ] If it succeeds:
      `./web-flash.sh firmware openwrt-mt2500-4.7.4-0328-1743128340.bin`.

Result: _not tried yet_. If it reports "UPDATE FAILED", go to Plan B.

## Plan B: UART with the Raspberry Pi

### What you need

- [ ] Raspberry Pi (3 or later) with Raspberry Pi OS; 64-bit is preferred
      but 32-bit works too. A Pi 3 is plenty for this job. Give it its own
      good 2.5 A supply.
- [ ] 3 female-female jumper wires. If the router's UART has bare pads, you'll
      need a 4-pin 2.54 mm header soldered on, or test hooks.
- [ ] Optional but recommended: a 1 kΩ resistor for the Pi TX → router RX
      wire (see step 2).
- [ ] The router's own USB-C power supply.
- [ ] An Ethernet cable from the Pi to the router's **LAN** port.
- [ ] A hard, non-conductive surface for the bare board while it's
      powered: cardboard (a flat box tray works well), wood or plastic, with
      air around it. Not packing foam, which traps heat (the SoC normally
      cools through the case), and certainly not black conductive foam, a
      silver antistatic bag or metal, which short the pads on the
      underside. Conductive foam is fine for storing the board unpowered.

### The setup

```
  phone ──WiFi── home network ──WiFi── Raspberry Pi 3
                                        │  eth0 192.168.1.2 + 192.168.8.2
                                        │  (no gateway)
                                        ├──Ethernet──► router LAN port
                                        └──UART pins─► router serial header
```

* **WiFi:** the Pi's internet connection, and how you reach it (SSH, or
  Claude via Remote Control).
* **Ethernet:** the Pi takes the place of "a PC with Chrome". It reaches
  U-Boot recovery and OpenWrt at 192.168.1.1, and GL.iNet stock firmware
  at 192.168.8.1. There's no gateway on this link, so the router never
  becomes the Pi's route to the internet. The cable can stay connected the
  whole time. WAN stays unplugged until the OpenWrt tests.
* **UART:** the serial console, and loading U-Boot into RAM.
* **Limit:** the Pi 3 B+'s Ethernet links at 1000 Mb/s, but its chip sits on
  USB 2.0, so expect about 300 Mbit/s at most (the Pi 3 Model B without the
  plus has 100 Mbit). That's fine for uploading firmware and copying
  backups, but not for measuring the router's throughput. In practice the
  SD card is slower still: a full eMMC backup was written at about
  4.5 MB/s.

### 1. Prepare the Pi

The recovery kit is built by the **Recovery kit** GitHub workflow. Run it
from the Actions tab with **publish** ticked; this creates the
`recovery-kit` release. GitHub only offers the manual "Run workflow" button
once the workflow file is on the default branch (`main`). Then on the Pi:

```sh
curl -fLO https://raw.githubusercontent.com/kduvekot/gl.inet-mt2500a/main/recovery/pi-setup.sh
chmod +x pi-setup.sh
sudo ./pi-setup.sh --download
sudo reboot
```

- [ ] After the reboot, `ls -l /dev/serial0` points to `ttyAMA0`.
- [ ] `~/mt2500-recovery-kit/` exists, and `sha256sum -c SHA256SUMS` passes inside it.

If the Pi isn't on WiFi yet:
`sudo nmcli dev wifi connect "YourSSID" password "YourPassword"`.

- [ ] `nmcli connection show mt2500-lan` shows the fixed eth0 profile.

`pi-setup.sh` enables the full PL011 UART on GPIO14/15. On a Pi 3 this
takes the UART away from Bluetooth, because the mini-UART can't hold the
921600 baud the loader uses. WiFi is not affected. The script also removes
the Linux serial console, installs `picocom`, `lrzsz` and `tmux`, and
creates the `mt2500-lan` profile for eth0 described above.

### 2. Open the router and connect the UART

- [ ] Remove the four rubber feet, loosen the four screws, take off the
      bottom cover and lift the board out
      ([CNX Software teardown](https://www.cnx-software.com/2022/11/09/gl-inet-gl-mt2500a-security-gateway-review-unboxing-teardown/)).
- [ ] While the board is out, photograph the chip next to the **WAN** port
      and read its marking: MaxLinear `GPY211` means profile
      `glinet_gl-mt2500`, Airoha `EN8811H` means `glinet_gl-mt2500-airoha`.
      This unit's chip is not necessarily the same as the replacement's.
- [ ] Find the 4-pin UART near the LAN port and read **its silkscreen
      labels**. Don't trust photos of other board revisions.
      On the old unit it's **J13**: four open through-holes at the board
      edge, labelled 3.3V (square pad), RX, TX, GND. Open holes take an
      unsoldered male header pressed in at a slight angle, male jumper
      ends, or a 2.54 mm pogo-pin clip.
- [ ] Wire it up. TX and RX cross over, and **3V3 is not connected**:

| Raspberry Pi header | Router UART |
|---|---|
| pin 6, GND | GND |
| pin 8, GPIO14 (TXD) | RX |
| pin 10, GPIO15 (RXD) | TX |

Both sides use 3.3 V logic, so no level shifter is needed. Don't use the
Pi's 5 V pins anywhere near the router.

**Why the resistor:** while the router is unpowered, the Pi's TX pin still
drives 3.3 V into the router's RX pin. That can partly power the SoC
through its input protection and cause odd boots. A 1 kΩ resistor in
series on that one wire limits the current, and it's harmless at these
baud rates. It matters most if the wires stay connected permanently.

- [ ] Sanity check, with the router not yet modified:
      `~/mt2500-recovery-kit/console.sh start`, power the router on, then
      `console.sh show`. You should see the BootROM/BL2/U-Boot log. If you
      see nothing, swap TX and RX; if you see garbage, check GND. Stop it
      with `console.sh stop`. The log in `logs/` shows the old U-Boot version
      and the MMC errors: keep it.

`console.sh` runs picocom inside tmux. You can watch it live from your
phone with `console.sh attach`, while Claude reads it with `console.sh show`
and types with `console.sh send`.

### 3. Load the fixed U-Boot into RAM

```sh
cd ~/mt2500-recovery-kit
./uartboot.sh
```

1. Router **unplugged**, then press Enter (or use `./uartboot.sh -y`). The
   loader waits at `Handshake...` for as long as it takes.
2. Plug in the router's power.
3. The loader sends BL2 (at 460800 baud), then the FIP (at 921600 baud).
   Wait for `NOTICE: Received FIP`.
4. The script starts the console in tmux and types `gl` for a few seconds
   to stop autoboot (`-n` skips that). Check with `./console.sh show`.

- [x] At the `MT7981>` prompt, `./console.sh send "mmc info"` shows the eMMC
      (about 7.3 GiB). **This is the decisive test.** If the new U-Boot
      can't see the eMMC either, stop: the eMMC may really be faulty.
      *(2026-10-24: passed, 52 MHz High Speed, 8-bit.)*
- [x] `./console.sh send "mmc part"` lists the partitions, including `fip`.

If the handshake never completes, check the wiring and that nothing else
holds the serial port. The loader keeps retrying, so the moment you power
the router on doesn't matter. Logs are in `~/mt2500-recovery-kit/logs/`.

Running Claude Code or another tmux user on the Pi? Start the kit's scripts
with `env -u TMUX`, so `console.sh` uses the default tmux server and you
can follow along with `tmux attach -t mt2500`.

### 3b. Back up the whole eMMC before writing anything

The RAM U-Boot can read the eMMC but can't send files out (no `tftpput`,
no USB). So boot an OpenWrt **initramfs** (a Linux that runs entirely from
RAM and writes nothing) over TFTP, and copy the eMMC over SSH.

**TFTP server on the Pi** (one-time setup, needs `sudo`):

```sh
sudo apt-get install -y tftpd-hpa
sudo cp -a /etc/default/tftpd-hpa /etc/default/tftpd-hpa.orig
sudo sed -i 's/^TFTP_ADDRESS=.*/TFTP_ADDRESS="192.168.1.2:69"/' /etc/default/tftpd-hpa
sudo systemctl disable --now tftpd-hpa      # only run it when needed
```

> **Warning: keep the root of `/srv/tftp` empty.** GL.iNet's U-Boot fetches
> `openwrt-gl-mt2500.bin` and `uboot-gl-mt2500.bin` from 192.168.1.2 **by
> itself** at boot (its `lf` / `lu` helpers, `mtkupgrade`) and writes them
> to the eMMC. A file with one of those names in the TFTP root would be
> flashed without asking. Put every image in a subfolder, and stop the
> server as soon as the transfer is done.

**The initramfs** (official OpenWrt 25.12.6 for the MaxLinear variant):

```sh
N=openwrt-25.12.6-mediatek-filogic-glinet_gl-mt2500-initramfs-kernel
B=https://downloads.openwrt.org/releases/25.12.6/targets/mediatek/filogic
mkdir -p ~/dl && cd ~/dl && curl -fLO $B/$N.bin
curl -fL $B/sha256sums | grep " \*$N.bin\$" > sha256sum.txt
sed 's/ \*/  /' sha256sum.txt | sha256sum -c
sudo install -d /srv/tftp/$N
sudo install -m 644 $N.bin /srv/tftp/$N/initramfs.bin
sudo install -m 644 sha256sum.txt /srv/tftp/$N/
```

**Boot it from the RAM U-Boot** (step 3 done, at `MT7981>`):

- [x] `sudo systemctl start tftpd-hpa`
- [x] `tftpboot 0x46000000 openwrt-25.12.6-mediatek-filogic-glinet_gl-mt2500-initramfs-kernel/initramfs.bin`
      → `Bytes transferred = 8017764`. Then `sudo systemctl stop tftpd-hpa`.
- [x] Optional check: `crc32 0x46000000 0x7a5764` must equal the CRC32 of
      the file on the Pi (`2065cca1` for this image).
- [x] `bootm 0x46000000`. OpenWrt comes up at 192.168.1.1, SSH as `root`
      without a password.

**Copy** (into a folder outside any public repo: boot1 holds the unit's MAC
address and serial number):

```sh
S="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.1.1"
mkdir -p -m 700 ~/mt2500-backup/$(date +%F) && cd ~/mt2500-backup/$(date +%F)
for p in boot0 boot1; do $S "cat /dev/mmcblk0$p" > mmcblk0$p.bin; done
$S 'cat /dev/mmcblk0' > mmcblk0.img        # 7.3 GiB; the Pi's SD card is the bottleneck
$S 'sha256sum /dev/mmcblk0boot0 /dev/mmcblk0boot1 /dev/mmcblk0'   # compare with sha256sum here
```

- [x] All three SHA256 values computed on the router match the copies.
      *(2026-10-24: about 25 min for the copy, 11 min for the router's hash.)*
- [ ] Keep a second copy somewhere private, off the Pi.

What's where: **boot0** holds BL2; **boot1** holds the MAC address, serial
number, DDNS ID and country code (OpenWrt reads the MAC from offset `0xa`);
the user area holds the GPT and `log`, `u-boot-env`, `rf`, `fip`, `kernel`,
`rootfs`. On this unit `log`, `u-boot-env` and `rf` were empty.

### 4. Write the fixed U-Boot permanently

Two known ways. Use the first; the second is a fallback.

**a) Recovery web page served by the RAM U-Boot**

- [ ] Repeat step 3 with `./uartboot.sh -n` (don't stop autoboot), and
      after `Received FIP` press and hold the router's reset button until
      the LED flashes about 5 times and stays on.
- [ ] From the Pi: `./web-flash.sh fip`. It only accepts the kit's FIP (by
      SHA256), uploads it, checks that the size and MD5 the router reports
      match, asks before writing, and then runs the same `/flashing.html`
      → `/result` steps as the browser.

`web-flash.sh` copies the recovery page's own JavaScript, extracted from
the U-Boot binary: `POST /upload` with field `fip` or `firmware` → reply
`"<size> <md5>"` or `fail`. It refuses the page's `bl2` and `gpt` uploads,
which would overwrite the first-stage loader and the partition table.
This has been tested against a simulated server only, not yet against the
real router.

**b) `mtkupgrade fip` over XMODEM on the console**

- [ ] At `MT7981>`, run `mtkupgrade fip`, then send `fip-mt2500-20250224.bin`
      with XMODEM. In picocom: Ctrl-A Ctrl-S, then the file name.
- [ ] Confirm the write reports OK.

Either way:

- [ ] Power-cycle **without** UART loading. The console should now show the
      2025 U-Boot booting from eMMC.

### 5. Put firmware back

- [ ] Enter the recovery page again (reset-button sequence) and flash
      **stock 4.7.4** from the kit:
      `./web-flash.sh firmware openwrt-mt2500-4.7.4-0328-1743128340.bin`.
      This proves the eMMC can be written and gives a known-good baseline.
      The stock web UI is then at `http://192.168.8.1/`, reachable from the
      Pi as well.
- [ ] Check the WAN PHY variant on **this** unit, and compare it with the
      chip marking from step 2:
      `dmesg | grep -iE 'en8811|airoha|gpy|maxlinear'`
- [ ] Only then flash our OpenWrt build for the matching profile.

### Which chip, and does it matter for recovery?

- **For recovery it doesn't matter.** GL.iNet's fixed U-Boot runs its
  recovery page on the LAN port, which uses the SoC's built-in gigabit PHY.
  The only PHY ID in the binary is `03a2.9461`, the MT7981's internal PHY,
  so it doesn't depend on the WAN chip.
- **For OpenWrt it does.** Both profiles list `glinet,mt2500-emmc` as a
  supported device, which appears to be the board name GL.iNet's firmware
  uses. So when flashing from stock firmware, the compatibility check
  probably **won't catch** the wrong image. (The Airoha image carries no
  image metadata at all.) The result would be a dead WAN port with LAN
  still working. That's recoverable by flashing the right image over LAN,
  but it's easy to avoid.
- **A guess, not a fact:** a unit that shipped with the September 2022
  U-Boot predates the Airoha revision, so it is most likely MaxLinear. The
  step 1 boot log shows the U-Boot date, and the chip marking settles it.

## Stop conditions

- Nothing on the console at all, after checking the wiring and swapping TX/RX.
- The fixed U-Boot from RAM also fails `mmc info`.
- The board's labels don't match the table above. Ask before wiring.

## Remote help

This cloud session can't open connections to your network. The plan is to
run Claude Code on the Pi itself and steer it from the phone via Remote
Control (see journey chapter 5). That session can use `console.sh`,
`uartboot.sh` and `web-flash.sh` directly. Otherwise, run the scripts
yourself: everything is logged under `logs/`, so the logs can be committed
or pasted for analysis.
