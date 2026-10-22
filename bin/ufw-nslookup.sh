#!/bin/bash
N=$(cat /var/log/ufw.log$1 | wc -l)
[ $N -eq 0 ] && echo "UFW log is empty" && exit 0
echo "NSLookup of /var/log/ufw.log$1 ($N lines):"
for ip in $(cat /var/log/ufw.log$1 | awk '{print $12}' | cut -d= -f2); do
	echo -n "IP=$ip:    "
	# nslookup $ip 8.8.8.8 2>/dev/null | grep -e 'name = ' || echo "(no info found)"
	nslookup $ip 8.8.8.8 | grep -e 'name = ' || echo " (no info found)"
done
