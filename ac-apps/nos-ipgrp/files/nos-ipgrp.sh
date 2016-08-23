#!/bin/sh

[ x$1 = xstop ] && {
	echo clean >/dev/nos_ipgrp_ctl
	exit 0
}

[ x$1 = xstart ] || {
	echo "usage: $0 start|stop"
	exit 0
}

echo clean >/dev/nos_ipgrp_ctl

for i in `seq 0 255`; do
	ipset destroy ipgrp_$i >/dev/null 2>&1
done

for i in `seq 0 255`; do
	[ x"`uci get nos-ipgrp.@ipgrp[$i] 2>/dev/null`" = xipgrp ] >/dev/null 2>&1 || break

	id="`uci get nos-ipgrp.@ipgrp[$i].id`"
	test -n "$id" || continue
	networks="`uci get nos-ipgrp.@ipgrp[$i].network 2>/dev/null`"
	type="`uci get nos-ipgrp.@ipgrp[$i].type 2>/dev/null`"

	if [ x"$type" = "xall" ]; then
		echo ipgrp $id=@all >/dev/nos_ipgrp_ctl
	else
		ipset create ipgrp_$id hash:net
		for network in $networks; do
			if echo $network | grep -q -- -; then
				ipcalc -r `echo $network | sed 's/-/ /'` | grep ^[0-9] | while read line; do
					ipset add ipgrp_$id $line
				done
			else
				ipset add ipgrp_$id $network
			fi
		done
		echo ipgrp $id=ipgrp_$id >/dev/nos_ipgrp_ctl
	fi
done

echo update magic >/dev/nos_ipgrp_ctl

exit 0
