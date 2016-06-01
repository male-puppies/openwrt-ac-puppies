#!/bin/sh
COMM_SO_DIR=/tmp
ARCH=x86_64 \
SUBARCH=x86_64 \
CGO_CFLAGS="-I/opt/86/openwrt-openwrt-puppies/staging_dir/host/include -I/opt/86/openwrt-openwrt-puppies/staging_dir/host/usr/include -I/opt/86/openwrt-openwrt-puppies/staging_dir/target-x86_64_musl-1.1.12/host/include -std=gnu99 -fno-strict-aliasing -D_GNU_SOURCE" \
CROSS_COMPILE=x86_64-openwrt-linux-musl- \
CGO_ENABLED=1 \
CC=/opt/86/openwrt-openwrt-puppies/staging_dir/toolchain-x86_64_gcc-5.2.0_musl-1.1.12/bin/x86_64-openwrt-linux-musl-gcc \
PATH=`pwd`/go/bin:/opt/86/openwrt-openwrt-puppies/staging_dir/toolchain-x86_64_gcc-5.2.0_musl-1.1.12/bin:/opt/86/openwrt-openwrt-puppies/staging_dir/host/bin:/opt/86/openwrt-openwrt-puppies/staging_dir/toolchain-x86_64_gcc-5.2.0_musl-1.1.12/bin:/opt/86/openwrt-openwrt-puppies/staging_dir/toolchain-x86_64_gcc-5.2.0_musl-1.1.12/bin:/opt/86/openwrt-openwrt-puppies/staging_dir/host/bin:/opt/86/openwrt-openwrt-puppies/staging_dir/host/bin:/ugw/bin:/ugw/script:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/root/bin \
GOROOT=`pwd`/go \
GOPATH=`pwd`/src/go \
CGO_LDFLAGS="-L${COMM_SO_DIR} -O2 -Wl,-rpath-link,${COMM_SO_DIR}" \
STAGING_DIR=/opt/86/openwrt-openwrt-puppies/staging_dir/target-x86_64_musl-1.1.12 \
CFLAGS="-I/opt/86/openwrt-openwrt-puppies/staging_dir/host/include -I/opt/86/openwrt-openwrt-puppies/staging_dir/host/usr/include -I/opt/86/openwrt-openwrt-puppies/staging_dir/target-x86_64_musl-1.1.12/host/include" \
CXXFLAGS="-I/opt/86/openwrt-openwrt-puppies/staging_dir/host/include -I/opt/86/openwrt-openwrt-puppies/staging_dir/host/usr/include -I/opt/86/openwrt-openwrt-puppies/staging_dir/target-x86_64_musl-1.1.12/host/include" \
LD_LIBRARY_PATH=/opt/86/openwrt-openwrt-puppies/staging_dir/host/lib:/opt/86/openwrt-openwrt-puppies/staging_dir/host/usr/lib:/opt/86/openwrt-openwrt-puppies/staging_dir/target-x86_64_musl-1.1.12/host/lib \
make -C src/go/src/app/cfgbak  
