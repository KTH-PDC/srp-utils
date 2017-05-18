#!/bin/bash

TARGETS="fe80:0000:0000:0000:0002:c903:0002:b417 fe80:0000:0000:0000:0002:c903:0002:b418"
INITIATORS="fe80:0000:0000:0000:0002:c903:0002:b24f fe80:0000:0000:0000:0002:c903:0002:b250"
ALUA_DEVGROUP="esos"
HOST_GROUP="zfs-hosts"
NUM_THREADS=4

lun=0

for hostdir in /sys/class/sas_host/*; do
	host=`basename $hostdir`
	for portdir in $hostdir/device/port-*; do
		port=`basename $portdir`
		for end_devdir in $portdir/end_device-*; do 
			end_dev=`basename $end_devdir`
			for targetdir in $end_devdir/target*; do
				target=`basename $targetdir`
				for devdir in $targetdir/*/block/*; do 
					dev=`basename $devdir`
					printf "found device $dev at host $host port $port end device $end_dev target $target\n"
					scst_device=`hostname -s`-$target
					echo "mapping device $dev to SCST device $scst_device"
					scstadmin -open_dev $scst_device -handler vdisk_blockio -attributes filename=/dev/$dev
					scstadmin -set_dev_attr $scst_device -attributes threads_pool_type=per_initiator,threads_num=$NUM_THREADS
					scstadmin -add_dgrp_dev $scst_device -dev_group $ALUA_DEVGROUP
					for srp_target in $TARGETS; do
						printf "mapping SCST device $scst_device to LUN $lun in SRP target $srp_target\n"
						scstadmin -add_lun $lun -driver ib_srpt -target $srp_target -group $HOST_GROUP -device $scst_device
					done
					((lun++))
				done
			done
		done
	done
done
