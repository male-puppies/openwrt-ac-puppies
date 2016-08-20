#!/bin/sh
. ./init_template_lib.sh
tbname=acset
keyname=setid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname( \
		$keyname 	integer 		primary key default 0, \
		setname	char(24)	not null unique default '',\
		setdesc	char(128)	not null default '',\
		setclass	char(8)		not null default '',\
		settype 	char(8) 		not null defautl '', \
		content		text		, \
		action		char(8)		not null default '',\
		enable		integer 		not null default 1 \
	)"
drop_mysql_disk_table $tbname
create_mysql_disk_table "create table $tbname(\
		$keyname 	integer 		primary key default 0, \
		setname	char(24)	not null unique default '',\
		setdesc	char(128)	not null default '',\
		setclass	char(8)		not null default '',\
		settype 	char(8) 		not null defautl '',\
		content		text		, \
		action		char(8)		not null default '',\
		enable		integer 		not null default 1 \
	)"