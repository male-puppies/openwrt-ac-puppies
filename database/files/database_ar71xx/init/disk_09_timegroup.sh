#!/bin/sh 
. ./init_template_lib.sh
tbname=timegroup
keyname=tmgid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key default 0, \
		tmgrpname	char(64) 	not null unique default '', \
		tmgrpdesc 	char(128) 	not null default '', \
		days		char(64) 	not null default '{}', \
		tmlist 		text 	\
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 	primary key default 0, \
		tmgrpname	char(64) 	not null unique default '', \
		tmgrpdesc 	char(128) 	not null default '', \
		days		char(64) 	not null default '{}', \
		tmlist 		text 	\
	)"
	