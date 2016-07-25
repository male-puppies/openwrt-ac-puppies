#!/bin/sh 

work_dir=`grep -E "work_dir[ \t]+=" ../config.lua  | awk -F\" '{print $2}'`
dbfile=$work_dir/disk.db
test -e $dbfile || eexit "missing $dbfile"
password=wjrc0409

eexit () {
	echo "$*" 1>&2
	exit 1
}

drop_sqlite3_disk_table() {
	#return
	local tbname=$1
	local sql="drop table if exists $tbname"
	sqlite3 $dbfile "$sql"
	test $? -eq 0 || eexit "sql fail $sql"
	
	local sql="drop trigger if exists ${tbname}_add"
	sqlite3 $dbfile "$sql"
	test $? -eq 0 || eexit "sql fail $sql"
	
	local sql="drop trigger if exists ${tbname}_del"
	sqlite3 $dbfile "$sql"
	test $? -eq 0 || eexit "sql fail $sql"
	
	local sql="drop trigger if exists ${tbname}_set"
	sqlite3 $dbfile "$sql"
	test $? -eq 0 || eexit "sql fail $sql"
}

create_sqlite3_disk_table() {
	local tbname=$1 
	local keyname=$2
	local sql=$3
	sqlite3 $dbfile "$sql"
	test $? -eq 0 || eexit "sql fail $sql" 
	
	sql="create trigger if not exists ${tbname}_add after insert on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'add', '$keyname', new.$keyname); end;"
	sqlite3 $dbfile "$sql"
	test $? -eq 0 || eexit "sql fail $sql"

	sql="create trigger if not exists ${tbname}_del after delete on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'del', '$keyname', old.$keyname); end;"
	sqlite3 $dbfile "$sql"
	test $? -eq 0 || eexit "sql fail $sql"

	sql="create trigger if not exists ${tbname}_set after update on $tbname begin insert into trigger(tb, act, key, val) values ('$tbname', 'set', '$keyname', new.$keyname); end;"
	sqlite3 $dbfile "$sql"
	test $? -eq 0 || eexit "sql fail $sql"
}


execute_sqlite3_disk_sql() { 
	local sql=$1
	sqlite3 $dbfile "$sql"
	test $? -eq 0 || eexit "sql fail $sql" 
}


drop_mysql_disk_table() {
	local sql="drop table if exists $1"
	mysql -uroot -p$password disk -e "$sql"	
	test $? -eq 0 || eexit "sql fail $sql"
}

create_mysql_disk_table() {
	local sql=$1
	mysql -uroot -p$password disk -e "$sql"	
	test $? -eq 0 || eexit "sql fail $sql"
}

drop_mysql_memo_table() {
	local sql="drop table if exists $1"
	mysql -uroot -p$password memo -e "$sql"	
	test $? -eq 0 || eexit "sql fail $sql"
}

create_mysql_memo_table() {
	local sql=$1
	mysql -uroot -p$password memo -e "$sql"	
	test $? -eq 0 || eexit "sql fail $sql"
}
