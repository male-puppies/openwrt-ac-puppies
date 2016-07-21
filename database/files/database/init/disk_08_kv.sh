#!/bin/sh 
. ./init_template_lib.sh
tbname=kv 
keyname="k"
drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		k 			char(64) 	not null primary key default '', \
		v 			char(128)	not null default '' \
	)"
	
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		k 			char(64) 	not null primary key default '', \
		v 			char(128)	not null default '' \
	) engine=memory"

