# oui/system.so of 4.1.1-4.7.0 from public source: zhaojh329/oui (MIT)
# oui-httpd/src/lua/lsystem.c at d6a4a00125, unchanged, compiled with -O1
# instead of OpenWrt's -Os: byte-identical to GL.iNet's (2026-10-28).
# The package's other files still come from the official image.
OUI_SRC:=https://raw.githubusercontent.com/zhaojh329/oui/d6a4a0012560034fbdb0ba8271e43a4352e9c20a/oui-httpd/src/lua
PKG_BUILD_DEPENDS:=lua

define Download/oui-lsystem
  URL:=$(OUI_SRC)
  URL_FILE:=lsystem.c
  FILE:=oui-d6a4a00125-lsystem.c
  HASH:=07102555771e008c10e60813690be8256330ae6f44c6981f8f05b78233ccda6c
endef
$(eval $(call Download,oui-lsystem))

define Download/oui-lua-compat
  URL:=$(OUI_SRC)
  URL_FILE:=lua_compat.h
  FILE:=oui-d6a4a00125-lua_compat.h
  HASH:=4c6cceb90dbcb2a14bae0fb3d72afd737f7f0d217305ad68c3e2aadd65c5f813
endef
$(eval $(call Download,oui-lua-compat))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/oui-d6a4a00125-lsystem.c $(PKG_BUILD_DIR)/lsystem.c
	$(CP) $(DL_DIR)/oui-d6a4a00125-lua_compat.h $(PKG_BUILD_DIR)/lua_compat.h
endef

define Build/Compile
	$(TARGET_CC) $(filter-out -O%,$(TARGET_CFLAGS)) -O1 $(TARGET_CPPFLAGS) -fPIC -shared \
		$(TARGET_LDFLAGS) -o $(PKG_BUILD_DIR)/system.so $(PKG_BUILD_DIR)/lsystem.c
	$(STAGING_DIR_HOST)/bin/sstrip -z $(PKG_BUILD_DIR)/system.so
endef

define Package/gl-oui-rpc/install-built
	# over the image's copy, keeping its mode
	cat $(PKG_BUILD_DIR)/system.so > $(1)/usr/lib/lua/oui/system.so
endef
