#!/bin/sh  
diskdb_name=disk.db

err_exit() {
	echo `uptime` " $*" 1>&2
	exit 3
}

copy_disk() {
	local diskdir=$1
	local workdir=$2
	local diskdb=$diskdir/$diskdb_name".tgz"
	if [ ! -d $workdir ]; then 
		mkdir -p $workdir || err_exit "mkdir fail $workdir"
	fi
	local dbpath=$workdir/$diskdb_name
	if [ -e $dbpath ]; then 
		rm -f $dbpath
		test $? -eq 0 || err_exit "rm fail $dbpath"
	fi
	if [ -e $diskdb ]; then 
		tar -xzf $diskdb -C $workdir
		chmod a+w $workdir/*
		test $? -eq 0 || err_exit "tar -xzf $diskdb -C $workdir fail"
	fi 
}

backup_disk() {
	local diskdir=$1
	local workdir=$2
	local diskdb=$diskdir/$diskdb_name".tgz"
	local tmp=$diskdb".tmp"
	local del=$diskdb".del"
	test -e $tmp && rm -f $tmp 

	tar -zcf $tmp -C $workdir $diskdb_name
	test $? -eq 0 || err_exit "tar -zcf $diskdb -C $workdir $diskdb_name fail"
	rm -f $del

	if [ -e $diskdb ]; then 
		mv $diskdb $del 
		test $? -eq 0 || err_exit "mv $diskdb $del fail"
	fi
	mv $tmp $diskdb
	rm -f $del $diskdir/log.bin
}

case $1 in
	copy)
		diskdir=$2
		workdir=$3
		test "$diskdir" = "" && exit 1
		test "$workdir" = "" && exit 2
		copy_disk $diskdir $workdir
		exit 0
		;;
	backup)
		diskdir=$2
		workdir=$3
		test "$diskdir" = "" && exit 1
		test "$workdir" = "" && exit 2
		backup_disk $diskdir $workdir
		exit 0
		;;
	*)
		exit 1
esac















;