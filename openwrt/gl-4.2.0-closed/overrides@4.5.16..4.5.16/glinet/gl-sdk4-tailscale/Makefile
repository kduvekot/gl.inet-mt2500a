include $(TOPDIR)/rules.mk

PKG_NAME:=gl-sdk4-tailscale
PKG_VERSION:=git-2024.059.33751-64b2eed
PKG_RELEASE:=1

# 4.5.16 only: GL.iNet's package bundles /usr/sbin/tailscale and tailscaled
# (from 4.6.2 on they're in the public tailscale package again). They are
# Tailscale's official static arm64 release 1.58.2, put through OpenWrt's
# rstrip (sstrip -z): byte-identical to GL.iNet's (2026-10-28).
TS_VERSION:=1.58.2

include $(INCLUDE_DIR)/package.mk

define Package/gl-sdk4-tailscale
  SECTION:=base
  CATEGORY:=GL.iNet (closed, from the official image)
  TITLE:=GL.iNet Tailscale API with Tailscale's official binaries
  DEPENDS:=
endef

define Package/gl-sdk4-tailscale/description
 TAILSCALE Info API for Gl.inet
endef

define Package/gl-sdk4-tailscale/conffiles
/etc/config/tailscale
endef

define Download/tailscale-static
  URL:=https://pkgs.tailscale.com/stable
  URL_FILE:=tailscale_$(TS_VERSION)_arm64.tgz
  FILE:=tailscale_$(TS_VERSION)_arm64.tgz
  HASH:=b971393e34ee9c4375f9ecff880e4c3bce9798e47fd12c7e96797f5caa3ace49
endef
$(eval $(call Download,tailscale-static))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(TAR) -xzf $(DL_DIR)/tailscale_$(TS_VERSION)_arm64.tgz -C $(PKG_BUILD_DIR) --strip-components=1
endef

define Build/Compile
endef

define Package/gl-sdk4-tailscale/install
	$(CP) ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/tailscale $(PKG_BUILD_DIR)/tailscaled $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,gl-sdk4-tailscale))
