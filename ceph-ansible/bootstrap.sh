#!/bin/bash

# change work directory
cd $(dirname $0)

# change root login password
echo "root:r00tme" | chpasswd

## setup ssh
unset cp
mkdir -p /root/.ssh
sudo cp -f .ssh/* /root/.ssh/
chown -R root:root /root/.ssh
chmod 0400 /root/.ssh/*
sed -e 's/^#PermitRootLogin .*$/PermitRootLogin yes/g' \
    -e 's/^PasswordAuthentication .*$/PasswordAuthentication yes/g' \
    -e 's/^#UseDNS .*/UseDNS no/g' \
    -e 's/^GSSAPIAuthentication .*/GSSAPIAuthentication no/g' \
    -i /etc/ssh/sshd_config
systemctl restart sshd

# disable selinux
setenforce 0
sed -i -e 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
systemctl stop firewalld
systemctl disable firewalld

# disable network manager
systemctl stop NetworkManager
systemctl disable NetworkManager
cat > /etc/resolv.conf << DNS
nameserver 114.114.114.114
nameserver 223.5.5.5
DNS

# set timezone
timedatectl set-timezone Asia/Shanghai

## disable ipv6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
echo 1 > /proc/sys/net/ipv6/conf/default/disable_ipv6

cat > /etc/sysctl.d/disable_ipv6.conf  <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

## setup hosts file
cat > /etc/hosts << HOSTS
127.0.0.1  localhost
192.168.55.101 ceph1 ceph1
192.168.55.102 ceph2 ceph2
192.168.55.103 ceph3 ceph3
HOSTS

# install python pip
yum install -y python-pip python-netaddr python36-six.noarch python36-PyYAML.x86_64
mkdir ~/.pip
cat > ~/.pip/pip.conf << EOF
[global]
trusted-host=mirrors.aliyun.com
index-url=https://mirrors.aliyun.com/pypi/simple/
EOF
pip3 install pecan werkzeug
