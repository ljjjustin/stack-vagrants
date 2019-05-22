#!/bin/bash

cd /vagrant/
# enable root login
echo "root:r00tme!" | chpasswd
sed -e 's/^#PermitRootLogin .*$/PermitRootLogin yes/g' \
    -e 's/^PasswordAuthentication .*$/PasswordAuthentication yes/g' \
    -e 's/^#UseDNS .*/UseDNS yes/g' \
    -i /etc/ssh/sshd_config
systemctl restart sshd

# disable selinux
setenforce 0
sed -i -e 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

# set timezone
timedatectl set-timezone Asia/Shanghai

# config dns server
cat > /etc/resolv.conf << 'EOF'
# INJECTED BY VAGRANT
nameserver 10.11.56.22
nameserver 10.11.56.23
nameserver 10.14.0.130
nameserver 10.14.0.131
EOF
chattr +i /etc/resolv.conf

# config proxy server
cp proxy.sh /etc/profile.d/proxy.sh && source /etc/profile.d/proxy.sh

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

mkdir -p /data/
# update packages
yum install -y bzip2 wget expect net-tools vim

