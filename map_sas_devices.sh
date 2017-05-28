#!/bin/bash

# define IB SRP target ports to map LUN's 
TARGETS="fe80:0000:0000:0000:0002:c903:0002:bb1c fe80:0000:0000:0001:0002:c903:0002:bb1d"

# define ALUA device group name and host groups to attach LUN's to
ALUA_DEVGROUP="esos"
HOST_GROUPS="pdc-irods-resc-zfs-01 pdc-irods-resc-zfs-02"

# define SCST device attributes
NUM_THREADS=4

# set LUN counter to zero, we map devices to corresponding LUN's of targets
scst_lun=0

hostpaths="/sys/class/sas_host/host"

for i in {0..1023}; do
	hostpath=$hostpaths$i

	if [ ! -d $hostpath ]; then
		continue;
	fi
 
	host=`basename $hostpath`
	printf "Found SAS host at SCSI host $i ($host)\n"

	portpaths="$hostpath/device/port-$i:"

	for j in {0..127}; do
		portpath=$portpaths$j

		if [ ! -d $portpath ]; then
			break;
		fi

		port=`basename $portpath`
		end_devpath="$portpath/end_device-$i:$j"

		if [ ! -d $end_devpath ]; then
			break;
		fi

		end_dev=`basename $end_devpath`
		targetpaths="$end_devpath/target$i:[0-9]:$j"

		for targetpath in $targetpaths; do
			if [ -d $targetpath ]; then
				target=`basename $targetpath`
				lunpaths="$targetpath/$i:[0-9]:$j:[0-9]"

				for lunpath in $lunpaths; do
					if [ -d $lunpath ]; then
						lun=`basename $lunpath`
						printf "\tFound SAS LUN $lun at SAS host $host port $port end device $end_dev target $target\n"

						devpath="$lunpath/block/sd[a-z]*"
						if [ -d $devpath ]; then
							dev=`basename $devpath`

							dev_id=`/usr/lib/udev/scsi_id -g /dev/$dev`
							dev_name="scsi-$dev_id"
							dev_by_id="/dev/disk/by-id/$dev_name"

							if [ -e $dev_by_id ]; then
								printf "\t\tFound attached block device $dev with SCSI ID $dev_id [persistent path: $dev_by_id]\n"
								printf "\t\tMapping device $dev_by_id to SCST device $dev_name\n"

								scstadmin -open_dev $dev_name -handler vdisk_blockio -attributes filename=$dev_by_id
								scstadmin -set_dev_attr $dev_name -attributes threads_pool_type=per_initiator,threads_num=$NUM_THREADS
								scstadmin -add_dgrp_dev $dev_name -dev_group $ALUA_DEVGROUP

								for srp_target in $TARGETS; do
									for host_group in $HOST_GROUPS; do 
										printf "\t\t\tMapping SCST device $dev_name to LUN $scst_lun at SRP target $srp_target host group $host_group\n"

										scstadmin -add_lun $scst_lun -driver ib_srpt -target $srp_target -group $host_group -device $dev_name
									done	
								done

								((scst_lun++))
							fi
						fi
					fi
				done
			fi
		done
	done
done
