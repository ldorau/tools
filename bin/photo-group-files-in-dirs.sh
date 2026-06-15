#!/bin/bash

DIRS=/tmp/dirs
FILES=/tmp/files

find .  -maxdepth 1 -type f -iname "20??????_*" > $FILES

cat $FILES | \
while IFS='' read -r line || [[ -n "$line" ]]; do
	FILE="$line"
	[ ! -f "$FILE" ] && echo "NOT FILE: $FILE" && continue

	echo "File: $FILE"

	BEGIN=$(echo $FILE | cut -c3-4)
	[ "$BEGIN" != "20" ] && continue
	echo "- begin: $BEGIN ($FILE)"

	YEAR=$(echo $FILE | cut -c3-6)
	MONTH=$(echo $FILE | cut -c7-8)
	DAY=$(echo $FILE | cut -c9-10)

	echo "- move to: $YEAR-$MONTH-$DAY"
	DIR=$YEAR-$MONTH-$DAY
	echo "- mkdir -p $DIR"
	mkdir -p $DIR
	echo "- mv $FILE $DIR"
	mv "$FILE" $DIR
done

exit 0

	CHANGE=$(echo $dir | cut -d'-' -f1-3 | cut -d'/' -f3)
	[ "$(echo $CHANGE | cut -c1-3)" != "$BEGIN" ] && continue

	newdir=$(echo $dir | sed "s/$CHANGE/$YEAR-$MONTH-$DAY/g")
	echo "- new dir: $newdir"
	echo "- move $dir $newdir"
	# mv -v "$dir" "$newdir"

newdir=$(echo "$dir" | sed "s/$DIR_FROM/$DIR_TO/g")
[ "$dir" == "$newdir" ] && continue
echo "NEW_DIR=$newdir"
mv -v "$dir" "$newdir"
