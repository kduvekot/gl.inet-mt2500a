# kmwan.ko (4.9.0) from GL.iNet's published source of this module (gl-inet/gl-image,
# gl-mt3600be, versions/4.9.0, GPL kernel module): built against our kernel like
# this, it's byte-identical to GL.iNet's (2026-10-29). The source is downloaded
# at a fixed commit and checked by hash.
#
# 4.9.0: the package's compiled Lua (/usr/lib/oui-httpd/rpc/kmwan)
# from GL.iNet's published source of the next release (gl-inet/gl-image,
# gl-be14000 4.9.1), compiled like GL.iNet's recipe (luac in the package
# folder, chunk name ./files/<name>.lua): byte-identical (2026-10-28).
GL_IMAGE_SRC:=https://raw.githubusercontent.com/gl-inet/gl-image/0649a9d7514a4c51a0f035057014d70952319bfa/versions/4.9.1/package/kernel/glinet/gl-sdk4-kmwan/files
PKG_BUILD_DEPENDS:=lua/host

define Download/kmwan-lua0
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=kmwan.lua
  FILE:=kmwan-0649a9d-kmwan.lua
  HASH:=b27e42058a54da9278c71ec7669fd3aa9550229896c469aa8ba0a1db06560206
endef
$(eval $(call Download,kmwan-lua0))

GL_IMAGE_KSRC:=https://raw.githubusercontent.com/gl-inet/gl-image/617e1f1d8f3cce672a63a3c59bb15003094652f3/versions/4.9.0/package/glinet/gl-sdk4-kmwan/src

define Download/kmwan-ko0
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=Makefile
  FILE:=kmwan-490-617e1f1-Makefile
  HASH:=0718432a8db4fe1bd607c5ab6dff1eef372aee49898c963419e02dd7a7ed9274
endef
$(eval $(call Download,kmwan-ko0))

define Download/kmwan-ko1
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=cJSON.c
  FILE:=kmwan-490-617e1f1-cJSON.c
  HASH:=3bb2ee1e105f27396fec28802cbbb13c07b1ba846c5a4bf669727493a37b5105
endef
$(eval $(call Download,kmwan-ko1))

define Download/kmwan-ko2
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=cJSON.h
  FILE:=kmwan-490-617e1f1-cJSON.h
  HASH:=7d4dc0903bb941357e71553f37d2a5373edf2a36fcf89b7d016e619368b673a4
endef
$(eval $(call Download,kmwan-ko2))

define Download/kmwan-ko3
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=config.c
  FILE:=kmwan-490-617e1f1-config.c
  HASH:=89c1bf142cd76a4fcf67bca74ee8399b79dc5dc5052c5f565f3a537a41321dec
endef
$(eval $(call Download,kmwan-ko3))

define Download/kmwan-ko4
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=fib.c
  FILE:=kmwan-490-617e1f1-fib.c
  HASH:=e819c83444f92d208148b69e96a5a630465de97240b4367ee73d231e221788ce
endef
$(eval $(call Download,kmwan-ko4))

define Download/kmwan-ko5
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=hook.c
  FILE:=kmwan-490-617e1f1-hook.c
  HASH:=7824b7a096f26375cbf98bc4626ff64df31cd746019b99b85effae51e3d451d5
endef
$(eval $(call Download,kmwan-ko5))

define Download/kmwan-ko6
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=hook6.c
  FILE:=kmwan-490-617e1f1-hook6.c
  HASH:=b1cd24df3186bb70ec7333b674efb2829d124347c095b9d0e6655cbbe7f75a08
endef
$(eval $(call Download,kmwan-ko6))

define Download/kmwan-ko7
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=hotplug.c
  FILE:=kmwan-490-617e1f1-hotplug.c
  HASH:=c003f4a4c5909b61212c560420876c1850d73fae50ddd004f14e928d2b4d7fdc
endef
$(eval $(call Download,kmwan-ko7))

define Download/kmwan-ko8
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=icmp.c
  FILE:=kmwan-490-617e1f1-icmp.c
  HASH:=f7f6ab435b3620cc61e911451ba35aff1b0e03247ae8368c277f5204233e5a12
endef
$(eval $(call Download,kmwan-ko8))

define Download/kmwan-ko9
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=kmwan.h
  FILE:=kmwan-490-617e1f1-kmwan.h
  HASH:=421ab8b51eea18bd4a30b02ceac3a0f3c2b84208bba0653216acde388ca83bd5
endef
$(eval $(call Download,kmwan-ko9))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/files
	$(CP) $(DL_DIR)/kmwan-0649a9d-kmwan.lua $(PKG_BUILD_DIR)/files/kmwan.lua
	$(CP) $(DL_DIR)/kmwan-490-617e1f1-Makefile $(PKG_BUILD_DIR)/Makefile
	$(CP) $(DL_DIR)/kmwan-490-617e1f1-cJSON.c $(PKG_BUILD_DIR)/cJSON.c
	$(CP) $(DL_DIR)/kmwan-490-617e1f1-cJSON.h $(PKG_BUILD_DIR)/cJSON.h
	$(CP) $(DL_DIR)/kmwan-490-617e1f1-config.c $(PKG_BUILD_DIR)/config.c
	$(CP) $(DL_DIR)/kmwan-490-617e1f1-fib.c $(PKG_BUILD_DIR)/fib.c
	$(CP) $(DL_DIR)/kmwan-490-617e1f1-hook.c $(PKG_BUILD_DIR)/hook.c
	$(CP) $(DL_DIR)/kmwan-490-617e1f1-hook6.c $(PKG_BUILD_DIR)/hook6.c
	$(CP) $(DL_DIR)/kmwan-490-617e1f1-hotplug.c $(PKG_BUILD_DIR)/hotplug.c
	$(CP) $(DL_DIR)/kmwan-490-617e1f1-icmp.c $(PKG_BUILD_DIR)/icmp.c
	$(CP) $(DL_DIR)/kmwan-490-617e1f1-kmwan.h $(PKG_BUILD_DIR)/kmwan.h
endef

define Build/Compile
	cd $(PKG_BUILD_DIR) && $(STAGING_DIR_HOSTPKG)/bin/luac -o kmwan.lua.luac ./files/kmwan.lua
	$(MAKE) -C "$(LINUX_DIR)" ARCH="$(LINUX_KARCH)" CROSS_COMPILE="$(TARGET_CROSS)" M="$(PKG_BUILD_DIR)" \
		KCFLAGS="-fmacro-prefix-map=$(BUILD_DIR)=$(notdir $(BUILD_DIR)) -fno-caller-saves" modules
	# stripped like OpenWrt's strip-kmod.sh
	$(TARGET_CROSS)objcopy -R .comment -R .pdr -R .mdebug.abi32 -R .gnu.attributes -R .reginfo -R .MIPS.abiflags \
		-R .note.GNU-stack -x -G __this_module --strip-unneeded -R .note.gnu.build-id \
		$(PKG_BUILD_DIR)/kmwan.ko $(PKG_BUILD_DIR)/kmwan.stripped.ko
endef

define Package/kmod-gl-sdk4-kmwan/install-built
	# over the image's copies, keeping their modes
	cat $(PKG_BUILD_DIR)/kmwan.lua.luac > $(1)/usr/lib/oui-httpd/rpc/kmwan
	cat $(PKG_BUILD_DIR)/kmwan.stripped.ko > $(1)/lib/modules/$(LINUX_VERSION)/kmwan.ko
endef
