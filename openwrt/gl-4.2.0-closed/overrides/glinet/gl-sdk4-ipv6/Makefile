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

# Link order = GL.iNet's build machine's directory order (4.2.x: sub-output
# sub-func interface sub). The order of sub-output and sub-func is read from
# the official sipcalc (link-order.py: their string literals); interface.c
# has too few strings to place, so interface and sub keep the 4.2.x order.
# (make's $(shell) in a recursive variable: runs when the compile step
# expands it, after the sources are unpacked; the system Python: OpenWrt
# puts its own host Python first in PATH)
GL_SIPCALC_FIRST = $(or $(shell /usr/bin/python3 -I /work/link-order.py objects /work/cmp/off_root/usr/bin/sipcalc \
	$(PKG_BUILD_DIR)/src/sub-output.c $(PKG_BUILD_DIR)/src/sub-func.c 2>/dev/null \
	| sed "s|.*/||; s|\.c$$|.o|"),sub-output.o sub-func.o)

define Build/Compile
	$(call Build/Compile/Default,sipcalc_OBJECTS="$(GL_SIPCALC_FIRST) interface.o sub.o")
endef

define Package/gl-sdk4-ipv6/install
	$(CP) ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/sipcalc $(1)/usr/bin/
endef

$(eval $(call BuildPackage,gl-sdk4-ipv6))
