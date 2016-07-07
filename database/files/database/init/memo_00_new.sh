#!/bin/sh 
sql="create database if not exists disk"
mysql -uroot -pwjrc0409 -e "$sql"
test $? -eq 0 || eexit "sql fail $sql"

sql="create database if not exists memo"
mysql -uroot -pwjrc0409 -e "$sql"
test $? -eq 0 || eexit "sql fail $sql"