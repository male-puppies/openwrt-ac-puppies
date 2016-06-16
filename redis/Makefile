#
# Copyright (C) 2012-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=redis
PKG_VERSION:=3.2.0
PKG_RELEASE:=3

#http://download.redis.io/releases/redis-3.2.0.tar.gz
PKG_SOURCE:=luv-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://download.redis.io/releases/
PKG_MD5SUM:=9ec99ff912f35946fdb56fe273140483
PKG_MAINTAINER:=JinShou Ye <aquariusye@163.com>
PKG_LICENSE:=GPL-2.0

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= 
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=redis 3.2.0
endef


define Package/$(PKG_NAME)/description
	redis 3.2.0
endef

define Package/$(PKG_NAME)/conffiles
endef

define Build/Configure
	
endef

define Package/$(PKG_NAME)/install
	#$(INSTALL_DIR) $(1)/usr/lib/lua/
	#$(CP) $(PKG_INSTALL_DIR)/usr/lib/lua/luv.so $(1)/usr/lib/lua
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	#cp -r patch/* $(PKG_BUILD_DIR)/
	#pwd
	#echo $(PKG_BUILD_DIR)
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
