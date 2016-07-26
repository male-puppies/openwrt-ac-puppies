#!/bin/sh 
. ./init_template_lib.sh

execute_sqlite3_disk_sql "insert or ignore into zone(zid,zonename,zonetype) values (0, 'zone0', 3),(3, 'zone3', 3)"
execute_sqlite3_disk_sql "insert or ignore into ipgroup(ipgid,ipgrpname,ranges,zid) values (0, 'ipgrp_0', 'all',255),(3, 'ipgrp_3', '192.168.0.0/16',3)"
execute_sqlite3_disk_sql "insert or ignore into acgroup(gid,groupname,pid) values (0, 'group_0', -1),(3, 'group_3', 0)"
execute_sqlite3_disk_sql "insert or ignore into authrule(rid,rulename,zid,ipgid,gid,authtype) values (1, 'rule_0', 3,3,3,'web')"
execute_sqlite3_disk_sql "insert or ignore into user(uid,username,password,gid) values(1,'yjs','123',3)"
