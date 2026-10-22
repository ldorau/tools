#!/bin/bash

DIR_FROM=$1
DIR_TO=$2

if [ "$DIR_FROM" == "" -o "$DIR_TO" == "" ]; then
	echo "Usage: $0 <dir-from> <dir-to>"
	exit 1
fi

DIRS=/tmp/dirs

find . -type d > $DIRS

cat $DIRS | \
while IFS='' read -r line || [[ -n "$line" ]]; do
	dir="$line"
	[ ! -d "$dir" ] && echo "NOT DIR: $dir" && continue
	[ "$dir" == "." ] && continue
	newdir=$(echo "$dir" | sed "s/$DIR_FROM/$DIR_TO/g")
	[ "$dir" == "$newdir" ] && continue
	echo "NEW_DIR=$newdir"
	echo "mv -v $dir $newdir"
	mv -v "$dir" "$newdir"
done
