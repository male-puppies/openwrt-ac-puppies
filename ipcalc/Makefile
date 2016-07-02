#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=ipcalc
PKG_VERSION:=0.41
PKG_RELEASE:=

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://jodies.de/ipcalc-archive/
PKG_SOURCE_VERSION:=$(PKG_VERSION)
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/ipcalc/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +perl +perlbase-essential
endef

define Package/ipcalc
  $(call Package/ipcalc/Default)
  TITLE:=IP Calculator
endef

define Package/ipcalc/description
 ipcalc takes an IP address and netmask and calculates the resulting
 broadcast, network, Cisco wildcard mask, and host range. By giving a
 second netmask, you can design subnets and supernets. It is also
 intended to be a teaching tool and presents the subnetting results as
 easy-to-understand binary values.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/ipcalc/conffiles
endef

define Package/ipcalc/postinst
endef

define Package/ipcalc/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ipcalc $(1)/usr/bin/ipcalc
endef

$(eval $(call BuildPackage,ipcalc))
