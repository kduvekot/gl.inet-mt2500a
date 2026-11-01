# parental_control.ko of 4.1.1 from GL.iNet's public parental-control
# repository (github.com/gl-inet/parental-control, GPL kernel module) at
# ea80343 (2022-09-21): built against our kernel like this, it's
# byte-identical to GL.iNet's (2026-10-28). Downloaded at that commit and
# checked by hash.
PC_SRC:=https://raw.githubusercontent.com/gl-inet/parental-control/ea8034336e0b8109ecdd663cba197c38a77a6bc1/src

define Download/pc411-0
  URL:=$(PC_SRC)
  URL_FILE:=Makefile
  FILE:=parental-control-ea80343-Makefile
  HASH:=2bd8aa727335e2a919c82e6e8c2fc7fd35d805815a2a5e761a91797169af7aa5
endef
$(eval $(call Download,pc411-0))

define Download/pc411-1
  URL:=$(PC_SRC)
  URL_FILE:=cJSON.c
  FILE:=parental-control-ea80343-cJSON.c
  HASH:=36ccc460ca551f6877c34beb01c9dd2ed1199e5ca683ef69cd0a301f96bb09e4
endef
$(eval $(call Download,pc411-1))

define Download/pc411-2
  URL:=$(PC_SRC)
  URL_FILE:=cJSON.h
  FILE:=parental-control-ea80343-cJSON.h
  HASH:=d71b1b00c25fc293df86db44835a36c9a0b468357193dcb5785cd6895aac01b5
endef
$(eval $(call Download,pc411-2))

define Download/pc411-3
  URL:=$(PC_SRC)
  URL_FILE:=pc_app.c
  FILE:=parental-control-ea80343-pc_app.c
  HASH:=e158637808a5f40d7f5394cfbf4c6a055eec27501e9e46e7c9107e38829a77a8
endef
$(eval $(call Download,pc411-3))

define Download/pc411-4
  URL:=$(PC_SRC)
  URL_FILE:=pc_config.c
  FILE:=parental-control-ea80343-pc_config.c
  HASH:=b8a5914258d03bb24644b8b9dcb60be346077de2b0de24462dd2cad178c7acd9
endef
$(eval $(call Download,pc411-4))

define Download/pc411-5
  URL:=$(PC_SRC)
  URL_FILE:=pc_filter.c
  FILE:=parental-control-ea80343-pc_filter.c
  HASH:=8c4b22d277a6c75e6c624a851d5fa6ee86ac40c8a6eed8078184e070d41280a4
endef
$(eval $(call Download,pc411-5))

define Download/pc411-6
  URL:=$(PC_SRC)
  URL_FILE:=pc_policy.c
  FILE:=parental-control-ea80343-pc_policy.c
  HASH:=5ac8b373dcfe70d92c647ea3a277ffb16180faa90915afa13520e8386de6fcb6
endef
$(eval $(call Download,pc411-6))

define Download/pc411-7
  URL:=$(PC_SRC)
  URL_FILE:=pc_policy.h
  FILE:=parental-control-ea80343-pc_policy.h
  HASH:=a1eccc5d93eac27e76edc5de1725a68b4af1df7a2742e57505b105e0dded0910
endef
$(eval $(call Download,pc411-7))

define Download/pc411-8
  URL:=$(PC_SRC)
  URL_FILE:=pc_utils.c
  FILE:=parental-control-ea80343-pc_utils.c
  HASH:=061f3f7aefccac476e21a894189703724e31759c3507fe71db2cfdc17a4ff582
endef
$(eval $(call Download,pc411-8))

define Download/pc411-9
  URL:=$(PC_SRC)
  URL_FILE:=pc_utils.h
  FILE:=parental-control-ea80343-pc_utils.h
  HASH:=1dc5578d087cd2ba1a8b03f34658ab1ce2e8af0d5d75f510195f904893724a07
endef
$(eval $(call Download,pc411-9))

define Download/pc411-10
  URL:=$(PC_SRC)
  URL_FILE:=regexp.c
  FILE:=parental-control-ea80343-regexp.c
  HASH:=194a69c2778b2dda0c0ca9e6377289656dd34169b49f69501559487e9bccc2e5
endef
$(eval $(call Download,pc411-10))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/parental-control-ea80343-Makefile $(PKG_BUILD_DIR)/Makefile
	$(CP) $(DL_DIR)/parental-control-ea80343-cJSON.c $(PKG_BUILD_DIR)/cJSON.c
	$(CP) $(DL_DIR)/parental-control-ea80343-cJSON.h $(PKG_BUILD_DIR)/cJSON.h
	$(CP) $(DL_DIR)/parental-control-ea80343-pc_app.c $(PKG_BUILD_DIR)/pc_app.c
	$(CP) $(DL_DIR)/parental-control-ea80343-pc_config.c $(PKG_BUILD_DIR)/pc_config.c
	$(CP) $(DL_DIR)/parental-control-ea80343-pc_filter.c $(PKG_BUILD_DIR)/pc_filter.c
	$(CP) $(DL_DIR)/parental-control-ea80343-pc_policy.c $(PKG_BUILD_DIR)/pc_policy.c
	$(CP) $(DL_DIR)/parental-control-ea80343-pc_policy.h $(PKG_BUILD_DIR)/pc_policy.h
	$(CP) $(DL_DIR)/parental-control-ea80343-pc_utils.c $(PKG_BUILD_DIR)/pc_utils.c
	$(CP) $(DL_DIR)/parental-control-ea80343-pc_utils.h $(PKG_BUILD_DIR)/pc_utils.h
	$(CP) $(DL_DIR)/parental-control-ea80343-regexp.c $(PKG_BUILD_DIR)/regexp.c
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
