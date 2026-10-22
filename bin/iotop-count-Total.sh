#!/bin/bash

FIRST=0

for threads in 32 48; do
	FILES=$(ls -1 ./iotop-$threads-* | sort | xargs)
	for file in $FILES; do
		N=$(cat $file | grep Total | cut -d: -f5- | awk '{ print $1 }' | wc -l)
		NUMBERS=$(cat $file | grep Total | cut -d: -f5- | awk '{ print $1 }' | xargs)
		SUM=0
		for n in $NUMBERS; do
			SUM=$(arith-sum $SUM $n) 
		done
		AVG=$(arith-div $SUM $N)

		D=$(echo $file | cut -d- -f5- | cut -c1-2)
		H=$(echo $file | cut -d- -f5- | cut -c4-5   | sed 's/^0//g')
		M=$(echo $file | cut -d- -f5- | cut -c7-8   | sed 's/^0//g')
		S=$(echo $file | cut -d- -f5- | cut -c10-11 | sed 's/^0//g')
		H=$(( $H + 24 * ($D - 21) ))

		[ $FIRST -eq 0 ] && FIRST=$(( 3600 * $H + 60 * $M + $S ))

		SECS=$(( 3600 * $H + 60 * $M + $S - $FIRST ))

		AVG=$(echo $AVG | sed 's/\./,/g')

		echo "$threads;$SECS;$AVG"
	done
	FIRST=0
done

# ./iotop-32-2017-12-22_00:54:04.txt == 42634 == 41348.898684
# ./iotop-48-2017-12-22_01:04:38.txt == 43268 == 53092.544507

