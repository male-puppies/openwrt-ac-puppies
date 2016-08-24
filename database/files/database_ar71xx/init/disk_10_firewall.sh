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
		type		char(8)			not null default '', \
		action		char(8)			not null default '', \
		proto 		char(8) 		not null default 'none', \
		from_szid	integer 		not null default 0, \
		from_dzid	integer 		not null default 0, \
		from_sip	char(24)  		not null default '', \
		from_sport 	integer 		not null default 0, \
		from_dip	char(24)  		not null default '', \
		from_dport 	integer 		not null default 0, \
		to_dzid		integer 		not null default 0, \
		to_sip		char(24)  		not null default '', \
		to_sport 	integer 		not null default 0, \
		to_dip		char(24)  		not null default '', \
		to_dport 	integer 		not null default 0, \
		foreign key(from_szid) references zone(zid) on delete restrict on update restrict, \
		foreign key(from_dzid) references zone(zid) on delete restrict on update restrict, \
		foreign key(to_dzid) references zone(zid) on delete restrict on update restrict \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 		primary key default 0, \
		fwname		char(32)		not null unique default '', \
		fwdesc  	char(32) 		not null default '', \
		enable		integer 		not null default 1, \
		priority	interger		not null default 0, \
		type		char(8)			not null default '', \
		action		char(8)			not null default '', \
		proto 		char(8) 		not null default 'none', \
		from_szid	integer 		not null default 0, \
		from_dzid	integer 		not null default 0, \
		from_sip	char(24)  		not null default '', \
		from_sport 	integer 		not null default 0, \
		from_dip	char(24)  		not null default '', \
		from_dport 	integer 		not null default 0, \
		to_dzid		integer 		not null default 0, \
		to_sip		char(24)  		not null default '', \
		to_sport 	integer 		not null default 0, \
		to_dip		char(24)  		not null default '', \
		to_dport 	integer 		not null default 0 \
	)"
