#!/bin/sh

set -x
sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"2.0.0_build`date +%Y%m%d%H%M`\"/" ./.config
touch ./package/base-files/files/etc/openwrt_release
set +x
