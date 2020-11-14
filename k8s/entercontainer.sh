#!/bin/bash

if [[ $# -ne 1 ]]; then
    echo "$0 <container id>"
    exit
fi

container_id=$1

cleanup() {
    if [ -L /var/run/netns/${container_id} ]; then
        rm -f /var/run/netns/${container_id}
        fi
    }
trap cleanup EXIT

pid=$(docker inspect -f '{{.State.Pid}}' ${container_id})

mkdir -p /var/run/netns/
ln -sfT /proc/$pid/ns/net /var/run/netns/${container_id}

ip netns exec ${container_id} /bin/bash
