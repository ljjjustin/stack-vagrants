#!/bin/bash

LOCKFILE=/tmp/ceph-lock.txt
if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    echo "already running"
    exit
fi

# make sure the lockfile is removed when we exit and then claim it
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ > ${LOCKFILE}

workdir=$(cd $(dirname $0) && pwd)

# install base packages
if [[ "$(hostname)" = "ceph1" ]]; then
    cd $workdir
    export https_proxy=10.211.55.2:6152
    if [ ! -d ceph-ansible ]; then
        git clone https://github.com/ceph/ceph-ansible.git
    fi
    cd ceph-ansible/ && git checkout stable-5.0
    pip3 install -r requirements.txt

    unset cp
    cp -f ${workdir}/ansible-config/site.yml .
    cp -f ${workdir}/ansible-config/ceph-hosts .
    cp -f ${workdir}/ansible-config/group_vars/* ./group_vars/
    ansible-playbook -vv -i ceph-hosts site.yml
fi
