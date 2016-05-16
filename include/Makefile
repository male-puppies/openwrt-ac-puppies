include $(TOPDIR)/rules.mk

PKG_NAME:=pps_comm
PKG_VERSION:=2015-08-06
PKG_RELEASE=1

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_MAINTAINER:=John Crispin <blogic@openwrt.org>

include $(INCLUDE_DIR)/package.mk

define Package/pps_comm
  SECTION:=Applications
  CATEGORY:=Puppies
  TITLE:=Generic common include files
endef

define Package/pps_comm/description
  common header for puppies apps.
endef

define Build/Prepare
	$(CP) ./src/*.h $(TOOLCHAIN_DIR)/include/
endef

define Build/Compile
	true
endef

define Build/InstallDev
	# echo ---$(TOOLCHAIN_DIR)----
	$(CP) ./src/*.h $(TOOLCHAIN_DIR)/include/
endef

$(eval $(call BuildPackage,pps_comm))

