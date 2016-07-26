#!/bin/sh 
. ./init_template_lib.sh
tbname=zone
keyname=zid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key default 0,
		zonename 	char(64) 	not null unique default '', \
		zonedesc 	char(128) 	not null default '', \
		zonetype 	integer 	not null default 3 \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 	primary key default 0,
		zonename 	char(64) 	not null unique default '', \
		zonedesc 	char(128) 	not null default '', \
		zonetype 	integer 	not null default 3 \
	)"
