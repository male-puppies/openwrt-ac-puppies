include $(TOPDIR)/rules.mk

PKG_NAME:=ruletable
PKG_VERSION:=2015-08-06
PKG_RELEASE=1

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_MAINTAINER:=Ivan <itgb1989@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=Applications
  CATEGORY:=Puppies
  TITLE:=Administration tool for Access control 
  DEPENDS:= +pps_comm
endef

define Package/$(PKG_NAME)/description
  Administration tool for Access control
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef


MAKE_FLAGS += CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"

define Package/$(PKG_NAME)/install
	#$(CP) -a ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ruletable $(1)/usr/sbin/ruletable
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

