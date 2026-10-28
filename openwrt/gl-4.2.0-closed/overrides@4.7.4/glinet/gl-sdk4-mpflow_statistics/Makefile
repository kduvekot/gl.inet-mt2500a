
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=gl-sdk4-mpflow_statistics
PKG_VERSION:=git-2024.352.34343-ddc056a
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define KernelPackage/$(PKG_NAME)
  SECTION:=base
  CATEGORY:=Kernel modules
  SUBMENU:=GL.iNet modules
  TITLE:=glinet mpflow statistics
  FILES:=$(PKG_BUILD_DIR)/gl-mpflow.ko
endef

KERNEL_MAKE_FLAGS?= \
	ARCH="$(LINUX_KARCH)" \
	CROSS_COMPILE="$(TARGET_CROSS)"

MAKE_OPTS:= \
	$(KERNEL_MAKE_FLAGS) \
	M="$(PKG_BUILD_DIR)"

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		$(MAKE_OPTS) \
		modules
endef

# (our addition) GL.iNet's MT2500 package also carries three scripts
# (/etc/init.d/mpflow, /etc/hotplug.d/iface/99-mpflow, /usr/bin/get_mpflow.sh,
# 4.7.4 to 4.9.0) that this published recipe doesn't install; they come from
# the image (files/, as for every closed package), the module from source
define KernelPackage/$(PKG_NAME)/install
	[ ! -d ./files/etc ] || $(CP) ./files/etc $(1)/
	[ ! -d ./files/usr ] || $(CP) ./files/usr $(1)/
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
