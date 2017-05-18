prog="scsictl"

function list_devices() {
    # glob thru the scsi hosts found in sysfs, identified as scsi_host/hostNN where NN host#
    for hostdir in /sys/class/scsi_host/host[0-9]*/; do
	host=`basename $hostdir`

	state=`cat $hostdir/state`
	proc_name=`cat $hostdir/proc_name`

	supported_mode=`cat $hostdir/supported_mode`
	active_mode=`cat $hostdir/active_mode`
	
	printf "SCSI host: $host [state: $state, name: $proc_name, modes: $active_mode/$supported_mode (active/supported)]\n"

	if [ "$1" == "verbose" ]; then
	    cmd_per_lun=`cat $hostdir/cmd_per_lun`

	    printf "\tSCSI Commands per LUN (Queue Depth): $cmd_per_lun\n"
	fi

	# detect SCSI subsystem type and act accordingly
	if [ -d $hostdir/device/srp_host ]; then 
	    printf "\tSCSI Subsystem Type: SRP (SCSI RDMA Protocol)\n"
	    list_srp_host $host
	fi
    done
}


function list_srp_host() {
    host=$1
    hostdir=/sys/class/scsi_host/$host

    # glob thru scsi targets in srp host dir host/device/targetX:Y:Z where X host#, Y bus#, Z target#                                                  
    for targetdir in $hostdir/device/target[0-9]*:[0-9]*:[0-9]*/; do
        target=`basename $targetdir`
        printf "\tSRP host $host target $target\n"
	
        # glob thru scsi devices in target dir target/X:Y:Z:N, where X,Y,Z as before, N lun#                                                           
        for devicedir in $targetdir/[0-9]*:[0-9]*:[0-9]:[0-9]*/; do
            device=`basename $devicedir`
            lun=`echo $device|awk -F: '{print $4}'`
            printf "\t\tSRP host $host target $target lun $lun (device $device)\n"
        done
    done
}


function list_scsi_target() {
    

    # glob thru scsi devices in target dir target/X:Y:Z:N, where X,Y,Z as before, N lun#                                                                                                                                                
    for devicedir in $targetdir/[0-9]*:[0-9]*:[0-9]:[0-9]*/; do
        device=`basename $devicedir`
        lun=`echo $device|awk -F: '{print $4}'`
        printf "\t\tSRP host $host target $target lun $lun (device $device)\n"
    done
}
