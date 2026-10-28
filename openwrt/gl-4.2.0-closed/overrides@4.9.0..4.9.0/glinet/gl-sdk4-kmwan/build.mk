# 4.9.0: the package's compiled Lua (/usr/lib/oui-httpd/rpc/kmwan)
# from GL.iNet's published source of the next release (gl-inet/gl-image,
# gl-be14000 4.9.1), compiled like GL.iNet's recipe (luac in the package
# folder, chunk name ./files/<name>.lua): byte-identical (2026-10-28).
GL_IMAGE_SRC:=https://raw.githubusercontent.com/gl-inet/gl-image/0649a9d7514a4c51a0f035057014d70952319bfa/versions/4.9.1/package/kernel/glinet/gl-sdk4-kmwan/files
PKG_BUILD_DEPENDS:=lua/host

define Download/kmwan-lua0
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=kmwan.lua
  FILE:=kmwan-0649a9d-kmwan.lua
  HASH:=b27e42058a54da9278c71ec7669fd3aa9550229896c469aa8ba0a1db06560206
endef
$(eval $(call Download,kmwan-lua0))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/files
	$(CP) $(DL_DIR)/kmwan-0649a9d-kmwan.lua $(PKG_BUILD_DIR)/files/kmwan.lua
endef

define Build/Compile
	cd $(PKG_BUILD_DIR) && $(STAGING_DIR_HOSTPKG)/bin/luac -o kmwan.lua.luac ./files/kmwan.lua
endef

define Package/kmod-gl-sdk4-kmwan/install-built
	# over the image's copies, keeping their modes
	cat $(PKG_BUILD_DIR)/kmwan.lua.luac > $(1)/usr/lib/oui-httpd/rpc/kmwan
endef
