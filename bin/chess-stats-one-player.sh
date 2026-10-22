#!/bin/bash

MIN_RANKING=1600
MAX_GLICKO=65

RANK="Daily"

SUFFIX=$(basename $0).txt
PREFIX="/tmp/chess"
OUT=$PREFIX-outfile-$SUFFIX

function get_Ranking() {
	cat $OUT | grep -e "title=\"$RANK (" | cut -d'(' -f2 | cut -d')' -f1
}

function get_GlickoRD() {
	cat $OUT | grep -A1 -e "Glicko RD" | grep -v -e "Glicko RD" | cut -d' ' -f12-15
}

function get_MoveTime() {
	cat $OUT | grep -e "Time per Move" | cut -d'>' -f2 | cut -d'<' -f1
}

for name in $*; do
	NAME=$name
	echo -e -n "* $NAME: "

	url="https://www.chess.com/stats/daily/chess/$NAME"
	wget -O $OUT $url 2>/dev/null

	ranking=$(get_Ranking)
	glicko=$(get_GlickoRD)
	mtime=$(get_MoveTime)

	echo -e "Ranking: $ranking \t Glicko RD: $glicko \t Move Time: $mtime"

	if [ "$ranking" == "" -o "$ranking" == "Unrated" ]; then
		echo -e "\t\t No Ranking! ($ranking)"
	else
		[ $ranking -lt $MIN_RANKING ] && echo -e "\t\t Ranking: $ranking < $MIN_RANKING "
	fi

	if [ ! $glicko ]; then
		echo -e "\t\t No Glicko!"
	else
		[ $glicko -gt $MAX_GLICKO ] && echo -e "\t\t Glicko: $glicko > $MAX_GLICKO (Ranking: $ranking)"
	fi

	[ "$(echo $mtime | grep -e day)" != "" ] && echo -e "\t\t Move time: $mtime > 1 day" && continue
	[ $(echo $mtime | cut -d' ' -f1) -gt 9 ] && echo -e "\t\t Move time: $mtime > 9 hours" && continue
done
