#!/bin/sh
name=database
dir=/usr/share/database

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

mkdir -p /tmp/db
mkdir -p /etc/sqlite3
cd $dir

echo `uptime` "start $name" >> /tmp/log/lua.error

./init.sh 2>>/tmp/log/lua.error
if [ $? -ne 0 ]; then
	echo "init database fail" >> /tmp/log/lua.error
	exit 1
fi

for i in 1 2 3 4 5 6 7 8 9 ; do
	mysql -uroot -pwjrc0409 -e "select 1" >/dev/null 2>&1
	test $? -eq 0 && break
	sleep 1
done

try_stop_instance $name

cd $dir
lua $dir/main.lua 2>>/tmp/log/lua.error &

pid=$!
echo -n "$pid" > /var/run/$name.pid

wait
