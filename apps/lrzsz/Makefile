#
# Copyright (C) 2006-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lrzsz
PKG_VERSION:=0.12.20
PKG_RELEASE:=1

PKG_SOURCE:=${PKG_NAME}-${PKG_VERSION}.tar.gz
PKG_SOURCE_URL:=https://ohse.de/uwe/releases/
PKG_MD5SUM:=b5ce6a74abc9b9eb2af94dffdfd372a4

PKG_MAINTAINER:=Bruno Randolf <ohse.de@gnu.org>
PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=COPYING

include $(INCLUDE_DIR)/package.mk

define Package/lrzsz/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  URL:=https://ohse.de/uwe/software/lrzsz.html
endef

define Package/lrzsz
  $(call Package/lrzsz/Default)
  TITLE:=Linux z-mode transport
endef

define Package/lrzsz/description
 lrzsz is a language that supports arbitrary precision numbers with
 interactive execution of statements.
endef

define Package/lrzsz/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lrz $(1)/usr/bin/rz
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lsz $(1)/usr/bin/sz
endef

$(eval $(call BuildPackage,lrzsz))
