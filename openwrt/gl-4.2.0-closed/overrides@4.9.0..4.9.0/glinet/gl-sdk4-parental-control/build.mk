# parental_control.ko (4.9.0) from GL.iNet's published source of this module (gl-inet/gl-image,
# gl-mt3600be, versions/4.9.0, GPL kernel module): built against our kernel like
# this, it's byte-identical to GL.iNet's (2026-10-29). The source is downloaded
# at a fixed commit and checked by hash.
#
# 4.9.0: the package's compiled Lua (/usr/bin/apps_domain_list.lua, /usr/share/gl-validator.d/parental-control.lua)
# from GL.iNet's published source of the next release (gl-inet/gl-image,
# gl-be14000 4.9.1), compiled like GL.iNet's recipe (luac in the package
# folder, chunk name ./files/<name>.lua): byte-identical (2026-10-28).
GL_IMAGE_SRC:=https://raw.githubusercontent.com/gl-inet/gl-image/0649a9d7514a4c51a0f035057014d70952319bfa/versions/4.9.1/package/kernel/glinet/gl-sdk4-parental-control/files
PKG_BUILD_DEPENDS:=lua/host

define Download/parental-control-lua0
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=apps_domain_list.lua
  FILE:=parental-control-0649a9d-apps_domain_list.lua
  HASH:=420432e9500f4cbec1172e3d78af616d3274a9c463cd21ec549e0443ef3ff6b2
endef
$(eval $(call Download,parental-control-lua0))

define Download/parental-control-lua1
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=validator.lua
  FILE:=parental-control-0649a9d-validator.lua
  HASH:=ab919c5279035a272e4bd20b7fe4e19d9f1a8dc835b6b65711f5d0cbaa6c1b25
endef
$(eval $(call Download,parental-control-lua1))

GL_IMAGE_KSRC:=https://raw.githubusercontent.com/gl-inet/gl-image/617e1f1d8f3cce672a63a3c59bb15003094652f3/versions/4.9.0/package/glinet/gl-sdk4-parental-control/src

define Download/parental-control-ko0
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=Makefile
  FILE:=parental-control-617e1f1-Makefile
  HASH:=2bd8aa727335e2a919c82e6e8c2fc7fd35d805815a2a5e761a91797169af7aa5
endef
$(eval $(call Download,parental-control-ko0))

define Download/parental-control-ko1
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=cJSON.c
  FILE:=parental-control-617e1f1-cJSON.c
  HASH:=3685a64278d77456cfffe1a49f20ea68052e22127d447826f7e13f3cd6f2b104
endef
$(eval $(call Download,parental-control-ko1))

define Download/parental-control-ko2
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=cJSON.h
  FILE:=parental-control-617e1f1-cJSON.h
  HASH:=fc5aad47eb39f70b1f4326292e2ffb04cd56a819ad8058c72264f9d38da5ff3c
endef
$(eval $(call Download,parental-control-ko2))

define Download/parental-control-ko3
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=pc_app.c
  FILE:=parental-control-617e1f1-pc_app.c
  HASH:=9d4ea4ffbb71220599472d12d20a4c2a407a57ce8baefa6a51783abf94c389e3
endef
$(eval $(call Download,parental-control-ko3))

define Download/parental-control-ko4
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=pc_config.c
  FILE:=parental-control-617e1f1-pc_config.c
  HASH:=1102cbcaa123fa97c3bdbcd1094ff02d3470d506e2dfb4f76e24a9bfa2fcaf96
endef
$(eval $(call Download,parental-control-ko4))

define Download/parental-control-ko5
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=pc_filter.c
  FILE:=parental-control-617e1f1-pc_filter.c
  HASH:=2937807605f4c599f3c13e0de639b64f69f1ae5728329b2ba182ae4e429bfc11
endef
$(eval $(call Download,parental-control-ko5))

define Download/parental-control-ko6
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=pc_policy.c
  FILE:=parental-control-617e1f1-pc_policy.c
  HASH:=8c7948cd9f2174dfd3ef412a906022162b9b142d90b894efdfd0c097619188f3
endef
$(eval $(call Download,parental-control-ko6))

define Download/parental-control-ko7
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=pc_policy.h
  FILE:=parental-control-617e1f1-pc_policy.h
  HASH:=dc15a636d712d50fabff35a32bff3d3598fce7d0dfab10a6374bdbb10b5d8f89
endef
$(eval $(call Download,parental-control-ko7))

define Download/parental-control-ko8
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=pc_utils.c
  FILE:=parental-control-617e1f1-pc_utils.c
  HASH:=cef7ab71a5eeed184cba5e77f8208832b72ce108e209514b3097efa89a72bdba
endef
$(eval $(call Download,parental-control-ko8))

define Download/parental-control-ko9
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=pc_utils.h
  FILE:=parental-control-617e1f1-pc_utils.h
  HASH:=aa1782a03f160c9fbdc98c1788ea5cfdac732361f2c306fd3a32c73511beb6b4
endef
$(eval $(call Download,parental-control-ko9))

define Download/parental-control-ko10
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=regexp.c
  FILE:=parental-control-617e1f1-regexp.c
  HASH:=4dbcbb1eb88a52bd8f48390306dad7c75ba6451b6576963861eef29e1c98eb71
endef
$(eval $(call Download,parental-control-ko10))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/files
	$(CP) $(DL_DIR)/parental-control-0649a9d-apps_domain_list.lua $(PKG_BUILD_DIR)/files/apps_domain_list.lua
	$(CP) $(DL_DIR)/parental-control-0649a9d-validator.lua $(PKG_BUILD_DIR)/files/validator.lua
	$(CP) $(DL_DIR)/parental-control-617e1f1-Makefile $(PKG_BUILD_DIR)/Makefile
	$(CP) $(DL_DIR)/parental-control-617e1f1-cJSON.c $(PKG_BUILD_DIR)/cJSON.c
	$(CP) $(DL_DIR)/parental-control-617e1f1-cJSON.h $(PKG_BUILD_DIR)/cJSON.h
	$(CP) $(DL_DIR)/parental-control-617e1f1-pc_app.c $(PKG_BUILD_DIR)/pc_app.c
	$(CP) $(DL_DIR)/parental-control-617e1f1-pc_config.c $(PKG_BUILD_DIR)/pc_config.c
	$(CP) $(DL_DIR)/parental-control-617e1f1-pc_filter.c $(PKG_BUILD_DIR)/pc_filter.c
	$(CP) $(DL_DIR)/parental-control-617e1f1-pc_policy.c $(PKG_BUILD_DIR)/pc_policy.c
	$(CP) $(DL_DIR)/parental-control-617e1f1-pc_policy.h $(PKG_BUILD_DIR)/pc_policy.h
	$(CP) $(DL_DIR)/parental-control-617e1f1-pc_utils.c $(PKG_BUILD_DIR)/pc_utils.c
	$(CP) $(DL_DIR)/parental-control-617e1f1-pc_utils.h $(PKG_BUILD_DIR)/pc_utils.h
	$(CP) $(DL_DIR)/parental-control-617e1f1-regexp.c $(PKG_BUILD_DIR)/regexp.c
endef

define Build/Compile
	cd $(PKG_BUILD_DIR) && $(STAGING_DIR_HOSTPKG)/bin/luac -o apps_domain_list.lua.luac ./files/apps_domain_list.lua
	cd $(PKG_BUILD_DIR) && $(STAGING_DIR_HOSTPKG)/bin/luac -o validator.lua.luac ./files/validator.lua
	$(MAKE) -C "$(LINUX_DIR)" ARCH="$(LINUX_KARCH)" CROSS_COMPILE="$(TARGET_CROSS)" M="$(PKG_BUILD_DIR)" \
		KCFLAGS="-fmacro-prefix-map=$(BUILD_DIR)=$(notdir $(BUILD_DIR)) -fno-caller-saves" modules
	# stripped like OpenWrt's strip-kmod.sh
	$(TARGET_CROSS)objcopy -R .comment -R .pdr -R .mdebug.abi32 -R .gnu.attributes -R .reginfo -R .MIPS.abiflags \
		-R .note.GNU-stack -x -G __this_module --strip-unneeded -R .note.gnu.build-id \
		$(PKG_BUILD_DIR)/parental_control.ko $(PKG_BUILD_DIR)/parental_control.stripped.ko
endef

define Package/kmod-gl-sdk4-parental-control/install-built
	# over the image's copies, keeping their modes
	cat $(PKG_BUILD_DIR)/apps_domain_list.lua.luac > $(1)/usr/bin/apps_domain_list.lua
	cat $(PKG_BUILD_DIR)/validator.lua.luac > $(1)/usr/share/gl-validator.d/parental-control.lua
	cat $(PKG_BUILD_DIR)/parental_control.stripped.ko > $(1)/lib/modules/$(LINUX_VERSION)/parental_control.ko
endef
