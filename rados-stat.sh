#!/bin/bash

# USAGE:./rados-stat <pool> <image>

if [ -z ${1} ] || [ -z ${2} ];
then
    echo "USAGE: ./rados-stat <pool> <image>"
exit 1
fi

rbd_prefix=$(rbd -p ${1} info ${2} | grep block_name_prefix | awk '{print $2}')
for i in $(rados -p ${1} ls | grep ${rbd_prefix})
do
    rados stat ${i} -p ${1} 
done
