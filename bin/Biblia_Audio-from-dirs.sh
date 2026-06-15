#!/bin/bash

for DIR in $(ls -1); do
	[ ! -d "$DIR" ] && continue
	mv -v $DIR/* . > /tmp/tmp-$$ 2>&1 || cat /tmp/tmp-$$ >> ./errors.txt
	rm -r $DIR
done

[ -f ./errors.txt ] && less ./errors.txt

