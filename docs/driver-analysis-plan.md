# Plan: MediaTek's drivers versus the open-source ones

How GL.iNet's firmware (MediaTek SDK, Linux 5.4.211) and upstream OpenWrt
(mainline drivers, Linux 6.12) drive the same MT7981 hardware, and where they
differ. Written 2026-10-24, before starting; results go into
`docs/driver-analysis.md` as each phase finishes.

## Questions

1. **WAN PHY (MaxLinear GPY211C, 2.5G):** how does each driver initialise the
   chip, set up the SGMII/2500base-x link to the SoC, and detect link
   changes? Upstream users report packet loss and lost links on this port
   (24.10); GL.iNet carries four patches for it (`0403`, `3003`, `3006`,
   `3007`). What does the vendor side do that mainline doesn't?
2. **Ethernet MAC and SGMII PCS:** which settings differ (speed, in-band
   status, auto-negotiation, flow control, offload features)?
3. **Hardware NAT (PPE):** MediaTek's `mtkhnat` + `mtfwd` + `mtqos` against
   mainline's PPE with nftables flowtable offload. What's accelerated, what
   QoS exists in hardware, what's missing upstream?
4. **eMMC:** GL.iNet runs it at 52 MHz, upstream's device tree caps it at
   26 MHz. Why, and does it matter?
5. **Closed modules** (`mtfwd`, `mtqos`, `fwdd`, `kmod-gl-sdk4-*`): what do
   they hook into and expose?

## Ground rules

- **Read only.** No register writes: `mii_mgr`/`mii_mgr_cl45` only with
  `-g`, never `-s`; `regs` only to read; no `ethtool -s`, no module
  reloads. Some PHY status bits are latched and clear when read; that's
  harmless, and each dump notes it.
- **One step at a time,** each command and its output logged on the Pi
  (`~/mt2500-analysis/<date>/`), master copy on the NAS share.
- **The public repo gets sanitized copies only:** the unit's MAC addresses
  (from boot1, also derived +1…+3) and serial number are replaced before
  anything is committed, as with the earlier logs.
- **Same conditions on both firmwares:** each dump is taken with WAN
  unplugged, then with a 1G peer, then (if available) a 2.5G peer, after
  the link has been up for at least a minute.
- **Changing firmware is a separate decision.** Phase C needs an explicit
  go; the eMMC backup and the UART route are the way back.

## Phase A: baseline on GL.iNet 4.7.4 (running now)

Tools already on the router: `mii_mgr`, `mii_mgr_cl45`, `regs`, `switch`,
`ethtool`, `tc`; debugfs (`hnat`, `mtketh`, `mmc0`, `regmap`, `clk`) and
`/proc/mtketh/`. Loaded: `mtkhnat`, `mtfwd`, `mtqos`, `air_en8811h`, GL.iNet's
`gl_sdk4_*`, `kmwan`.

| Step | What | How |
|---|---|---|
| A1 | System | `uname -a`, `/proc/cmdline`, full `dmesg`, `lsmod`, `/sys/firmware/fdt` (the live device tree), `/proc/config.gz` if present |
| A2 | Ethernet ports | `ethtool -i/-k/-a/-S` and plain `ethtool` on `eth0` (WAN) and `eth1` (LAN); `ip -d link`; `/proc/mtketh/*`; debugfs `mtketh/*` |
| A3 | GPY211 registers | Clause 22 registers 0–31 (`mii_mgr -g -p 5 -r N`); Clause 45 MMDs 1 (PMA/PMD), 3 (PCS), 7 (AN), 30/31 (vendor, incl. SGMII control and firmware version), at the addresses the drivers use (list taken from both drivers in phase B1) |
| A4 | SGMII/PCS block in the SoC | debugfs `regmap/*sgmii*`; or `regs` at the SGMII base from the device tree |
| A5 | Hardware NAT | debugfs `hnat/*` (entries, configuration, counters); `/sys/module/{mtkhnat,mtfwd,mtqos}/parameters/*` |
| A6 | eMMC | debugfs `mmc0/ios` (clock, timing, bus width), `mmc0/*`; `/sys/block/mmcblk0/` |
| A7 | Closed modules | on the Pi, from the firmware archive: `modinfo`-style fields, exported/imported symbols, strings of `mtfwd.ko`, `mtqos.ko`, `fwdd`, `gl-sdk4-*.ko` |

Output: one log per step and condition, plus a summary table.

## Phase B: source comparison (on the Pi, no router needed)

Vendor side: patch `0002-init-from-mediatek-sdk-v7.6.6.1` and GL.iNet's
patches (fork tag used for 4.2.0, and main). Open side: Linux 6.12 as used by
OpenWrt 25.12.6, including OpenWrt's own patches for `mediatek`.

| Block | Vendor (SDK, 5.4) | Mainline (6.12) |
|---|---|---|
| B1 WAN PHY | `drivers/net/phy/gpy211.c` + GL patches `0403`, `3006` | `drivers/net/phy/mxl-gpy.c` |
| B2 Ethernet + SGMII | `drivers/net/ethernet/mediatek/mtk_eth_soc.c`, `mtk_sgmii.c` + GL `3003`, `3007` | `mtk_eth_soc.c`, `drivers/net/pcs/pcs-mtk-lynxi.c` |
| B3 Hardware NAT | `drivers/net/ethernet/mediatek/mtk_hnat/` | `mtk_ppe.c`, `mtk_ppe_offload.c` |
| B4 eMMC | `drivers/mmc/host/mtk-sd.c` (SDK) + device tree | `mtk-sd.c` + OpenWrt device tree (`max-frequency = <26000000>`) |

Method per block: init sequence, link handling, register writes the vendor
side does that mainline doesn't (and the reverse), workarounds and their
comments, known errata. Output: a description per block, with the register
addresses that feed back into A3/A4 and C.

## Phase C: the same measurements on upstream OpenWrt (needs a go)

1. Flash upstream 25.12.6 `glinet_gl-mt2500` (MaxLinear profile; it accepts
   GL.iNet's `glinet,mt2500-emmc` as compatible) on the old unit.
2. Repeat A1–A6 with upstream's tools (`ethtool`, debugfs, `mdio-tools` or
   `phytool` for the PHY), same conditions.
3. Compare register by register with the baseline.
4. WAN tests: link stability over hours (`ping` with loss statistics, link
   flaps in `dmesg`), with and without hardware flow offloading. Throughput
   needs a peer faster than the Pi (~300 Mbit/s).
5. Way back: GL.iNet 4.7.4 via sysupgrade or the recovery page, or the
   eMMC backup over UART.

## Phase D: closed modules in depth (optional)

Only if A7 leaves important questions: disassembly of `mtfwd.ko` /
`mtqos.ko` for interoperability (allowed in the EU for that purpose, as far
as we know; not legal advice).

## Deliverables

- `docs/driver-analysis.md`: findings per question, with sources.
- Sanitized logs in `docs/logs/`; raw logs on the Pi and the NAS.
- A journey chapter and logbook lines per finished phase.

## Order

A (baseline now) → B1/B2 (WAN-related source first) → A3/A4 again with the
register list from B1 → B3/B4 → decision on C → C → D if needed.
