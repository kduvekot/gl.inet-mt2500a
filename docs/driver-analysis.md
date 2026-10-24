# What GL.iNet's firmware does with the hardware, versus upstream OpenWrt

How GL.iNet's firmware (MediaTek SDK, Linux 5.4.211) and upstream OpenWrt
25.12 (mainline drivers, Linux 6.12) drive the same MT7981 hardware, and
where they differ. Findings from 2026-10-24/25. The plan is in
[driver-analysis-plan.md](driver-analysis-plan.md).

Marks: **our inference** means we read it from code or registers but no
source says it outright. Everything else was checked in source or on a unit.

## How we analysed

| Phase | What | Status |
|---|---|---|
| A | Read-only baseline on a running GL.iNet 4.7.4 (old unit): `mii_mgr -g`, `mii_mgr_cl45` (hex arguments), `regs`, debugfs, `dmesg` | done |
| B | Code reading on the Pi: vendor tree (SDK 7.6.6.1 plus GL.iNet patches) against Linux 6.12.112 plus OpenWrt patches | done (B1 to B4) |
| C | Same measurements on upstream OpenWrt on the old unit | waiting (GMKtec peer next week) |
| D | Closed modules (`mtfwd`, `mtqos`, `fwdd`, `kmwan`, `black_white_list`, `gl-mpflow`) in depth, with the recreated toolchain | optional, not started |

No register was written in phase A. Raw logs and the eMMC backup stay on the
Pi.

## WAN PHY: MaxLinear GPY211

| | GL.iNet (vendor) | Mainline / OpenWrt |
|---|---|---|
| Driver | `gpy211.c`, 71 lines | `mxl-gpy.c`, about 1070 lines |
| Does | feature setup, one write to MMD 30 (VEND1) register 8, a 1000 ms wait for the PHY firmware | firmware mailbox, link and speed handling, SGMII mode switching, WoL, hwmon, interrupts |
| SGMII in-band | cleared by writing `0xa4fa` to VEND1 reg 8; PHY stays in 2500base-x with rate adaption | switches the host interface 2500base-x or SGMII with the speed |

Live on 4.7.4 with a 1 Gbit/s link: VEND1 reg 8 = `0x24FA`, PHY_MIISTAT
(reg 0x18) = `0x053A`.

In-band SGMII status support in mainline `mxl-gpy`: commit 9da9633 (Daniel
Golle, 2026-01-10, mainline v7.0).

| OpenWrt | Kernel | Has that commit |
|---|---|---|
| 25.12.6 | 6.12 | **no.** Still carries patches 732 and 750 that switch off SGMII in-band autonegotiation as a stopgap |
| main | 6.18 | **yes** (backport 730-11-v7.0; 732 and 750 removed) |

GL.iNet's patches around this PHY: `0403`, `3003` (link polling), `3006`
(drops the `SGMII_FIXED_2G5` bit), `3007` (HSGMII link-down fix).

## Ethernet and SGMII

- **Fixed link.** On 4.7.4 the WAN port `eth0` runs "fixed/2500base-x". GL
  patch `3003` keeps phylink's fixed-link mode but takes link, speed and
  duplex from the PHY: it reads PHY_MIISTAT over MDIO. The PHY address 5 is
  hard-coded in that callback.
- **Rate adaption.** In 2500base-x the vendor code programs 1000 line speed
  when the PHY reports 100 Mbit/s, so the PHY paces the data.
- **Vendor PCS (`mtk_sgmii.c`).** For 1000/2500base-x it forces the mode on
  every `mac_config`: power-down, software reset, speed bits, AN off, no link
  timer. GL patch `3007` adds a PCS reset after the power-down.
- **Mainline PCS (`pcs-mtk-lynxi.c`).** Configures only when the interface
  changes. It can run autonegotiation also for 2500base-x and writes the link
  timer. OpenWrt patch `750` removes AN for 2500base-x again, and `732` keeps
  `mxl-gpy` from using in-band status.
- **Likely main difference (our inference).** Upstream still switches the
  interface between 2500base-x and SGMII when the speed changes, so the PCS
  is power-cycled and reset on every change. The vendor interface never
  changes.
- **MAC.** The vendor driver already sets the RX FIFO clear-disable bit (bit
  12 of MCR), which mainline added as a fix; both agree on that.

## Hardware NAT and QoS

| Feature | GL.iNet `mtkhnat` | Mainline PPE |
|---|---|---|
| Trigger | own netfilter hooks and conntrack | flowtable via `ndo_setup_tc` (nft `flags offload`) |
| IPv4 NAPT, VLAN, PPPoE | yes | yes |
| IPv6 routing | yes (GL toggle `ipv6_en`) | yes |
| IPv6 NAT | no | no |
| DS-Lite, 6RD, MAP-E | yes | no (enum values only) |
| Multicast | code present, disabled in the build (our inference) | no |
| Hardware QoS | QDMA: 4 schedulers, 16 queues, rates and weights, queue chosen by `skb->mark` | one fixed queue per flow, not configurable |
| Per-flow accounting | v2/v4 only | yes |
| Configuration | debugfs read/write, closed `mtqos` and `mtfwd` | nft; debugfs read-only |

GL patches: `3004` hard-codes the MT2500 port layout (LAN on GMAC2, WAN on
GMAC1), `3009` adds the IPv6 offload switch, `3010` fixes stale entries on a
neighbour change.

**Missing upstream (MT2500, no Wi-Fi):**

- Hardware shaping and scheduling in QDMA. Use software SQM/CAKE instead
  (CPU cost).
- Hardware offload of DS-Lite, 6RD and MAP-E tunnels (software path).
- Runtime tuning through debugfs.
- Automatic offload: upstream needs firewall4 `flow_offloading` and
  `flow_offloading_hw` switched on (our inference).

`mtfwd` and `mtqos` have no references in the hnat source. That `mtqos`
sets the marks and queue settings is our inference; phase D would tell.

## eMMC

- **Root cause of the stuck unit.** The 2022 U-Boot cannot initialise the
  eMMC (`-110` / `-524`). GL.iNet's 2025-02-24 U-Boot raises the eMMC pin
  drive strength from 4-6 mA to 12 mA, and then reads it.
- **Linux clock.** GL.iNet 4.1.1 to 4.6.8 run the eMMC at 52 MHz. From
  4.7.0 the device tree lowers `max-frequency` to 26 MHz (so we measured 26
  MHz live on 4.7.4). 4.7.4 also sets 12 mA drive strength on the eMMC pins
  in the device tree.
- **Card limit?** No. The card reports HS200/HS400 (EXT_CSD DEVICE_TYPE
  `0x57`), so 26 MHz is a board-level choice. This replaces our earlier
  guess that the card only does HS_26.
- **Upstream.** OpenWrt took both changes from GL.iNet in commit f7735158f3
  (April 2025, Yin Ni, GL.iNet): 12 mA drive strength and
  `max-frequency = <26000000>`. The message says only "use 26 MHz as the
  maximum clock". No measurement is linked.
- **Cost.** At 26 MHz, 8 bit, SDR the theoretical peak is 26 MB/s (our
  estimate: 15 to 20 MB/s in practice). Not needed for routing.

## Airoha EN8811H (replacement unit)

- PHY ID `03a2:a411`, found at MDIO address **5** (address 13 reads 0), on
  GL.iNet 4.7.13, board name `glinet,mt2500-emmc`. Kernel log: `Airoha
  EN8811H mdio-bus:05: PHY(0xd) = 3a2 - a411`; firmware `EthMD32.dm.bin` and
  `EthMD32.DSP.bin` loaded ("Bootmode: Download Code").
- GL.iNet's device tree (4.6.2 onward, one for both hardware variants) has
  `phy@5`, compatible `ethernet-phy-ieee802.3-c45`.
- Upstream `mt7981b-glinet-gl-mt2500-v2.dts` (commit 8d30e07180, 2025-05-14,
  Matthew Bilker) uses `reg = <13>`. So upstream's address does not match
  GL.iNet's firmware or this unit; probably wrong at least for units like
  this. A report upstream is possible.
- Both drivers use address + 8 for the chip's internal bus (mainline
  `EN8811H_PBUS_ADDR_OFFS 8`). The log's `0xd` fits 5 + 8 (our inference).

Reset timing differs:

| | Where | Assert | After deassert |
|---|---|---|---|
| GL.iNet 4.6.2 onward | MDIO bus, GPIO 14 | `reset-delay-us` 100000 | `reset-post-delay-us` 100000 |
| Upstream `.dtsi` | shared, GPIO 14 | `reset-delay-us` 600 | `reset-post-delay-us` 20000 |

GL.iNet's earlier firmware (before 4.6.2) put the reset on the PHY node
(assert 600 us, deassert 20 ms), the same as upstream today.

**Before flashing upstream on the replacement unit:**

1. Have a way back ready: an eMMC backup and the UART. Try upstream on the
   old unit (MaxLinear profile) first; the replacement is the working one.
2. Boot the Airoha profile's initramfs (nothing written) and see whether the
   kernel finds the PHY, and at which address.
3. If the PHY is at 5 and upstream looks at 13, expect no WAN with the stock
   upstream device tree; a corrected device tree (or an upstream fix) comes
   first.

## Who maintains what

From the Linux `MAINTAINERS` file (kernel.org):

| Driver | Maintainers |
|---|---|
| `mtk_eth_soc` | Felix Fietkau, Lorenzo Bianconi |
| `mxl-gpy` | Xu Liang (maxlinear.com, status Supported) |
| `pcs-mtk-lynxi` | Alexander Couzens, Daniel Golle |
| `mtk-sd` (eMMC) | Chaotian Jing (mediatek.com) |

## Firmware versions timeline

16 GL.iNet versions (the 15 published ones, 4.1.1 to 4.9.0_beta3, plus 4.7.13) were compared: kernel image,
embedded kernel config, device tree, modules and firmware files. All run
Linux 5.4.211.

| Version | Hardware-layer change |
|---|---|
| 4.2.0 | Device tree: USB port list and `flash_size`. `mtkhnat`, `mtfwd`, `mtqos` rebuilt |
| 4.2.1 | Device tree again (USB) |
| 4.5.0 | Shortcut-FE modules added; `mtkhnat` changed |
| 4.5.16 | Outlier: kernel built with only 148 modules (`=m`) against about 910 elsewhere; the "923/928 config changes" in the raw table are this artefact |
| 4.6.2 | **Big one.** EN8811H support (`air_en8811h`, PHY firmware files); PHY node compatible `ethernet-phy-id67c9.de0a` becomes generic `ethernet-phy-ieee802.3-c45`; PHY reset moves from the PHY node (assert 600 us, deassert 20 ms) to the MDIO bus (GPIO 14, 100 ms and 100 ms). `mtkhnat`, `mtfwd`, `mtqos` last changed here |
| 4.7.0 | eMMC `max-frequency` 52 to 26 MHz; `usb3-bus-dev`; extra conntrack helpers |
| 4.7.4 | eMMC pin drive strength 12 mA; ramoops at `0x42ff0000` |
| 4.7.13 | (unpublished) same kernel config and EN8811H driver as 4.7.4; only `kmwan`, `parental_control`, `nf_nat` differ |
| 4.8.2 | More helpers (FTP), `veth` |
| 4.9.0_beta3 | MediaTek Wi-Fi drivers and firmware shipped (`mt_wifi`, `mtk_warp`) although the MT2500 has no Wi-Fi |

The package version of the hnat, fwd and qos modules stays `5.4.211-1`
throughout; only the files change. The EN8811H driver and PHY firmware never
change between 4.6.2 and 4.9.0_beta3.

## Open questions

- Does upstream's address 13 work on the replacement unit? Report upstream?
- Which vendor/mainline difference matters most for the WAN link on
  upstream (the PCS power cycle on a speed change is our best guess)?
- Does 52 MHz work reliably on upstream, given the card supports it? Why
  did GL.iNet lower it in 4.7.0?
- What do the closed `mtfwd`, `mtqos` and `fwdd` do exactly (phase D)?
- Does mainline `mxl-gpy` from OpenWrt main (kernel 6.18) fix the WAN link on
  the old unit (phase C)?
