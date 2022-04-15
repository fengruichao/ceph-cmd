
#!/bin/bash
if [ -z ${1} ];
then
    echo "USAGE: ./pool-rm <pool>"
exit 1
fi

ceph osd pool delete ${1} ${1} --yes-i-really-really-mean-it
