#!/bin/bash

FILE=$1
[ "$FILE" == "" ] && FILE="./*"

ALL=~/chess/players-all.txt 
CPY=~/chess/players-all.txt_copy
TMP=/tmp/players-all.txt
DIFF=/tmp/players-all.txt_diff

echo "Chess stats: added new players..." > $DIFF

cp -f $ALL $CPY

cat $FILE | grep -e "data-name=" | grep -e "data-username=" | grep -v -e "chess-players\.sh" | sed 's/data-username=\"/\^/g' | cut -d'^' -f2 | cut -d'"' -f1 | sort | uniq >> $ALL

# CURRENT games = have to logged in
# cat $FILE | grep -A1 -e "<span class=\"username\">" | grep -v -e "<span class=\"username\">" -e "dluki" -e "--" | cut -d' ' -f5 | sort | uniq >> $ALL

cat $ALL | sort | uniq > $TMP
mv $TMP $ALL

for player in $(diff $CPY $ALL | grep -e '>' | cut -d' ' -f2); do
	chess-stats-one-player.sh $player | tee -a $DIFF
done

[ $(cat $DIFF | wc -l) -gt 1 ] && ~/bin/md $DIFF
