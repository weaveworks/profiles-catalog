#!/bin/bash
# Script to sort and select a vip
#

set -eu
set -o pipefail

subnet=192.168.1.
lastAvailableIP=24
ipAvailableStartingAt=4

highest=$ipAvailableStartingAt
for cluster in $(kubectl get MicrovmCluster --output=jsonpath={.items..spec.controlPlaneEndpoint.host}); do 
    oc4=$(echo $cluster | awk -F. '{print $4}')
    echo $oc4
    if [ $oc4 -gt $highest ]
        then
            echo "$oc4 is greater than $highest"
            highest=$oc4
    fi
done
echo "Highest is $highest"
if [ $highest -gt $lastAvailableIP ]
    then
        echo "No IPs left starting over"
        highest=$ipAvailableStartingAt
        

fi
echo "IP Selected is"  $subnet$highest
echo $subnet$highest > /tmp/mvm-vip