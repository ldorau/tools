#!/bin/bash

if [ "$1" = "" ]; then
	echo "Usage: block.sh <ip> [min-block|0] [min-unblock|10]"
	exit 1
fi

[ "$2" == "" ] && M=0 || M=$2
echo "Sleeping $M minutes ..."
sleep ${M}m

ufw-deny "192.168.0.$1"

[ "$3" == "" ] && M=10 || M=$3
echo "Sleeping $M minutes ..."
sleep ${M}m

ubl "$1"
