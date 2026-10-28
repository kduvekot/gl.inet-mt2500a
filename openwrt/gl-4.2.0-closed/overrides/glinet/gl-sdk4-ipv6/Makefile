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
  DEPENDS:=
endef

define Package/gl-sdk4-ipv6/description
glinet SDK4 ipv6 module
endef

# Link order = GL.iNet's build machine's directory order: 4.2.x sub-output
# sub-func interface sub; from 4.4.x on the sorted order, interface sub-func
# sub-output sub (both verified byte-identical, 2026-10-27). Which one is
# read from the official sipcalc by the position of a string from sub-output
# and sub-func (link-order.py marks); interface.c has no string of its own.
# OpenWrt reads this recipe before the sources are unpacked, so it can't
# look at them.
GL_SIPCALC_MARKS := $(shell /usr/bin/python3 -I /work/link-order.py marks /work/cmp/off_root/usr/bin/sipcalc \
	"sub-output.o=Compressed address" "sub-func.o=Aggregatable Global Unicast Addresses" 2>/dev/null)
GL_SIPCALC_OBJECTS := $(if $(filter sub-func.o,$(firstword $(GL_SIPCALC_MARKS))),\
	interface.o sub-func.o sub-output.o sub.o,sub-output.o sub-func.o interface.o sub.o)

define Build/Compile
	$(call Build/Compile/Default,sipcalc_OBJECTS="$(GL_SIPCALC_OBJECTS)")
endef

define Package/gl-sdk4-ipv6/install
	$(CP) ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/sipcalc $(1)/usr/bin/
endef

$(eval $(call BuildPackage,gl-sdk4-ipv6))
