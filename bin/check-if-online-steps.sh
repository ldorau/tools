#!/bin/bash

LOG=~/cron/offline-minutes.txt
NO_INTERNET=~/.status-no-internet
NO_WIFI=~/.status-no-wifi


function ping_once() {
	ping -c 1 -W 3 $1 > /dev/null 2>&1
}

function check_dest() {
	echo -n "- $1: "
	shift 1
	for ip in $*; do
		ping_once $ip && echo "ok" && 	return
	done
	echo "NO !!!"
}

echo ">>> Ping connectivity checks:"
check_dest "Wave    " 91.224.116.1 91.224.116.6
check_dest "Google  " 8.8.8.8 8.8.4.4
check_dest "OpenDNS " 208.67.222.222 208.67.220.220
# check_dest "LastDNS " 4.2.2.1 4.2.2.2
echo ">>> DNS connectivity checks:"
check_dest "www.google.com " www.google.com
check_dest "www.wp.pl      " www.wp.pl
check_dest "www.rp.pl      " www.rp.pl
