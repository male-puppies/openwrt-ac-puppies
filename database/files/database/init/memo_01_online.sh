#!/bin/sh 
. ./init_template_lib.sh
tbname=online

drop_mysql_memo_table $tbname	
create_mysql_memo_table "create table $tbname ( \
		ukey	 	char(36)	primary key not null default '', \
		type 		char(8) 	not null default '', \
		username 	char(40) 	not null default '', \
		rid 		int 		not null default 0, \
		ip 			char(24) 	not null default '', \
		mac 		char(24) 	not null default '', \
		login 		int			not null default 0, \
		rx 			bigint 		not null default 0, \
		tx 			bigint 		not null default 0, \
		active		int 		not null default 0 \
	) engine=memory"

# username may be not exists in user