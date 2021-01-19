#!/bin/sh


if [ -z $1 ]; then
	echo "Please give an IPBus address to test"
	exit
fi

addr=$((0x64000000 + ($1 << 2)))

ITERATION=0
ERRORS=0
TIME_START=`date +%s`
HEX_NUMBER_RE=^0[xX][0-9a-fA-F]+$

while [ $ITERATION -lt 1000 ]; do
	VALUE=`awk -F - '{print(("0x"$1) % 0xffff)}' /proc/sys/kernel/random/uuid`
	#echo "writing $VALUE"
	mpoke $addr $VALUE
	READBACK=`mpeek $addr`
        #echo "read back $READBACK"
	if ! echo $READBACK | egrep -q $HEX_NUMBER_RE; then
		echo "ERROR: readback is not a number: $READBACK"
		let ERRORS=ERRORS+1
	elif [ $VALUE -ne $(( $READBACK )) ]; then
		echo "ERROR: wrote $VALUE, got $READBACK, which is $(( $READBACK ))"
		let ERRORS=ERRORS+1
		echo "exiting on first error (comment this line to not exits and count errors instead)"
		exit
	fi
	let ITERATION=ITERATION+1
done

TIME_END=`date +%s`

echo "Total errors: $ERRORS"
echo "Total time spent: $(( $TIME_END - $TIME_START ))"
