#!/bin/sh 
. ./init_template_lib.sh
tbname=iface
keyname=fid

drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname			integer 	primary key default 0,
		name 				char(64) 	not null unique default '', \
		des 				char(16) 	not null default '', \
		ethertype 			char(16) 	not null default '', \
		type 				char(2) 	not null default '3', \
		proto 				char(8) 	not null default 'none', \
		mtu 				integer 	not null default 1500, \
		mac 				char(20) 	not null default '' , \
		pppoe_account 		char(64) 	not null default '', \
		pppoe_password		char(64) 	not null default '', \
		static_ip 			text 		not null, \
		dhcp_enable 		integer 	not null default 0, \
		dhcp_start 			char(16) 	not null default '', \
		dhcp_end 			char(16) 	not null default '', \
		dhcp_time 			integer 	not null default 0, \
		dhcp_dynamic		integer 	not null default 0, \
		dhcp_lease 			text		not null, \
		dhcp_dns			text 		not null, \
		br_ports 			text 		not null \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname			int 			primary key default 0,
		name 				char(64) 		not null unique default '', \
		des 				char(16) 		not null default '', \
		ethertype 			char(16) 		not null default '', \
		type 				char(2) 		not null default '3', \
		proto 				char(8) 		not null default 'none', \
		mtu 				int 			not null default 1500, \
		mac 				char(20) 		not null default '' , \
		pppoe_account 		char(64) 		not null default '', \
		pppoe_password		char(64) 		not null default '', \
		static_ip 			varchar(2048) 	not null, \
		dhcp_enable 		int 			not null default 0, \
		dhcp_start 			char(16) 		not null default '', \
		dhcp_end 			char(16) 		not null default '', \
		dhcp_time 			int 			not null default 0, \
		dhcp_dynamic		int 			not null default 0, \
		dhcp_lease 			varchar(10240)	not null, \
		dhcp_dns			varchar(1024) 	not null, \
		br_ports 			varchar(1024) 	not null \
	) engine=memory"
