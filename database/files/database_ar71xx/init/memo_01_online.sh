#!/bin/sh 
. ./init_template_lib.sh
tbname=online

drop_mysql_memo_table $tbname	
create_mysql_memo_table "create table $tbname ( \
		ukey	 	char(36)	primary key not null default '', \
		type 		char(8) 	not null default '', \
		username 	char(40) 	not null default '', \
		rid 		integer 	not null default 0, \
		gid 		integer 	not null default 0, \
		ip		char(24) 	not null default '', \
		mac 		char(24) 	not null default '', \
		login 		integer		not null default 0, \
		active		integer 	not null default 0 \
	)"

# username may be not exists in user