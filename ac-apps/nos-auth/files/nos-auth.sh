#!/bin/sh

[ x$1 = xstop ] && {
	echo clean >/dev/nos_auth_ctl
	exit 0
}

[ x$1 = xstart ] || {
	echo "usage: $0 start|stop"
	exit 0
}

no_flow_timeout="`uci get nos-auth.@defaults[0].no_flow_timeout 2>/dev/null`"
test -n "$no_flow_timeout" || no_flow_timeout=3600
redirect_ip="`uci get nos-auth.@defaults[0].redirect_ip 2>/dev/null`"
test -n "$redirect_ip" || redirect_ip="1.0.0.8"
bypass_http_host="`uci get nos-auth.@defaults[0].bypass_http_host 2>/dev/null`"
bypass_dst_ip="`uci get nos-auth.@defaults[0].bypass_dst_ip 2>/dev/null`"

echo clean >/dev/nos_auth_ctl
for i in `seq 0 255`; do
	ipset destroy auth_bypass_src_ip$i >/dev/null 2>&1
	ipset destroy auth_bypass_src_mac$i >/dev/null 2>&1
done

ipset destroy auth_global_bypass_dst_ip >/dev/null 2>&1
if test -n "$bypass_dst_ip" || test -n "$bypass_http_host"; then
	ipset create auth_global_bypass_dst_ip hash:ip

	test -n "$bypass_dst_ip" && {
		for ip in $bypass_dst_ip; do
			ipset add auth_global_bypass_dst_ip $ip
		done
	}

	test -n "$bypass_http_host" && {
		dh_conf="/tmp/dnsmasq.d/auth_global_bypass_host.conf"
		mkdir -p /tmp/dnsmasq.d
		echo -n >$dh_conf
		for host in $bypass_http_host; do
			echo ipset=/$host/auth_global_bypass_dst_ip >>$dh_conf
		done
		/etc/init.d/dnsmasq reload
		(
		 for host in $bypass_http_host; do
			nslookup $host >/dev/null 2>&1
		 done
		) &
	}
	echo auth_global_bypass_dst_ip=auth_global_bypass_dst_ip >/dev/nos_auth_ctl
fi

ifconfig br-lo >/dev/null 2>&1 || brctl addbr br-lo
ip addr flush dev br-lo
ip addr add $redirect_ip/32 brd + dev br-lo

echo no_flow_timeout=$no_flow_timeout >/dev/nos_auth_ctl
echo redirect_ip=$redirect_ip >/dev/nos_auth_ctl

for i in `seq 0 255`; do
	[ x"`uci get nos-auth.@rule[$i] 2>/dev/null`" = xrule ] >/dev/null 2>&1 || break
	disabled="`uci get nos-auth.@rule[$i].disabled 2>/dev/null`"
	[ x$disabled = x1 ] && {
		echo "info: rule [$i] disabled"
		continue
	}

	type="`uci get nos-auth.@rule[$i].type`"
	test -n "$type" || continue
	id="`uci get nos-auth.@rule[$i].id`"
	test -n "$id" || continue
	szone="`uci get nos-auth.@rule[$i].szone`"
	test -n "$szone" || continue
	sipgrp="`uci get nos-auth.@rule[$i].sipgrp`"
	test -n "$sipgrp" || continue

	cmd="auth id=$id,szone=$szone,sipgrp=$sipgrp,type=$type"

	case $type in
		"web")
			bypass_src_ip="`uci get nos-auth.@rule[$i].bypass_src_ip 2>/dev/null`"
			test -n "$bypass_src_ip" && ipset create auth_bypass_src_ip$id hash:net && {
				for net in $bypass_src_ip; do
					ipset add auth_bypass_src_ip$id $net
				done
				cmd="$cmd,ipwhite=auth_bypass_src_ip$id"
			}

			bypass_src_mac="`uci get nos-auth.@rule[$i].bypass_src_mac 2>/dev/null`"
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
			echo nos-auth.@rule[$i]: type error
			continue
		;;
	esac

	echo "$cmd" >/dev/nos_auth_ctl
done

echo update magic >/dev/nos_auth_ctl

exit 0
