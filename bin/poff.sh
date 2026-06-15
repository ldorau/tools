#!/bin/bash

if [ "$1" = "" ]; then
	echo "Usage: poff <min-block> [min-unblock|10]"
	exit 1
fi

echo "Sleeping $1 minutes ..."
sleep $1m

ufw-deny "192.168.0.0/16" || true

[ "$2" == "" ] && M=10 || M=$2
echo "Sleeping $M minutes ..."
sleep ${M}m

ubl "0/16"
