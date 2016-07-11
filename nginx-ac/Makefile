#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=nginx-ac
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Jinshou Ye <aquariusye@163.com>
PKG_LICENSE:=GPL-2.0
 
include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +nginx +ski
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:= nginx config and ngxrpc lib
endef

define Package/$(PKG_NAME)/description
	nginx config and ngxrpc lib
endef

define Package/$(PKG_NAME)/conffiles
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh

if [ -z "$$IPKG_INSTROOT" ]; then
  ( . /etc/uci-defaults/95-nginx-ac )
  rm -f /etc/uci-defaults/95-nginx-ac
fi

exit 0
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DATA) ./files/nginx-ac.defaults $(1)/etc/uci-defaults/95-nginx-ac
	$(INSTALL_DIR) $(1)/usr/share/nginx-ac/
	$(CP) -r ./files/demo $(1)/usr/share/nginx-ac/
	$(CP) -r ./files/html $(1)/usr/share/nginx-ac/
	$(INSTALL_DATA) ./files/nginx.conf $(1)/usr/share/nginx-ac/
	$(CP) -r ./files/sites-enabled $(1)/usr/share/nginx-ac/
	$(INSTALL_BIN) ./files/nginx.init $(1)/usr/share/nginx-ac/nginx.init
	$(CP) -r ./files/lualib $(1)/usr/share/nginx-ac/
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(CP) -r ./files/lib/* $(1)/usr/lib/lua/
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

