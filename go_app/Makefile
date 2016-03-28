#
# Copyright (C) 2006-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=go_app
PKG_VERSION:=2015-08-20
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=
PKG_MAINTAINER:=helloshiki <aquariusye@163.com>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=Applications
	CATEGORY:=Puppies
	TITLE:=golang-based application
endef

define Package/$(PKG_NAME)/description
	golang  
endef


define Build/Prepare 
	$(shell if [ ! -e go ]; then \
		tar -xzf $(DL_DIR)/go1.5.1.linux-amd64.tar.gz -C . ; \
	fi)
	true
endef

define Build/Compile 
	ARCH=$(ARCH) \
	SUBARCH=$(ARCH) \
	CGO_ENABLED=1 \
	CROSS_COMPILE=$(TARGET_CROSS) \
	GOROOT="`pwd`/go" \
	GOPATH="`pwd`/src/go" \
	CGO_CFLAGS="-std=gnu99 -fno-strict-aliasing -D_GNU_SOURCE $(HOST_CFLAGS)" \
	CFLAGS="$(HOST_CFLAGS)" \
	CXXFLAGS="$(HOST_CFLAGS)" \
	STAGING_DIR="$(STAGING_DIR)" \
	PATH="`pwd`/go/bin:$(PATH)" \
	LD_LIBRARY_PATH="$(STAGING_DIR_HOST)/lib:$(STAGING_DIR_HOST)/usr/lib:$(STAGING_DIR)/host/lib" \
	$(MAKE) -C src/go/src/app $(TARGET_CONFIGURE_OPTS) 
	true
endef

define Package/$(PKG_NAME)/install
	#install -d -m0755 /home/opmt.git/staging_dir/target-mipsel_1004kc+dsp_musl-1.1.10/root-ramips/tmp-except/usr/bin 
	#$(CP) -a ./root/* $(1)/
endef

define Package/$(PKG_NAME)/postinst
	true
	exit 0
endef

define Package/$(PKG_NAME)/prerm
	true
	exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
