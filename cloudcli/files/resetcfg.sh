#!/bin/sh
opt=$1
reset_ad() {
	local adpath=/etc/config/ad.tgz
	local cloudpath=/usr/share/auth-web/www/cloud
	local tmpdir=$cloudpath".tmp"
	local deldir=$cloudpath".del"

	test -e $adpath || return
	rm -rf $tmpdir
	mkdir -p $tmpdir

	tar -xzf $adpath -C $tmpdir
	test $? -ne 0 && return

	test -e $cloudpath && mv $cloudpath $deldir
	mv $tmpdir $cloudpath
	rm -rf $deldir
	rm -rf /tmp/www
	/etc/init.d/authd restart
	/etc/init.d/cfgmgr restart
}

reset_dev() {
	/etc/init.d/authd restart
}

cloud_switch() {
	rm /tmp/invalid_account
	/etc/init.d/proxybase restart
	/etc/init.d/cloudcli restart
	/etc/init.d/authd restart
	/etc/init.d/cfgmgr restart
}

case $opt in
	dev)
		reset_dev
		;;
	ad)
		reset_ad
		;;
	cloud_switch)
		cloud_switch
		;;
	*)
		echo "invalid type"
		;;
esac
