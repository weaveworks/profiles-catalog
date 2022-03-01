#!/bin/bash

modprobe 8021q
echo "8021q" >> /etc/modules-load.d/networking.conf

ip link add link bond0 name "bond0.$VLAN_ID" type vlan id "$VLAN_ID"

ip addr add "192.168.1.$ADDR/25" dev "bond0.$VLAN_ID"

ip -d link set dev "bond0.$VLAN_ID" up

ip -d link show "bond0.$VLAN_ID"
