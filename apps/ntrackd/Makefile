include $(TOPDIR)/rules.mk

PKG_NAME:=ntrackd
PKG_VERSION:=2015-08-06
PKG_RELEASE=1

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_MAINTAINER:=John Crispin <blogic@openwrt.org>

include $(INCLUDE_DIR)/package.mk

define Package/ntrackd
  SECTION:=Applications
  CATEGORY:=Puppies
  DEPENDS:=+pps_comm +libpps
  TITLE:=Generic ntrackd user space tools 
endef

define Package/ntrackd/description
  ntrackd system for user track & flow track.
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

define Package/ntrackd/install
	$(CP) -a ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ntrackd $(1)/usr/sbin/ntrackd
endef

define Package/ntrackd/postinst
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Enabling rc.d symlink for tbq"
	/etc/init.d/ntrackd enable
fi
exit 0
endef

define Package/ntrackd/prerm
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Removing rc.d symlink for ntrackd"
	/etc/init.d/ntrackd disable
fi
exit 0
endef

$(eval $(call BuildPackage,ntrackd))

