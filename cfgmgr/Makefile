#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=cfgmgr
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0
 
include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +ski +lua-cjson +luasql-mysql +lualib-ac +database
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:= lua config update manager
endef

define Package/$(PKG_NAME)/description
  lua config update manager
endef

define Package/$(PKG_NAME)/conffiles 
endef

define Package/$(PKG_NAME)/postinst
endef

define Package/$(PKG_NAME)/install 
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/share/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/cfgmgr.init $(1)/etc/init.d/cfgmgr
	$(INSTALL_BIN) ./files/cfgmgr.sh $(1)/usr/sbin/cfgmgr
ifeq ($(CONFIG_TARGET_x86_64_Generic),y)
	#TODO change database_ar71xx to database_x86
	$(CP) -r files/cfgmgr_71xx $(1)/usr/share/
endif	
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

