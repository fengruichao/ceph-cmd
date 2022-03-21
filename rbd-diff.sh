#!/bin/bash
if [ -z ${1} ] || [ -z ${2} ];
then
    echo "USAGE: ./rbd-diff <pool> <image>"
exit 1
fi

for varible1 in {1..100000}
#for varible1 in 1 2 3 4 5
do
     rbd diff ${1}/${2} >> ./logs/${2}-diff.txt
done
