#!/bin/bash

ADD=104

for n in $(seq 1 73); do
	[ $(echo $n | wc -c) -eq 2 ] && N="0$n" || N=$n
	FILE=$(ls -1 ${N}_01* 2>/dev/null | head -n1)
	[ "$FILE" == "" -o ! -f "$FILE" ] && continue
	NUM=$((${n} + $ADD))
	DIR=${NUM}-BA-$(echo $FILE | cut -c 7- | sed 's/_Rozdzial.*//g' | sed 's/_Prolog.*//g' | sed 's/_Psalm_.*//g' | sed 's/^_Ksiega/Ksiega/g' | sed 's/\.mp3//g')
	# echo $DIR && continue
	mkdir -v $DIR
	mv -v ${N}_* $DIR > /tmp/tmp-$$ 2>&1 || cat /tmp/tmp-$$ >> ./errors.txt
done

[ -f ./errors.txt ] && less ./errors.txt

