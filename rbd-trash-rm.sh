#!/bin/bash

# USAGE:./rbd-rm <pool>

if [ -z ${1} ];
then
    echo "USAGE: ./rbd-loc <pool>"
exit 1
fi
images=$(rbd trash list -p ${1}|awk '{print $1}')
for i in $images
do
    rbd trash remove ${i} -p ${1} --force
done
