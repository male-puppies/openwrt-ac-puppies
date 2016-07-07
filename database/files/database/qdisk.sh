#!/bin/sh  
diskdb=/tmp/db/disk.db
sqlite3 $diskdb -cmd "PRAGMA foreign_keys=ON" "$*"

