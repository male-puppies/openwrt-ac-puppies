#!/bin/sh 
. ./init_template_lib.sh
tbname=authrule
keyname=rid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key autoincrement,
		rulename	char(64) 	not null unique default '', \
		ruledes 	char(128) 	not null default '', \
		zid 		integer		not null default 0, \
		ipgid 		integer 	not null default 0, \
		gid 		integer		not null default 0, \
		authtype 	char(16) 	not null default 'auto', \
		foreign key(zid) references zone(zid) 			on delete restrict on update restrict, \
		foreign key(ipgid) references ipgroup(ipgid) 	on delete restrict on update restrict, \
		foreign key(gid) references acgroup(gid) 		on delete restrict on update restrict \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table if not exists $tbname ( \
		$keyname 	int 		primary key, \
		rulename	char(64) 	not null unique default '', \
		ruledes 	char(128) 	not null default '', \
		zid 		int			not null default 0, \
		ipgid 		int 		not null default 0, \
		gid 		int			not null default 0, \
		authtype 	char(16) 	not null default 'auto' \
	)engine=memory"

# type : auto wechat sms onekey 