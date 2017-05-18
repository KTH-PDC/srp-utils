#!/bin/bash

# glob thru the srp hosts found in sysfs, identified as srp_host/hostNN where NN host# 
for srp_hostdir in /sys/class/srp_host/host[0-9]*/; do 
    host=`basename $srp_hostdir`
    printf "SRP host $host\n"

    # glob thru scsi targets in srp host dir host/device/targetX:Y:Z where X host#, Y bus#, Z target#
    for targetdir in $srp_hostdir/device/target[0-9]*:[0-9]*:[0-9]*/; do
	target=`basename $targetdir`
	printf "SRP host $host target $target\n"

	# glob thru scsi devices in target dir target/X:Y:Z:N, where X,Y,Z as before, N lun#
	for devicedir in $targetdir/[0-9]*:[0-9]*:[0-9]:[0-9]*/; do
	    device=`basename $devicedir`
	    lun=`echo $device|awk -F: '{print $4}'`
	    printf "SRP host $host target $target lun $lun (device $device)\n"
	done
    done
done
