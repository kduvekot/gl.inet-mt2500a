# 4.9.0: the package's compiled Lua (/usr/lib/oui-httpd/rpc/black_white_list)
# from GL.iNet's published source of the next release (gl-inet/gl-image,
# gl-be14000 4.9.1), compiled like GL.iNet's recipe (luac in the package
# folder, chunk name ./files/<name>.lua): byte-identical (2026-10-28).
GL_IMAGE_SRC:=https://raw.githubusercontent.com/gl-inet/gl-image/0649a9d7514a4c51a0f035057014d70952319bfa/versions/4.9.1/package/kernel/glinet/gl-sdk4-black_white_list/files
PKG_BUILD_DEPENDS:=lua/host

define Download/black-white-list-lua0
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=black_white_list.lua
  FILE:=black-white-list-0649a9d-black_white_list.lua
  HASH:=f136e71b8fa8d6b7218163e70ad429324689bc4afd1ebf04e401f36a67960fd7
endef
$(eval $(call Download,black-white-list-lua0))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/files
	$(CP) $(DL_DIR)/black-white-list-0649a9d-black_white_list.lua $(PKG_BUILD_DIR)/files/black_white_list.lua
endef

define Build/Compile
	cd $(PKG_BUILD_DIR) && $(STAGING_DIR_HOSTPKG)/bin/luac -o black_white_list.lua.luac ./files/black_white_list.lua
endef

define Package/kmod-gl-sdk4-black_white_list/install-built
	# over the image's copies, keeping their modes
	cat $(PKG_BUILD_DIR)/black_white_list.lua.luac > $(1)/usr/lib/oui-httpd/rpc/black_white_list
endef
