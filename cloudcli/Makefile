#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=cloudcli
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +ski +lua-cjson +lualib-ac +proxybase
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=cloud registry and update config from cloud
endef

define Package/$(PKG_NAME)/description
  cloud registry and update config from cloud
endef

define Package/$(PKG_NAME)/conffiles
endef

define Package/$(PKG_NAME)/postinst
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/cloudcli.init $(1)/etc/init.d/cloudcli
	$(INSTALL_DIR) $(1)/usr/share/
	cp -r files/cloudcli $(1)/usr/share/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/cloudcli.sh $(1)/usr/sbin/cloudcli
	$(INSTALL_BIN) ./files/resetcfg.sh $(1)/usr/sbin/resetcfg.sh
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