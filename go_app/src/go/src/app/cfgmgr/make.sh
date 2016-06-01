#!/bin/sh
# export TOP_DIR=$(pwd)
export TOP_DIR=/opt/86/openwrt-openwrt-puppies/feeds/puppies/go_app/src
export STAGING_DIR="${TOP_DIR}/toolchains/prebuilt/x86_64-openwrt-linux"
export ARCH=x86_64
export SUBARCH=x86_64
export CROSS_COMPILE=x86_64-openwrt-linux-

export INSTALL_ROOT="${TOP_DIR}/output"
export COMM_SO_DIR="${INSTALL_ROOT}/so"
export COMM_INC_DIR="${TOP_DIR}/src/inc"
export COMM_LIB_DIR="${COMM_SO_DIR}"
export COMM_MK_DIR="${TOP_DIR}/src/inc/makefiles"
export KERNEL_SRC_DIR="${TOP_DIR}/src/linux-3.6.6"
export KERNEL_INC_DIR="${TOP_DIR}/src/inc"

export LD_LIBRARY_PATH="${COMM_SO_DIR}:${STAGING_DIR}/host/lib"

export CFLAGS="-g -I${STAGING_DIR}/target-x86_64_uClibc-0.9.33.2/usr/include"
export CXXFLAGS="-g -I${STAGING_DIR}/target-x86_64_uClibc-0.9.33.2/usr/include"

export GOPATH="${TOP_DIR}/src/go"
export GOROOT="${TOP_DIR}/go"
export CGO_CFLAGS="-I${COMM_INC_DIR} -std=gnu99 -fno-strict-aliasing -D_GNU_SOURCE -I${STAGING_DIR}/target-x86_64_uClibc-0.9.33.2/usr/include -I${STAGING_DIR}/target-x86_64_uClibc-0.9.33.2/usr/lib/libiconv-stub/include"
export CGO_LDFLAGS="-L${COMM_SO_DIR} -Wl,-rpath-link,${COMM_SO_DIR}"
export TOOLCHAIN="${STAGING_DIR}/toolchain-x86_64_gcc-4.8-linaro_uClibc-0.9.33.2"
export CGO_ENABLED=1
export CC=${TOOLCHAIN}/bin/x86_64-openwrt-linux-gcc

echo $PATH | grep prebuilt 2>&1 >/dev/null|| export PATH="${GOROOT}/bin:${TOP_DIR}/toolchains/prebuilt/x86_64-openwrt-linux/toolchain-x86_64_gcc-4.8-linaro_uClibc-0.9.33.2/bin:$PATH"

echo "PATH = " $PATH
cat devenvrc  | grep ^export | cut -d= -f1 | awk '{ print $2}' | while read var; do eval echo \"$var = \" $\{$var\}; done

$GOROOT/bin/go build -v -x 

