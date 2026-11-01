include $(TOPDIR)/rules.mk

PKG_NAME:=gl-sdk4-uci
PKG_VERSION:=git-2025.042.27505-7e5f319
PKG_RELEASE:=1

# libguci.so from GL.iNet's own source of this version (revision 7e5f319,
# the one in the MT2500's 4.7.4 to 4.9.0), published in gl-inet/gl-image
# (branch gl-be10000, versions/4.8.6/package/libs/gl-sdk4-uci). GL.iNet's
# README there says no license has been assigned yet, so the source isn't
# stored here: it is downloaded from GL.iNet's repository at a fixed commit
# and checked by hash. Built like GL.iNet's recipe (CMake), libguci.so is
# byte-identical to GL.iNet's 4.7.4 and 4.8.2 ones (2026-10-28).
GL_IMAGE_SRC:=https://raw.githubusercontent.com/gl-inet/gl-image/bfe99df8e1872b63aee42d2bcd98b6b093c1ccf9/versions/4.8.6/package/libs/gl-sdk4-uci/src

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/gl-sdk4-uci
  SECTION:=base
  CATEGORY:=GL.iNet (closed, from the official image)
  TITLE:=GL.iNet UCI C wrapper library
  DEPENDS:=+libuci
endef

define Package/gl-sdk4-uci/description
A warp around libuci, aim to use simple
endef

define Download/guci-cmake
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=CMakeLists.txt
  FILE:=gl-sdk4-uci-7e5f319-CMakeLists.txt
  HASH:=5dc4af3fce8a1535412a610b281c7eaca73f475086deeed208e952326d953512
endef
$(eval $(call Download,guci-cmake))

define Download/guci-c
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=guci.c
  FILE:=gl-sdk4-uci-7e5f319-guci.c
  HASH:=0cd672ccc0623a2c795f00baccfcb035998a181a18900bd23c701b79c36a4d4c
endef
$(eval $(call Download,guci-c))

define Download/guci-h
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=guci.h
  FILE:=gl-sdk4-uci-7e5f319-guci.h
  HASH:=32e73c365953d1fc3c3bca45fb0c38744f197ee7a212a4aeeab161704d6ff072
endef
$(eval $(call Download,guci-h))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/gl-sdk4-uci-7e5f319-CMakeLists.txt $(PKG_BUILD_DIR)/CMakeLists.txt
	$(CP) $(DL_DIR)/gl-sdk4-uci-7e5f319-guci.c $(PKG_BUILD_DIR)/guci.c
	$(CP) $(DL_DIR)/gl-sdk4-uci-7e5f319-guci.h $(PKG_BUILD_DIR)/guci.h
endef

# libguci.so and guci.h for packages that link against it (oopslog, from
# 4.7.4 on built from GL.iNet's source too)
define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib $(1)/usr/include
	$(CP) $(PKG_BUILD_DIR)/libguci.so $(1)/usr/lib/
	$(CP) $(PKG_BUILD_DIR)/guci.h $(1)/usr/include/
endef

define Package/gl-sdk4-uci/install
	$(CP) ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libguci.so $(1)/usr/lib/
endef

$(eval $(call BuildPackage,gl-sdk4-uci))
