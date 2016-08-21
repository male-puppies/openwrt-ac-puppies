#
# Copyright (C) 2014-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
#include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=cjson
PKG_VERSION:=4.0.1
PKG_RELEASE:=3a7bd6924a67c301b8811f521de6ed07c7cf0c3c

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE).tar.xz
PKG_SOURCE_URL:=https://github.com/DaveGamble/cJSON.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=$(PKG_RELEASE)
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_MAINTAINER:=Chen Minqiang <ptpt52@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default
  SECTION:=Applications
  CATEGORY:=Puppies
  #DEPENDS:= +perl +perlbase-essential
endef

define Package/$(PKG_NAME)
  $(call Package/$(PKG_NAME)/Default)
  TITLE:=cjson
endef

define Package/ipcalc/description
cJSON aims to be the dumbest possible parser that you can get your job done with.
It's a single file of C, and a single header file.
endef

TARGET_CFLAGS += $(FPIC)

CONFIGURE_ARGS += \
	--enable-shared \
	--enable-static \

MAKE_FLAGS += \
	CFLAGS="$(TARGET_CFLAGS)" \

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/libcjson
	$(CP) $(PKG_INSTALL_DIR)/usr/include/* $(1)/usr/include/libcjson/
	$(INSTALL_DIR) $(1)/usr/lib/libcjson
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/*.{a,so} $(1)/usr/lib/libcjson/
endef

define Package/libevent/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/*.so.* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libevent))
