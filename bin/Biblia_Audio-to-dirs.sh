#!/bin/bash

for N in $(seq 0 73); do
	[ $(echo $N | wc -c) -eq 2 ] && N="0$N"
	FILE=$(ls -1 ${N}_01* 2>/dev/null | head -n1)
	[ "$FILE" == "" -o ! -f "$FILE" ] && continue
	DIR=${N}-$(echo $FILE | cut -c 7- | sed 's/_Rozdzial.*//g' | sed 's/_Prolog.*//g' | sed 's/_Psalm_.*//g' | sed 's/^_Ksiega/Ksiega/g' | sed 's/\.mp3//g')
	# echo $DIR
	mkdir -v $DIR
	mv -v ${N}_* $DIR > /tmp/tmp-$$ 2>&1 || cat /tmp/tmp-$$ >> ./errors.txt
done

[ -f ./errors.txt ] && less ./errors.txt

