#!/bin/sh

[ x$1 = xstop ] && {
	exit 0
}

[ x$1 = xstart ] || {
	echo "usage: $0 start|stop"
	exit 0
}

no_flow_timeout="`uci get userauth.@defaults[0].no_flow_timeout`"
test -n "$no_flow_timeout" || no_flow_timeout=3600
redirect_ip="`uci get userauth.@defaults[0].redirect_ip`"
test -n "$redirect_ip" || redirect_ip="1.0.0.8"

echo clean >/dev/nos_auth_ctl
for i in `seq 0 255`; do
	ipset destroy auth_bypass_src_ip$i >/dev/null 2>&1
	ipset destroy auth_bypass_src_mac$i >/dev/null 2>&1
done

ipset destroy auth_global_bypass_dst_ip >/dev/null 2>&1
ipset create auth_global_bypass_dst_ip hash:ip

ifconfig br-lo >/dev/null 2>&1 || brctl addbr br-lo
ip addr flush dev br-lo
ip addr add $redirect_ip/32 brd + dev br-lo

echo no_flow_timeout=$no_flow_timeout >/dev/nos_auth_ctl
echo redirect_ip=$redirect_ip >/dev/nos_auth_ctl

for i in `seq 0 255`; do
	[ x"`uci get userauth.@rule[$i] 2>/dev/null`" = xrule ] >/dev/null 2>&1 || break
	disabled="`uci get userauth.@rule[$i].disabled`"
	[ x$disabled = x1 ] && {
		echo "info: rule [$i] disabled"
		continue
	}

	type="`uci get userauth.@rule[$i].type`"
	test -n "$type" || continue
	id="`uci get userauth.@rule[$i].id`"
	test -n "$id" || continue
	szone="`uci get userauth.@rule[$i].szone`"
	test -n "$szone" || continue
	sipgrp="`uci get userauth.@rule[$i].sipgrp`"
	test -n "$sipgrp" || continue

	cmd="auth id=$id,szone=$szone,sipgrp=$sipgrp,type=$type"

	case $type in
		"web")
			bypass_src_ip="`uci get userauth.@rule[$i].bypass_src_ip`"
			test -n "$bypass_src_ip" && ipset create auth_bypass_src_ip$id hash:net && {
				for net in $bypass_src_ip; do
					ipset add auth_bypass_src_ip$id $net
				done
				cmd="$cmd,ipwhite=auth_bypass_src_ip$id"
			}

			bypass_src_mac="`uci get userauth.@rule[$i].bypass_src_mac`"
			test -n "$bypass_src_mac" && ipset create auth_bypass_src_mac$id hash:mac && {
				for mac in $bypass_src_mac; do
					ipset add auth_bypass_src_mac$id $mac
				done
				cmd="$cmd,macwhite=auth_bypass_src_mac$id"
			}
				;;
		"auto")
			:
		;;
		"*")
			echo userauth.@rule[$i]: type error
			continue
		;;
	esac

	echo "$cmd" >/dev/nos_auth_ctl
done

exit 0
