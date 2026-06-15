#!/bin/bash

DIRS=/tmp/du-all-dirs.in
OUT=/tmp/du-all-dirs.out

rm -f $DIRS $OUT

echo -n "*** Finding all directories... "
sudo find / \
	-path /sys -prune -o \
	-path /dev -prune -o \
	-path /mnt -prune -o \
	-path /proc -prune -o \
	-path $HOME/work -prune -o \
	-path $HOME/apps -prune -o \
	-path $HOME/abs -prune -o \
	-path $HOME/aur -prune -o \
	-type d 2>/dev/null > $DIRS

ALL=$(cat $DIRS | wc -l)
N=0

echo "done (found $ALL dirs)."
echo "*** Counting disk usage..."
cat $DIRS | \
while IFS='' read -r line || [[ -n "$line" ]]; do
	dir="$line"
	[ ! -d "$dir" ] && continue

	sudo du -s $dir 2>/dev/null >> $OUT

	N=$(($N + 1)) && echo -ne "\r$N"
done

cat $OUT | sort -nr > $DIRS
mv $DIRS $OUT
less $OUT
echo "*** Output saved to $OUT"
