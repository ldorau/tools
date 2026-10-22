#!/bin/bash

set -e

MASK=$1

FILES=$(find -type f -name "$MASK" | xargs)

for f in $FILES; do
	sed -i '/Copyright/d' $f
done

for f1 in $FILES; do
for f2 in $FILES; do
	[ "$f1" == "$f2" ] && continue
	SIZE1=$(stat -c %s $f1)
	SIZE2=$(stat -c %s $f2)
	[ "$SIZE1" != "$SIZE2" ] && continue
	# echo "########################################################"
	# diff $f1 $f2 && echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> $f1 == $f2"
	diff $f1 $f2 >/dev/null 2>&1 && echo ">>> $f1 == $f2"
done
done
