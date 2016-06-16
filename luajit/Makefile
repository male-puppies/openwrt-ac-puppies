#
# Copyright (C) 2012-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=LuaJIT
PKG_VERSION:=2.1.0-beta2
PKG_RELEASE:=2

PKG_SOURCE:=LuaJIT-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://luajit.org/download/
PKG_MD5SUM:=fa14598d0d775a7ffefb138a606e0d7b
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
  TITLE:=luajit
endef


define Package/$(PKG_NAME)/description
	luajit
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
	#echo $(PKG_BUILD_DIR)
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
