#!/bin/sh 
. ./init_template_lib.sh
tbname=ipgroup
keyname=ipgid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key default 0, \
		ipgrpname	char(64) 	not null unique default '', \
		ipgrpdes 	char(128) 	not null default '', \
		ranges 		char(255) 	not null default '{}', \
		zid			integer		not null default 0, \
		foreign key(zid) references zone(zid) on delete restrict on update restrict \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 	primary key default 0, \
		ipgrpname	char(64) 	not null unique default '', \
		ipgrpdes 	char(128) 	not null default '', \
		ranges 		char(255) 	not null default '{}', \
		zid			integer		not null default 0 \
	)"
	