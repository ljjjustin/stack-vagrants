#!/bin/bash

# change work directory
cd $(dirname $0)

# change root login password
echo "root:r00tme" | chpasswd

## setup hosts file
cat > /etc/hosts << HOSTS
127.0.0.1  localhost
HOSTS

## setup ssh
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
killall dhclient
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

## config yum repo
yum clean all
cd /etc/yum.repos.d/ && mkdir backup
mv *.repo backup

wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo

yum update -y
yum install -y net-tools rsync vim git tcpdump wget strace
