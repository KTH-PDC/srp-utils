prog="scsictl"

function show_devices()
{
    case "$1" in
	host)
            # show only one host specified in argument 2
            if [ "$2" != "" ]; then
                show_scsi_host $2 $3 $4
	    else
		echo "$prog: usage: $prog show host [host] [target] [verbose]"
		exit
	    fi
            ;;

	all)
	    # show all hosts with all targets
	    show_all_scsi_hosts all $2
	    ;;

	*)
	    # simply list all hosts
	    show_all_scsi_hosts
	    ;;
    esac
}


function show_all_scsi_hosts()
{
    # glob thru the scsi hosts found in sysfs, identified as /class/scsi_host/hostNN where NN host#
    for hostpath in /sys/class/scsi_host/host[0-9]*/; do
        host=`basename $hostpath`
        show_scsi_host $host $1 $2
    done
}


function show_scsi_host()
{
    host=$1
    hostpath=/sys/class/scsi_host/$host

    # check existence of host path in sysfs
    if [ ! -d $hostpath ]; then
	echo "$prog: SCSI host $host not found in sysfs path $hostpath"
	exit
    fi
    
    # get basic scsi host info
    state=`cat $hostpath/state`
    proc_name=`cat $hostpath/proc_name`
    supported_mode=`cat $hostpath/supported_mode`
    active_mode=`cat $hostpath/active_mode`

    printf "SCSI host: $host [state: $state, name: $proc_name, modes: $active_mode/$supported_mode (active/supported)]\n"

    # more detailed info per host
    cmd_per_lun=`cat $hostpath/cmd_per_lun`
    host_busy=`cat $hostpath/host_busy`

    printf "\tSCSI Commands per LUN (Queue Depth): $cmd_per_lun\n"
    printf "\tSCSI Host Busy: "
    ( ((host_busy)) && echo yes ) || ( ((!host_busy)) && echo no )

    target=$2

    # detect SCSI subsystem type and act accordingly
    if [ -d $hostpath/device/srp_host ]; then
	printf "\tSCSI Subsystem Type: SRP (SCSI RDMA Protocol)\n"
        show_srp_host $host $target
    elif [ -d $hostpath/device/sas_host ]; then
	printf "\tSCSI Subsystem Type: SAS (Serial Attached SCSI)\n"
	show_sas_host $host $target
    elif [ -d $hostpath/device/fc_host ]; then
	printf "\tSCSI Subsystem type: FC (Fibre Channel)\n"
	show_fc_host $host $target
    fi
}


function show_srp_host()
{
    host=$1
    target=$2
    
    hostpath=/sys/class/srp_host/$host
    
    if [ ! -d $hostpath ]; then
	echo "$prog: SCSI host path not found in sysfs"
	exit
    fi

    if [ "$target" == "all" ]; then
	# glob thru scsi targets in srp host path host/device/targetX:Y:Z where X host#, Y bus#, Z target#
	for targetpath in $hostpath/device/target[0-9]*:[0-9]*:[0-9]*/; do
            target=`basename $targetpath`
            printf "\t\tSCSI target $target\n"
	    show_srp_target $targetpath
	done
    elif [ "$target" != "" ]; then
	targetpath="$hostpath/device/target$target"
	show_srp_target $targetpath
    fi
}


function show_srp_target()
{
    targetpath=$1
    
    # verify existence of sysfs path for target
    if [ ! -d $targetpath ]; then
	echo "$prog: SCSI target path $targetpath not found in sysfs"
	exit
    fi

    # glob thru scsi devices in target path target/X:Y:Z:N, where X,Y,Z as before, N lun#
    for devicepath in $targetpath/[0-9]*:[0-9]*:[0-9]:[0-9]*/; do
        device=`basename $devicepath`
        lun=`echo $device|awk -F: '{print $4}'`
        printf "\t\t\tLUN $lun (device $device)\n"
    done
}

function show_srp_lun()
{
    return
}


function show_sas_host()
{
    return
}


function show_fc_host()
{
    return
}
