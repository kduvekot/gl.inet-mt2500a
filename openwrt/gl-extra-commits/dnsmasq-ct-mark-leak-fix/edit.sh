#!/bin/sh
# GL.iNet's 4.8.2+ dnsmasq also creates the user dnsmasq_vpn (uid 456, group
# dnsmasq), as in GL.iNet's published dnsmasq Makefile (gl-inet/gl-image,
# gl-be10000 bfe99df8, versions/4.8.6). Part of this commit so dnsmasq's
# AUTORELEASE stays GL.iNet's (2.85-14 in 4.8.2).
set -e
f=package/network/services/dnsmasq/Makefile
grep -q '^  USERID:=dnsmasq=453:dnsmasq=453$' "$f"
sed -i 's/^  USERID:=dnsmasq=453:dnsmasq=453$/  USERID:=dnsmasq=453:dnsmasq=453 dnsmasq_vpn=456:dnsmasq=453/' "$f"
