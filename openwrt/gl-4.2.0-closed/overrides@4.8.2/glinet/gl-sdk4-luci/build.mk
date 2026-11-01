# The LuCI packages gl-sdk4-luci bundles in /etc/luci_ipks (4.8.2 on) are
# GL.iNet's own build of the public LuCI feed (openwrt-21.02 at 63bfee6, as
# ours): built here too (extra_config selects them as modules) and bundled
# instead of the image's copies. Each must exist: a missing one fails the
# package rather than silently keeping GL.iNet's file.
PKG_BUILD_DEPENDS:=lucihttp luci luci-base luci-compat luci-app-firewall luci-app-opkg \
	luci-lib-base luci-lib-ip luci-lib-jsonc luci-lib-nixio luci-mod-admin-full \
	luci-mod-network luci-mod-status luci-mod-system luci-proto-ipv6 luci-proto-ppp \
	luci-theme-bootstrap rpcd-mod-luci rpcd-mod-rrdns

define Build/Compile
endef

define Package/gl-sdk4-luci/install-built
	sh ./bundle-luci.sh $(1)/etc/luci_ipks $(OUTPUT_DIR)/packages/$(ARCH_PACKAGES)
endef
