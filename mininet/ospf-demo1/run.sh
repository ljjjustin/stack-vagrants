#!/bin/bash

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

cat > r1ospfd.conf << EOF
hostname r1ospfd
password zebra
enable password zebra

router ospf
  ospf router-id 10.0.3.10
  network 10.0.3.0/24 area 0
  network 10.0.1.0/24 area 0

debug ospf event
log file ${workdir}/r1ospfd.log
EOF

cat > r2ospfd.conf << EOF
hostname r2ospfd
password zebra
enable password zebra

router ospf
  ospf router-id 10.0.3.20
  network 10.0.3.0/24 area 0
  network 10.0.2.0/24 area 0

debug ospf event
log file ${workdir}/r2ospfd.log
EOF

sudo chown quagga *.conf

sudo python topo.py
