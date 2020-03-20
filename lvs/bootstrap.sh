#!/bin/bash

# auto change work directory
workdir=$(cd $(dirname $0) && pwd)
cd ${workdir}

if [[ "$(hostname)" =~ "lvs" ]]; then
    systemctl stop firewalld
    systemctl disable firewalld
    ./setup-lvs.sh
elif [[ "$(hostname)" =~ "rs" ]]; then
    systemctl stop firewalld
    systemctl disable firewalld
    ./setup-real-server.sh start
    sudo nohup python -m SimpleHTTPServer 80 &
else
    echo "hostname not match, ignore"
    exit 0
fi
