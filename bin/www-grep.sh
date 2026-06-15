#!/bin/bash

VER_2019=0
if [ "$1" == "2019" ]; then
	VER_2019=1
	shift
fi

LOG=$HOME/www.log
echo >> $LOG
echo ">>> $(date +'%F %T') $(basename $0) $*" >> $LOG

DIR=$(dirname $0)
source $DIR/functions.sh

[ $# -lt 2 ] && log_cmd echo "Usage: $0 <URL> <match1> [<match2> ...]" && exit 1

OPTS="$*"
OUT=/tmp/www-grep-out
URL=$1
shift
MATCHES=""

while [ "$1" != "" ]; do
	MATCHES="$MATCHES -e $1"
	shift
done

if [ $VER_2019 -eq 0 ]; then
	echo "$ www-get.sh $URL | grep --text $MATCHES > $OUT" >> $LOG
	$DIR/www-get.sh $URL | grep --text $MATCHES > $OUT
	RV=$?
else
	echo "$ www-get.sh $URL | grep --text $MATCHES | grep --text -e 2019 > $OUT" >> $LOG
	$DIR/www-get.sh $URL | grep --text $MATCHES | grep --text -e 2019 > $OUT
	RV=$?
fi
if [ $RV -eq 0 ]; then
	SUBJECT="WGET MATCH: $OPTS"
	[ $DEFAULT_EMAIL_ADDRESS ] \
		&& mail_log $DEFAULT_EMAIL_ADDRESS "$SUBJECT" $OUT \
		|| (log_cmd echo "$SUBJECT" && log_cmd cat $OUT)
fi

