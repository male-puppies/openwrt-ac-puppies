#!/bin/sh 
eexit () {
	echo "$*" 1>&2
	exit 1
}

work_dir=`grep -E "work_dir[ \t]+=" ../config.lua  | awk -F\" '{print $2}'`
dbfile=$work_dir/disk.db
test -e $dbfile || eexit "missing $dbfile"

tbname=user
sql="create table if not exists $tbname ( \
		uid		 integer 	primary key autoincrement,
		username char(64) 	not null unique default '', \
		password char(64) 	not null default ''
	)"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"

sql="create trigger if not exists user_add after insert on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'add', 'uid', new.uid); end;"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"

sql="create trigger if not exists user_del after delete on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'del', 'uid', old.uid); end;"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"

sql="create trigger if not exists user_set after update on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'set', 'uid', new.uid); end;"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"

## test user data 
sqlite3 $dbfile "insert or ignore into $tbname (username, password) values ('user1', 'passwd1')"
sqlite3 $dbfile "insert or ignore into $tbname (username, password) values ('user2', 'passwd2')"
sqlite3 $dbfile "insert or ignore into $tbname (username, password) values ('user3', 'passwd3')"
sqlite3 $dbfile "insert or ignore into $tbname (username, password) values ('user5', 'passwd5')"

## following mysql 
sql="drop table if exists $tbname"
mysql -uroot -pwjrc0409 cnf -e "$sql"
test $? -eq 0 || eexit "sql fail $sql"

sql="create table $tbname ( \
		uid		 int 		primary key, \
		username char(64) 	not null unique default '', \
		password char(64) 	not null default ''
	) engine=memory"
mysql -uroot -pwjrc0409 cnf -e "$sql"	
test $? -eq 0 || eexit "sql fail $sql"
