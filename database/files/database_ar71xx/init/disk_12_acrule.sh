#!/bin/sh
. ./init_template_lib.sh
tbname=acrule
keyname=ruleid

#drop_sqlite3_disk_table $tbname	
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key default 0, \
		rulename	char(64) 	not null unique default '', \
		ruletype	char(16)	not null default 'control', \
		ruledesc 	char(128) 	not null default '', \
		src_zids 	text		, \
		src_ipgids	text		, \
		dest_zids 	text		, \
		dest_ipgids 	text		, \
		proto_ids 	text		, \
		tmgrp_ids 	text		, \
		actions 	char(32)	not null default '{}', \
		enable 		integer 	not null default 1, \
		priority	integer		not null default 0 \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 	primary key default 0, \
		rulename	char(64) 	not null unique default '', \
		ruletype	char(16)	not null default 'control', \
		ruledesc 	char(128) 	not null default '', \
		src_zids 	text		, \
		src_ipgids	text		, \
		dest_zids 	text		, \
		dest_ipgids 	text		, \
		proto_ids 	text		, \
		tmgrp_ids 	text		, \
		actions 	char(32)	not null default '{}', \
		enable 		integer 	not null default 1, \
		priority	integer		not null default 0 \
	)"
