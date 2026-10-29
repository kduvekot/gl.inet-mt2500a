# dns_mark.ko (4.9.0) from GL.iNet's published source of this module (gl-inet/gl-image,
# gl-mt3600be, versions/4.9.0, GPL kernel module): built against our kernel like
# this, it's byte-identical to GL.iNet's (2026-10-29). The source is downloaded
# at a fixed commit and checked by hash.
GL_IMAGE_KSRC:=https://raw.githubusercontent.com/gl-inet/gl-image/617e1f1d8f3cce672a63a3c59bb15003094652f3/versions/4.9.0/package/glinet/gl-sdk4-dns-mark/src

define Download/dns-mark-ko0
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=Kbuild
  FILE:=dns-mark-617e1f1-Kbuild
  HASH:=87f5fb7db352e67b5a41b54b387266a24d29e1b81f28977fe44a1a48ff06789d
endef
$(eval $(call Download,dns-mark-ko0))

define Download/dns-mark-ko1
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=dns.c
  FILE:=dns-mark-617e1f1-dns.c
  HASH:=1b2069c860dcfbd53be2a57d5d9e601f915bb6405093f1cfd40141ea96a7a636
endef
$(eval $(call Download,dns-mark-ko1))

define Download/dns-mark-ko2
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=dns_mark.h
  FILE:=dns-mark-617e1f1-dns_mark.h
  HASH:=df760b5c2bffd50e9ab884e4f87d697107e36747ee307a3d7c2ee9a776f17031
endef
$(eval $(call Download,dns-mark-ko2))

define Download/dns-mark-ko3
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=main.c
  FILE:=dns-mark-617e1f1-main.c
  HASH:=f9903e7d902ece0e9ec2e6b57687537a0dd5e312a33eb48669c5f00a49b2b44a
endef
$(eval $(call Download,dns-mark-ko3))

define Download/dns-mark-ko4
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=proc.c
  FILE:=dns-mark-617e1f1-proc.c
  HASH:=34f2b1dc855d813fb5062cb8f506e9fd8504d44116d221f0cfd27959ab2cbe50
endef
$(eval $(call Download,dns-mark-ko4))

define Download/dns-mark-ko5
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=proc.h
  FILE:=dns-mark-617e1f1-proc.h
  HASH:=2e04070b70a6d97ed762e2aa658e0764f638085bead52c405acb0029f9a1a452
endef
$(eval $(call Download,dns-mark-ko5))

define Download/dns-mark-ko6
  URL:=$(GL_IMAGE_KSRC)
  URL_FILE:=rules.c
  FILE:=dns-mark-617e1f1-rules.c
  HASH:=0b112ea5b0c562af8030ae996edfab05746b59d16101692d4342a8781df82862
endef
$(eval $(call Download,dns-mark-ko6))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/dns-mark-617e1f1-Kbuild $(PKG_BUILD_DIR)/Kbuild
	$(CP) $(DL_DIR)/dns-mark-617e1f1-dns.c $(PKG_BUILD_DIR)/dns.c
	$(CP) $(DL_DIR)/dns-mark-617e1f1-dns_mark.h $(PKG_BUILD_DIR)/dns_mark.h
	$(CP) $(DL_DIR)/dns-mark-617e1f1-main.c $(PKG_BUILD_DIR)/main.c
	$(CP) $(DL_DIR)/dns-mark-617e1f1-proc.c $(PKG_BUILD_DIR)/proc.c
	$(CP) $(DL_DIR)/dns-mark-617e1f1-proc.h $(PKG_BUILD_DIR)/proc.h
	$(CP) $(DL_DIR)/dns-mark-617e1f1-rules.c $(PKG_BUILD_DIR)/rules.c
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" ARCH="$(LINUX_KARCH)" CROSS_COMPILE="$(TARGET_CROSS)" M="$(PKG_BUILD_DIR)" \
		KCFLAGS="-fmacro-prefix-map=$(BUILD_DIR)=$(notdir $(BUILD_DIR)) -fno-caller-saves" modules
	# stripped like OpenWrt's strip-kmod.sh
	$(TARGET_CROSS)objcopy -R .comment -R .pdr -R .mdebug.abi32 -R .gnu.attributes -R .reginfo -R .MIPS.abiflags \
		-R .note.GNU-stack -x -G __this_module --strip-unneeded -R .note.gnu.build-id \
		$(PKG_BUILD_DIR)/dns_mark.ko $(PKG_BUILD_DIR)/dns_mark.stripped.ko
endef

define Package/kmod-gl-sdk4-dns-mark/install-built
	# over the image's copy, keeping its mode
	cat $(PKG_BUILD_DIR)/dns_mark.stripped.ko > $(1)/lib/modules/$(LINUX_VERSION)/dns_mark.ko
endef
