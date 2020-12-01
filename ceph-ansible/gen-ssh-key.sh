#!/bin/bash

cd $(dirname $0)

if [ ! -d .ssh ]; then
    mkdir .ssh
fi

if [ ! -f .ssh/id_rsa ]; then
    ssh-keygen -t rsa -P '' -f .ssh/id_rsa
fi

if [ ! -f .ssh/id_rsa.pub ]; then
    ssh-keygen -t rsa -P '' -f .ssh/id_rsa
fi

if [ ! -f .ssh/config ]; then
    cat > .ssh/config << CFG
LogLevel error
ServerAliveInterval 30
ServerAliveCountMax 6
StrictHostKeyChecking no
UserKnownHostsFile /dev/null
CFG
fi

if [ ! -f .ssh/authorized_keys ]; then
    cp .ssh/id_rsa.pub .ssh/authorized_keys
fi
