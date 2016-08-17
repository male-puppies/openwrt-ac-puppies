#!/bin/sh 
exit 0
. ./init_template_lib.sh
tbname=device
keyname=devid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	char(32) primary key	not null default '', \
		devdesc		char(64) 				not null default '', \
		devtype		char(8)					not null default '', \
		gw 			char(32) 				not null default '', \
		ip 			char(16) 				not null default '', \
		mask 		char(32) 				not null default '', \
		dns 		varchar(128) 			not null default '', \
		distribute	char(8) 				not null default '', \
		radios 		char(16) 				not null default '', \
		ac_host 	char(64) 				not null default '', \
		ac_port 	integer 				not null default 0, \
		mode 		char(16) 				not null default '', \
		scan_chan 	char(16) 				not null default '', \
		hbd_time 	integer 				not null default 0, \
		hbd_cycle 	integer 				not null default 0, \
		nml_cycle 	integer 				not null default 0, \
		nml_time 	integer 				not null default 0, \
		mnt_time 	integer 				not null default 0, \
		mnt_cycle 	integer 				not null default 0, \
		detail 		text 					\
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	char(32) primary key	not null default '', \
		devdesc		char(64) 				not null default '', \
		devtype		char(8)					not null default '', \
		gw 			char(32) 				not null default '', \
		ip 			char(16) 				not null default '', \
		mask 		char(32) 				not null default '', \
		dns 		varchar(128) 			not null default '', \
		distribute	char(8) 				not null default '', \
		radios 		char(16) 				not null default '', \
		ac_host 	char(64) 				not null default '', \
		ac_port 	integer 				not null default 0, \
		mode 		char(16) 				not null default '', \
		scan_chan 	char(16) 				not null default '', \
		hbd_time 	integer 				not null default 0, \
		hbd_cycle 	integer 				not null default 0, \
		nml_cycle 	integer 				not null default 0, \
		nml_time 	integer 				not null default 0, \
		mnt_time 	integer 				not null default 0, \
		mnt_cycle 	integer 				not null default 0, \
		detail 		text 					\
	)"
	
