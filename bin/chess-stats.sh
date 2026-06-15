#!/bin/bash

# URL_CURRENT="https://www.chess.com/daily/games/current/dluki"
URL="https://www.chess.com/games/archive/dluki"

OUT=~/chess/out
DIR=~/chess/
ERR=/tmp/err

function wget_url() {
	local URL=$1
	local OUT=$2
	local ERR=$3

	rm -f $OUT
	echo "wget: $URL"
	wget --timeout=180 -O $OUT $URL 2>>$ERR
	if [ $? -ne 0 ]; then
		~/bin/md $ERR
		exit 1
	fi
}

cd $DIR
echo "Chess stats WGET error" > $ERR

wget_url $URL $OUT $ERR
chess-grep-players.sh $OUT

rm -f $OUT

chess-stats-players-all.sh mail
