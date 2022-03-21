#!/bin/bash

# USAGE:./crush-map-set <outfilename>

if [ -z ${1} ];
then
    echo "USAGE: ./crush-map-set <outfilename>"
exit 1
fi
crushtool -c ./${1}.txt -o ./${1}_new.bin
ceph osd setcrushmap -i ./${1}_new.bin
