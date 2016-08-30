#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=struct
PKG_VERSION:=0.2
PKG_RELEASE:=

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://www.inf.puc-rio.br/~roberto/struct/
PKG_SOURCE_VERSION:=$(PKG_VERSION)
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/struct/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:=+lua
endef

define Package/struct
  $(call Package/struct/Default)
  TITLE:=struct
endef

define Package/struct/description
 Library for Converting Data to and from C Structs for Lua 5.1/5.2
endef

define Build/Configure
endef

define Build/Prepare
	gzip -dc $(DL_DIR)/$(FILE) | tar -C $(PKG_BUILD_DIR) $(TAR_OPTIONS)
endef

define Package/struct/conffiles
endef

define Package/struct/postinst
endef

define Package/struct/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/struct.so $(1)/usr/lib/lua/
endef

$(eval $(call BuildPackage,struct))
