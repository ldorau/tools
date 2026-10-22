#!/bin/bash

[ "$1" != "" ] && SEC=$1 || SEC=1

beep; sleep 1; beep; sleep 1; beep;

watch -n$SEC battery-check.sh
