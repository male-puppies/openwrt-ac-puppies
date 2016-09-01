include $(TOPDIR)/rules.mk

PKG_NAME:=ski-redis
PKG_VERSION:=2015-08-06
PKG_RELEASE=1

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_MAINTAINER:=Jinshou Ye <aquariusye@163.com>

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:= +lua +ski +redis
  TITLE:= lua ski library for redis
endef

define Package/$(PKG_NAME)/description
  lua ski library for redis
endef

define Build/Prepare
endef

define Package/$(PKG_NAME)/install
	$(CP) -r files/* $(1)/usr/lib/lua/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

