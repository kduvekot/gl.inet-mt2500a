include $(TOPDIR)/rules.mk

PKG_NAME:=gl-sdk4-ipv6
PKG_VERSION:=git-2023.045.36273-662fe6b
PKG_RELEASE:=1

# /usr/bin/sipcalc is sipcalc 1.1.6 built as below (verified byte-identical
# with GL.iNet's in the oss feed, 2026-10-25).
PKG_SOURCE:=sipcalc_1.1.6.orig.tar.gz
PKG_SOURCE_URL:=http://deb.debian.org/debian/pool/main/s/sipcalc/
PKG_HASH:=cfd476c667f7a119e49eb5fe8adcfb9d2339bc2e0d4d01a1d64b7c229be56357
PKG_BUILD_DIR:=$(BUILD_DIR)/sipcalc-1.1.6

include $(INCLUDE_DIR)/package.mk

CONFIGURE_VARS += ac_cv_func_gethostbyname=no ac_cv_func_gethostbyname2=no ac_cv_func_inet_ntop=no \
	ac_cv_func_getipnodebyaddr=no ac_cv_func_getaddrinfo=no ac_cv_func_getopt_long=no

define Build/Configure
	$(call Build/Configure/Default)
	sed -i -E 's/^#define (HAVE_(GETHOSTBYNAME2?|GETADDRINFO)(_NETDB)?|HAVE_INET_NTOP|HAVE_GETOPT_LONG) .*/\/* #undef \1 *\//' $(PKG_BUILD_DIR)/config.h
endef

define Package/gl-sdk4-ipv6
  SECTION:=base
  CATEGORY:=GL.iNet (closed, from the official image)
  TITLE:=glinet SDK4 ipv6 module
  DEPENDS:=+libiwinfo-lua +kmod-ipt-nat6 +gl-sdk4-lua-utils
endef

define Package/gl-sdk4-ipv6/description
glinet SDK4 ipv6 module
endef

define Build/Compile
	$(call Build/Compile/Default,sipcalc_OBJECTS="sub-output.o sub-func.o interface.o sub.o")
endef

define Package/gl-sdk4-ipv6/install
	$(CP) ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/sipcalc $(1)/usr/bin/
endef

$(eval $(call BuildPackage,gl-sdk4-ipv6))
