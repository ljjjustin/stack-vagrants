#!/bin/bash

VIP=10.0.1.100
workdir=$(cd $(dirname $0) && pwd)

# setup cleanup function
cleanup_on_exit() {
    rm -f *.log *.conf
}
trap "cleanup_on_exit" EXIT

cd "$workdir"
sudo chown quagga .

# generate config files
cat > r1zebra.conf << EOF
hostname r1zebra
password 123
enable password 123

log file ${workdir}/r1zebra.log
EOF

cat > r2zebra.conf << EOF
hostname r2zebra
password 123
enable password 123

log file ${workdir}/r2zebra.log
EOF

cat > r1bgpd.conf << EOF
hostname r1bgpd
password en
enable password zebra
log file ${workdir}/r1bgpd.log

router bgp 65000
  bgp router-id 10.0.3.10
  network 10.0.3.0/24
  network 192.168.0.0/16
  redistribute connected

  neighbor 10.0.3.20 remote-as 65000
  neighbor 10.0.3.20 activate
  neighbor 10.0.3.20 soft-reconfiguration inbound
  !neighbor 10.0.3.20 route-server-client
  !neighbor 10.0.3.20 route-map RSCLIENT-IMPORT import
  !neighbor 10.0.3.20 route-map RSCLIENT-EXPORT export

  neighbor 192.168.10.10 remote-as 65000
  neighbor 192.168.10.10 activate
  !neighbor 192.168.10.10 soft-reconfiguration inbound
  !neighbor 192.168.10.10 route-server-client
  !neighbor 192.168.10.10 route-map RSCLIENT-IMPORT import
  !neighbor 192.168.10.10 route-map RSCLIENT-EXPORT export

  neighbor 192.168.20.10 remote-as 65000
  neighbor 192.168.20.10 activate
  !neighbor 192.168.20.10 soft-reconfiguration inbound
  !neighbor 192.168.20.10 route-server-client
  !neighbor 192.168.20.10 route-map RSCLIENT-IMPORT import
  !neighbor 192.168.20.10 route-map RSCLIENT-EXPORT export

ip prefix-list LBVIP seq 5 permit 10.0.1.100/32
ip prefix-list LBVIP seq 10 deny any

route-map RSCLIENT-IMPORT deny 10
route-map RSCLIENT-EXPORT permit 10
  match ip address prefix-list LBVIP
EOF

cat > r2bgpd.conf << EOF
hostname r2bgpd
password zebra
enable password zebra
log file ${workdir}/r2bgpd.log

router bgp 65000
  bgp router-id 10.0.3.20
  network 10.0.3.0/24
  network 192.168.0.0/16
  redistribute connected

  neighbor 10.0.3.10 remote-as 65000
  neighbor 10.0.3.10 activate
  neighbor 10.0.3.10 soft-reconfiguration inbound
  !neighbor 10.0.3.10 route-server-client
  !neighbor 10.0.3.10 route-map RSCLIENT-IMPORT import
  !neighbor 10.0.3.10 route-map RSCLIENT-EXPORT export

  neighbor 192.168.10.10 remote-as 65000
  neighbor 192.168.10.10 activate
  !neighbor 192.168.10.10 soft-reconfiguration inbound
  !neighbor 192.168.10.10 route-server-client
  !neighbor 192.168.10.10 route-map RSCLIENT-IMPORT import
  !neighbor 192.168.10.10 route-map RSCLIENT-EXPORT export

  neighbor 192.168.20.10 remote-as 65000
  neighbor 192.168.20.10 activate
  !neighbor 192.168.20.10 soft-reconfiguration inbound
  !neighbor 192.168.20.10 route-server-client
  !neighbor 192.168.20.10 route-map RSCLIENT-IMPORT import
  !neighbor 192.168.20.10 route-map RSCLIENT-EXPORT export

ip prefix-list LBVIP seq 5 permit 10.0.1.100/32
ip prefix-list LBVIP seq 10 deny any

route-map RSCLIENT-IMPORT deny 10
route-map RSCLIENT-EXPORT permit 10
  match ip address prefix-list LBVIP
EOF

cat > keep1.conf << EOF
! Configuration File for keepalived
global_defs {
}

vrrp_instance VIP1 {
    state BACKUP
    nopreempt
    interface eth0
    virtual_router_id 31
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 123465
    }
    unicast_src_ip 192.168.10.10
    unicast_peer {
        192.168.20.10
    }
    virtual_ipaddress {
        ${VIP}
    }
}
EOF

cat > keep2.conf << EOF
! Configuration File for keepalived
global_defs {
}

vrrp_instance VIP1 {
    state BACKUP
    nopreempt
    interface eth0
    virtual_router_id 31
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 123465
    }
    unicast_src_ip 192.168.20.10
    unicast_peer {
        192.168.10.10
    }
    virtual_ipaddress {
        ${VIP}
    }
}
EOF

cat > exabgp1.env << EOF
[exabgp.daemon]
user=root
daemonize=true

[exabgp.api]
cli=false

[exabgp.log]
destination=/tmp/exabgp1.log
EOF

cat > exabgp1.conf << EOF
process service-cmd {
    run /usr/bin/socat stdout pipe:/tmp/exabgp1.cmd;
    encoder text;
}
template {
    neighbor ipv4 {
        router-id 192.168.10.10;
        local-address 192.168.10.10;
        local-as 65000;
        peer-as 65000;
        api {
            processes [ service-cmd ];
        }
    }
}
neighbor 10.0.3.10 {
    inherit ipv4;
}

neighbor 10.0.3.20 {
    inherit ipv4;
}
EOF

cat > exabgp2.env << EOF
[exabgp.daemon]
user=root
daemonize=true

[exabgp.api]
cli=false

[exabgp.log]
destination=/tmp/exabgp2.log
EOF

cat > exabgp2.conf << EOF
process service-cmd {
    run /usr/bin/socat stdout pipe:/tmp/exabgp2.cmd;
    encoder text;
}
template {
    neighbor ipv4 {
        router-id 192.168.20.10;
        local-address 192.168.20.10;
        local-as 65000;
        peer-as 65000;
        api {
            processes [ service-cmd ];
        }
    }
}
neighbor 10.0.3.10 {
    inherit ipv4;
}

neighbor 10.0.3.20 {
    inherit ipv4;
}
EOF
sudo chown quagga *.conf
sudo chown exabgp exabgp*

sudo python topo.py
