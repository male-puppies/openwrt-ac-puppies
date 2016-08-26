#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=nos-zone
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0
 
include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +kmod-nos
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=Zone config load script
endef

define Package/$(PKG_NAME)/description
  Zone config script
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/nos-zone
endef

define Package/$(PKG_NAME)/postinst
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/nos-zone.init $(1)/etc/init.d/nos-zone
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/nos-zone.config $(1)/etc/config/nos-zone
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/nos-zone.sh $(1)/usr/bin/nos-zone
endef

define Build/Configure
  true
endef

define Build/Prepare
  true
endef

define Build/Compile
  true
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

