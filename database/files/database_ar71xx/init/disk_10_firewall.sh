#!/bin/sh 
. ./init_template_lib.sh
tbname=firewall
keyname=fwid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 		primary key default 0, \
		fwname		char(32)		not null unique default '', \
		fwdesc  	char(32) 		not null default '', \
		enable		integer 		not null default 1, \
		priority	interger		not null default 0, \
		proto 		char(8) 		not null default 'none', \
		src_zid		integer 		not null default 0, \
		src_ip		char(24)  		not null default '', \
		src_port 	integer 		not null default 0, \
		dest_ip		char(24)  		not null default '', \
		dest_port	integer			not null default 0, \
		target_zid	integer 		not null default 0, \
		target_ip	char(24)  		not null default '', \
		target_port	integer			not null default 0, \
		foreign key(src_zid) references zone(zid) on delete restrict on update restrict, \
		foreign key(target_zid) references zone(zid) on delete restrict on update restrict \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 		primary key default 0, \
		fwname		char(32)		not null unique default '', \
		fwdesc  	char(32) 		not null default '', \
		enable		integer 		not null default 1, \
		priority	interger		not null default 0, \
		proto 		char(8) 		not null default 'none', \
		src_zid		integer 		not null default 0, \
		src_ip		char(24)  		not null default '', \
		src_port 	integer 		not null default 0, \
		dest_ip		char(24)  		not null default '', \
		dest_port	integer			not null default 0, \
		target_zid	integer 		not null default 0, \
		target_ip	char(24)  		not null default '', \
		target_port	integer			not null default 0 \
	)"
