#!/bin/sh 
. ./init_template_lib.sh
tbname=radio

#drop_sqlite3_disk_table $tbname
sql="create table if not exists $tbname ( \
		devid 		char(32) 			not null default '', \
		band 		char(8)	 			not null default '', \
		proto 		char(8)				not null default '', \
		ampdu 		char(8)				not null default '1', \
		amsdu		char(8)				not null default '1', \
		bandwidth 	char(8)				not null default 'auto', \
		beacon 		char(8)				not null default '100', \
		bswitch 	char(8)				not null default '1', \
		chanid 		char(8)				not null default 'auto', \
		dtim 		char(8)				not null default '1', \
		leadcode 	char(8)				not null default '1', \
		power 		char(8)				not null default 'auto', \
		remax		char(8)				not null default '4', \
		rts 		char(8)				not null default '2347', \
		shortgi 	char(8)				not null default '1', \
		usrlimit 	char(8)				not null default '30', \
		foreign key(devid) references device(devid) on delete restrict on update restrict \
	)"

sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"	

sql="create trigger if not exists ${tbname}_add after insert on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'add', 'devid_band', new.devid||'_'||new.band); end;"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"

sql="create trigger if not exists ${tbname}_del after delete on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'del', 'devid_band', old.devid||'_'||old.band); end;"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"

sql="create trigger if not exists ${tbname}_set after update on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'set', 'devid_band', new.devid||'_'||new.band); end;"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"
	
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		devid 		char(32) 			not null default '', \
		band 		char(8)	 			not null default '', \
		proto 		char(8)				not null default '', \
		ampdu 		char(8)				not null default '1', \
		amsdu		char(8)				not null default '1', \
		bandwidth 	char(8)				not null default 'auto', \
		beacon 		char(8)				not null default '100', \
		bswitch 	char(8)				not null default '1', \
		chanid 		char(8)				not null default 'auto', \
		dtim 		char(8)				not null default '1', \
		leadcode 	char(8)				not null default '1', \
		power 		char(8)				not null default 'auto', \
		remax		char(8)				not null default '4', \
		rts 		char(8)				not null default '2347', \
		shortgi 	char(8)				not null default '1', \
		usrlimit 	char(8)				not null default '30', \
	)"
	