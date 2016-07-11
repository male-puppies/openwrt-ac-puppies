#!/bin/sh 
. ./init_template_lib.sh
tbname=online

drop_mysql_memo_table $tbname	
create_mysql_memo_table "create table $tbname ( \
		uid		 	int 		primary key auto_increment, \
		type 		char(16) 	not null default '', \
		state		int 		not null default 1, \
		username 	char(64) 	not null unique default '', \
		ip 			char(24) 	not null default '', \
		mac 		char(24) 	not null default '', \
		uptime 		int			not null default 0, \
		flow 		int 		not null default 0 \
	) engine=memory"

# username may be not exists in user