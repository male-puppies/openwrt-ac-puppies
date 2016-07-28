#!/bin/sh 
. ./init_template_lib.sh
tbname=iface
keyname=fid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname			integer 	primary key default 0,
		ifname				char(64) 	not null unique default '', \
		ifdesc				char(16) 	not null default '', \
		ethertype 			char(16) 	not null default '', \
		iftype 				integer 	not null default 3, \
		proto 				char(8) 	not null default 'none', \
		mtu 				integer 	not null default 1500, \
		mac 				char(20) 	not null default '' , \
		metric				integer 	not null default 600, \
		gateway				char(20)	not null default '', \
		pppoe_account			char(64) 	not null default '', \
		pppoe_password			char(64) 	not null default '', \
		static_ip 			text 		, \
		dhcp_enable			integer 	not null default 0, \
		dhcp_start 			char(16) 	not null default '', \
		dhcp_end 			char(16) 	not null default '', \
		dhcp_time 			char(8) 	not null default '', \
		dhcp_dynamic			integer 	not null default 0, \
		dhcp_lease 			text		, \
		dhcp_dns			text 		, \
		pid 				integer 	not null default -1, \
		zid					integer		not null default 255, \
		foreign key(zid) references zone(zid) on delete restrict on update restrict \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname			integer 	primary key default 0,
		ifname				char(64) 	not null unique default '', \
		ifdesc				char(16) 	not null default '', \
		ethertype 			char(16) 	not null default '', \
		iftype 				integer 	not null default 3, \
		proto 				char(8) 	not null default 'none', \
		mtu 				integer 	not null default 1500, \
		mac 				char(20) 	not null default '' , \
		metric				integer 	not null default 600, \
		gateway				char(20)	not null default '', \
		pppoe_account			char(64) 	not null default '', \
		pppoe_password			char(64) 	not null default '', \
		static_ip 			text 		, \
		dhcp_enable			integer 	not null default 0, \
		dhcp_start 			char(16) 	not null default '', \
		dhcp_end 			char(16) 	not null default '', \
		dhcp_time 			char(8) 	not null default '', \
		dhcp_dynamic			integer 	not null default 0, \
		dhcp_lease 			text		, \
		dhcp_dns			text 		, \
		pid 				integer 	not null default -1, \
		zid				integer		not null default 255 \
	)"
