#!/bin/bash

set -x

VOBS=$(find $1 -iname '*.vob')
for vob in $VOBS; do
	ffmpeg -i $vob -target film-dvd ./$vob.mpg
done

MPGS=$(find . -iname '*.mpg')
for mpg in $MPGS; do
	ffmpeg -i $mpg
done
