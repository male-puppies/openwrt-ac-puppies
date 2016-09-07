#!/bin/sh

[ x"$1" = x"-f" ] || {
	echo "usage: $0 -f"
	exit 0
}

if test -f /rom/lib/preinit/79_disk_ready; then
	sleep 1; killall dropbear uhttpd; sleep 1; echo erase >/dev/sda3 && reboot
else
	sleep 1; killall dropbear uhttpd; sleep 1; jffs2reset -y && reboot
fi
