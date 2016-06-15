#
# Copyright (C) 2012-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luv
PKG_VERSION:=1.9.0-3
PKG_RELEASE:=1

#https://github.com/luvit/luv/releases/download/1.9.0-3/luv-1.9.0-3.tar.gz
PKG_SOURCE:=luv-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/luvit/luv/releases/download/1.9.0-3/
PKG_MD5SUM:=171d5ac227d4a4e36190c56f35f15f9d
PKG_MAINTAINER:=JinShou Ye <aquariusye@163.com>
PKG_LICENSE:=GPL-2.0

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +libuv +liblua
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=lua binding for libuv
endef


define Package/$(PKG_NAME)/description
	lua binding for libuv
endef

define Package/$(PKG_NAME)/conffiles
endef

define Build/Configure
	
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/lua/luv.so $(1)/usr/lib/lua
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	cp -r patch/* $(PKG_BUILD_DIR)/
	pwd
	echo $(PKG_BUILD_DIR)
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
