#!/bin/sh 
. ./init_template_lib.sh
tbname=ipgroup
keyname=ipgid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key default 0, \
		ipgrpname	char(64) 	not null unique default '', \
		ipgrpdesc 	char(128) 	not null default '', \
		ranges 		char(255) 	not null default '{}' \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 	primary key default 0, \
		ipgrpname	char(64) 	not null unique default '', \
		ipgrpdesc 	char(128) 	not null default '', \
		ranges 		char(255) 	not null default '{}' \
	)"
	