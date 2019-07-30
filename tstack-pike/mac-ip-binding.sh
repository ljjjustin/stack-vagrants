#!/bin/bash

for i in $(seq 1 5)
do
    ip_postfix=$((110+i))
    virsh net-update vagrant-libvirt add ip-dhcp-host "<host mac='52:54:56:00:01:0${i}' ip='192.168.121.${ip_postfix}'/>" --live --config --parent-index 0
done
