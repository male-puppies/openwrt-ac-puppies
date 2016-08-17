#!/bin/sh 
exit 0
. ./init_template_lib.sh
tbname=wlan2ap

#drop_sqlite3_disk_table $tbname
sql="create table if not exists $tbname ( \
		devid 		char(32) 	not null default '', \
		wlanid		integer		not null default 0, \
		primary key (devid, wlanid), \
		foreign key(devid) references device(devid) on delete restrict on update restrict, \
		foreign key(wlanid) references wlan(wlanid) on delete restrict on update restrict \
	)"

sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"	

sql="create trigger if not exists ${tbname}_add after insert on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'add', 'devid_wlanid', new.devid||'_'||new.wlanid); end;"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"

sql="create trigger if not exists ${tbname}_del after delete on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'del', 'devid_wlanid', old.devid||'_'||old.wlanid); end;"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"

sql="create trigger if not exists ${tbname}_set after update on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'set', 'devid_wlanid', new.devid||'_'||new.wlanid); end;"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"
	
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		devid 		char(32) 	not null default '', \
		wlanid		integer		not null default 0 \
	)"
	
