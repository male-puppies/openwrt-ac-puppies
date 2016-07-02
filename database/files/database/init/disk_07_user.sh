#!/bin/sh 
. ./init_template_lib.sh
tbname=user
keyname=uid

drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		uid		 integer 	primary key autoincrement,
		username char(64) 	not null unique default '', \
		password char(64) 	not null default ''
	)"
drop_mysql_memory_table $tbname	
create_mysql_memory_table "create table $tbname ( \
		uid		 int 		primary key, \
		username char(64) 	not null unique default '', \
		password char(64) 	not null default ''
	) engine=memory"
	