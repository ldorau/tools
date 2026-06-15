#!/bin/bash

function run_command()
{
        COMMAND="$*"
        echo "$ $COMMAND"
        eval $COMMAND
        echo
}

function log_cmd()
{
        CMD=$1
	shift

	[ $LOG ] && eval $CMD $* &>> $LOG
	eval $CMD $*
}

function mail_log()
{
	ADDRESS=$1
	SUBJECT=$2
	BODY=$3

	if [ $LOG ]; then
		echo "Sending E-MAIL:"				>> $LOG
		echo "   To:      $ADDRESS"			>> $LOG
		echo "   Subject: $SUBJECT"			>> $LOG
		echo "--- BEGINNING OF E-MAIL MESSAGE ---"	>> $LOG
		cat $BODY					>> $LOG
		echo "--- END OF E-MAIL MESSAGE ---"		>> $LOG
		echo						>> $LOG
	fi

	mail -s "[RPI] $SUBJECT" $ADDRESS < $BODY
}

