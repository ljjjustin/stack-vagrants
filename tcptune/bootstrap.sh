#!/bin/bash

# change password
echo r00tme | passwd --stdin root

# change yum config
if ! grep -q ip_resolve /etc/yum.conf; then
    echo "ip_resolve=4" >> /etc/yum.conf
fi
# auto change work directory
cd $(dirname $0)

# disable selinux
if [ "$(getenforce)" != "Disabled" ]; then
    setenforce 0
    sed -i "s/^SELINUX=.*$/SELINUX=disabled/g" /etc/selinux/config
fi

# disable firewalld
systemctl stop firewalld
systemctl disable firewalld

# tune kernel params
cat > /etc/sysctl.conf << EOF
fs.file-max = 4194304

net.core.somaxconn = 30000
net.core.netdev_max_backlog = 30000

net.ipv4.tcp_max_orphans = 30000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_fin_timeout = 15
net.ipv4.ip_local_port_range = 1024 65535

net.ipv4.tcp_mem =  1048576 1572864 2097152
net.ipv4.tcp_rmem = 4096 4096 8388608
net.ipv4.tcp_wmem = 4096 4096 8388608
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1

net.ipv6.conf.all.disable_ipv6 = 1
EOF
sysctl -p


# config and restart nginx
myip=$(ip a show dev eth1 | grep -w inet | awk '{print $2}' | cut -d/ -f1)
if [ "${myip}" != "192.168.55.31" ]; then
    if ! grep -q ulimit /root/.bashrc; then
        echo "ulimit -n 500000" >> /root/.bashrc
    fi
    exit
fi

if rpm -q nginx | grep -qi 'not installed'; then
    yum install -y nginx
fi

cat > /etc/nginx/nginx.conf << EOF
worker_processes 4;

events {
    use epoll;
    worker_connections 200000;
}
worker_rlimit_nofile 200000;

http {
    server {
        listen 80;
        listen 81;
        listen 82;
        listen 83;
        listen 84;

        location / {
            return 200 'hello, nginx serving';
        }
    }
}
EOF

systemctl enable nginx
systemctl restart nginx
