prog="scsictl"

function show_devices()
{
    case "$1" in
	host)
            # show only one host specified in argument 2
            if [ "$2" != "" ]; then
                show_scsi_host $2 $3 $4
	    else
		echo "$prog: usage: $prog show host [hostNN] [target|all]"
		exit
	    fi
            ;;

	all)
	    # show all hosts with all targets
	    show_all_scsi_hosts all $2
	    ;;

	hosts)
	    # simply list all hosts
	    show_all_scsi_hosts
	    ;;

	*)
	    echo "$prog: usage: $prog show [all|hosts|host]"
	    exit
	    ;;
    esac
}


function show_all_scsi_hosts()
{
    # glob thru the scsi hosts found in sysfs, identified as /class/scsi_host/hostNN where NN host#
    for hostpath in /sys/class/scsi_host/host[0-9]*/; do
        local host=`basename $hostpath`
        show_scsi_host $host $1 $2
	printf "\n"
    done
}


function show_scsi_host()
{
    local host=$1
    local hostpath=/sys/class/scsi_host/$host

    # check existence of host path in sysfs
    if [ ! -d $hostpath ]; then
	echo "$prog: SCSI host $host not found in sysfs path $hostpath"
	exit
    fi

    # get basic SCSI host info
    local state=$(<$hostpath/state)
    local proc_name=$(<$hostpath/proc_name)
    local supported_mode=$(<$hostpath/supported_mode)
    local active_mode=$(<$hostpath/active_mode)

    printf "Host Interface: $host [state: $state, name: $proc_name, modes: $active_mode/$supported_mode (active/supported)]\n"

    # more detailed info per host (still SCSI generic)
    local host_busy=$(<$hostpath/host_busy)
    local sg_tablesize=$(<$hostpath/sg_tablesize)

    printf "\tSCSI Host Busy: "
    ( ((host_busy)) && echo yes ) || ( ((!host_busy)) && echo no )

    printf "\tSCSI Scatter/Gather Table Size: $sg_tablesize\n"

    local target=$2

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
    local host=$1
    local target=$2

    # we use the SCSI host path from sysfs, and check
    local hostpath=/sys/class/scsi_host/$host

    if [ ! -d $hostpath ]; then
	echo "$prog: SCSI host path not found in sysfs"
	exit
    fi

    # we get SRP speficic attributes from the sysfs path
    local local_ib_device=$(<$hostpath/local_ib_device)
    local local_ib_port=$(<$hostpath/local_ib_port)

    local sgid=$(<$hostpath/sgid)
    local dgid=$(<$hostpath/dgid)

    local service_id=$(<$hostpath/service_id)
    local pkey=$(<$hostpath/pkey)
    local tl_retry_count=$(<$hostpath/tl_retry_count)
    
    printf "\n\tSRP InfiniBand Device: $local_ib_device (Port $local_ib_port)\n"
    printf "\tSRP Local Port GID: $sgid\n"
    printf "\tSRP Remote Port GID: $dgid\n"
    printf "\tSRP Target Node GUID: $service_id\n"
    printf "\tSRP InfiniBand Partition Key: $pkey\n"
    printf "\tSRP Transport Layer Retry count: $tl_retry_count\n"

    if [ "$target" == "all" ]; then
	# glob thru scsi targets in srp host path host/device/targetX:Y:Z where X host#, Y bus#, Z target#
	for targetpath in $hostpath/device/target[0-9]*:[0-9]*:[0-9]*/; do
	    show_scsi_target $targetpath "\t"
	done
    elif [ "$target" != "" ]; then
	targetpath="$hostpath/device/target$target"
	show_scsi_target $targetpath "\t"
    fi
}


function show_scsi_target()
{
    local targetpath=$1
    local prepend=$2

    # verify existence of sysfs path for target
    if [ ! -d $targetpath ]; then
	echo "$prog: SCSI target path $targetpath not found in sysfs"
	exit
    fi

    local target=`basename $targetpath`
    printf "\n$prepend""SCSI Target $target\n"

    # glob thru scsi devices in target path target/X:Y:Z:N, where X,Y,Z as before, N lun#
    for devicepath in $targetpath/[0-9]*:[0-9]*:[0-9]*:[0-9]*/; do
        local device=`basename $devicepath`
        local lun=`echo $device|awk -F: '{print $4}'`

	show_scsi_lun $devicepath "$prepend\t"
    done
}


function show_scsi_lun()
{
    local devicepath=$1
    local prepend=$2

    if [ ! -d $devicepath ]; then
	echo "$prog: SCSI device path $devicepath not found in sysfs"
	exit
    fi

    local state=$(<$devicepath/state)
    local vendor=$(<$devicepath/vendor)
    local model=$(<$devicepath/model)
    local queue_depth=$(<$devicepath/queue_depth)

    if [ -d $devicepath/block ]; then
	local blockdev=`ls $devicepath/block/`
	local blockdev_majmin=$(<$devicepath/block/$blockdev/dev)
    else
	local blockdev="N/A"
	local blockdev_majmin="N/A"
    fi

    printf "\n"
    printf "$prepend""LUN $lun [ID $device]\n"
    printf "$prepend""\tVendor: '$vendor'\n"
    printf "$prepend""\tModel: '$model'\n"
    printf "$prepend""\tQueue Depth: $queue_depth [state: $state]\n"
    printf "$prepend""\tBlock Device: $blockdev [$blockdev_majmin]\n"
}


function show_sas_host()
{
    local host=$1
    local target=$2

    local hostpath=/sys/class/scsi_host/$host

    if [ ! -d $hostpath ]; then
	echo "$prog: host path $hostpath not found in sysfs"
	exit
    fi
    
    # identify SAS host device
    local board_name=$(<$hostpath/board_name)
    local version_product=$(<$hostpath/version_product)
    local version_fw=$(<$hostpath/version_fw)

    # read SAS host properties
    local host_sas_address=$(<$hostpath/host_sas_address)

    printf "\n\tSAS Host Identification: '$board_name' [product: '$version_product', firmware: $version_fw]\n"
    printf "\tSAS Host Address: $host_sas_address\n"
    printf "\n\tSAS Fabric:\n\n"

    local devpath="$hostpath/device"

    printf "\tHost at SAS Address $host_sas_address\n"
    show_sas_node $devpath "\t\t"
}


function show_sas_node()
{
    local devpath=$1
    local prepend=$2

    if [ ! -d $devpath ]; then
	echo "show_sas_node() - device path $devpath not found"
	exit
    fi

    local devname=`basename $devpath`

    # check if we are a SAS expander
    if [ -d $devpath/sas_expander/$devname ]; then
	local product_id=$(<$devpath/sas_expander/$devname/product_id)
	local product_rev=$(<$devpath/sas_expander/$devname/product_rev)
	
	printf "\n$prepend""SAS Expander $devname [product: '$product_id', revision: $product_rev]\n"
	prepend="$prepend""\t"
    fi

    # glob thru SAS PHY interfaces available
    for phypath in $devpath/phy-*; do
	local phy=`basename $phypath`
	local phy_devpath="$devpath/$phy/sas_phy/$phy"

	local sas_address=$(<$phy_devpath/sas_address)
	local maximum_linkrate=$(<$phy_devpath/maximum_linkrate)
	local minimum_linkrate=$(<$phy_devpath/minimum_linkrate)
	local negotiated_linkrate=$(<$phy_devpath/negotiated_linkrate)

	printf "$prepend""PHY $phy at SAS Address $sas_address "
	printf "[link rates: $minimum_linkrate/$maximum_linkrate (min/max), negotiation status: $negotiated_linkrate]\n"
    done

    # glob thru SAS active ports
     for portpath in $devpath/port-*; do
	 local port=`basename $portpath`
	 local port_devpath="$devpath/$port/sas_port/$port"

	 local num_phys=$(<$port_devpath/num_phys)

	 printf "\n$prepend""Port $port [PHY count: $num_phys]\n"
	 printf "$prepend\t""Assigned PHYs:"

	 # glob thru SAS PHYs attached to this port
	 for phypath in $portpath/phy-*; do 
	     local phy=`basename $phypath`
	     printf " $phy"
	 done
	 printf "\n"
	
	 # if we have end devices at this node
	 if [ -d $portpath/end_device-* ]; then
	     # glob thru SAS end devices found from this port
	     for enddevpath in $portpath/end_device-*; do 
		 local enddev=`basename $enddevpath`
		 local enddev_devpath="$enddevpath/sas_device/$enddev"

		 local sas_address=$(<$enddev_devpath/sas_address)
		 local device_type=$(<$enddev_devpath/device_type)
		 local enclosure_identifier=$(<$enddev_devpath/enclosure_identifier)
		 local bay_identifier=$(<$enddev_devpath/bay_identifier)
		 local initiator_port_protocols=$(<$enddev_devpath/initiator_port_protocols)
		 local target_port_protocols=$(<$enddev_devpath/target_port_protocols)

		 printf "\n"
		 printf "$prepend\t""Device $enddev at SAS Address $sas_address\n"
		 printf "$prepend\t\t""Device Type: $device_type\n"
		 printf "$prepend\t\t""Initiator Port Protocols: $initiator_port_protocols\n"
		 printf "$prepend\t\t""Target Port Protocols: $target_port_protocols\n"

		 [ "$enclosure_identifier" != "" ] && printf "$prepend\t\t""Enclosure ID: $enclosure_identifier\n"
		 [ "$bay_identifier" != "" ] && printf "$prepend\t\t""Bay ID: $bay_identifier\n"
		 
		 # if the device has SCSI targets
		 if [ -d $enddevpath/target[0-9]*:[0-9]*:[0-9]* ]; then
		     # glob thru SCSI targets found in this end device
		     for targetpath in $enddevpath/target[0-9]*:[0-9]*:[0-9]*; do 
			 show_scsi_target $targetpath "$prepend\t\t"
		     done
		 fi
	     done
	 fi

	 # if we have SAS expanders, recurse into them
	 if [ -d $portpath/expander-* ]; then
	     # glob thru the SAS expanders in this port
	     for expanderpath in $portpath/expander-*; do
		 show_sas_node $expanderpath "$prepend\t\t"
	     done
	 fi
     done
}


function show_fc_host()
{
    return
}
