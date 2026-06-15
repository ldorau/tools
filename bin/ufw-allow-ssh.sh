#!/bin/bash

for ip in $*; do
	sudo ufw limit proto tcp from $ip to any port 22
done
