# 4.9.0: the package's compiled Lua (/usr/bin/apps_domain_list.lua, /usr/share/gl-validator.d/parental-control.lua)
# from GL.iNet's published source of the next release (gl-inet/gl-image,
# gl-be14000 4.9.1), compiled like GL.iNet's recipe (luac in the package
# folder, chunk name ./files/<name>.lua): byte-identical (2026-10-28).
GL_IMAGE_SRC:=https://raw.githubusercontent.com/gl-inet/gl-image/0649a9d7514a4c51a0f035057014d70952319bfa/versions/4.9.1/package/kernel/glinet/gl-sdk4-parental-control/files
PKG_BUILD_DEPENDS:=lua/host

define Download/parental-control-lua0
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=apps_domain_list.lua
  FILE:=parental-control-0649a9d-apps_domain_list.lua
  HASH:=420432e9500f4cbec1172e3d78af616d3274a9c463cd21ec549e0443ef3ff6b2
endef
$(eval $(call Download,parental-control-lua0))

define Download/parental-control-lua1
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=validator.lua
  FILE:=parental-control-0649a9d-validator.lua
  HASH:=ab919c5279035a272e4bd20b7fe4e19d9f1a8dc835b6b65711f5d0cbaa6c1b25
endef
$(eval $(call Download,parental-control-lua1))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/files
	$(CP) $(DL_DIR)/parental-control-0649a9d-apps_domain_list.lua $(PKG_BUILD_DIR)/files/apps_domain_list.lua
	$(CP) $(DL_DIR)/parental-control-0649a9d-validator.lua $(PKG_BUILD_DIR)/files/validator.lua
endef

define Build/Compile
	cd $(PKG_BUILD_DIR) && $(STAGING_DIR_HOSTPKG)/bin/luac -o apps_domain_list.lua.luac ./files/apps_domain_list.lua
	cd $(PKG_BUILD_DIR) && $(STAGING_DIR_HOSTPKG)/bin/luac -o validator.lua.luac ./files/validator.lua
endef

define Package/kmod-gl-sdk4-parental-control/install-built
	# over the image's copies, keeping their modes
	cat $(PKG_BUILD_DIR)/apps_domain_list.lua.luac > $(1)/usr/bin/apps_domain_list.lua
	cat $(PKG_BUILD_DIR)/validator.lua.luac > $(1)/usr/share/gl-validator.d/parental-control.lua
endef
