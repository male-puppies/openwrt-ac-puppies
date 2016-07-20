#!/bin/sh 
dir=/usr/share/cfgmgr
cd $dir
lua $dir/main.lua >>/tmp/log/lua.error 2>&1
