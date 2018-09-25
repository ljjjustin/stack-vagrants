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
# INJECTED BY VAGRANT
nameserver 10.11.56.22
nameserver 10.11.56.23
nameserver 10.14.0.130
nameserver 10.14.0.131
EOF
chattr +i /etc/resolv.conf

# config proxy server
cp proxy.sh /etc/profile.d/proxy.sh && source /etc/profile.d/proxy.sh

# update systemd
mkdir /etc/yum.repos.d/backup && (cd /etc/yum.repos.d/ && mv -f *.repo backup)
cp *.repo /etc/yum.repos.d/

yum update systemd -y
echo -n > /etc/profile.d/proxy.sh && (cd /etc/yum.repos.d/ && mv -f *.repo backup)
