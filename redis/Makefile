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
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://download.redis.io/releases/
PKG_MD5SUM:=9ec99ff912f35946fdb56fe273140483
PKG_MAINTAINER:=JinShou Ye <aquariusye@163.com>
PKG_LICENSE:=GPL-2.0

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +libc +libpthread
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

define Build/Compile
	+$(MAKE) install -C "$(PKG_BUILD_DIR)" USE_JEMALLOC=no PREFIX="$(PKG_INSTALL_DIR)" INSTALL_BIN="$(PKG_INSTALL_DIR)/bin" LDFLAGS="-lc -lm -lpthread" $(TARGET_CONFIGURE_OPTS)
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/redis-cli $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/redis-server $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/redis-check-aof $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/redis-check-rdb $(1)/usr/sbin/
	
	$(INSTALL_DIR) $(1)/usr/share/redis 
	$(CP) -r files/conf $(1)/usr/share/redis
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/redis.init $(1)/etc/init.d/redis
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/redis.sh $(1)/usr/sbin/redis
endef

define Build/Prepare
	$(call Build/Prepare/Default)
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
