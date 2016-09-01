#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=performer
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0
 
include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +ski +lua-cjson +lua-md5 +luasql-mysql +lualib-ac +nos-auth +nos-ipgrp +nos-tbqd +nos-zone +ruletable +cfgmgr +cfgmgr-common
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:= performer
endef

define Package/$(PKG_NAME)/description
  transform config stored in database and act
endef

define Package/$(PKG_NAME)/conffiles 
endef

define Package/$(PKG_NAME)/postinst
endef

define Package/$(PKG_NAME)/install 
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/performer.init $(1)/etc/init.d/performer
	$(INSTALL_DIR) $(1)/usr/share/
	cp -r files/performer $(1)/usr/share/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/performer.sh $(1)/usr/sbin/performer
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

