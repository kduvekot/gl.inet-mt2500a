# parental_control.ko of 4.2.1 from GL.iNet's public source of this module in
# gl-inet/gl-feeds (gl-sdk4-parental-control at c6eabb9, 2023-03-25): built against
# our kernel unchanged, it's byte-identical to GL.iNet's 4.2.1 module (2026-10-29,
# 4.2.1's tree). Downloaded at that commit and checked by hash.
GL_FEEDS_PC421:=https://raw.githubusercontent.com/gl-inet/gl-feeds/c6eabb97a774dc4305fd624c833464cfb6ffef7e/gl-sdk4-parental-control/src

define Download/parental-control-421-c6eabb9-0
  URL:=$(GL_FEEDS_PC421)
  URL_FILE:=Makefile
  FILE:=parental-control-421-c6eabb9-Makefile
  HASH:=2bd8aa727335e2a919c82e6e8c2fc7fd35d805815a2a5e761a91797169af7aa5
endef
$(eval $(call Download,parental-control-421-c6eabb9-0))

define Download/parental-control-421-c6eabb9-1
  URL:=$(GL_FEEDS_PC421)
  URL_FILE:=cJSON.c
  FILE:=parental-control-421-c6eabb9-cJSON.c
  HASH:=36ccc460ca551f6877c34beb01c9dd2ed1199e5ca683ef69cd0a301f96bb09e4
endef
$(eval $(call Download,parental-control-421-c6eabb9-1))

define Download/parental-control-421-c6eabb9-2
  URL:=$(GL_FEEDS_PC421)
  URL_FILE:=cJSON.h
  FILE:=parental-control-421-c6eabb9-cJSON.h
  HASH:=d71b1b00c25fc293df86db44835a36c9a0b468357193dcb5785cd6895aac01b5
endef
$(eval $(call Download,parental-control-421-c6eabb9-2))

define Download/parental-control-421-c6eabb9-3
  URL:=$(GL_FEEDS_PC421)
  URL_FILE:=pc_app.c
  FILE:=parental-control-421-c6eabb9-pc_app.c
  HASH:=77dc3c7960e7f8fd440373da9f745c43e7fbcd755b0a308538aa567cf8b81e60
endef
$(eval $(call Download,parental-control-421-c6eabb9-3))

define Download/parental-control-421-c6eabb9-4
  URL:=$(GL_FEEDS_PC421)
  URL_FILE:=pc_config.c
  FILE:=parental-control-421-c6eabb9-pc_config.c
  HASH:=1cbe42ba05e35b327e254a33d66fe71bd05066be49fd7f059cbabdf3e7e56f3d
endef
$(eval $(call Download,parental-control-421-c6eabb9-4))

define Download/parental-control-421-c6eabb9-5
  URL:=$(GL_FEEDS_PC421)
  URL_FILE:=pc_filter.c
  FILE:=parental-control-421-c6eabb9-pc_filter.c
  HASH:=75a39de0f917d39e87b973f67fb1160492bcb7e8adb95607cf68988364c4b639
endef
$(eval $(call Download,parental-control-421-c6eabb9-5))

define Download/parental-control-421-c6eabb9-6
  URL:=$(GL_FEEDS_PC421)
  URL_FILE:=pc_policy.c
  FILE:=parental-control-421-c6eabb9-pc_policy.c
  HASH:=aa2b36757216f28dfa6eb114f10736eb84dec3ed0017ba1cbf45f7b10266cc28
endef
$(eval $(call Download,parental-control-421-c6eabb9-6))

define Download/parental-control-421-c6eabb9-7
  URL:=$(GL_FEEDS_PC421)
  URL_FILE:=pc_policy.h
  FILE:=parental-control-421-c6eabb9-pc_policy.h
  HASH:=6219d17070c2d9e1f343b9436e2f4739ff01aaef06e480cb50ad89a151fddb9b
endef
$(eval $(call Download,parental-control-421-c6eabb9-7))

define Download/parental-control-421-c6eabb9-8
  URL:=$(GL_FEEDS_PC421)
  URL_FILE:=pc_utils.c
  FILE:=parental-control-421-c6eabb9-pc_utils.c
  HASH:=061f3f7aefccac476e21a894189703724e31759c3507fe71db2cfdc17a4ff582
endef
$(eval $(call Download,parental-control-421-c6eabb9-8))

define Download/parental-control-421-c6eabb9-9
  URL:=$(GL_FEEDS_PC421)
  URL_FILE:=pc_utils.h
  FILE:=parental-control-421-c6eabb9-pc_utils.h
  HASH:=1dc5578d087cd2ba1a8b03f34658ab1ce2e8af0d5d75f510195f904893724a07
endef
$(eval $(call Download,parental-control-421-c6eabb9-9))

define Download/parental-control-421-c6eabb9-10
  URL:=$(GL_FEEDS_PC421)
  URL_FILE:=regexp.c
  FILE:=parental-control-421-c6eabb9-regexp.c
  HASH:=bcd447627d9ee2dd34ba8404e1604ff6ff235ea19a557f2cfdaaec2b48e62a1a
endef
$(eval $(call Download,parental-control-421-c6eabb9-10))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/parental-control-421-c6eabb9-Makefile $(PKG_BUILD_DIR)/Makefile
	$(CP) $(DL_DIR)/parental-control-421-c6eabb9-cJSON.c $(PKG_BUILD_DIR)/cJSON.c
	$(CP) $(DL_DIR)/parental-control-421-c6eabb9-cJSON.h $(PKG_BUILD_DIR)/cJSON.h
	$(CP) $(DL_DIR)/parental-control-421-c6eabb9-pc_app.c $(PKG_BUILD_DIR)/pc_app.c
	$(CP) $(DL_DIR)/parental-control-421-c6eabb9-pc_config.c $(PKG_BUILD_DIR)/pc_config.c
	$(CP) $(DL_DIR)/parental-control-421-c6eabb9-pc_filter.c $(PKG_BUILD_DIR)/pc_filter.c
	$(CP) $(DL_DIR)/parental-control-421-c6eabb9-pc_policy.c $(PKG_BUILD_DIR)/pc_policy.c
	$(CP) $(DL_DIR)/parental-control-421-c6eabb9-pc_policy.h $(PKG_BUILD_DIR)/pc_policy.h
	$(CP) $(DL_DIR)/parental-control-421-c6eabb9-pc_utils.c $(PKG_BUILD_DIR)/pc_utils.c
	$(CP) $(DL_DIR)/parental-control-421-c6eabb9-pc_utils.h $(PKG_BUILD_DIR)/pc_utils.h
	$(CP) $(DL_DIR)/parental-control-421-c6eabb9-regexp.c $(PKG_BUILD_DIR)/regexp.c
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" ARCH="$(LINUX_KARCH)" CROSS_COMPILE="$(TARGET_CROSS)" M="$(PKG_BUILD_DIR)" \
		KCFLAGS="-fmacro-prefix-map=$(BUILD_DIR)=$(notdir $(BUILD_DIR)) -fno-caller-saves" modules
	# stripped like OpenWrt's strip-kmod.sh
	$(TARGET_CROSS)objcopy -R .comment -R .pdr -R .mdebug.abi32 -R .gnu.attributes -R .reginfo -R .MIPS.abiflags \
		-R .note.GNU-stack -x -G __this_module --strip-unneeded -R .note.gnu.build-id \
		$(PKG_BUILD_DIR)/parental_control.ko $(PKG_BUILD_DIR)/parental_control.stripped.ko
endef

define Package/kmod-gl-sdk4-parental-control/install-built
	# over the image's copy, keeping its mode
	cat $(PKG_BUILD_DIR)/parental_control.stripped.ko > $(1)/lib/modules/$(LINUX_VERSION)/parental_control.ko
endef
