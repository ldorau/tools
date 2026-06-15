#!/bin/bash

MASK="$1"
SEP="$2"

if [ "$2" == "" ]; then
	echo "Usage: $0 <file_mask> <separator>"
	echo "For files like: IMG-20220305-WA0033.jpg"
	echo "   file_mask='IMG-' separator='-'"
	exit 1
fi

for file in $(ls -1 ${MASK}*); do 
	DATE=$(echo $file | cut -d"$SEP" -f2)
	YY=$(echo $DATE | cut -c1-4)
	MM=$(echo $DATE | cut -c5-6)
	DD=$(echo $DATE | cut -c7-8)

	mkdir -p $YY-$MM-$DD
	mv -v $file $YY-$MM-$DD/
done
