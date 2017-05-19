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
    
    # get basic SCSI host info
    state=$(<$hostpath/state)
    proc_name=$(<$hostpath/proc_name)
    supported_mode=$(<$hostpath/supported_mode)
    active_mode=$(<$hostpath/active_mode)

    printf "SCSI host: $host [state: $state, name: $proc_name, modes: $active_mode/$supported_mode (active/supported)]\n"

    # more detailed info per host (still SCSI generic)
    cmd_per_lun=$(<$hostpath/cmd_per_lun)
    host_busy=$(<$hostpath/host_busy)

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
    
    # we use the SCSI host path from sysfs, and check
    hostpath=/sys/class/scsi_host/$host
    
    if [ ! -d $hostpath ]; then
	echo "$prog: SCSI host path not found in sysfs"
	exit
    fi

    # we get SRP speficic attributes from the sysfs path
    local_ib_device=$(<$hostpath/local_ib_device)
    local_ib_port=$(<$hostpath/local_ib_port)

    sgid=$(<$hostpath/sgid)
    dgid=$(<$hostpath/dgid)

    service_id=$(<$hostpath/service_id)
    pkey=$(<$hostpath/pkey)

    sg_tablesize=$(<$hostpath/sg_tablesize)
    tl_retry_count=$(<$hostpath/tl_retry_count)
    
    printf "\tSRP InfiniBand Device: $local_ib_device (Port $local_ib_port)\n"
    printf "\tSRP Local Port GID: $sgid\n"
    printf "\tSRP Remote Port GID: $dgid\n"
    printf "\tSRP Target Node GUID: $service_id\n"
    printf "\tSRP InfiniBand Partition Key: $pkey\n"
    printf "\tSRP Scatter/Gather Table Size: $sg_tablesize\n"
    printf "\tSRP Transport Layer Retry count: $tl_retry_count\n"

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
        printf "\t\t\tLUN $lun [ID $device]\n"
	show_srp_lun $devicepath
    done
}

function show_scsi_lun()
{
    devicepath=$1

    if [ ! -d $devicepath ]; then
	echo "$prog: SCSI device path $devicepath not found in sysfs"
	exit
    fi

    state=$(<$devicepath/state)
    vendor=$(<$devicepath/vendor)
    model=$(<$devicepath/model)
    queue_depth=$(<$devicepath/queue_depth)

    blockdev=`ls $devicepath/block/`
    blockdev_majmin=$(<$devicepath/block/$blockdev/dev)
    
    printf "\t\t\t\tBlock Device: $blockdev [$blockdev_majmin]\n"
    printf "\t\t\t\tVendor/Model: $vendor/$model\n"
    printf "\t\t\t\tQueue Depth: $queue_depth [state: $state]\n"
    
}

function show_srp_lun()
{
    show_scsi_lun $1
}


function show_sas_host()
{
    return
}


function show_fc_host()
{
    return
}
