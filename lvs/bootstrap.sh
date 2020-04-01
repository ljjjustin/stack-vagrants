#!/bin/bash

# auto change work directory
workdir=$(cd $(dirname $0) && pwd)
lvs_mode="nat"  ## nat/tun/dr
lvs_script="./setup-lvs-${lvs_mode}.sh"
rs_script="./setup-rs-${lvs_mode}.sh"

cd ${workdir}

if [[ "$(hostname)" =~ "lvs" ]]; then
    exec ${lvs_script}
elif [[ "$(hostname)" =~ "rs" ]]; then
    exec ${rs_script} start
else
    echo "hostname not match, ignore"
    exit 0
fi
