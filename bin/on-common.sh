#!/bin/bash

MINIMUM=300

function get_period_secs() {
	DATE_PREV=$1
	DATE_NEXT=$2
	SEC_PREV=$(date +%s -d "$DATE_PREV")
	SEC_NEXT=$(date +%s -d "$DATE_NEXT")

	SECS=$(($SEC_NEXT - $SEC_PREV))
	echo $SECS
}

function print_period() {
	DATE_PREV=$1
	DATE_NEXT=$2
	SEC_PREV=$(date +%s -d "$DATE_PREV")
	SEC_NEXT=$(date +%s -d "$DATE_NEXT")

	SECS=$(($SEC_NEXT - $SEC_PREV))
	MINS=$(($SECS / 60))
	HOURS=$(($MINS / 60))
	DAYS=$(($HOURS / 24))

	SEC=$(($SECS % 60))
	MIN=$(($MINS % 60))
	HOUR=$(($HOURS % 24))

	TIME=""
	[ $DAYS -gt 0 ] && TIME="$DAYS days"
	[ $DAYS -gt 0 ] && [ $HOUR -gt 0 ] && TIME="${TIME} "
	[ $HOUR -gt 0 ] && TIME="${TIME}${HOUR} hours"
	[ $HOUR -gt 0 ] && [ $MIN  -gt 0 ] && TIME="${TIME} "
	[ $MIN  -gt 0 ] && TIME="${TIME}${MIN} min"
	[ $MIN  -gt 0 ] && [ $SEC  -gt 0 ] && TIME="${TIME} "
	[ $SEC  -gt 0 ] && TIME="${TIME}${SEC} sec"

	echo "$DATE_PREV -- $DATE_NEXT (${TIME})"
}

function print_total_secs() {
	SECS=$1
	MINS=$(($SECS / 60))
	HOURS=$(($MINS / 60))
	DAYS=$(($HOURS / 24))

	SEC=$(($SECS % 60))
	MIN=$(($MINS % 60))
	HOUR=$(($HOURS % 24))

	TIME=""
	[ $DAYS -gt 0 ] && TIME="$DAYS days"
	[ $DAYS -gt 0 ] && [ $HOUR -gt 0 ] && TIME="${TIME} "
	[ $HOUR -gt 0 ] && TIME="${TIME}${HOUR} hours"
	[ $HOUR -gt 0 ] && [ $MIN  -gt 0 ] && TIME="${TIME} "
	[ $MIN  -gt 0 ] && TIME="${TIME}${MIN} min"
	[ $MIN  -gt 0 ] && [ $SEC  -gt 0 ] && TIME="${TIME} "
	[ $SEC  -gt 0 ] && TIME="${TIME}${SEC} sec"

	echo "$1 sec TOTAL TIME ($TIME)"
}

function work_on_file() {
	FILE=$1
	FIRST_DATE=""
	PREV_DATE=""
	NEXT_DATE=""
	TOTAL_SECS=0

	while IFS='' read -r line || [[ -n "$line" ]]; do
		NEXT_DATE="$line"
		if [ "$PREV_DATE" == "" ]; then
			PREV_DATE="$line"
			FIRST_DATE="$line"
		fi

		SECS=$(get_period_secs "$PREV_DATE" "$NEXT_DATE")
		if [ $SECS -gt $MINIMUM ]; then
			print_period "$FIRST_DATE" "$PREV_DATE"
			SECS=$(get_period_secs "$FIRST_DATE" "$PREV_DATE")
			TOTAL_SECS=$(( $TOTAL_SECS + $SECS ))
			FIRST_DATE=$NEXT_DATE
		fi
		PREV_DATE=$NEXT_DATE
	done < $FILE

	if [ "$FIRST_DATE" != "$PREV_DATE" ]; then
		print_period "$FIRST_DATE" "$PREV_DATE"
		SECS=$(get_period_secs "$FIRST_DATE" "$PREV_DATE")
		TOTAL_SECS=$(( $TOTAL_SECS + $SECS ))
	fi

	echo
	print_total_secs $TOTAL_SECS
}
