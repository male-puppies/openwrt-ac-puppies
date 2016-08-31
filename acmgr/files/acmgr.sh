#!/bin/sh
name=acmgr
dir=/usr/share/$name

try_stop_instance() {
	local name=$1
	if [ -e /var/run/$name.pid ] ; then
		kill $(cat /var/run/$name.pid) &> /dev/null
		rm /var/run/$name.pid &> /dev/null
	fi
}

[ x$1 = xstop ] && {
	try_stop_instance $name
	exit 0
}

[ x$1 = xstart ] || {
	echo "usage: $0 start|stop"
	exit 0
}

try_stop_instance $name

cd $dir
lua $dir/main.lua >>/tmp/log/lua.error 2>&1 &

pid=$!
echo -n "$pid" > /var/run/$name.pid

wait
