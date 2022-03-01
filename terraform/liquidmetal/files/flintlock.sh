#!/bin/bash

wget https://raw.githubusercontent.com/weaveworks/flintlock/main/hack/scripts/provision.sh
chmod +x provision.sh

./provision.sh all -y --grpc-address "0.0.0.0:9090" --parent-iface "bond0.$VLAN_ID"
