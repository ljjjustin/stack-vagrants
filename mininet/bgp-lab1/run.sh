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

router bgp 100
  neighbor 192.168.12.2 remote-as 200
EOF

cat > r2bgpd.conf << EOF
hostname r2bgpd
password zebra
enable password zebra
log file ${workdir}/r2bgpd.log

router bgp 200
  neighbor 192.168.12.1 remote-as 100
EOF

sudo chown quagga *.conf

sudo python topo.py
