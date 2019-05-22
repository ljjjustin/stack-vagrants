#!/bin/bash

cd /vagrant/
# enable root login
echo "root:r00tme!" | chpasswd
mkdir -p /root/.ssh/
cat > /root/.ssh/authorized_keys << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCfPkgDo5oKOd6eawMRRJ2uEVOzJLGyJ0POQFwOOnd9RIdgkskzV/b6/t9SyZj1EsgXujlxvH7KsDhIT0pLEDegx3mhV7vXydUESsn+5X3jhnNptp8uH+TanbbbwB/05xzyPY66KjqFHOkIqEID1bDHaKuAEulv0Dic0QZp9B0imtzX79ROCd4TuZ9vV1kFDd/n2zXt4a/A3sCHYAMo6PjrZ8Y5MKfYmnjXKgbJCXPIRVe0NR6+/vY22mTJI4+77FJhshrUcR06naW2qVbEBPM5rvy3Qof8LDhtJMAip4p81isYJa3qILNgEe0wxxdegaLqPRzQMkBUD0FtbePiDVv/ root@liujjliu-pc1
EOF
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
nameserver 10.1.156.78
nameserver 10.1.156.79
nameserver 10.14.198.15
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
