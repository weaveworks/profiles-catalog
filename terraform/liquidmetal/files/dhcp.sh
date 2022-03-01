#!/bin/bash

apt update
apt install -y isc-dhcp-server

mv /etc/dhcp/dhcpd.conf{,.backup}
cat <<EOF >/etc/dhcp/dhcpd.conf
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 192.168.1.0 netmask 255.255.255.128 {
  range 192.168.1.26 192.168.1.126;
  option routers 192.168.1.2;
  option domain-name-servers 147.75.207.207, 147.75.207.208;
}
EOF

sed -i "s/INTERFACESv4.*/INTERFACESv4=\"bond0.$VLAN_ID\"/g" /etc/default/isc-dhcp-server

systemctl restart isc-dhcp-server.service
