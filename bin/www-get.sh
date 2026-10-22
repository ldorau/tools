#!/bin/bash

LOG=$HOME/www.log
echo >> $LOG
echo ">>> $(date +'%F %T') $(basename $0) $*" >> $LOG

DIR=$(dirname $0)
source $DIR/functions.sh

[ ! "$1" ] && log_cmd echo "Error: URL required!" && exit 1
[ ! $DEFAULT_EMAIL_ADDRESS ] && log_cmd echo "Warning: default e-mail address is not set!"

URL=$1
OUT=/tmp/www-get-out
ERR=/tmp/www-get-err
rm -f $OUT $ERR

function wget_url() {
	local URL=$1
	local OUT=$2
	local ERR=$3

	echo "$ wget -O $OUT $URL 2>$ERR" >> $LOG
	wget --timeout=180 -O $OUT $URL 2>$ERR
	if [ $? -ne 0 ]; then
		[ $DEFAULT_EMAIL_ADDRESS ] \
			&& mail_log $DEFAULT_EMAIL_ADDRESS "WGET ERROR ($URL)" $ERR \
			|| (log_cmd echo "Error:" && log_cmd cat $ERR)
		exit 1
	fi
}

wget_url $URL $OUT $ERR

# sed - replace ń with n
[ "$2" == "no" ] && cat $OUT || cat $OUT | sed 's/\xF1/n/g' | sed 's/\xB1/a/g' | sed 's/<[^<>]*>//g'
