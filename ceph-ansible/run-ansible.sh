#!/bin/bash

workdir=$(cd $(dirname $0) && pwd)

cd $workdir

# install base packages
if [[ "$(hostname)" = "ceph1" ]]; then
    if [ ! -d ceph-ansible ]; then
        git clone https://github.com/ceph/ceph-ansible.git
    fi
    cd ceph-ansible/ && git checkout stable-5.0
    pip install -r requirements.txt

    unset cp
    cp -f ${workdir}/ansible-config/site.yml .
    cp -f ${workdir}/ansible-config/ceph-hosts .
    cp -f ${workdir}/ansible-config/group_vars/* ./group_vars/
    ansible-playbook -vv -i ceph-hosts site.yml
fi
