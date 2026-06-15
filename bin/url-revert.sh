#!/bin/bash

function revert_url() {
	new=""
	token=""
	rest=$1
	while [ "$rest" != "$token" ]; do
		token=$(echo $rest | cut -d'.' -f1)
		rest=$(echo $rest | cut -d'.' -f2-)
		[ "$new" = "" ] && new="${token}" || new="${token}.${new}"
	done
	echo $new
}

if [ "$*" = "" ]; then
	while IFS= read -r line; do
		for url in $line; do
			revert_url $url
		done
	done < /dev/stdin
else
	for url in $*; do
		revert_url $url
	done
fi
