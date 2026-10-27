#!/bin/sh
# Airoha EN8811H 2.5G PHY (WAN chip of the MT2500's Airoha variant), as in
# GL.iNet's 4.6.2+: driver v1.2.5 (GL.iNet's module reports v1.2.5), its
# kernel patch and PHY firmware from MediaTek's feed at 3d921e1 (2024-04-01;
# GL.iNet's mirror), the package definition of MediaTek's 004da0a. The files
# are fetched and checked, not stored here (the firmware is MediaTek's).
# Our construction: the package also installs the firmware, as GL.iNet's
# kmod-phy-air_en8811h does (MediaTek ships it in base-files).
set -e
R=https://raw.githubusercontent.com/gl-inet/mtk-openwrt-feeds/3d921e11b1eb7cd918a911bc18761d841cfa1133/21.02/files/target/linux/mediatek
T=target/linux/mediatek
fetch() {   # <path below $R> <destination> <sha256>
	mkdir -p "$(dirname "$2")"
	curl -fsSL --retry 5 -o "$2" "$R/$1"
	echo "$3  $2" | sha256sum -c -
}
fetch files-5.4/drivers/net/phy/air_en8811h.h $T/files-5.4/drivers/net/phy/air_en8811h.h 9641a129b13f2c5bd7b0145e3330a9b3955a24e5bba1b139d0f9dbb883d05c21
fetch files-5.4/drivers/net/phy/air_en8811h_api.c $T/files-5.4/drivers/net/phy/air_en8811h_api.c a4790d054fddc4eb345288fce5d27a4990d93c5f15e92a6e04ed5c32fba75f0d
fetch files-5.4/drivers/net/phy/air_en8811h_api.h $T/files-5.4/drivers/net/phy/air_en8811h_api.h 18965e180c466337ca54e93b8c5ac74a4b2aca1a8f51fe2241fb43b3de687be9
fetch files-5.4/drivers/net/phy/air_en8811h_main.c $T/files-5.4/drivers/net/phy/air_en8811h_main.c b21ad67fa277e372fa57803609946d16a72fdc710fe4171d2e7ada33cf03b09d
fetch patches-5.4/999-2704-en8811h-2p5gphy-support.patch $T/patches-5.4/999-2704-en8811h-2p5gphy-support.patch 5dad7d41de61acfd1cc44231086f4934053981e4895ce489676e2836e06c3cc0
fetch mt7981/base-files/lib/firmware/EthMD32.dm.bin $T/en8811h-firmware/EthMD32.dm.bin c4212623112b7e55fe677d56ca77c859ad30d34619984d881e2225a92bdbcd72
fetch mt7981/base-files/lib/firmware/EthMD32.DSP.bin $T/en8811h-firmware/EthMD32.DSP.bin 05c4abe35d3838a2d106db796c5a7058d4c2edd74ac545bbef256382459828fd
grep -q "CONFIG_AIROHA_EN8811H_PHY" $T/mt7981/config-5.4 || \
	sed -i 's/^\(CONFIG_AIROHA_EN8801SC_PHY=y\)$/\1\n# CONFIG_AIROHA_EN8811H_PHY is not set/' $T/mt7981/config-5.4
grep -q "AIROHA_EN8811H_PHY" $T/mt7981/config-5.4
cat >> $T/modules.mk << 'MK'

define KernelPackage/phy-air_en8811h
  SUBMENU:=Network Devices
  TITLE:=Airoha EN8811H PHY driver
  DEPENDS:=@TARGET_mediatek
  KCONFIG:= \
	CONFIG_AIROHA_EN8811H_PHY \
	CONFIG_AIROHA_EN8811H_PHY_DEBUGFS=y
  FILES:= \
	$(LINUX_DIR)/drivers/net/phy/air_en8811h.ko
  AUTOLOAD:=$(call AutoLoad,20,air_en8811h,1)
endef

define KernelPackage/phy-air_en8811h/description
  kernel modules for Airoha EN8811H PHY driver
endef

define KernelPackage/phy-air_en8811h/install
	$(INSTALL_DIR) $(1)/lib/firmware
	$(INSTALL_DATA) $(TOPDIR)/target/linux/mediatek/en8811h-firmware/EthMD32.dm.bin \
		$(TOPDIR)/target/linux/mediatek/en8811h-firmware/EthMD32.DSP.bin $(1)/lib/firmware/
endef

$(eval $(call KernelPackage,phy-air_en8811h))
MK
