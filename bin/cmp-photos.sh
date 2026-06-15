#!/bin/bash -e

DIR_NEW=/mnt/hd/_Lukasz/Zdjecie-NOWE/Zdjecia-Filmy-Telefon-Gosi
DIR_ALL=/mnt/hd/_Lukasz/Zdjecia/

cd $DIR_NEW
# DIR_NEW=$(pwd)
PATH_NEW=$(pwd)
NEW=$(find -type f)

cd $DIR_ALL
PATH_ALL=$(pwd)

[ "$PATH_NEW" == "$PATH_ALL" ] && exit 1

for f in $NEW; do
	NAME=$(basename $f)
	OLD=$(find -type f -name $NAME | head -n1)
	if [ "$OLD" ]; then
		SIZE_NEW=$(stat -c %s $DIR_NEW/$f)
		SIZE_OLD=$(stat -c %s "$DIR_ALL/$OLD")
		MD5SUM_NEW=$(md5sum $DIR_NEW/$f | cut -d' ' -f1)
		MD5SUM_OLD=$(md5sum "$DIR_ALL/$OLD" | cut -d' ' -f1)
		if [ $SIZE_NEW -eq $SIZE_OLD -a "$MD5SUM_NEW" != "$MD5SUM_OLD" ]; then
			echo ">>> WRONG MD5SUM !!!"
			echo ">>> NEW: $DIR_NEW/$f"
			echo ">>> OLD: $DIR_ALL/$OLD"
			exit 1
		fi
		if [ $SIZE_NEW -eq $SIZE_OLD -a "$MD5SUM_NEW" == "$MD5SUM_OLD" ]; then
			if cmp $DIR_NEW/$f "$DIR_ALL/$OLD"; then
				echo "RM $DIR_NEW/$f"
				rm -v $DIR_NEW/$f
			fi
		fi
	else
		echo "No OLD for $f"
	fi
done

cd $DIR_NEW
DIRS=$(find -type d)
for d in $DIRS; do
	if [ -z "$(ls -A $d)" ]; then
		echo "Removing empty dir: $d"
		rm -r $d
	fi
done
