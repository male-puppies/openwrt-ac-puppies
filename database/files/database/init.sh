#!/bin/sh
eexit () {
	echo "$*" 1>&2
	exit 1
}

dir="./init"
cd $dir || eexit "cd $dir fail"
for script in `ls ./disk_*`; do  
	msg=`$script`
	test $? -eq 0 || eexit "script fail $script $msg"
done



