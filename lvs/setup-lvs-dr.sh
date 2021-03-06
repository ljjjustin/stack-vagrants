#!/bin/bash

set -xe

ETH1_VIP=192.168.55.200
RS1=192.168.55.33

# change kernel params
cat > /etc/sysctl.conf << EOF
net.ipv6.conf.all.disable_ipv6=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.eth0.rp_filter = 0
net.ipv4.conf.eth1.rp_filter = 0
EOF
sysctl -p

## install keepalived
if rpm -q keepalived | grep -q 'not installed'; then
	yum install -y keepalived ipvsadm
fi
cp -f notify.sh /etc/keepalived/
## config keepalived
cat > /etc/keepalived/keepalived.conf << EOF
! Configuration File for keepalived

global_defs {
   notification_email {
     sysadmin@firewall.loc
   }
   notification_email_from example@firewall.loc
   router_id LVS_DEMO
   vrrp_strict
}

vrrp_instance VIP1 {
    state BACKUP
    nopreempt
    interface eth1
    virtual_router_id 31
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        ${ETH1_VIP} dev eth1
    }
    notify_master "/etc/keepalived/notify.sh master"
    notify_backup "/etc/keepalived/notify.sh backup"
}

virtual_server ${ETH1_VIP} 80 {
    delay_loop 5
    lb_algo rr
    lb_kind DR
    protocol TCP

    real_server ${RS1} 80 {
        weight 100
        TCP_GET {
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3
            connect_port 80
        }
    }
}
EOF

## disable firewalld
systemctl stop firewalld
systemctl disable firewalld

## 启动Keepalived
systemctl enable keepalived
systemctl restart keepalived
