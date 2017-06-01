#!/bin/bash

# define ESOS ALUA device group to configure
ALUA_DEVGROUP="esos"

# define SRP ALUA targets to configure
ALUA_TARGETS=""

# define ESOS SRP initiator host groups to define
HOST_GROUPS=""


println() {
    printf "\e[1m$1\e[0m\n"
}

# we start from relative target id 1
rel_tgt_id=1

println "Creating ALUA device group: $ALUA_DEVGROUP"
scstadmin -add_dgrp $ALUA_DEVGROUP

println "Creating ALUA target group: local [device group: $ALUA_DEVGROUP]"
scstadmin -add_tgrp local -dev_group $ALUA_DEVGROUP
scstadmin -set_tgrp_attr local -dev_group $ALUA_DEVGROUP -attributes group_id=1

for target in $ALUA_TARGETS; do
    println "Adding SRP target to ALUA device group $ALUA_DEVGROUP target group local: $target"
    
    scstadmin -add_tgrp_tgt $target -dev_group $ALUA_DEVGROUP -tgt_group local
    scstadmin -set_ttgt_attr $target -driver ib_srpt -dev_group $ALUA_DEVGROUP -tgt_group local -attributes rel_tgt_id=$rel_tgt_id
    
    ((rel_tgt_id++))
done

for target in $ALUA_TARGETS; do
    for host_group in $HOST_GROUPS; do
	println "Creating host group for target $target: $host_group"
	scstadmin -add_group $host_group -driver ib_srpt -target $target
    done
done

for target in $ALUA_TARGETS; do
    println "Enabling SRP target: $target"	
    scstadmin -enable_target $target -driver ib_srpt
done

println "Saving SCST configuration..."
scstadmin -write_config /etc/scst.conf

println "Synchronizing ESOS configuration..."
/usr/local/sbin/usb_sync.sh 
