#!/bin/bash

source `dirname $0`/functions.sh

case "$1" in
    show)
	shift
        show_devices $@
        ;;
    
    status)
        dev_status
	;;
    
    delete)
        dev_delete
        ;;
    
    rescan)
	rescan_bus
        ;;

    *)
        echo $"Usage: $0 {show|status|delete|rescan}"
        exit 1
esac
