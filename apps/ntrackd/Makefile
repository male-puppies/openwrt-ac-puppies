#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=ntrackd
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0
 
include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +pps_comm +libpps +libcjson
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=Generic ntrackd user space tools
endef

define Package/$(PKG_NAME)/description
  ntrackd system for user track & flow track.
endef

define Package/$(PKG_NAME)/conffiles
endef

define Package/$(PKG_NAME)/postinst
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

TARGET_LDFLAGS += -lpps -lpthread -lcjson
TARGET_CFLAGS += -pthread

MAKE_FLAGS += \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/ntrackd.init $(1)/etc/init.d/ntrackd
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ntrackd $(1)/usr/sbin/ntrackd
endef

define Build/Configure
  true
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

