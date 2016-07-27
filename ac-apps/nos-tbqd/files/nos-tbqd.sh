#!/bin/sh

FSYS='/sys/module/tbq/tbq'

[ x$1 = xstop ] && {
	echo 0 > ${FSYS}
	exit 0
}

[ x$1 = xstart ] || {
	echo "usage: $0 start|stop"
	exit 0
}


mkdir -p /tmp/memfile/
echo 0 > ${FSYS}
lua /usr/share/nos-tbqd/settc.lua /etc/config/tc.json | cat > ${FSYS}
echo 1 > ${FSYS}

exit 0
