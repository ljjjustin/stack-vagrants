#!/bin/bash

VIP=10.0.1.100
workdir=$(cd $(dirname $0) && pwd)

# setup cleanup function
cleanup_on_exit() {
    rm -f *.log *.conf
}
trap "cleanup_on_exit" EXIT

cd "$workdir"

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

cat > r1ospfd.conf << EOF
hostname r1ospfd
password 123
enable password 123
log file ${workdir}/r1ospfd.log

router ospf
  ospf router-id 10.0.3.10
  network 10.0.3.0/24 area 0
  network 192.168.0.0/16 area 0
  network 10.0.1.100/32 area 0
EOF

cat > r2ospfd.conf << EOF
hostname r2ospfd
password zebra
enable password zebra
log file ${workdir}/r2ospfd.log

router ospf
  ospf router-id 10.0.3.20
  network 10.0.3.0/24 area 0
  network 192.168.0.0/16 area 0
  network 10.0.1.100/32 area 0

EOF

cat > lb1zebra.conf << EOF
hostname lb1zebra
password 123
enable password 123

log file ${workdir}/lb1zebra.log
EOF

cat > lb2zebra.conf << EOF
hostname lb2zebra
password 123
enable password 123

log file ${workdir}/lb2zebra.log
EOF

cat > lb1ospfd.conf << EOF
hostname lb1ospfd
password 123
enable password 123
log file ${workdir}/lb1ospfd.log

router ospf
  ospf router-id 192.168.10.10
  network 10.0.3.0/24 area 0
  network 192.168.0.0/16 area 0
  network 10.0.1.100/32 area 0
EOF

cat > lb2ospfd.conf << EOF
hostname lb2ospfd
password zebra
enable password zebra
log file ${workdir}/lb2ospfd.log

router ospf
  ospf router-id 192.168.20.10
  network 10.0.3.0/24 area 0
  network 192.168.0.0/16 area 0
  network 10.0.1.100/32 area 0

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

sudo chown quagga *.conf

sudo python topo.py
