#!/bin/sh

err_exit() {
	echo "$*"
	exit 1
}

backup() {
	outpath=$1
	backupdir=/tmp/sysbackup
	rm -rf $backupdir /tmp/sysbackup_*.bin
	mkdir -p $backupdir

	cp /etc/openwrt_* $backupdir
	date >> $backupdir/time.txt

	sysupgrade --create-backup $backupdir/cfg.tar.tgz
	test $? -eq 0 || err_exit "sysupgrade --create-backup fail"

	timeout -t 10 openssltar.sh tar $backupdir $outpath wjrc0409
	test $? -eq 0 || err_exit "openssltar.sh tar fail"

	rm -rf $backupdir
}

restore() {
	inpath=$1
	recover_dir=/tmp/recover_dir
	rm -rf $recover_dir

	timeout -t 10 openssltar.sh untar $inpath $recover_dir wjrc0409
	test $? -eq 0 || err_exit "openssltar.sh tar fail"

	s1=`cat $recover_dir/openwrt_release | grep DISTRIB_DESCRIPTION`
	test $? -eq 0 || err_exit "read $recover_dir/openwrt_release fail"
	s2=`cat /etc/openwrt_release | grep DISTRIB_DESCRIPTION`
	test $? -eq 0 || err_exit "read /etc/openwrt_release fail"
	if [ "$s1" == "$s2" ]; then 
		sysupgrade --restore-backup $recover_dir/cfg.tar.tgz
		test $? -eq 0 || err_exit "sysupgrade --restore-backup fail"

		rm -rf $recover_dir
		echo "result:ok"
		exit 0
	fi
	echo "result:$s1 <======> $s2"
	exit 1
}

case $1 in
"backup")
	backup $2;;
"restore")
	restore $2;;
*)
	echo "error";;
esac