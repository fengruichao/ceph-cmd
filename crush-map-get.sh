#!/bin/bash

# USAGE:./crush-map-get <outfilename>

if [ -z ${1} ];
then
    echo "USAGE: ./crush-map-get <outfilename>"
exit 1
fi
ceph osd getcrushmap -o ./${1}.bin
crushtool -d ./${1}.bin -o ./${1}.txt
