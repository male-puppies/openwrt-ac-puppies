#!/bin/sh
OPENSSL=openssl
tar(){
	inpath=$1
	outpath=$2
	password=$3
	cmd="cd $inpath && tar -zcf - * | $OPENSSL aes-256-cbc -salt -k '$password' -out $outpath"
	rm -f $outpath
	sh -c "$cmd"
	if [ $? -ne 0 ]; then
		echo "tar fail"
		exit 1
	fi
	echo "tar success"
	exit 0
}

untar(){
	inpath=$1
	outpath=$2
	password=$3
	test ! -d $outpath && mkdir -p $outpath
	# bug in tar, cannot only judge by $?. in addition, by the error string
	cmd="$OPENSSL aes-256-cbc -d -salt -k '$password' -in $inpath | tar -zxf - -C $outpath"
	res=$(sh -c "$cmd" 2>&1)
	if [ $? -ne 0 ]; then
		echo "untar fail"
		exit 1
	fi
	echo $res | grep -E "bad magic|invalid magic|short read|error" > /dev/null
	if [ $? -ne 0 ]; then
		echo "untar success"
		exit 0
	fi
	echo "untar fail"
	exit 1
}

usage() {
	echo "usage $0 tar|untar inpath outpath [password]"
	echo "password : 123456(default)"
	exit 1
}

test $# -lt 3 && usage

option=$1
inpath=$2
outpath=$3
password=$4

test "$password" == "" && password="123456"
test "$option" == "tar" && tar $inpath $outpath $password
test "$option" == "untar" && untar $inpath $outpath $password
usage

