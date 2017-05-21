prog="scsictl"

function srp_action()
{
    case "$1" in
	hosts)
	    shift
	    srp_report_hosts $@
	    ;;
	
	discover)
	    shift
	    srp_discover_targets $@
	    ;;
	
	targetlogin)
	    shift
	    srp_target_login $@
	    ;;
	
	*)
	    echo "$prog: usage: $prog srp [hosts|discover|targetlogin]"
	    exit
	    ;;
    esac
}


function srp_report_hosts()
{
    local srpif=$1

    if [ "$srpif" == "" ]; then
	echo "$prog: usage: $prog srp hosts [interface]"
	exit
    fi

    local srpifpath="/sys/class/infiniband_srp/$srpif"
    
    if [ -d $srpifpath ]; then
	local hosts=$(srp_node_hosts $srpifpath)
	echo $hosts
    fi
}


function show_action()
{
    case "$1" in
	host)
	    shift
	    show_host $@
            ;;

	srp)
	    shift
	    show_srp $@
	    ;;
	
	*)
	    echo "$prog: usage: $prog show [host|srp]"
	    exit
	    ;;
    esac
}


function show_host()
{
    case "$1" in
	all)
	    show_all_scsi_hosts $2
	    ;;
	
	*)
	    if [ "$1" != "" ]; then
		if [[ "$1" =~ ^host[0-9]*$ ]]; then
		    show_scsi_host $1 $2
		else
		    show_scsi_host "host$1" $2
		fi
	    else
		echo "$prog: usage $prog show host [host ID|all] [detail|topology]"
		exit
	    fi
	    ;;
    esac
}


function show_srp()
{
    case "$1" in
	all)
	    show_all_srp_if $2
	    ;;
	
	*)
	    if [ "$1" != "" ]; then
		show_srp_if $1 $2
	    else
		echo "$prog: usage show srp [node ID|all] [detail]"
		exit
	    fi
	    ;;
    esac
}


function show_all_scsi_hosts()
{
    # glob thru the scsi hosts found in sysfs, identified as /class/scsi_host/hostNN where NN host#
    local hostpaths="/sys/class/scsi_host/host[0-9]*"

    for hostpath in $hostpaths; do
	if [ -d $hostpath ]; then
            local host=`basename $hostpath`
            show_scsi_host $host $1
	fi
    done
}


function show_scsi_host()
{
    local host=$1
    local mode=$2

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

    printf "Host Interface: $host "
    printf "[state: $state, name: $proc_name, modes: $active_mode/$supported_mode (active/supported)]\n"

    if [ "$mode" == "detail" ] || [ "$mode" == "topology" ]; then
	# more detailed info per host (still SCSI generic)
	local host_busy=$(<$hostpath/host_busy)
	local sg_tablesize=$(<$hostpath/sg_tablesize)
	
	printf "\tSCSI Host Busy: "
	( ((host_busy)) && echo yes ) || ( ((!host_busy)) && echo no )
	
	printf "\tSCSI Scatter/Gather Table Size: $sg_tablesize\n"
	
	# detect SCSI subsystem type and act accordingly
	if [ -d $hostpath/device/srp_host ]; then
	    printf "\tSCSI Subsystem Type: SRP (SCSI RDMA Protocol)\n"
            show_srp_host $host $mode
	elif [ -d $hostpath/device/sas_host ]; then
	    printf "\tSCSI Subsystem Type: SAS (Serial Attached SCSI)\n"
	    show_sas_host $host $mode
	elif [ -d $hostpath/device/fc_host ]; then
	    printf "\tSCSI Subsystem type: FC (Fibre Channel)\n"
	    show_fc_host $host $mode
	fi

	printf "\n"
    fi
}


function show_srp_host()
{
    local host=$1
    local mode=$2

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

    if [ "$mode" == "topology" ]; then
	# glob thru scsi targets in srp host path host/device/targetX:Y:Z where X host#, Y bus#, Z target#
	local targetpaths="$hostpath/device/target[0-9]*:[0-9]*:[0-9]*"

	for targetpath in $targetpaths; do
	    if [ -d $targetpath ]; then
		show_scsi_target $targetpath "\t"
	    fi
	done
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
    local devicepaths="$targetpath/[0-9]*:[0-9]*:[0-9]*:[0-9]*"

    for devicepath in $devicepaths; do
	if [ -d $devicepath ]; then
	    show_scsi_lun $devicepath "$prepend\t"
	fi
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

    local device=`basename $devicepath`
    local lun=`echo $device|awk -F: '{print $4}'`

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
    local mode=$2

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

    if [ "$mode" == "topology" ]; then
	printf "\n\tSAS Fabric:\n\n"
	printf "\tHost at SAS Address $host_sas_address\n"
	
	local devpath="$hostpath/device"
	show_sas_node $devpath "\t\t"
    fi
}


function show_sas_node()
{
    local devpath=$1
    local prepend=$2

    if [ ! -d $devpath ]; then
	echo "$prog: device path $devpath not found"
	exit
    fi

    local devname=`basename $devpath`

    # check if we are a SAS expander
    local expanderpath="$devpath/sas_expander/$devname"
    
    if [ -d $expanderpath ]; then
	local product_id=$(<$expanderpath/product_id)
	local product_rev=$(<$expanderpath/product_rev)
	
	printf "\n$prepend""SAS Expander $devname [product: '$product_id', revision: $product_rev]\n"
	prepend="$prepend""\t"
    fi
    
    # glob thru SAS PHY interfaces available
    local phypaths="$devpath/phy-*"

    for phypath in $phypaths; do
	if [ -d $phypath ]; then
	    local phy=`basename $phypath`
	    local phy_devpath="$devpath/$phy/sas_phy/$phy"
	
	    local sas_address=$(<$phy_devpath/sas_address)
	    local maximum_linkrate=$(<$phy_devpath/maximum_linkrate)
	    local minimum_linkrate=$(<$phy_devpath/minimum_linkrate)
	    local negotiated_linkrate=$(<$phy_devpath/negotiated_linkrate)
	    
	    printf "$prepend""PHY $phy at SAS Address $sas_address "
	    printf "[link rates: $minimum_linkrate/$maximum_linkrate (min/max), negotiation status: $negotiated_linkrate]\n"
	fi
    done

    # glob thru SAS active ports
    local portpaths="$devpath/port-*"
    
    for portpath in $portpaths; do
	if [ -d $portpath ]; then
	    local port=`basename $portpath`
	    local port_devpath="$devpath/$port/sas_port/$port"
	    
	    local num_phys=$(<$port_devpath/num_phys)
	    
	    printf "\n$prepend""Port $port [PHY count: $num_phys]\n"
	    printf "$prepend\t""Assigned PHY(s):"
	    
	    # glob thru SAS PHYs attached to this port
	    local phypaths="$portpath/phy-*"
	    
	    for phypath in $phypaths; do
		if [ -d $phypath ]; then
		    local phy=`basename $phypath`
		    printf " $phy"
		fi
	    done
	    printf "\n"
	    
	    # glob thru end devices at this node, if present
	    local enddevpaths="$portpath/end_device-*"
	    
	    for enddevpath in $enddevpaths; do
		if [ -d $enddevpath ]; then
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
		    
		    # glob thru SCSI targets found in this end device
		    local enddev_targets="$enddevpath/target[0-9]*:[0-9]*:[0-9]*"
		    
		    for enddev_target in $enddev_targets; do
			if [ -d $enddev_target ]; then
			    show_scsi_target $enddev_target "$prepend\t\t"
			fi
		    done
		fi
	    done
	    
	    # glob thru the SAS expanders in this port
	    local sasexpanders="$portpath/expander-*"
	    
	    for expanderpath in $sasexpanders; do
		if [ -d $expanderpath ]; then
		    show_sas_node $expanderpath "$prepend\t\t"
		fi
	    done
	fi
    done

    # glob thru SCSI targets found in this node
    local targetpaths="$devpath/target[0-9]*:[0-9]*:[0-9]*"
    
    for targetpath in $targetpaths; do
	if [ -d $targetpath ]; then
	    show_scsi_target $targetpath "$prepend"
	    printf "\n"
	fi
    done
}


function show_fc_host()
{
    return
}


function show_all_srp_if()
{
    # glob thru all the SRP paths 
    local srpnodes="/sys/class/infiniband_srp/*"

    for srpnodepath in $srpnodes; do
	if [ -d $srpnodepath ]; then
	    local srpnode=`basename $srpnodepath`
	    show_srp $srpnode $1
	fi
    done
}


function show_srp_if()
{
    local srpnode=$1
    local mode=$2

    # SRP i/f name from the sysfs path
    local srpnodepath="/sys/class/infiniband_srp/$srpnode"

    # check existence
    if [ ! -d $srpnodepath ]; then
	echo "$prog: SRP node not found at sysfs path $srpnodepath"
	exit
    fi

    # get associated InfiniBand HCA and port
    local ibdev=$(<$srpnodepath/ibdev)
    local port=$(<$srpnodepath/port)

    printf "InfiniBand SRP Interface: $srpnode [device $ibdev, port $port]\n"

    if [ "$mode" == "detail" ]; then
	# construct sysfs path to InfiniBand HCA device
	local ibdevpath=$srpnodepath/device/infiniband/$ibdev

	# if we can access the HCA device, query some attributes
	if [ -d $ibdevpath ]; then
	    local fw_ver=$(<$ibdevpath/fw_ver)
	    local hca_type=$(<$ibdevpath/hca_type)
	    local node_desc=$(<$ibdevpath/node_desc)
	    local hw_rev=$(<$ibdevpath/hw_rev)
	    local node_type=$(<$ibdevpath/node_type)
	    local node_guid=$(<$ibdevpath/node_guid)
	    local sys_image_guid=$(<$ibdevpath/sys_image_guid)

	    printf "\tHCA Type: $hca_type [hw revision: $hw_rev, firmware: $fw_ver]\n"
	    printf "\tNode Type: '$node_type' [description: '$node_desc']\n"
	    printf "\tNode GUID: $node_guid\n"
	    printf "\tSystem Image GUID: $sys_image_guid\n"
	else
	    printf "ERROR: InfiniBand HCA Device $ibdev not found in sysfs path $ibdevpath\n"
	fi

	# get NUMA node# for the PCI device
	local numa_node=$(<$srpnodepath/device/numa_node)
	printf "\tNUMA Node: $numa_node\n\n"

	# get SCSI host interfaces for this SRP interface
	local srphosts=$(srp_node_hosts $srpnodepath)
	printf "\tSRP SCSI Hosts: $srphosts\n\n"
    fi
}


function srp_node_hosts()
{
    local srpnodepath=$1

    local ibdev=$(<$srpnodepath/ibdev)
    local port=$(<$srpnodepath/port)

    local -a hosts=()
    local hostcount=0

    # define glob for srp host paths in sysfs
    local srphosts="/sys/class/srp_host/host[0-9]*"

    # glob thru SRP hosts
    for srphost in $srphosts; do
	if [ -d $srphost ]; then
	    host=`basename $srphost`
	    scsihost="/sys/class/scsi_host/$host"
 
	    if [ -d $scsihost ]; then
		local_ib_device=$(<$scsihost/local_ib_device)
		local_ib_port=$(<$scsihost/local_ib_port)

		if [ "$local_ib_device" == "$ibdev" ] && [ "$local_ib_port" == "$port" ]; then
		    hosts[$hostcount]=$host
		    ((hostcount++))
		fi
	    fi
	fi
    done

    printf "${hosts[*]}"
}
