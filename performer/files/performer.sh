#!/bin/sh 
dir=/usr/share/performer
cd $dir
lua $dir/main.lua >>/tmp/log/lua.error 2>&1
