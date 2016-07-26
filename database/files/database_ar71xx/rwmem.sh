#!/bin/sh  
memodb=/tmp/db/memo.db
sqlite3 $memodb "$*" -header -column 

