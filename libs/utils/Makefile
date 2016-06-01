include $(TOPDIR)/rules.mk

PKG_NAME:=libpps
PKG_VERSION:=2015-08-06
PKG_RELEASE=1

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=BSD

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_MAINTAINER:=John Crispin <blogic@openwrt.org>

include $(INCLUDE_DIR)/package.mk

define Package/libpps
  SECTION:=libs
  CATEGORY:=Puppies
  DEPENDS:=+pps_comm
  TITLE:=Generic common api libs for puppies.
endef

define Package/libpps/description
  common libs for puppies system.
endef

define Build/Prepare
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	-$(CP) $(PKG_BUILD_DIR)/*.h $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libpps.so* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/lib/pkgconfig
	-$(CP) $(PKG_BUILD_DIR)/pps.pc $(1)/usr/lib/pkgconfig/
endef

define Package/libpps/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libpps.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libpps))

