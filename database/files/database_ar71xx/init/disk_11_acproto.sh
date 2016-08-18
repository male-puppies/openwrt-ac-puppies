#!/bin/sh
. ./init_template_lib.sh
tbname=acproto
keyname=proto_id

#drop_sqlite3_disk_table $tbname	
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	char(32) 		primary key default '', \
		proto_name	varchar(256) 		not null unique default '', \
		proto_desc 	char(64)		not null default '', \
		enable		integer			not null default 1, \
		pid 		integer 		not null default -1, \
		node_type	char(8)			not null default '', \
		ext 		text			 \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table if not exists $tbname ( \
		$keyname	char(32) 		primary key default '', \
		proto_name	varchar(256) 		not null unique default '', \
		proto_desc 	char(64)		not null default '', \
		enable		integer			not null default 1, \
		pid 		integer			not null default -1, \
		node_type	char(8) 		not null default '', \
		ext 		text			 \
	)"
