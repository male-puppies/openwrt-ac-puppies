#!/bin/sh 
. ./init_template_lib.sh
tbname=user
keyname=uid

drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname integer 	primary key autoincrement,
		username char(64) 	not null unique default '', \
		password char(64) 	not null default '', \
		des 	 char(64) 	not null default '', \
		enable	 integer 	not null default 1, \
		bindip	 char(24) 	not null default '', \
		bindmac	 char(24) 	not null default '', \
		expire 	 datetime	not null default '1970-01-01 00:00:00', \
		gid 	 integer	not null default 0, \
		foreign key(gid) references acgroup(gid) on delete cascade on update cascade \
	)"
	
#insert into user(username,password,gid) select 'yjs','123',gid from acgroup where name='g11' 
#insert into user(username,password,gid) select '15914180656','123',gid from acgroup where name='g11'
	
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname int 		primary key, \
		username char(64) 	not null unique default '', \
		password char(64) 	not null default '', \
		des 	 char(64) 	not null default '', \
		enable	 int 		not null default 1, \
		bindip	 char(24) 	not null default '', \
		bindmac	 char(24) 	not null default '', \
		expire 	 datetime	not null default '1970-01-01 00:00:00', \
		gid 	 int 		not null default 0 \
	) engine=memory"
	