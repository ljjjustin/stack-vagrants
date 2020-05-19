#!/bin/bash

# change password
echo r00tme | passwd --stdin root

# disable firewall
systemctl stop firewalld
systemctl disable firewalld

# disable selinux
setenforce 0

# change yum config
if ! grep -q ip_resolve /etc/yum.conf; then
    echo "ip_resolve=4" >> /etc/yum.conf
fi
# auto change work directory
workdir=$(cd $(dirname $0) && pwd)

# install redis
if rpm -q redis | grep -q 'not installed'; then
    yum install -y redis
fi

redis_pass=c72ThAPVzx3N3O2R
redis_myip=$(ip a show dev eth1 | grep -w inet | awk '{print $2}' | cut -d/ -f1)

# config redis
cat > /etc/redis.conf << EOF
bind 0.0.0.0
port 6379
daemonize yes
loglevel notice
logfile "/var/log/redis/redis.log"
dir "/var/lib/redis"
dbfilename "dump.rdb"

# disable persistent
#save 900 1
#save 300 10
#save 60 10000
#appendonly yes
#appendfsync everysec

appendonly no
maxmemory 400mb
stop-writes-on-bgsave-error no
maxmemory-policy volatile-lru
repl-diskless-sync yes
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
slowlog-log-slower-than 20000
slowlog-max-len 128

requirepass "${redis_pass}"
masterauth "${redis_pass}"
EOF

if [ "${redis_myip}" != "192.168.55.31" ]; then
    cat >> /etc/redis.conf << EOF
slaveof 192.168.55.31 6379
EOF
fi

# config redis sentinel
cat > /etc/redis-sentinel.conf << EOF
port 26379
daemonize yes
protected-mode no
dir /var/lib/redis/
logfile /var/log/redis/sentinel.log

sentinel monitor sdemo 192.168.55.31 6379 2
sentinel auth-pass sdemo ${redis_pass}
sentinel down-after-milliseconds sdemo 8000
sentinel failover-timeout sdemo 12000
sentinel parallel-syncs sdemo 1
EOF

chown redis:redis /etc/{redis.conf,redis-sentinel.conf}

# start redis
systemctl enable redis
systemctl enable redis-sentinel
systemctl restart redis
systemctl restart redis-sentinel
