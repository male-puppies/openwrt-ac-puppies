#!/bin/sh 
. ./init_template_lib.sh
tbname=kv
keyname=kid

drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key autoincrement,
		k 			char(64) 	not null unique default '', \
		v 			char(128)	not null default '' \
	)"
execute_sqlite3_disk_sql "insert or ignore into kv(k, v) values ('redirect_ip','1.0.0.8')"
execute_sqlite3_disk_sql "insert or ignore into kv(k, v) values ('no_flow_timeout','1800')"
	
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname 	int 		primary key, \
		k 			char(64) 	not null unique default '', \
		v 			char(128)	not null default '' \
	) engine=memory"

