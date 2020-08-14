#!/bin/bash

VIP=192.168.55.33
IP1=192.168.55.31
IP2=192.168.55.32
HEARTBEAT_INTF=eth1

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

net.ipv4.ip_nonlocal_bind = 1
EOF
sysctl -p


if rpm -q haproxy | grep -qi 'not installed'; then
    yum install -y haproxy
fi
if rpm -q keepalived | grep -qi 'not installed'; then
    yum install -y keepalived
fi

mkdir -p /etc/haproxy/conf.d/
cat > /etc/haproxy/conf.d/00-global.cfg << EOF
global
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     40000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

defaults
    mode tcp
    log global
    option tcplog
    option dontlognull
    option http-server-close
    option redispatch
    retries 3
    balance roundrobin

    timeout connect 10s
    timeout client  30s
    timeout server  30s

    maxconn 10000

listen stats
    bind 0.0.0.0:2936
    mode http
    stats enable
    stats refresh 10s
    stats hide-version
    stats uri  /status
    stats realm HaProxy\ Statistics
    stats auth admin:haproxy123

EOF

# config rsyslog
if ! grep -q "haproxy.log" /etc/rsyslog.d/*; then
    cat > /etc/rsyslog.d/haproxy.conf << EOF
$ModLoad imudp
$UDPServerRun 514

if \$programname startswith 'haproxy' then /var/log/haproxy.log
&~
EOF
    systemctl restart rsyslog
fi

systemctl enable haproxy
systemctl start haproxy

# reload haproxy config
cat > /etc/haproxy/update-config.sh << EOS
#!/bin/bash

postfix=$(date "+%Y%m%d-%H%M%S")

cp /etc/haproxy/haproxy.cfg{,$postfix}

cat /etc/haproxy/conf.d/*.cfg > /etc/haproxy/haproxy.cfg

if haproxy -q -c -f /etc/haproxy/haproxy.cfg; then
    systemctl reload haproxy
else
    echo "config NOT valid"
fi
EOS
chmod +x /etc/haproxy/update-config.sh
/etc/haproxy/update-config.sh

if [ "${IP1}" = "${myip}" ]; then
        peer_ip=$IP2
    elif [ "${IP2}" = "${myip}" ]; then
        peer_ip=$IP1
fi

cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
}

vrrp_script chk_haproxy {
   script "/etc/keepalived/check_haproxy.sh"
   interval 2
   timeout 3
   rise 5
   fall 3
}

vrrp_instance VIP1 {
    state BACKUP
    nopreempt
    interface ${HEARTBEAT_INTF}
    virtual_router_id 71
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 123465
    }
    unicast_src_ip ${myip}
    unicast_peer {
        ${peer_ip}
    }
    virtual_ipaddress {
        ${VIP}
    }
    track_script {
       chk_haproxy
    }
    notify_master "/etc/keepalived/notify.sh master"
    notify_backup "/etc/keepalived/notify.sh backup"
}
EOF
cp -f notify.sh check_haproxy.sh /etc/keepalived/

systemctl enable keepalived
systemctl start keepalived
