#!/bin/sh 
. ./init_template_lib.sh
execute_sqlite3_disk_sql "insert or ignore into kv(k, v) values ('redirect_ip','1.0.0.8')"
execute_sqlite3_disk_sql "insert or ignore into kv(k, v) values ('no_flow_timeout','1800')"
execute_sqlite3_disk_sql "insert or ignore into kv(k, v) values ('offline_time','1800')"
