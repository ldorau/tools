#!/bin/bash

function diff-dir-names() {

	DIR_1=$1
	DIR_2=$2
	LS_1=/tmp/diff-dir-1
	LS_2=/tmp/diff-dir-2

	ls -1 "$DIR_1" | sort > $LS_1
	ls -1 "$DIR_2" | sort > $LS_2

	diff $LS_1 $LS_2 > /dev/null
	RV=$?
	[ $RV -eq 0 ] && return 0

	echo "LINES: $(cat $LS_1 | wc -l) and $(cat $LS_2 | wc -l)"
	return $RV
}


DIR_FROM=$1
DIR_TO=$2

if [ "$DIR_FROM" == "" -o "$DIR_TO" == "" ]; then
	echo "Usage: $0 <dir-from> <dir-to>"
	exit 1
fi

if [ ! -d "$DIR_FROM" ]; then
	echo "Error: "$DIR_FROM" is not a directory"
	exit 1
fi

if [ ! -d "$DIR_TO" ]; then
	echo "Error: "$DIR_TO" is not a directory"
	exit 1
fi

FOUND=/tmp/found
DIRS=/tmp/dirs

ls -1 $DIR_FROM > $DIRS

cat $DIRS | \
while IFS='' read -r line || [[ -n "$line" ]]; do
	dir="$line"
	[ ! -d "$DIR_FROM/$dir" ] && echo "NOT DIR: $DIR_FROM/$dir" && continue

	echo "- $DIR_FROM/$dir ..."

	[ $(find $DIR_FROM/$dir -type f | wc -l) -eq 0 ] && rmdir -v $DIR_FROM/$dir && continue

	DATE=$(echo $dir | cut -c1-10)
	ls -1 $DIR_TO | grep -e $DATE > $FOUND
	RV=$?
	# echo "dir=$dir RV=$RV"

	# nothing found in TO
	if [ $RV -ne 0 ]; then
		echo "Moving: $DIR_FROM/$dir to: $DIR_TO"
		mv -v "$DIR_FROM/$dir" "$DIR_TO"
		continue
	fi

	if [ $(cat $FOUND | wc -l) -gt 1 ]; then
		echo "WARNING: found more than one ($(cat $FOUND | wc -l)) for '$DATE' (SKIPPING...)"
		cat $FOUND
		continue
	fi

	cat $FOUND | \
	while IFS='' read -r line || [[ -n "$line" ]]; do
		found="$line"
		# echo "found=$found"
		[ ! -d "$DIR_TO/$found" ] && echo "NOT FOUND DIR: $DIR_TO/$found" && continue

		echo "MOVING: mv -v $DIR_FROM/$dir/* TO $DIR_TO/$found/"
		mv -n -v $DIR_FROM/$dir/* $DIR_TO/$found/
	done
done
