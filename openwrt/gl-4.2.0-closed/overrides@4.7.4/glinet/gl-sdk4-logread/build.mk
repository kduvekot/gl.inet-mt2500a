# oopslog of 4.7.4 on from GL.iNet's published source (gl-inet/gl-image,
# gl-be10000 4.8.6 package/utils/gl-oopslog, GPL-2.0, "source_files_unmodified"
# from gl-sdk4-logread 90760d8), built like GL.iNet's recipe against
# libguci: byte-identical for 4.7.4, 4.8.2 and 4.9.0 (2026-10-28). The program
# carries its build date and time (__DATE__/__TIME__); GL.iNet's are read
# from the image's copy and given to the compiler as SOURCE_DATE_EPOCH.
# (4.1.1-4.7.0 used an older source, %d where this has %u: not public.)
GL_IMAGE_SRC:=https://raw.githubusercontent.com/gl-inet/gl-image/bfe99df8e1872b63aee42d2bcd98b6b093c1ccf9/versions/4.8.6/package/utils/gl-oopslog/src
PKG_BUILD_DEPENDS:=gl-sdk4-uci

define Download/oopslog-c
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=oopslog.c
  FILE:=gl-oopslog-bfe99df-oopslog.c
  HASH:=2a43712dce5721a24ac3b5ccd5d7e7d7b462e34098e17fd51362a4010e4cf0d2
endef
$(eval $(call Download,oopslog-c))

define Download/oopslog-mk
  URL:=$(GL_IMAGE_SRC)
  URL_FILE:=Makefile
  FILE:=gl-oopslog-bfe99df-Makefile
  HASH:=1db2d2cb5003a6e369e7d73e1d738ec40ca6df39b26b55f6426a2b4b3144db06
endef
$(eval $(call Download,oopslog-mk))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/gl-oopslog-bfe99df-oopslog.c $(PKG_BUILD_DIR)/oopslog.c
	$(CP) $(DL_DIR)/gl-oopslog-bfe99df-Makefile $(PKG_BUILD_DIR)/Makefile
endef

define Build/Compile
	SOURCE_DATE_EPOCH=`sh ./build-date.sh ./files/usr/bin/oopslog` \
	$(MAKE) -C $(PKG_BUILD_DIR) $(TARGET_CONFIGURE_OPTS) \
		CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS) $(TARGET_LDFLAGS) -Wl,-rpath-link=$(STAGING_DIR)/usr/lib" -j1
	$(STAGING_DIR_HOST)/bin/sstrip -z $(PKG_BUILD_DIR)/oopslog
endef

define Package/gl-sdk4-logread/install-built
	# over the image's copy, keeping its mode
	cat $(PKG_BUILD_DIR)/oopslog > $(1)/usr/bin/oopslog
endef
