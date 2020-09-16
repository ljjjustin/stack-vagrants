#!/bin/bash

# change password
echo r00tme | passwd --stdin root

# change yum config
if ! grep -q ip_resolve /etc/yum.conf; then
    echo "ip_resolve=4" >> /etc/yum.conf
fi
# auto change work directory
cd $(dirname $0)

# disable selinux
if [ "$(getenforce)" != "Disabled" ]; then
    setenforce 0
    sed -i "s/^SELINUX=.*$/SELINUX=disabled/g" /etc/selinux/config
fi

# disable firewalld
systemctl stop firewalld
systemctl disable firewalld

# install tiup
if [[ "$(hostname)" =~ "^tiup$" ]]; then
    set -e
    if [[ type tiup |& grep -q 'not found' ]]; then
        curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
        source ~/.bash_profile
    fi
    tiup cluster deploy tidb-cluster v4.0.0 ./topo.yaml
fi
