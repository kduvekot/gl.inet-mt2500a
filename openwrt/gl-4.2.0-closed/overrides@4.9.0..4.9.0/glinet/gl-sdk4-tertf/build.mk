# gl-sdk4-tertf.ko (4.9.0) from GL.iNet's published source of this module (gl-inet/gl-image,
# gl-mt3600be, versions/4.9.0, GPL kernel module): built against our kernel like
# this, it's byte-identical to GL.iNet's (2026-10-29). The source is downloaded
# at a fixed commit and checked by hash.
GL_IMAGE_KSRC:=https://raw.githubusercontent.com/gl-inet/gl-image/617e1f1d8f3cce672a63a3c59bb15003094652f3/versions/4.9.0/package/glinet/gl-sdk4-tertf/src

define Download/tertf-ko0
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=Makefile
  FILE:=tertf-617e1f1-Makefile
  HASH:=f8be1261597e11a8c5a07f0da4c951aeee5387bbdd44899800f9981af7759026
endef
$(eval $(call Download,tertf-ko0))

define Download/tertf-ko1
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=main.c
  FILE:=tertf-617e1f1-main.c
  HASH:=1444d0ccaf17f4c8c47af1cb7ea24082dd45643696ad39c03e54ecae1f3c9f24
endef
$(eval $(call Download,tertf-ko1))

define Download/tertf-ko2
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=subnet.c
  FILE:=tertf-617e1f1-subnet.c
  HASH:=4eb0fae32f7248bca81015c42470bfeb617edcb31af6a10d7405312a2aee7c0e
endef
$(eval $(call Download,tertf-ko2))

define Download/tertf-ko3
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=subnet.h
  FILE:=tertf-617e1f1-subnet.h
  HASH:=4d8e0669a465b18f8a0996e1397ba4017ec6ea8c5ec6203c64df01d73d546e78
endef
$(eval $(call Download,tertf-ko3))

define Download/tertf-ko4
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=term.c
  FILE:=tertf-617e1f1-term.c
  HASH:=7f64df7aba03dd62b49c34773a79827aad4b541a582727f02639e8bfff9bd139
endef
$(eval $(call Download,tertf-ko4))

define Download/tertf-ko5
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=term.h
  FILE:=tertf-617e1f1-term.h
  HASH:=c10d5caf222530bfaa7e73e16f2aa0aee036045dc7c3c9fd5767af40b0d0a46d
endef
$(eval $(call Download,tertf-ko5))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/tertf-617e1f1-Makefile $(PKG_BUILD_DIR)/Makefile
	$(CP) $(DL_DIR)/tertf-617e1f1-main.c $(PKG_BUILD_DIR)/main.c
	$(CP) $(DL_DIR)/tertf-617e1f1-subnet.c $(PKG_BUILD_DIR)/subnet.c
	$(CP) $(DL_DIR)/tertf-617e1f1-subnet.h $(PKG_BUILD_DIR)/subnet.h
	$(CP) $(DL_DIR)/tertf-617e1f1-term.c $(PKG_BUILD_DIR)/term.c
	$(CP) $(DL_DIR)/tertf-617e1f1-term.h $(PKG_BUILD_DIR)/term.h
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
