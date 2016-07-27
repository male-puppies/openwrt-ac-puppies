#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=ac-basic
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0
 
include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +ski +libsqlite3 +rdsparser +lua-cjson +luasql-sqlite3 +luasql-mysql +lualib-ac +luafilesystem +sqlite3-cli
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=basic tools 
endef

define Package/$(PKG_NAME)/description
	basic tools 
endef

define Package/$(PKG_NAME)/conffiles 
endef

define Package/$(PKG_NAME)/postinst
endef

define Package/$(PKG_NAME)/install 

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

