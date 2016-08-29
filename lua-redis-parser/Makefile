#
# Copyright (C) 2012-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lua-redis-parser
PKG_VERSION:=0.12
PKG_RELEASE:=1

#https://github.com/openresty/lua-redis-parser/archive/v0.12.tar.gz
PKG_SOURCE:=v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/openresty/lua-redis-parser/archive/
PKG_MD5SUM:=bfd4d18134578c1381f8d467c026a6db
PKG_MAINTAINER:=JinShou Ye <aquariusye@163.com>
PKG_LICENSE:=GPL-2.0

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +liblua
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=lua-redis-parser
endef


define Package/$(PKG_NAME)/description
	lua-redis-parser
endef

define Package/$(PKG_NAME)/conffiles
endef

define Build/Configure

endef

define Build/Compile
	+$(MAKE) -C $(PKG_BUILD_DIR) $(TARGET_CONFIGURE_OPTS)
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/redis/
	$(CP) $(PKG_INSTALL_DIR)/usr/local/lib/lua/5.1/redis/parser.so $(1)/usr/lib/lua/redis/
endef

define Build/Prepare
	$(call Build/Prepare/Default)
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
