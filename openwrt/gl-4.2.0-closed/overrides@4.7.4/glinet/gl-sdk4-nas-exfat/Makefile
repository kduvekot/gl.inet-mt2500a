include $(TOPDIR)/rules.mk

PKG_NAME:=gl-sdk4-nas-exfat
PKG_VERSION:=1.6
PKG_RELEASE:=1

# From 4.7.4 on GL.iNet builds its own copy of exfat (reformatted, strcpy
# replaced by strncpy), published with its recipe in gl-inet/gl-image
# (branch gl-be10000, commit bfe99df8, versions/4.8.6/package/libs/
# gl-sdk4-nas-exfat): src/ is that source unchanged, built with its own
# src/Makefile. fsck.exfat, mkfs.exfat and libexfat.so verified
# byte-identical with GL.iNet's 4.7.4 ones (2026-10-28); 4.7.0 and earlier
# match relan/exfat 1.2.7 (overrides/).

include $(INCLUDE_DIR)/package.mk

define Package/gl-sdk4-nas-exfat
  SECTION:=base
  CATEGORY:=GL.iNet (closed, from the official image)
  TITLE:=lib exfat
  DEPENDS:=+libpthread
endef

define Package/gl-sdk4-nas-exfat/description
lib exfat
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Package/gl-sdk4-nas-exfat/install
	$(CP) ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/bin $(1)/usr/lib/gl
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/mkfs.exfat $(PKG_BUILD_DIR)/fsck.exfat $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libexfat.so $(1)/usr/lib/gl/
endef

$(eval $(call BuildPackage,gl-sdk4-nas-exfat))
