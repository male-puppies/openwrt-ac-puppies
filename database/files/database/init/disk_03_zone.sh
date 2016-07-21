#!/bin/sh 
. ./init_template_lib.sh
tbname=zone
keyname=zid

drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key default 0,
		name 		char(64) 	not null unique default '', \
		des 		char(128) 	not null default '', \
		type 		char(2) 	not null default '3' \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	int 		primary key default 0,
		name 		char(64) 	not null unique default '', \
		des 		char(128) 	not null default '', \
		type 		char(2) 	not null default '3' \
	) engine=memory"
