#!/bin/bash

DIRS=/tmp/dirs

find . -type d -name "201-*" > $DIRS

cat $DIRS | \
while IFS='' read -r line || [[ -n "$line" ]]; do
	dir="$line"
	[ ! -d "$dir" ] && echo "NOT DIR: $dir" && continue
	[ "$dir" == "." ] && continue

	CDIRS=$(find $dir -type d)
	if [ "$CDIRS" != "$dir" ]; then
		echo "SKIPPING: $dir"
	fi
	echo "Process: $dir"

	FILE=$(ls -1 $dir | head -n1)
	echo "- file: $FILE"

	BEGIN=$(echo $FILE | cut -c1-3)
	[ "$BEGIN" != "201" ] && continue

	CHANGE=$(echo $dir | cut -d'-' -f1-3 | cut -d'/' -f3)
	[ "$(echo $CHANGE | cut -c1-3)" != "$BEGIN" ] && continue

	YEAR=$(echo $FILE | cut -c1-4)
	MONTH=$(echo $FILE | cut -c5-6)
	DAY=$(echo $FILE | cut -c7-8)
	echo "- change: $CHANGE to $YEAR-$MONTH-$DAY"
	newdir=$(echo $dir | sed "s/$CHANGE/$YEAR-$MONTH-$DAY/g")
	echo "- new dir: $newdir"
	echo "- move $dir $newdir"
	# mv -v "$dir" "$newdir"
done

exit 0

newdir=$(echo "$dir" | sed "s/$DIR_FROM/$DIR_TO/g")
[ "$dir" == "$newdir" ] && continue
echo "NEW_DIR=$newdir"
mv -v "$dir" "$newdir"
