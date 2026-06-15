#!/bin/bash

DIRS=/tmp/dirs
FILES=/tmp/files

find . -type d > $DIRS

cat $DIRS | \
while IFS='' read -r line || [[ -n "$line" ]]; do
	dir="$line"
	[ ! -d "$dir" ] && echo "NOT DIR: $dir" && continue
	[ "$dir" == "." ] && continue

	cd $dir

	ALL=$(find . -maxdepth 1 -type f ! -iname "*.AVI" | wc -l)
	GOOD=$(find . -maxdepth 1 -type f -name "20??????_??????*" | wc -l)

	if [ $GOOD -gt 0 -a $GOOD -lt $ALL ]; then
		echo "*** MIXED DIR: $dir"
		find . -maxdepth 1 -type f ! -name "20??????_??????*" ! -iname "*.AVI" | head -n1
		echo "---"
		find . -maxdepth 1 -type f -name "20??????_??????*" | head -n1
		echo "=================="
		cd - > /dev/null
		continue
	fi

	if [ $GOOD -eq 0 -a $ALL -gt 0 ]; then
		echo "*** TO BE PROCESSED ($ALL): $dir"
		find . -maxdepth 1 -type f ! -name "20??????_??????-*" ! -iname "*.AVI" | head -n1
		exiftool-rename-dir.sh 2>/dev/null
		echo "=================="
		cd - > /dev/null
		continue
	fi

	cd - > /dev/null
	continue
done

exit 0

	CDIRS=$(find $dir -type d)
	if [ "$CDIRS" != "$dir" ]; then
		echo "SKIPPING: $dir"
	fi
	echo "Process: $dir"

	FILE=$(ls -1 $dir | tail -n1)
	echo "- file: $FILE"

	BEGIN=$(echo $FILE | cut -c1-3)
	echo "- begin: $BEGIN ($FILE)"
	[ "$BEGIN" != "01-" ] && continue

	echo "- processing: $dir"
	cd $dir
	~/bin/exiftool-rename-only.sh
	cd ..
