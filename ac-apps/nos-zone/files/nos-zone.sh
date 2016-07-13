#!/bin/sh

[ x$1 = xstop ] && {
	exit 0
}

[ x$1 = xstart ] || {
	echo "usage: $0 start|stop"
	exit 0
}

echo clean >/dev/nos_zone_ctl

for i in `seq 0 255`; do
	[ x"`uci get nos-zone.@zone[$i] 2>/dev/null`" = xzone ] >/dev/null 2>&1 || break

	id="`uci get nos-zone.@zone[$i].id`"
	test -n "$id" || continue
	ifnames="`uci get nos-zone.@zone[$i].ifname`"
	test -n "$ifnames" || continue

	for ifname in $ifnames; do
		echo zone $id=$ifname >/dev/nos_zone_ctl
	done
done

echo update magic >/dev/nos_zone_ctl

exit 0
