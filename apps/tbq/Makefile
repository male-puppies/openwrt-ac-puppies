include $(TOPDIR)/rules.mk

PKG_NAME:=tbqd
PKG_VERSION:=2015-08-06
PKG_RELEASE=1

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=

PKG_MAINTAINER:=John Crispin <blogic@openwrt.org>

include $(INCLUDE_DIR)/package.mk

define Package/tbqd
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Generic tbqd user space scripts & htmls 
endef

define Build/Compile
	true
endef

define Package/wwan/install
	$(INSTALL_DATA) ./files/* $(1)/
endef

$(eval $(call BuildPackage,tbqd))
