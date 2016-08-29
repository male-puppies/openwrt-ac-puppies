#!/bin/sh

[ x$1 = xstop ] && {
	exit 0
}

[ x$1 = xstart ] || {
	echo "usage: $0 start|stop"
	exit 0
}

dir=/usr/share/cloudcli
cd $dir
lua $dir/main.lua