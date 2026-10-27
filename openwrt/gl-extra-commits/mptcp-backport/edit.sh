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
# GL.iNet's patch is for 5.4.281; three hunks need our 5.4.211 context (our
# construction, the added lines unchanged): net/Makefile has no muldf_helper
# line (another GL.iNet feature), and tcp_v6_connect assigns icsk_af_ops
# directly (5.4.281's WRITE_ONCE() came later from stable)
python3 - $T/patches-5.4/999-9999-2-compat-mptcp-proto.patch << 'PYP'
import sys
p = sys.argv[1]; s = open(p).read()
reps = [
    ("@@ -90,3 +90,5 @@", "@@ -90,2 +90,4 @@"),
    (" obj-y\t\t\t\t+= muldf_helper/\n+obj-$(CONFIG_MPTCP)", "+obj-$(CONFIG_MPTCP)"),
    ("@@ -238,6 +238,8 @@", "@@ -238,5 +238,7 @@"),
    (" \t\t/* Paired with READ_ONCE() in tcp_(get|set)sockopt() */\n \t\tWRITE_ONCE(icsk->icsk_af_ops, &ipv6_mapped);\n",
     " \t\ticsk->icsk_af_ops = &ipv6_mapped;\n"),
    ("@@ -249,6 +251,8 @@", "@@ -249,5 +251,7 @@"),
    (" \t\t\t/* Paired with READ_ONCE() in tcp_(get|set)sockopt() */\n \t\t\tWRITE_ONCE(icsk->icsk_af_ops, &ipv6_specific);\n",
     " \t\t\ticsk->icsk_af_ops = &ipv6_specific;\n"),
]
for old, new in reps:
    assert s.count(old) == 1, old
    s = s.replace(old, new)
open(p, "w").write(s)
PYP
