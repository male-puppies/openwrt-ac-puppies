#!/bin/sh 
eexit () {
	echo "$*" 1>&2
	exit 1
}

work_dir=`grep -E "work_dir[ \t]+=" ../config.lua  | awk -F\" '{print $2}'`
dbfile=$work_dir/disk.db
test -e $dbfile || eexit "missing $dbfile"

tbname=trigger
sql="create table if not exists $tbname ( \
		tid		integer 	primary key autoincrement, \
		tb 		char(24) 	not null default '', \
		act 	char(64) 	not null default '', \
		key 	char(64) 	not null default '', \
		val		char(64) 	not null default '' \
	)"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"

sql="delete from $tbname"
sqlite3 $dbfile "$sql"
test $? -eq 0 || eexit "sql fail $sql"
