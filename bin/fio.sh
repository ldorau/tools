#!/bin/bash
DISKS=$(for i in `cat /proc/partitions |grep -v sdgj$|grep -v sdgj[0-9]|grep sd|awk '{print $4}'`;do echo -n " --name=$i --filename=/dev/$i";done) 
fio --rw=read --time_based --ioengine=sync   -bsrange=512k-4m --runtime=$1 $DISKS 2>&1> fio.log


