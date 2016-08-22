#!/bin/sh
dir=/usr/share/acmgr
cd $dir
lua $dir/main.lua >>/tmp/log/lua.error 2>&1
