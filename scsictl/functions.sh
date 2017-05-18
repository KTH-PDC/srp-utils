prog="scsictl"

function list_devices()
{
    case "$1" in
	host)
            # list only one host specified in argument 2    
            if [ "$2" != "" ]; then
                list_scsi_host $2 $3 $4
	    else
		echo "$prog: usage: $prog list host [host] [target] [verbose]"
		exit
	    fi
            ;;

	all)
	    # list all hosts with all targets
	    list_all_scsi_hosts all $2
	    ;;

	*)
	    # list all hosts 
	    list_all_scsi_hosts
	    ;;
    esac
}


function list_all_scsi_hosts()
{
    # glob thru the scsi hosts found in sysfs, identified as /class/scsi_host/hostNN where NN host#
    for hostdir in /sys/class/scsi_host/host[0-9]*/; do
        host=`basename $hostdir`
        list_scsi_host $host $1 $2
    done
}


function list_scsi_host()
{
    host=$1
    hostdir=/sys/class/scsi_host/$host

    # check existence of host path in sysfs
    if [ ! -d $hostdir ]; then
	echo "$prog: SCSI host $host not found in sysfs path $hostdir"
	exit
    fi
    
    # get basic scsi host info
    state=`cat $hostdir/state`
    proc_name=`cat $hostdir/proc_name`
    supported_mode=`cat $hostdir/supported_mode`
    active_mode=`cat $hostdir/active_mode`

    printf "SCSI host: $host [state: $state, name: $proc_name, modes: $active_mode/$supported_mode (active/supported)]\n"

    # more detailed info per host
    cmd_per_lun=`cat $hostdir/cmd_per_lun`
    host_busy=`cat $hostdir/host_busy`

    printf "\tSCSI Commands per LUN (Queue Depth): $cmd_per_lun\n"
    printf "\tSCSI Host Busy: "
    ( ((host_busy)) && echo yes ) || ( ((!host_busy)) && echo no )

    target=$2

    # detect SCSI subsystem type and act accordingly
    if [ -d $hostdir/device/srp_host ]; then
	printf "\tSCSI Subsystem Type: SRP (SCSI RDMA Protocol)\n"
        list_srp_host $host $target
    elif [ -d $hostdir/device/sas_host ]; then
	printf "\tSCSI Subsystem Type: SAS (Serial Attached SCSI)\n"
	list_sas_host $host $target
    elif [ -d $hostdir/device/fc_host ]; then
	printf "\tSCSI Subsystem type: FC (Fibre Channel)\n"
	list_fc_host $host $target
    fi
}


function list_srp_host()
{
    host=$1
    target=$2
    
    hostdir=/sys/class/srp_host/$host
    
    if [ ! -d $hostdir ]; then
	echo "$prog: SCSI host path not found in sysfs"
	exit
    fi

    if [ "$target" == "all" ]; then
	# glob thru scsi targets in srp host dir host/device/targetX:Y:Z where X host#, Y bus#, Z target#                                                  
	for targetdir in $hostdir/device/target[0-9]*:[0-9]*:[0-9]*/; do
            target=`basename $targetdir`
            printf "\t\tSCSI target $target\n"
	    list_srp_target $targetdir
	done
    elif [ "$target" != "" ]; then
	targetdir="$hostdir/device/target$target"
	list_srp_target $targetdir
    fi
}


function list_srp_target()
{
    targetdir=$1
    
    # verify existence of sysfs path for target
    if [ ! -d $targetdir ]; then
	echo "$prog: SCSI target path $targetdir not found in sysfs"
	exit
    fi

    # glob thru scsi devices in target dir target/X:Y:Z:N, where X,Y,Z as before, N lun#                                                                                                                                                
    for devicedir in $targetdir/[0-9]*:[0-9]*:[0-9]:[0-9]*/; do
        device=`basename $devicedir`
        lun=`echo $device|awk -F: '{print $4}'`
        printf "\t\t\tLUN $lun (device $device)\n"
    done
}


function list_sas_host()
{
    return
}


function list_fc_host()
{
    return
}
