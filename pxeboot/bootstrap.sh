#!/bin/bash

cd /vagrant/
# enable root login
echo "root:r00tme" | chpasswd
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
nameserver 119.29.29.29
nameserver 114.114.114.114
EOF
chattr +i /etc/resolv.conf

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

# update packages
yum install -y epel-release
yum install -y dnsmasq xinetd syslinux nfs-utils tftp-server

systemctl enable dnsmasq xinetd nfs

# setup PXE environment
cp -f pxerc ks.template update.sh /var/lib/tftpboot
cd /var/lib/tftpboot; bash -x ./update.sh
