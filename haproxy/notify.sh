#!/bin/bash


role=$1

if [ "${role}" = "master" ]; then
    iptables -R INPUT 1 -m set --match-set keepalived dst -j ACCEPT
elif [ "${role}" = "backup" ]; then
    iptables -R INPUT 1 -m set --match-set keepalived dst -j DROP
else
    echo status became ${role}, ignore..
fi
