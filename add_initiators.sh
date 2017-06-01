#!/bin/bash

FILE=sun_targets

cat $FILE | while read s; do 
    hostname=$(echo $s|cut -d ' ' -f 1)
    target1=$(echo $s|cut -d ' ' -f 2)
    target2=$(echo $s|cut -d ' ' -f 3)
    
    # for axen05, both fabrics (one HCA in each fabric)
    ssh -n root@$hostname "yes | scstadmin -add_init fe80:0000:0000:0000:0002:c903:004e:f7b9 -target $target1 -driver ib_srpt -group axen05 "
    ssh -n root@$hostname "yes | scstadmin -add_init fe80:0000:0000:0001:0002:c903:0051:9821 -target $target2 -driver ib_srpt -group axen05"

    # for axen06, both fabrics (one HCA in each fabric)
    ssh -n root@$hostname "yes | scstadmin -add_init fe80:0000:0000:0000:0002:c903:004e:f775 -target $target1 -driver ib_srpt -group axen06"
    ssh -n root@$hostname "yes | scstadmin -add_init fe80:0000:0000:0001:0002:c903:004e:f7c5 -target $target2 -driver ib_srpt -group axen06"
done