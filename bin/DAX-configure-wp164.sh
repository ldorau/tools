#!/bin/bash

set -ex

export UMF_LOG="level:debug;flush:debug;output:stderr;pid:yes"
export UMF_TESTS_DEVDAX_PATH=/dev/dax0.0
export UMF_TESTS_DEVDAX_SIZE=1054867456
export UMF_TESTS_FSDAX_PATH=/mnt/pmem1/$(whoami)-file

sudo ndctl destroy-namespace namespace0.0 --force
sudo ndctl create-namespace -e namespace0.0 --mode=devdax --align=2M --force -v
sudo chmod a+rw /dev/dax0.0
ls -al /dev/dax0.0

sudo umount /dev/pmem1 || true
echo y | sudo mkfs.ext4 /dev/pmem1
sudo mount -o dax /dev/pmem1 /mnt/pmem1
mount | grep pmem
sudo chmod -R a+rw /mnt/pmem1
touch $UMF_TESTS_FSDAX_PATH
ls -al /mnt/pmem1
