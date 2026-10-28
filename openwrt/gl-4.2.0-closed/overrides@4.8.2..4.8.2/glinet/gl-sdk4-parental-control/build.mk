# parental_control.ko of 4.8.2 from GL.iNet's published source of this module
# (gl-inet/gl-image, gl-mt3600be, 4.8.7, GPL kernel module): built against our
# kernel like this, it's byte-identical to GL.iNet's (2026-10-28). The
# source is downloaded at a fixed commit and checked by hash.
GL_IMAGE_SRC:=https://raw.githubusercontent.com/gl-inet/gl-image/617e1f1d8f3cce672a63a3c59bb15003094652f3/versions/4.8.7/package/glinet/gl-sdk4-parental-control/src

define Download/parental-control-0
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=Makefile
  FILE:=parental-control-617e1f1-Makefile
  HASH:=c818236e48813cff7b8558b37879202b9b0d16a41230e88cda320f8611758854
endef
$(eval $(call Download,parental-control-0))

define Download/parental-control-1
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=cJSON.c
  FILE:=parental-control-617e1f1-cJSON.c
  HASH:=fcba42dbc49cd4fad0e8df99c76bb860d9c0bba610ed37206eab4085ce6b3967
endef
$(eval $(call Download,parental-control-1))

define Download/parental-control-2
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=cJSON.h
  FILE:=parental-control-617e1f1-cJSON.h
  HASH:=fc5aad47eb39f70b1f4326292e2ffb04cd56a819ad8058c72264f9d38da5ff3c
endef
$(eval $(call Download,parental-control-2))

define Download/parental-control-3
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=pc_app.c
  FILE:=parental-control-617e1f1-pc_app.c
  HASH:=9d4ea4ffbb71220599472d12d20a4c2a407a57ce8baefa6a51783abf94c389e3
endef
$(eval $(call Download,parental-control-3))

define Download/parental-control-4
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=pc_config.c
  FILE:=parental-control-617e1f1-pc_config.c
  HASH:=cc7a2186f2f458330f3c61e1fa1ac8cc464f4a88e524c727c6933af94736dbe6
endef
$(eval $(call Download,parental-control-4))

define Download/parental-control-5
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=pc_filter.c
  FILE:=parental-control-617e1f1-pc_filter.c
  HASH:=93aba74c9c9f1cabf58bc425da89905a9999facfe721278bf9ac7e5613d74477
endef
$(eval $(call Download,parental-control-5))

define Download/parental-control-6
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=pc_policy.c
  FILE:=parental-control-617e1f1-pc_policy.c
  HASH:=abe5a82ab93f61c0b1d9b864854c20477bfe09e5fcf57c53c4570d8913f9ce56
endef
$(eval $(call Download,parental-control-6))

define Download/parental-control-7
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=pc_policy.h
  FILE:=parental-control-617e1f1-pc_policy.h
  HASH:=6c764362c8cb52e7ff3a848011dfe5ec5e7eec653dcc91c46d163915d3c9e408
endef
$(eval $(call Download,parental-control-7))

define Download/parental-control-8
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=pc_utils.c
  FILE:=parental-control-617e1f1-pc_utils.c
  HASH:=cef7ab71a5eeed184cba5e77f8208832b72ce108e209514b3097efa89a72bdba
endef
$(eval $(call Download,parental-control-8))

define Download/parental-control-9
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=pc_utils.h
  FILE:=parental-control-617e1f1-pc_utils.h
  HASH:=1dc5578d087cd2ba1a8b03f34658ab1ce2e8af0d5d75f510195f904893724a07
endef
$(eval $(call Download,parental-control-9))

define Download/parental-control-10
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=regexp.c
  FILE:=parental-control-617e1f1-regexp.c
  HASH:=2f45496b2fcde61ba80cd87f46b19e88bbfcb0cd8ff7d533c59f0e2df8f5b050
endef
$(eval $(call Download,parental-control-10))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
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
