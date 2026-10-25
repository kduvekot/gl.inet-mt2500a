include $(TOPDIR)/rules.mk

PKG_NAME:=gl-sdk4-adguardhome
PKG_VERSION:=git-2023.054.23547-2fe3109
PKG_RELEASE:=1

# AdGuardHome itself is AdGuard's official v0.107.8 release binary
# (linux/arm64, same Go build ID); OpenWrt's sstrip turns it into GL.iNet's
# file. Verified 2026-10-25: identical code and data, only the section table
# and trailing zeros removed.
PKG_SOURCE:=AdGuardHome_linux_arm64.tar.gz
PKG_SOURCE_URL:=https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.8/
PKG_HASH:=77a678e8beaa7978b950d3d8dff9e54c9bd50ae43495a9ad478f59ef73bced67
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)/AdGuardHome

include $(INCLUDE_DIR)/package.mk

define Package/gl-sdk4-adguardhome
  SECTION:=base
  CATEGORY:=GL.iNet (closed, from the official image)
  TITLE:=Adguardhome API for Gl.inet
  DEPENDS:=
endef

define Package/gl-sdk4-adguardhome/description
Adguardhome API for Gl.inet
endef

define Package/gl-sdk4-adguardhome/conffiles
/etc/config/adguardhome
/etc/AdGuardHome/config.yaml
endef

define Build/Compile
endef

define Build/Prepare
	mkdir -p $(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
	$(TAR) -C $(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION) -xzf $(DL_DIR)/$(PKG_SOURCE)
endef

define Package/gl-sdk4-adguardhome/install
	$(CP) ./files/* $(1)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/AdGuardHome $(1)/etc/AdGuardHome/AdGuardHome
endef

$(eval $(call BuildPackage,gl-sdk4-adguardhome))
