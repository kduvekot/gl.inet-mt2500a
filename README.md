# gl.inet-mt2500a

Upstream OpenWrt firmware and recovery tooling for the GL.iNet GL-MT2500 /
GL-MT2500A (Brume 2).

* **Story so far:** [docs/journey.md](docs/journey.md)
* **Firmware sources and hashes:** [docs/firmware-sources.md](docs/firmware-sources.md)
* **UART recovery with a Raspberry Pi:** [docs/recovery-uart-raspberry-pi.md](docs/recovery-uart-raspberry-pi.md)

## Workflows

| Workflow | What it does |
|---|---|
| [Build OpenWrt](.github/workflows/build-openwrt.yml) | Builds OpenWrt 25.12.6 with the official ImageBuilder for `glinet_gl-mt2500` (MaxLinear WAN PHY) and `glinet_gl-mt2500-airoha` (Airoha EN8811H WAN PHY). Pushing a `v*` tag publishes a release. |
| [Recovery kit](.github/workflows/recovery-kit.yml) | Bundles `mtk_uartboot` for the Pi, the MT7981 RAM BL2, GL.iNet's fixed 2025-02-24 U-Boot and stock firmware 4.7.4. Run it manually with *publish* ticked to update the `recovery-kit` release. |

Extra packages go in [`openwrt/packages.txt`](openwrt/packages.txt).
Configuration files to bake into the image go in `openwrt/files/`, which is
optional.

## Which image do I need?

Check the WAN PHY on the running router:

```sh
dmesg | grep -iE 'en8811|airoha|gpy|maxlinear'
```

Airoha / EN8811H → `glinet_gl-mt2500-airoha`; MaxLinear / GPY → `glinet_gl-mt2500`.
