#!/bin/sh
# MPTCP for kernel 5.4: GL.iNet's backport of upstream MPTCP (net/mptcp,
# headers, one kernel patch) and its kmod-mptcp definition, as published in
# GL.iNet's GPL tree for the BE10000 (gl-inet/gl-image, branch gl-be10000,
# commit bfe99df8, versions/4.8.6). Fetched and checked here (files.sha256),
# not stored. 4.6.2: MPTCP=y, MPTCP_IPV6=y; 4.7.0+: package kmod-mptcp.
# The version in GL.iNet's MT2500 builds may be older (the backport differs
# slightly between GL.iNet's trees).
set -e
d=$(dirname "$0")
R=https://raw.githubusercontent.com/gl-inet/gl-image/bfe99df8e1872b63aee42d2bcd98b6b093c1ccf9/versions/4.8.6/target/linux/mediatek
T=target/linux/mediatek
while read -r sum f; do
	mkdir -p "$T/$(dirname "$f")"
	curl -fsSL --retry 5 -o "$T/$f" "$R/$f"
	echo "$sum  $T/$f" | sha256sum -c -
done < "$d/files.sha256"
cat >> package/kernel/linux/modules/netsupport.mk << 'MK'

define KernelPackage/mptcp
  SUBMENU:=$(NETWORK_SUPPORT_MENU)
  TITLE:=MPTCP support
  KCONFIG:= \
    CONFIG_MPTCP=y \
    CONFIG_MPTCP_IPV6=y \
    CONFIG_MPTCP_HMAC_TEST=n \
    CONFIG_SKB_EXTENSIONS=y
  AUTOLOAD:=$(call AutoProbe, mptcp)
endef

define KernelPackage/mptcp/description
  MPTCP support
endef

$(eval $(call KernelPackage,mptcp))
MK
