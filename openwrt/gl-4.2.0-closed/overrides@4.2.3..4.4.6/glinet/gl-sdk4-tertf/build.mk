# gl-sdk4-tertf.ko (4.2.3-4.4.6) from GL.iNet's public source of this module in
# gl-inet/gl-feeds (commit 86d1e06, 2022-11-28, before "remove parental-control and
# tertf" in 4.2.3's feed revision): built against our kernel unchanged, it's
# byte-identical to GL.iNet's 4.2.3-4.4.6 module (2026-10-29, 4.4.6's tree). The
# source is downloaded at a fixed commit and checked by hash.
GL_FEEDS_TERTF:=https://raw.githubusercontent.com/gl-inet/gl-feeds/86d1e06d57b37c97e89c016c6291378490791123/gl-sdk4-tertf/src

define Download/tertf-ko0
  URL:=$(GL_FEEDS_TERTF)
  URL_FILE:=Makefile
  FILE:=tertf-423-86d1e06-Makefile
  HASH:=f8be1261597e11a8c5a07f0da4c951aeee5387bbdd44899800f9981af7759026
endef
$(eval $(call Download,tertf-ko0))

define Download/tertf-ko1
  URL:=$(GL_FEEDS_TERTF)
  URL_FILE:=main.c
  FILE:=tertf-423-86d1e06-main.c
  HASH:=289bd6ec59e4cb81f5f861be7ee6e701b03855a457cf5a31550db3c32c740dff
endef
$(eval $(call Download,tertf-ko1))

define Download/tertf-ko2
  URL:=$(GL_FEEDS_TERTF)
  URL_FILE:=subnet.c
  FILE:=tertf-423-86d1e06-subnet.c
  HASH:=52ec0943d902dd63174224d9e39824821bf4396ab024f721516b8ed87171933d
endef
$(eval $(call Download,tertf-ko2))

define Download/tertf-ko3
  URL:=$(GL_FEEDS_TERTF)
  URL_FILE:=subnet.h
  FILE:=tertf-423-86d1e06-subnet.h
  HASH:=4d8e0669a465b18f8a0996e1397ba4017ec6ea8c5ec6203c64df01d73d546e78
endef
$(eval $(call Download,tertf-ko3))

define Download/tertf-ko4
  URL:=$(GL_FEEDS_TERTF)
  URL_FILE:=term.c
  FILE:=tertf-423-86d1e06-term.c
  HASH:=fba66681c9112588281d38087b3821fb6f6f8ba58d52408e0470122b5b5fa371
endef
$(eval $(call Download,tertf-ko4))

define Download/tertf-ko5
  URL:=$(GL_FEEDS_TERTF)
  URL_FILE:=term.h
  FILE:=tertf-423-86d1e06-term.h
  HASH:=18533abb82577989472923a95acfcb0be68a322106b0076e1344f5f79f102084
endef
$(eval $(call Download,tertf-ko5))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/tertf-423-86d1e06-Makefile $(PKG_BUILD_DIR)/Makefile
	$(CP) $(DL_DIR)/tertf-423-86d1e06-main.c $(PKG_BUILD_DIR)/main.c
	$(CP) $(DL_DIR)/tertf-423-86d1e06-subnet.c $(PKG_BUILD_DIR)/subnet.c
	$(CP) $(DL_DIR)/tertf-423-86d1e06-subnet.h $(PKG_BUILD_DIR)/subnet.h
	$(CP) $(DL_DIR)/tertf-423-86d1e06-term.c $(PKG_BUILD_DIR)/term.c
	$(CP) $(DL_DIR)/tertf-423-86d1e06-term.h $(PKG_BUILD_DIR)/term.h
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" ARCH="$(LINUX_KARCH)" CROSS_COMPILE="$(TARGET_CROSS)" M="$(PKG_BUILD_DIR)" \
		KCFLAGS="-fmacro-prefix-map=$(BUILD_DIR)=$(notdir $(BUILD_DIR)) -fno-caller-saves" modules
	# stripped like OpenWrt's strip-kmod.sh
	$(TARGET_CROSS)objcopy -R .comment -R .pdr -R .mdebug.abi32 -R .gnu.attributes -R .reginfo -R .MIPS.abiflags \
		-R .note.GNU-stack -x -G __this_module --strip-unneeded -R .note.gnu.build-id \
		$(PKG_BUILD_DIR)/gl-sdk4-tertf.ko $(PKG_BUILD_DIR)/gl-sdk4-tertf.stripped.ko
endef

define Package/kmod-gl-sdk4-tertf/install-built
	# over the image's copy, keeping its mode
	cat $(PKG_BUILD_DIR)/gl-sdk4-tertf.stripped.ko > $(1)/lib/modules/$(LINUX_VERSION)/gl-sdk4-tertf.ko
endef
