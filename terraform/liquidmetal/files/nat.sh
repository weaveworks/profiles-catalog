#!/bin/bash

apt update
apt install -y firewalld

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i "bond0.$VLAN_ID" -o bond0 -j ACCEPT
firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -o bond0 -j MASQUERADE
firewall-cmd --reload
