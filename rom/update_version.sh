#!/bin/sh

set -x
sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"V2.0-`date +%Y%m%d%H%M`\"/" ./.config
touch ./package/base-files/files/etc/openwrt_release
set +x
