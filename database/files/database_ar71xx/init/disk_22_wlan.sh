#!/bin/sh 
exit 0
. ./init_template_lib.sh
tbname=wlan
keyname=wlanid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key default 0, \
		ssid		char(24) 	not null unique default '', \
		band		char(8)		not null default '', \
		encrypt		char(8)		not null default '', \
		password	char(24) 	not null default '', \
		hide 		integer		not null default 0, \
		enable 		integer		not null default 1, \
		vlan_enable	integer		not null default 0, \
		vlanid		integer		not null default 0, \
		apply_all	integer		not null default 0 \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 	primary key default 0, \
		ssid		char(24) 	not null unique default '', \
		band		char(8)		not null default '', \
		encrypt		char(8)		not null default '', \
		password	char(24) 	not null default '', \
		hide 		integer		not null default 0, \
		enable 		integer		not null default 1, \
		vlan_enable	integer		not null default 0, \
		vlanid		integer		not null default 0, \
		apply_all	integer		not null default 0 \
	)"
	
