#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=base-config
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  SUBMENU:=Base config setup for AP/AC
  DEPENDS:= +maccalc +ethtool
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=$(PKG_NAME)
endef

define Package/$(PKG_NAME)/config
  source "$(SOURCE)/Config.in"
endef

define Package/$(PKG_NAME)/description
  Base config for AP or AC
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh

if [ -z "$$IPKG_INSTROOT" ]; then
  ( . /etc/uci-defaults/95-base-config )
  rm -f /etc/uci-defaults/95-base-config
fi

exit 0
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/share/base-config
	cp -r ./files/etc $(1)/usr/share/base-config/
	$(INSTALL_DIR) $(1)/etc/uci-defaults
ifeq ($(CONFIG_TARGET_AC_x86_64),y)
	$(INSTALL_DATA) ./files/x86_64/uci.defaults $(1)/etc/uci-defaults/95-base-config
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/x86_64/fstab.config $(1)/etc/config/fstab
	$(INSTALL_DIR) $(1)/lib/preinit
	$(INSTALL_DATA) ./files/x86_64/disk_ready.preinit $(1)/lib/preinit/79_disk_ready
endif
ifeq ($(CONFIG_TARGET_AC_qca9531),y)
	$(INSTALL_DATA) ./files/qca9531/board.json $(1)/usr/share/base-config/board.json
	$(INSTALL_DATA) ./files/qca9531/uci.defaults $(1)/etc/uci-defaults/95-base-config
	$(INSTALL_DATA) ./files/board.lua $(1)/usr/share/base-config/board.lua
	$(INSTALL_DATA) ./files/qca9531/wireless.json $(1)/usr/share/base-config/wireless.json
	$(INSTALL_DATA) ./files/qca9531/applist.json $(1)/usr/share/base-config/applist.json
	$(INSTALL_DATA) ./files/qca9531/default_version.json $(1)/usr/share/base-config/default_version.json
	$(INSTALL_DATA) ./files/qca9531/cloud.json $(1)/usr/share/base-config/cloud.json
endif
ifeq ($(CONFIG_TARGET_AC_qca9563),y)
	$(INSTALL_DATA) ./files/qca9563/board.json $(1)/usr/share/base-config/board.json
	$(INSTALL_DATA) ./files/qca9563/uci.defaults $(1)/etc/uci-defaults/95-base-config
	$(INSTALL_DATA) ./files/board.lua $(1)/usr/share/base-config/board.lua
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

