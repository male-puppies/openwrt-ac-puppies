#!/bin/sh 
. ./init_template_lib.sh
tbname=authrule
keyname=rid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key,
		rulename	char(64) 	not null unique default '', \
		ruledesc 	char(128) 	not null default '', \
		zid 		integer		not null default 0, \
		ipgid 		integer 	not null default 0, \
		authtype 	char(16) 	not null default 'auto', \
		enable 		integer		not null default 1, \
		modules 	char(32)	not null default '[]', \
		iscloud		integer		not null default 0, \
		white_ip	text		, \
		white_mac	text		, \
		wechat		text		, \
		sms 		text 		, \
		foreign key(zid) references zone(zid) 			on delete restrict on update restrict, \
		foreign key(ipgid) references ipgroup(ipgid) 	on delete restrict on update restrict \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 	primary key,
		rulename	char(64) 	not null unique default '', \
		ruledesc 	char(128) 	not null default '', \
		zid 		integer		not null default 0, \
		ipgid 		integer 	not null default 0, \
		authtype 	char(16) 	not null default 'auto', \
		enable 		integer		not null default 1, \
		modules 	char(32)	not null default '[]', \
		iscloud		integer		not null default 0, \
		white_ip	text		, \
		white_mac	text		, \
		wechat		text		, \
		sms 		text 		 \
	)"

# type : auto wechat sms onekey 