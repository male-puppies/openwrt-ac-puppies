#
# Copyright (C) 2012-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=resty-mysql
PKG_VERSION:=0.16
PKG_RELEASE:=0

#https://github.com/openresty/lua-resty-mysql/archive/v0.16.tar.gz
PKG_SOURCE:=v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/openresty/lua-resty-mysql/archive/
PKG_MD5SUM:=07528b833a2b2190cebe2fe6a9aa4d12
PKG_MAINTAINER:=JinShou Ye <aquariusye@163.com>
PKG_LICENSE:=GPL-2.0

PKG_BUILD_DIR:=$(BUILD_DIR)/lua-$(PKG_NAME)-$(PKG_VERSION)

PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +nginx +luabitop +mysql
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=nignx mysql module 
endef


define Package/$(PKG_NAME)/description
	nignx mysql module 
endef

define Package/$(PKG_NAME)/conffiles
endef

define Build/Configure
	
endef

define Package/$(PKG_NAME)/install 
	$(INSTALL_DIR) $(1)/usr/lib/lua/resty
	$(CP) $(PKG_INSTALL_DIR)/usr/local/lib/lua/resty/mysql.lua $(1)/usr/lib/lua/resty
endef

define Build/Prepare 
	$(call Build/Prepare/Default) 
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
