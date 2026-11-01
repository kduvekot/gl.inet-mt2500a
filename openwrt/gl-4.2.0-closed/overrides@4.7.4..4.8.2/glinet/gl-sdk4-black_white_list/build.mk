# gl-sdk4-black_white_list.ko of 4.7.4 and 4.8.2 (the same file) from GL.iNet's published source of this module
# (gl-inet/gl-image, gl-be10000, 4.8.6, GPL kernel module): built against our
# kernel like this, it's byte-identical to GL.iNet's (2026-10-28). The
# source is downloaded at a fixed commit and checked by hash.
GL_IMAGE_SRC:=https://raw.githubusercontent.com/gl-inet/gl-image/bfe99df8e1872b63aee42d2bcd98b6b093c1ccf9/versions/4.8.6/package/kernel/glinet/gl-sdk4-black_white_list/src

define Download/black-white-list-0
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=Makefile
  FILE:=black-white-list-bfe99df-Makefile
  HASH:=8adb662a6e87c8d6b9e213db3dbb797faa10193b8fbfa0a54aa69732650973a1
endef
$(eval $(call Download,black-white-list-0))

define Download/black-white-list-1
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=black_white_list.c
  FILE:=black-white-list-bfe99df-black_white_list.c
  HASH:=faeb6c12aa19ba88d9c425f2f12491250cec659500d7054121b6515e79dfae18
endef
$(eval $(call Download,black-white-list-1))

define Download/black-white-list-2
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=black_white_list.h
  FILE:=black-white-list-bfe99df-black_white_list.h
  HASH:=242565c800b7ea4986e3c0e9c5f3b7461e1f560249e9a48ccfcb6830c542139a
endef
$(eval $(call Download,black-white-list-2))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/black-white-list-bfe99df-Makefile $(PKG_BUILD_DIR)/Makefile
	$(CP) $(DL_DIR)/black-white-list-bfe99df-black_white_list.c $(PKG_BUILD_DIR)/black_white_list.c
	$(CP) $(DL_DIR)/black-white-list-bfe99df-black_white_list.h $(PKG_BUILD_DIR)/black_white_list.h
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" ARCH="$(LINUX_KARCH)" CROSS_COMPILE="$(TARGET_CROSS)" M="$(PKG_BUILD_DIR)" \
		KCFLAGS="-fmacro-prefix-map=$(BUILD_DIR)=$(notdir $(BUILD_DIR)) -fno-caller-saves" modules
	# stripped like OpenWrt's strip-kmod.sh
	$(TARGET_CROSS)objcopy -R .comment -R .pdr -R .mdebug.abi32 -R .gnu.attributes -R .reginfo -R .MIPS.abiflags \
		-R .note.GNU-stack -x -G __this_module --strip-unneeded -R .note.gnu.build-id \
		$(PKG_BUILD_DIR)/gl-sdk4-black_white_list.ko $(PKG_BUILD_DIR)/gl-sdk4-black_white_list.stripped.ko
endef

define Package/kmod-gl-sdk4-black_white_list/install-built
	# over the image's copy, keeping its mode
	cat $(PKG_BUILD_DIR)/gl-sdk4-black_white_list.stripped.ko > $(1)/lib/modules/$(LINUX_VERSION)/gl-sdk4-black_white_list.ko
endef
