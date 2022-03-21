#!/bin/bash
if [ -z ${1} ] || [ -z ${2} ];
then
    echo "USAGE: ./rbd-du <pool> <image>"
exit 1
fi

rbd du ${1}/${2}
