#!/bin/bash

# USAGE:./rbd-rm <pool>

if [ -z ${1} ];
then
    echo "USAGE: ./rbd-loc <pool> <image>"
exit 1
fi

images=$(rbd ls -p kube|grep -vE "csi-vol-5eb7363b-8a48-11ec-a72f-7aea63104423|csi-vol-0965742a-8a58-11ec-a72f-7aea63104423|csi-vol-96a24701-8ae4-11ec-a72f-7aea63104423|csi-vol-eb2f03ec-92c7-11ec-9926-3ed66ed83941|csi-vol-04969bc4-953d-11ec-9926-3ed66ed83941|csi-vol-d9611099-9547-11ec-9926-3ed66ed83941|csi-vol-117792e5-7e94-11ec-a72f-7aea63104423|csi-vol-f3d1c5c9-7e93-11ec-a72f-7aea63104423|csi-vol-ff32acf4-7e93-11ec-a72f-7aea63104423|csi-vol-28f134b2-7e94-11ec-a72f-7aea63104423|csi-vol-28f2a70c-7e94-11ec-a72f-7aea63104423")
for i in $images
do
    rbd remove kube/${i}
done
