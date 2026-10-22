#!/bin/bash

INSTALLED=$(pacman -Q | grep 'linux ' | grep -v '\-linux' | cut -d' ' -f2 | sed 's/.arch/-arch/g')
RUNNING=$(uname -r | sed 's/-ARCH//g')

[ "$INSTALLED" == "$RUNNING" ] && echo OK && exit 0

echo "Kernel installed: $INSTALLED"
echo "Kernel running:   $RUNNING"

