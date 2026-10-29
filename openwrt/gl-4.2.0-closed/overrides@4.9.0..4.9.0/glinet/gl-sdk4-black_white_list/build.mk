# gl-sdk4-black_white_list.ko (4.9.0) from GL.iNet's published source of this module (gl-inet/gl-image,
# gl-mt3600be, versions/4.9.0, GPL kernel module): built against our kernel like
# this, it's byte-identical to GL.iNet's (2026-10-29). The source is downloaded
# at a fixed commit and checked by hash.
#
# 4.9.0: the package's compiled Lua (/usr/lib/oui-httpd/rpc/black_white_list)
# from GL.iNet's published source of the next release (gl-inet/gl-image,
# gl-be14000 4.9.1), compiled like GL.iNet's recipe (luac in the package
# folder, chunk name ./files/<name>.lua): byte-identical (2026-10-28).
GL_IMAGE_SRC:=https://raw.githubusercontent.com/gl-inet/gl-image/0649a9d7514a4c51a0f035057014d70952319bfa/versions/4.9.1/package/kernel/glinet/gl-sdk4-black_white_list/files
PKG_BUILD_DEPENDS:=lua/host

define Download/black-white-list-lua0
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=black_white_list.lua
  FILE:=black-white-list-0649a9d-black_white_list.lua
  HASH:=f136e71b8fa8d6b7218163e70ad429324689bc4afd1ebf04e401f36a67960fd7
endef
$(eval $(call Download,black-white-list-lua0))

GL_IMAGE_KSRC:=https://raw.githubusercontent.com/gl-inet/gl-image/617e1f1d8f3cce672a63a3c59bb15003094652f3/versions/4.9.0/package/glinet/gl-sdk4-black_white_list/src

define Download/black-white-list-ko0
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=Makefile
  FILE:=black-white-list-617e1f1-Makefile
  HASH:=8adb662a6e87c8d6b9e213db3dbb797faa10193b8fbfa0a54aa69732650973a1
endef
$(eval $(call Download,black-white-list-ko0))

define Download/black-white-list-ko1
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=black_white_list.c
  FILE:=black-white-list-617e1f1-black_white_list.c
  HASH:=09733d5183c02aef99d172c491861e64f16821d82d1fda5cda3c558fea7019b8
endef
$(eval $(call Download,black-white-list-ko1))

define Download/black-white-list-ko2
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=black_white_list.h
  FILE:=black-white-list-617e1f1-black_white_list.h
  HASH:=2bd06c0ffdfb2612f176df6e4e8f3a84c6855d70802c82cb5a5eac7e6e738c77
endef
$(eval $(call Download,black-white-list-ko2))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/files
	$(CP) $(DL_DIR)/black-white-list-0649a9d-black_white_list.lua $(PKG_BUILD_DIR)/files/black_white_list.lua
	$(CP) $(DL_DIR)/black-white-list-617e1f1-Makefile $(PKG_BUILD_DIR)/Makefile
	$(CP) $(DL_DIR)/black-white-list-617e1f1-black_white_list.c $(PKG_BUILD_DIR)/black_white_list.c
	$(CP) $(DL_DIR)/black-white-list-617e1f1-black_white_list.h $(PKG_BUILD_DIR)/black_white_list.h
endef

define Build/Compile
	cd $(PKG_BUILD_DIR) && $(STAGING_DIR_HOSTPKG)/bin/luac -o black_white_list.lua.luac ./files/black_white_list.lua
	$(MAKE) -C "$(LINUX_DIR)" ARCH="$(LINUX_KARCH)" CROSS_COMPILE="$(TARGET_CROSS)" M="$(PKG_BUILD_DIR)" \
		KCFLAGS="-fmacro-prefix-map=$(BUILD_DIR)=$(notdir $(BUILD_DIR)) -fno-caller-saves" modules
	# stripped like OpenWrt's strip-kmod.sh
	$(TARGET_CROSS)objcopy -R .comment -R .pdr -R .mdebug.abi32 -R .gnu.attributes -R .reginfo -R .MIPS.abiflags \
		-R .note.GNU-stack -x -G __this_module --strip-unneeded -R .note.gnu.build-id \
		$(PKG_BUILD_DIR)/gl-sdk4-black_white_list.ko $(PKG_BUILD_DIR)/gl-sdk4-black_white_list.stripped.ko
endef

define Package/kmod-gl-sdk4-black_white_list/install-built
	# over the image's copies, keeping their modes
	cat $(PKG_BUILD_DIR)/black_white_list.lua.luac > $(1)/usr/lib/oui-httpd/rpc/black_white_list
	cat $(PKG_BUILD_DIR)/gl-sdk4-black_white_list.stripped.ko > $(1)/lib/modules/$(LINUX_VERSION)/gl-sdk4-black_white_list.ko
endef
