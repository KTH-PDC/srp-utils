#!/bin/bash

FILE=sun_targets

cat $FILE | while read s; do 
    hostname=$(echo $s|cut -d ' ' -f 1)
    target1=$(echo $s|cut -d ' ' -f 2|sed -e 's/://g')
    target2=$(echo $s|cut -d ' ' -f 3|sed -e 's/://g')

    target1_login=$(for umad_dev in /dev/infiniband/umad*; do ibsrpdm -c -d $umad_dev; done| grep $target1)
    target2_login=$(for umad_dev in /dev/infiniband/umad*; do ibsrpdm -c -d $umad_dev; done| grep $target2)

    echo $target1_login > /sys/class/infiniband_srp/srp-mlx4_0-1/add_target
    echo $target2_login > /sys/class/infiniband_srp/srp-mlx4_0-2/add_target
done
