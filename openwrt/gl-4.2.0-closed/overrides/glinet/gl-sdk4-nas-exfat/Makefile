include $(TOPDIR)/rules.mk

PKG_NAME:=gl-sdk4-nas-exfat
PKG_VERSION:=1.6
PKG_RELEASE:=1

# mkfs.exfat, fsck.exfat and libexfat.so are relan/exfat 1.2.7 built as
# below (verified byte-identical with GL.iNet's in the oss feed, 2026-10-25).
PKG_SOURCE:=exfat-utils-1.2.7.tar.gz
PKG_SOURCE_URL:=https://github.com/relan/exfat/releases/download/v1.2.7/
PKG_HASH:=386132d155b92c7d27735483663f2724844cb904ef9ecd83c374cffe831dffe4
PKG_BUILD_DIR:=$(BUILD_DIR)/exfat-utils-1.2.7

include $(INCLUDE_DIR)/package.mk

TARGET_CFLAGS += -fPIC

define Package/gl-sdk4-nas-exfat
  SECTION:=base
  CATEGORY:=GL.iNet (closed, from the official image)
  TITLE:=lib exfat
  DEPENDS:=+libpthread
endef

define Package/gl-sdk4-nas-exfat/description
lib exfat
endef

# upstream builds a static libexfat.a; GL.iNet linked a shared libexfat.so
define Build/Compile
	$(call Build/Compile/Default)
	$(TARGET_CC) $(TARGET_LDFLAGS) -shared -Wl,-z,lazy -o $(PKG_BUILD_DIR)/libexfat.so $(PKG_BUILD_DIR)/libexfat/*.o
	cd $(PKG_BUILD_DIR) && \
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) mkfs/*.o -o mkfs.exfat -L. -l:libexfat.so -Wl,-rpath-link,. && \
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) fsck/*.o -o fsck.exfat -L. -l:libexfat.so -Wl,-rpath-link,.
endef

define Package/gl-sdk4-nas-exfat/install
	$(CP) ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/bin $(1)/usr/lib/gl
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/mkfs.exfat $(PKG_BUILD_DIR)/fsck.exfat $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libexfat.so $(1)/usr/lib/gl/
endef

$(eval $(call BuildPackage,gl-sdk4-nas-exfat))
