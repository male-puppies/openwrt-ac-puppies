#!/bin/sh 
. ./init_template_lib.sh
tbname=acgroup
keyname=gid

drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key autoincrement,
		name	 	char(64) 	not null unique default '', \
		des 		char(128) 	not null default '', \
		pid 		integer 	not null default 0 \
	)"
drop_mysql_memory_table $tbname	
create_mysql_memory_table "create table if not exists $tbname ( \
		$keyname 	int 		primary key, \
		name	 	char(64) 	not null unique default '', \
		des 		char(128) 	not null default '', \
		pid 		int 		not null default 0 \
	)engine=memory"
	