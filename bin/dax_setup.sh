#!/bin/bash

sudo umount /mnt/pmem /dev/pmem*

sudo ndctl disable-region all
sudo ndctl zero-labels all
sudo ndctl enable-region all

for n in $(seq -s ' ' 0 4); do
	sudo ndctl destroy-namespace namespace${n}.0 --force
done

[ "$1" == "del" ] && exit 0

if [ "$1" == "1" ]; then
	sudo ndctl create-namespace -f -e namespace0.0 -m dax -a 4096
	sudo chmod 777 /dev/dax*

	# o+r resources
	sudo chmod o+r /sys/bus/nd/devices/ndbus*/region*/resource
	sudo chmod o+r /sys/bus/nd/devices/ndbus*/region*/dax*/resource

	ls -al /dev/dax0.0

	exit 0
fi

if [ "$4" == "" ]; then
	sudo ndctl create-namespace -m dax -e namespace1.0 -f -a 4K
	sudo ndctl create-namespace -m dax -e namespace2.0 -f -a 4K
	sudo ndctl create-namespace -m dax -e namespace3.0 -f -a 2M
	sudo ndctl create-namespace -m dax -e namespace4.0 -f -a 2M
else
	sudo ndctl create-namespace -m dax -e namespace1.0 -f -a $1
	sudo ndctl create-namespace -m dax -e namespace2.0 -f -a $2
	sudo ndctl create-namespace -m dax -e namespace3.0 -f -a $3
	sudo ndctl create-namespace -m dax -e namespace4.0 -f -a $4
fi

sudo chmod 777 /dev/dax*

sudo ndctl create-namespace -f -e namespace0.0 -m memory -a 4096
echo y | sudo mkfs.ext4 /dev/pmem0
sudo mount -o dax /dev/pmem0 /mnt/pmem
sudo chmod 777 /mnt/pmem

# o+r resources
sudo chmod o+r /sys/bus/nd/devices/ndbus*/region*/resource
sudo chmod o+r /sys/bus/nd/devices/ndbus*/region*/dax*/resource
