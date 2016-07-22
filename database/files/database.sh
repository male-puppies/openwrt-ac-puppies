#!/bin/sh
mkdir -p /tmp/db
mkdir -p /etc/sqlite3
cd /usr/share/database
./init.sh

for i in 1 2 3 4 5 6 7 8 9 ; do 
	mysql -uroot -pwjrc0409 -e "select 1" >/dev/null 2>&1 
	test $? -eq 0 && break 
	sleep 1 
done
dir=/usr/share/database
cd $dir
lua $dir/main.lua >>/tmp/log/lua.error 2>&1
