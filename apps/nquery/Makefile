include $(TOPDIR)/rules.mk

PKG_NAME:=nquery
PKG_VERSION:=2015-08-06
PKG_RELEASE=1

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_MAINTAINER:=John Crispin <blogic@openwrt.org>

include $(INCLUDE_DIR)/package.mk

define Package/nquery
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:=+pps_comm +libpps +libpcap
  TITLE:=Generic ntrack query user space tools 
endef

define Package/nquery/description
  nquery system for user track & flow track.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

TARGET_LDFLAGS += -lpps -lpcap

MAKE_FLAGS += CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"

define Package/nquery/install
	#$(CP) -a ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/nquery $(1)/usr/sbin/nquery
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) ./files/nquery.lua $(1)/usr/lib/lua/nquery.lua
endef

$(eval $(call BuildPackage,nquery))

