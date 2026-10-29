# port_forward.ko (4.9.0) from GL.iNet's published source of this module (gl-inet/gl-image,
# gl-mt3600be, versions/4.9.0, GPL kernel module): built against our kernel like
# this, it's byte-identical to GL.iNet's (2026-10-29). The source is downloaded
# at a fixed commit and checked by hash.
# not a kernel-module recipe: kernel.mk for LINUX_DIR, LINUX_KARCH, LINUX_VERSION
include $(INCLUDE_DIR)/kernel.mk

GL_IMAGE_KSRC:=https://raw.githubusercontent.com/gl-inet/gl-image/617e1f1d8f3cce672a63a3c59bb15003094652f3/versions/4.9.0/package/glinet/gl-sdk4-port-forward/src

define Download/port-forward-ko0
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=Kbuild
  FILE:=port-forward-617e1f1-Kbuild
  HASH:=6df2d6442fc47cb07b3448e19476006bd5084928b63569034b378fa371701a6f
endef
$(eval $(call Download,port-forward-ko0))

define Download/port-forward-ko1
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=port_forward.c
  FILE:=port-forward-617e1f1-port_forward.c
  HASH:=8c0cfd31288dba45bb7878b2f3fdd75ecc7c4d36815b257b0cc2d2082d5f53b7
endef
$(eval $(call Download,port-forward-ko1))

define Download/port-forward-ko2
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=port_forward.h
  FILE:=port-forward-617e1f1-port_forward.h
  HASH:=5a4f73b62e15a64fd12dedf08609016828b304da51851f9347540bccd2e3d60c
endef
$(eval $(call Download,port-forward-ko2))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/port-forward-617e1f1-Kbuild $(PKG_BUILD_DIR)/Kbuild
	$(CP) $(DL_DIR)/port-forward-617e1f1-port_forward.c $(PKG_BUILD_DIR)/port_forward.c
	$(CP) $(DL_DIR)/port-forward-617e1f1-port_forward.h $(PKG_BUILD_DIR)/port_forward.h
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" ARCH="$(LINUX_KARCH)" CROSS_COMPILE="$(TARGET_CROSS)" M="$(PKG_BUILD_DIR)" \
		KCFLAGS="-fmacro-prefix-map=$(BUILD_DIR)=$(notdir $(BUILD_DIR)) -fno-caller-saves" modules
	# stripped like OpenWrt's strip-kmod.sh
	$(TARGET_CROSS)objcopy -R .comment -R .pdr -R .mdebug.abi32 -R .gnu.attributes -R .reginfo -R .MIPS.abiflags \
		-R .note.GNU-stack -x -G __this_module --strip-unneeded -R .note.gnu.build-id \
		$(PKG_BUILD_DIR)/port_forward.ko $(PKG_BUILD_DIR)/port_forward.stripped.ko
endef

define Package/gl-sdk4-firewall/install-built
	# over the image's copy, keeping its mode
	cat $(PKG_BUILD_DIR)/port_forward.stripped.ko > $(1)/lib/modules/$(LINUX_VERSION)/port_forward.ko
endef
