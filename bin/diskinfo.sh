#!/bin/bash

echo
echo "Running a quick all-hard-disks check" 
echo

# for disk in `ls /dev/[s,d]d[a-z]`; do
for disk in `ls /dev/sd[a-e]`; do

    #overall disk information

        #show device name
        echo -n "Disk name:            "
        echo $disk
        #show serial number 
        echo -n "Disk serial number:   "
        hdparm -I $disk | grep "Serial Number:" | awk '{print $3}'
        #show device size in GB
        echo -n "Size [GB]:            "
        fdisk -l 2>/dev/null | grep $disk | grep GB | awk '{print $3}'

    #checking disk health status

        #checking the SMART status
        status=`smartctl -H $disk | grep health | awk -F":" '{print $2}' | awk '{print $1}'`

        if [ "$status" != "PASSED" ]; then
                echo "Smart Health Status:  Broken"
        else
                echo "Smart Health Status:  OK"
        fi

        #checking more of the SMART status - if any of the VALUES or WORST is below the THRESH then the disk is close to crushing down
        smartctl -s on $disk > /dev/null
        smartctl -t offline $disk > /dev/null

        smartctl -A $disk | grep 0x00 | awk '{ if ($4<$6) print "The VALUE or WORST score of",$2,"indicates the disk is heavily damaged, backup the data and replace disk ASAP!\n  Minimum value: ",$6,"\n  Worst value:   ",$5,"\n  Current value: ",$4 }'
	echo
        smartctl -A $disk | grep 0x00 | awk '{ if ($5<$6 && $4>$6) print "The disk seems fine now, but the",$2,"had problems before. If it is connected with temperature, try to provide better cooling for the disk.\n  Minimum value: ",$6,"\n  Worst value:   ",$5,"\n  Current value: ",$4 }'
	echo
	echo
done

