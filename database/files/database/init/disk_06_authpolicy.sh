#!/bin/sh 
. ./init_template_lib.sh
tbname=authpolicy
keyname=polid

drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key autoincrement,
		name	 	char(64) 	not null unique default '', \
		des 		char(128) 	not null default '', \
		zid 		integer		not null default 0, \
		ipgid 		integer 	not null default 0, \
		gid 		integer		not null default 0, \
		type 		char(16) 	not null default 'auto' \
	)"
drop_mysql_memory_table $tbname	
create_mysql_memory_table "create table if not exists $tbname ( \
		$keyname 	int 		primary key, \
		name	 	char(64) 	not null unique default '', \
		des 		char(128) 	not null default '', \
		zid 		int			not null default 0, \
		ipgid 		int 		not null default 0, \
		gid 		int			not null default 0, \
		type 		char(16) 	not null default 'auto' \
	)engine=memory"
