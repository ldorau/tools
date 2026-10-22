#!/bin/bash

path_to_me=`dirname $0`

echo "Resize all disks connected to the Intel RAID SATA controller"
if [ $# != 1 ]; then
        echo "Usage: $0 [size]"
        echo "  [size] size in GB, will be set for all disks connected to the Intel RAID controller"
        exit 1
fi
#get Intel RAID controller
paths=( /sys/bus/pci/drivers/isci /sys/bus/pci/drivers/ahci )
uniq_ids=[]
j=0
for path in ${paths[*]}
do
    links=`ls $path | grep 0000:`
    for link in ${links[*]}
    do
        vendor_id=`cat $path/$link/vendor`
        if [ "$vendor_id" = "0x8086" ]
        then
            uniq_ids[$j]=$link
            j=$(($j+1))
        fi
    done
done

for id in ${uniq_ids[*]}
do
    for file in `ls /dev/disk/by-path/pci-$id*`
    do
        dev_name=`readlink -f $file`
        # experimental - do not change cd-rom :)
        is_disk=`ls -la $dev_name | grep -Eo "*disk*"`
        if [ "$is_disk" != "disk" ]
        then
        	continue
        fi
        dev_sn=`dmraid -b | grep $dev_name | awk '{print $4}' | cut -d"\"" -f2`
        echo "resizing $dev_name, sn = $dev_sn with size $1 GB..."
        $path_to_me/resize.sh -s $1 -d $dev_name
    done
done
