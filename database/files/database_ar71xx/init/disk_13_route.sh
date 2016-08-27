#!/bin/sh
. ./init_template_lib.sh
tbname=route
keyname=rid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 		primary key default 0, \
		target		char(24)  		not null default '', \
		netmask 	char(24) 		not null default '', \
		gateway		char(24)  		not null default '', \
		metric		integer 		not null default 0, \
		mtu			integer 		not null default 0, \
		iface		char(16)		not null default '' \
	)"
drop_mysql_disk_table $tbname
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 		primary key default 0, \
		target		char(24)  		not null default '', \
		netmask 	char(24) 		not null default '', \
		gateway		char(24)  		not null default '', \
		metric		integer 		not null default 0, \
		mtu			integer 		not null default 0, \
		iface		char(16)		not null default '' \
	)"
