#!/bin/bash


ensure_link() {
    local netns=$1
    local link=$2

    if ! ip netns | grep -q -w "${netns}"; then
        ip netns add ${netns}
    fi
    if ip netns exec ${netns} ip link | grep -q -w ${link}; then
        return
    fi
    if ! ip link | grep -q -w ${link}; then
        ip link add link eth1 name ${link} type ipvlan mode l3
    fi
    ip link set dev ${link} netns ${netns}
}

ensure_link ns1 ipvlan1
ensure_link ns2 ipvlan2

if [ "$(hostname)"  = "ipvlan1" ]; then
    ip netns exec ns1 ip a add dev ipvlan1 10.10.10.1/24
    ip netns exec ns2 ip a add dev ipvlan2 10.10.10.2/24
    ip netns exec ns1 ip l set ipvlan1 up
    ip netns exec ns2 ip l set ipvlan2 up
    ip netns exec ns1 ip r add default via 10.10.10.254
    ip netns exec ns2 ip r add default via 10.10.10.254
else
    ip netns exec ns1 ip a add dev ipvlan1 10.10.10.3/24
    ip netns exec ns2 ip a add dev ipvlan2 10.10.10.4/24
    ip netns exec ns1 ip l set ipvlan1 up
    ip netns exec ns2 ip l set ipvlan2 up
    ip netns exec ns1 ip r add default via 10.10.10.254
    ip netns exec ns2 ip r add default via 10.10.10.254
fi
