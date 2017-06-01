#!/bin/bash

# define ALUA device group name
ALUA_DEVGROUP="esos"

# define IB SRP target ports to map LUN's 
TARGETS=""

# define host groups to attach LUN's to
HOST_GROUPS=""

# define SCST device attributes
NUM_THREADS=4

# set LUN counter to zero, we map devices to corresponding LUN's of targets
scst_lun=0


println() {
    printf "\e[1m$1\e[0m\n"
}

hostpaths="/sys/class/sas_host/host"

for i in {0..1023}; do
    hostpath=$hostpaths$i
    
    if [ ! -d $hostpath ]; then
	      continue;
    fi
    
    host=`basename $hostpath`
    println "Found SAS host at SCSI host $i ($host)\n"
    
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
			                  println "Found SAS LUN $lun at SAS host $host port $port end device $end_dev target $target"
			                  
			                  devpath="$lunpath/block/sd[a-z]*"
			                  if [ -d $devpath ]; then
			                      dev=`basename $devpath`
			                      
			                      dev_id=`/usr/lib/udev/scsi_id -g /dev/$dev`
			                      dev_name="scsi-$dev_id"
			                      dev_by_id="/dev/disk/by-id/$dev_name"
			                      dev_sd=/dev/$dev			    
                            
			                      if [ -e "$dev_by_id" ]; then
                                println "Found attached block device $dev with SCSI ID $dev_id [using persistent path: $dev_by_id]"
                            else
				                        dev_by_id=$dev_sd
                                println "Found attached block device $dev with SCSI ID $dev_id [WARNING: using non-persistent path: $dev_by_id]"
			                      fi

				                    println "Mapping device $dev_by_id to SCST device $dev_name"
				                    
				                    scstadmin -open_dev $dev_name -handler vdisk_blockio -attributes filename=$dev_by_id
				                    scstadmin -set_dev_attr $dev_name -attributes threads_pool_type=per_initiator,threads_num=$NUM_THREADS
				                    scstadmin -add_dgrp_dev $dev_name -dev_group $ALUA_DEVGROUP
				                    
				                    for srp_target in $TARGETS; do
				                        for host_group in $HOST_GROUPS; do 
					                          println "Mapping SCST device $dev_name to LUN $scst_lun at SRP target $srp_target host group $host_group"
					                          
					                          scstadmin -add_lun $scst_lun -driver ib_srpt -target $srp_target -group $host_group -device $dev_name
				                        done	
				                    done
				                    
				                    ((scst_lun++))
			                  fi
		                fi
		            done
	          fi
	      done
    done
done
