include $(TOPDIR)/rules.mk

PKG_NAME:=ski-mysql
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
  DEPENDS:=+lua +ski +libcrypto
  TITLE:= lua ski library for accessing mysql async 
endef

define Package/$(PKG_NAME)/description
  lua ski library for accessing mysql  
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

MAKE_FLAGS += CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"

define Package/$(PKG_NAME)/install 
	#$(INSTALL_DIR) $(1)/usr/lib/lua/
	#$(INSTALL_DATA) $(PKG_BUILD_DIR)/rdsparser.so $(1)/usr/lib/lua/
	#ls $(PKG_BUILD_DIR)/rdsparser.so $(1)/usr/lib/lua/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

