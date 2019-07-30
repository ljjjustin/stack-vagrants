#!/bin/bash

cd /vagrant/
# enable root login
echo "root:r00tme!" | chpasswd

sed -e 's/^#PermitRootLogin .*$/PermitRootLogin yes/g' \
    -e 's/^PasswordAuthentication .*$/PasswordAuthentication yes/g' \
    -e 's/^#UseDNS .*/UseDNS no/g' \
    -e 's/^GSSAPIAuthentication .*/GSSAPIAuthentication no/g' \
    -i /etc/ssh/sshd_config
systemctl restart sshd

# disable selinux
setenforce 0
sed -i -e 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

# set timezone
timedatectl set-timezone Asia/Shanghai

# set language
echo "LANG=en_US.UTF-8" > /etc/environment
echo "LC_ALL=C" > /etc/environment

## disable ipv6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
echo 1 > /proc/sys/net/ipv6/conf/default/disable_ipv6

cat > /etc/sysctl.d/disable_ipv6.conf  <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

# config yum repo
mkdir /etc/yum.repos.d/backup && (cd /etc/yum.repos.d/ && mv -f *.repo backup)
#cp tstack.repo /etc/yum.repos.d/
