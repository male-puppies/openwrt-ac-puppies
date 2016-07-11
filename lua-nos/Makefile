include $(TOPDIR)/rules.mk

PKG_NAME:=luanos
PKG_VERSION:=1.0
PKG_RELEASE=0

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_MAINTAINER:=Jinshou Ye <aquariusye@163.com>

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:=+lua +pps_comm +libpps
  TITLE:=lua binding for nos
endef

define Package/$(PKG_NAME)/description
  lua binding for nos 
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

TARGET_LDFLAGS += -lpps -lpthread
TARGET_CFLAGS += -pthread

MAKE_FLAGS += \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"

define Package/$(PKG_NAME)/install 
	$(INSTALL_DIR) $(1)/usr/lib/lua/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/luanos.so $(1)/usr/lib/lua/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
