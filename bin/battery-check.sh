#!/bin/bash

export BATTERY_THRESHOLD=15
SHUTDOWN_SENT=/tmp/battery-shutdown

function battery_status() {
	upower -i /org/freedesktop/UPower/devices/battery_BAT0
}

STATE=$(battery_status | grep -e "state:" | awk '{print $2}')
LEVEL=$(battery_status | grep -e "percentage:" | awk '{print $2}' | cut -d% -f1)

echo "BATTERY LEVEL: ${LEVEL}%"
battery_status | grep -e "state:" -e "time to"

if [ "$STATE" == "charging" -o "$STATE" == "fully-charged" ]; then
	if [ $LEVEL -eq 100 -o "$STATE" == "fully-charged" ]; then
		if [ ! -f ${SHUTDOWN_SENT} ] ; then
			touch ${SHUTDOWN_SENT}
			# sudo shutdown -P +1 "WARNING \!\!\! Battery level is ${LEVEL}% \! The system is going down in 1 minute \!\!\!"
			# alarm &
		fi
	else
		rm -f ${SHUTDOWN_SENT}
	fi
	exit 0
fi

#
# STATE == discharging
#

if [ $LEVEL -lt $BATTERY_THRESHOLD ]; then
	if [ ! -f ${SHUTDOWN_SENT} ] ; then
		touch ${SHUTDOWN_SENT}
		sudo shutdown +1 "WARNING \!\!\! Battery level is ${LEVEL}% \! The system is going down in 1 minute \!\!\!"
		alarm &
	fi
	exit 0
elif [ $LEVEL -lt $(( $BATTERY_THRESHOLD + 3 )) ]; then
	sudo wall "WARNING \!\!\! Battery level is ${LEVEL}% \! The system will be shut down soon \!\!\!"
	beep
	killall alarm 2>/dev/null
	alarm 1 &
	rm -f ${SHUTDOWN_SENT}
else
	rm -f ${SHUTDOWN_SENT}
fi
