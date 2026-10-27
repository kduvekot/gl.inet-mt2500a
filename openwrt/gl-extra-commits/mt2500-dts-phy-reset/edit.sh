#!/bin/sh
# 4.6.2+ device tree (one tree for the GPY211 and the Airoha EN8811H unit):
# the WAN PHY's reset moves from the PHY node (600 us / 20 ms) to the MDIO
# bus (100 ms / 100 ms), and the PHY node becomes a generic C45 PHY. Our
# construction, matching GL.iNet's 4.6.2 device tree property by property
# (decompiled, in source order).
set -e
python3 - target/linux/mediatek/files-5.4/arch/arm64/boot/dts/mediatek/mt7981-gl-mt2500.dts << 'PY'
import sys
p = sys.argv[1]; s = open(p).read()
reps = [
    ("\tmdio: mdio-bus {\n\t\t#address-cells = <1>;\n\t\t#size-cells = <0>;\n",
     "\tmdio: mdio-bus {\n\t\t#address-cells = <1>;\n\t\t#size-cells = <0>;\n"
     "\t\treset-gpios = <&pio 14 1>;\n\t\treset-delay-us = <100000>;\n\t\treset-post-delay-us = <100000>;\n"),
    ("\t\tphy5: phy@5 {\n\t\t\tcompatible = \"ethernet-phy-id67c9.de0a\";\n\t\t\treg = <5>;\n"
     "\t\t\treset-gpios = <&pio 14 1>;\n\t\t\treset-assert-us = <600>;\n\t\t\treset-deassert-us = <20000>;\n\t\t};\n",
     "\t\tphy5: phy@5 {\n\t\t\tcompatible = \"ethernet-phy-ieee802.3-c45\";\n\t\t\treg = <5>;\n\t\t};\n"),
]
for old, new in reps:
    assert s.count(old) == 1, old
    s = s.replace(old, new)
open(p, "w").write(s)
PY
