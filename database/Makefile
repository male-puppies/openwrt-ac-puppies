#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=database
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0
 
include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +ski +libsqlite3 +rdsparser +lua-cjson +luasql-sqlite3 +lualib-ac +luafilesystem +sqlite3-cli +base-config
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=lua single thread sqlite3 database
endef

define Package/$(PKG_NAME)/description
  lua single thread sqlite3 database
endef

define Package/$(PKG_NAME)/conffiles 
/etc/sqlite3
endef

define Package/$(PKG_NAME)/postinst
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/share/
	$(INSTALL_DIR) $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/usr/sbin
	
	$(INSTALL_BIN) ./files/database.init $(1)/etc/init.d/database
	$(CP) -r files/lib/* $(1)/usr/lib/lua/
	$(INSTALL_BIN) ./files/database.sh $(1)/usr/sbin/database
ifeq ($(CONFIG_TARGET_AC_qca9531),y)
	$(CP) -r files/database_ar71xx $(1)/usr/share/database 	
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

