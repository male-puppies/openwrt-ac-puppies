#
# Copyright (C) 2008-2010 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=klog
PKG_RELEASE:=3

include $(INCLUDE_DIR)/package.mk

define KernelPackage/klog
  CATEGORY:=Puppies
  SUBMENU:=Nos kernel modules
  TITLE:=nos kernel debug log driver
  FILES:=$(PKG_BUILD_DIR)/klog.ko
  AUTOLOAD:=$(call AutoProbe,klog)
  KCONFIG:=
endef

define KernelPackage/klog/description
  Kernel module for debug printk level set.
endef

EXTRA_KCONFIG:= \
	CONFIG_NTRACK=m

EXTRA_CFLAGS:= \
	$(patsubst CONFIG_%, -DCONFIG_%=1, $(patsubst %=m,%,$(filter %=m,$(EXTRA_KCONFIG)))) \
	$(patsubst CONFIG_%, -DCONFIG_%=1, $(patsubst %=y,%,$(filter %=y,$(EXTRA_KCONFIG)))) \

MAKE_OPTS:= \
	ARCH="$(LINUX_KARCH)" \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	SUBDIRS="$(PKG_BUILD_DIR)" \
	EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
	$(EXTRA_KCONFIG)

define Build/Prepare
	@echo --- $(TOOLCHAIN_DIR) ---
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
	$(CP) ./src/klog.h $(TOOLCHAIN_DIR)/include/linux/
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		$(MAKE_OPTS) \
		modules
endef

$(eval $(call KernelPackage,klog))
