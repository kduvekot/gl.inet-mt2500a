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

- [ ] PC with a static address `192.168.1.2/24`, one cable to the router's
      **LAN** port, nothing in WAN or USB.
- [ ] Router unplugged. Hold reset, plug in power, keep holding until the LED
      has flashed about 5 times and then stays on.
- [ ] In **Chrome or Edge** (not Firefox), open `http://192.168.1.1/uboot.html`
      and upload
      `uboot-mt2500-20250224-md5-74286e770cfb041b611d80d4adaef189.bin`
      from [gl-inet/mt798x-boot](https://github.com/gl-inet/mt798x-boot/tree/main/bin).
- [ ] If it says success: open `http://192.168.1.1/` and flash stock 4.7.4.

Result: _not tried yet_. If it reports "UPDATE FAILED", go to Plan B.

## Plan B: UART with the Raspberry Pi

### What you need

- [ ] Raspberry Pi (3 or later) with Raspberry Pi OS; 64-bit is preferred
      but 32-bit works too.
- [ ] 3 female-female jumper wires. If the router's UART has bare pads, you'll
      need a 4-pin 2.54 mm header soldered on, or test hooks.
- [ ] The router's own USB-C power supply.
- [ ] An Ethernet cable between a PC and the router's LAN port, for the web
      steps later.

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

`pi-setup.sh` enables the full PL011 UART on GPIO14/15. On a Pi 3 this
moves Bluetooth off it, because the mini-UART can't hold the 921600 baud
the loader uses. It also removes the Linux serial console and installs
`picocom` and `lrzsz`.

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
- [ ] Wire it up. TX and RX cross over, and **3V3 is not connected**:

| Raspberry Pi header | Router UART |
|---|---|
| pin 6, GND | GND |
| pin 8, GPIO14 (TXD) | RX |
| pin 10, GPIO15 (RXD) | TX |

Both sides use 3.3 V logic, so no level shifter is needed. Don't use the
Pi's 5 V pins anywhere near the router.

- [ ] Sanity check, with the router not yet modified: run
      `picocom -b 115200 /dev/serial0`, power the router on, and you should
      see the BootROM/BL2/U-Boot log. If you see nothing, swap TX and RX.
      If you see garbage, check GND. Save this log: it shows the old U-Boot
      version and the MMC errors.

### 3. Load the fixed U-Boot into RAM

```sh
cd ~/mt2500-recovery-kit
./uartboot.sh
```

1. Router **unplugged**, then press Enter. The loader waits at `Handshake...`.
2. Plug in the router's power.
3. The loader sends BL2 (at 460800 baud), then the FIP (at 921600 baud).
   Wait for `NOTICE: Received FIP`.
4. The script then opens a logged console. U-Boot from RAM starts. Type `gl`
   during the countdown to stop autoboot.

- [ ] At the `MT7981>` prompt, `mmc info` shows the eMMC (about 7.3 GiB).
      **This is the decisive test.** If the new U-Boot can't see the eMMC
      either, stop: the eMMC may really be faulty.
- [ ] `gpt` (or `mmc part`) lists the partitions, including `fip`.

If the handshake never completes, try powering the router a little later or
earlier. The BootROM only listens for a short moment after power-on.
Logs are in `~/mt2500-recovery-kit/logs/`.

### 4. Write the fixed U-Boot permanently

Two known ways. Use the first; the second is a fallback.

**a) Recovery web page served by the RAM U-Boot**

- [ ] Repeat step 3, but this time after `Received FIP`, press and hold the
      router's reset button until the LED flashes about 5 times and stays on.
- [ ] From the PC (static `192.168.1.2`, LAN port), open
      `http://192.168.1.1/uboot.html` in Chrome and upload
      `fip-mt2500-20250224.bin` from the kit.

**b) `mtkupgrade fip` over XMODEM on the console**

- [ ] At `MT7981>`, run `mtkupgrade fip`, then send `fip-mt2500-20250224.bin`
      with XMODEM. In picocom: Ctrl-A Ctrl-S, then the file name.
- [ ] Confirm the write reports OK.

Either way:

- [ ] Power-cycle **without** UART loading. The console should now show the
      2025 U-Boot booting from eMMC.

### 5. Put firmware back

- [ ] Enter the recovery page again (reset-button sequence) and flash
      **stock 4.7.4** from the kit at `http://192.168.1.1/`. This proves the
      eMMC can be written and gives a known-good baseline.
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

This cloud session can't open connections to your network. To let Claude
drive the Pi directly, run Claude Code on a machine on your LAN, either
your own computer or the Pi itself with 64-bit OS, and have it SSH into the Pi.
Otherwise, run the scripts yourself: everything is logged under `logs/`, so
the logs can be committed or pasted for analysis.
