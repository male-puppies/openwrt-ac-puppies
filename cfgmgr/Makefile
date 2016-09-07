#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=cfgmgr
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/cfgmgr
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +ski +lua-cjson +openssl-util +lualib-ac +database +logserver +sands +base-config +nginx-ac +admin-web +cfgmgr-common
  TITLE:= lua config update manager
endef

define Package/cfgmgr/description
  lua config update manager
endef

define Package/cfgmgr/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/cfgmgr.init $(1)/etc/init.d/cfgmgr
	$(INSTALL_BIN) ./files/cfgmgr.sh $(1)/usr/sbin/cfgmgr
	$(INSTALL_BIN) ./files/openssltar.sh $(1)/usr/sbin/openssltar.sh
	$(INSTALL_BIN) ./files/system_reset.sh $(1)/usr/sbin/system_reset
ifeq ($(CONFIG_TARGET_AC_qca9531),y)
	$(INSTALL_DIR) $(1)/usr/share/cfgmgr
	$(INSTALL_DATA) ./files/cfgmgr_71xx/acgroup.lua $(1)/usr/share/cfgmgr/acgroup.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/acrule.lua $(1)/usr/share/cfgmgr/acrule.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/acset.lua $(1)/usr/share/cfgmgr/acset.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/authrule.lua $(1)/usr/share/cfgmgr/authrule.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/cfglib.lua $(1)/usr/share/cfgmgr/cfglib.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/cfg.lua $(1)/usr/share/cfgmgr/cfg.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/cloud.lua $(1)/usr/share/cfgmgr/cloud.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/dbevent.lua $(1)/usr/share/cfgmgr/dbevent.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/firewall.lua $(1)/usr/share/cfgmgr/firewall.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/iface.lua $(1)/usr/share/cfgmgr/iface.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/ipgroup.lua $(1)/usr/share/cfgmgr/ipgroup.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/kv.lua $(1)/usr/share/cfgmgr/kv.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/main.lua $(1)/usr/share/cfgmgr/main.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/mwan.lua $(1)/usr/share/cfgmgr/mwan.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/route.lua $(1)/usr/share/cfgmgr/route.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/system.lua $(1)/usr/share/cfgmgr/system.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/tc.lua $(1)/usr/share/cfgmgr/tc.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/timegroup.lua $(1)/usr/share/cfgmgr/timegroup.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/user.lua $(1)/usr/share/cfgmgr/user.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/zone.lua $(1)/usr/share/cfgmgr/zone.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/radio.lua $(1)/usr/share/cfgmgr/radio.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/wlanssid.lua $(1)/usr/share/cfgmgr/wlanssid.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/applist.lua $(1)/usr/share/cfgmgr/applist.lua
	$(INSTALL_BIN) ./files/cfgmgr_71xx/sysbackup.sh $(1)/usr/share/cfgmgr/sysbackup.sh
endif
endef

define Package/cfgmgr-common
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +lua-cjson +lualib-ac +base-config
  TITLE:= lua config update manager common libraries
endef

define Package/cfgmgr-common/description
  cfgmgr common libraries
endef

define Package/cfgmgr-common/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/cfgmgr
ifeq ($(CONFIG_TARGET_AC_qca9531),y)
	$(INSTALL_DATA) ./files/cfgmgr_71xx/common/board.lua $(1)/usr/lib/lua/cfgmgr/board.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/common/network.lua $(1)/usr/lib/lua/cfgmgr/network.lua
	$(INSTALL_DATA) ./files/cfgmgr_71xx/common/mwan.lua $(1)/usr/lib/lua/cfgmgr/mwan.lua
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

$(eval $(call BuildPackage,cfgmgr-common))
$(eval $(call BuildPackage,cfgmgr))
