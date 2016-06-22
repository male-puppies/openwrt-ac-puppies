#!/bin/sh 
eexit () {
	echo "$*" 1>&2
	exit 1
}

work_dir=`grep -E "work_dir[ \t]+=" ../config.lua  | awk -F\" '{print $2}'`
dbfile=$work_dir/disk.db
test -e $dbfile || eexit "missing $dbfile"
sql="create table if not exists user ( \
		username char(64) 	not null primary key default '', \
		password char(64) 	not null default '', \
		active 	 datetime 	not null default '0000-00-00 00:00:00' \
	)"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"

## test user data 
sqlite3 $dbfile "insert or ignore into user (username, password, active) values ('user1', 'passwd1', '2016-06-21 09:58:57')"
sqlite3 $dbfile "insert or ignore into user (username, password, active) values ('user2', 'passwd2', '2016-06-21 09:58:58')"
sqlite3 $dbfile "insert or ignore into user (username, password, active) values ('user3', 'passwd3', '2016-06-21 09:58:59')"
sqlite3 $dbfile "insert or ignore into user (username, password, active) values ('user5', 'passwd5', '2016-06-21 09:59:00')"

## following mysql 
sql="drop table if exists user"
mysql -uroot -pwjrc0409 cnf -e "$sql"
test $? -eq 0 || eexit "sql fail $sql"

sql="create table user ( \
		username char(64) 	not null primary key default '', \
		password char(64) 	not null default '', \
		active 	 datetime 	not null default '0000-00-00 00:00:00' \
	) engine=memory"
mysql -uroot -pwjrc0409 cnf -e "$sql"	
test $? -eq 0 || eexit "sql fail $sql"
