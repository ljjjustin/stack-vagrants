#!/bin/sh

ETH1_VIP=192.168.55.200

LOCK=/var/lock/ipvsadm.lock
. /etc/rc.d/init.d/functions

## disable firewalld
systemctl stop firewalld
systemctl disable firewalld

ensure_nginx() {
    if rpm -q nginx | grep -q 'not installed'; then
        yum install -y nginx
    fi
    if [ ! -e "/usr/share/nginx/html/lvsdemo" ]; then
        echo "nginx1" > /usr/share/nginx/html/lvsdemo
    fi
    systemctl enable nginx
    systemctl start nginx
}

start() {
    ensure_nginx
    # add vip to lo dev
    ip a add ${ETH1_VIP} dev lo
    route add -host ${ETH1_VIP} dev lo

    echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore
    echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce
    echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore
    echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce
    /bin/touch $LOCK
    echo "starting LVS-TUN-RIP server is ok !"
}

stop() {
    echo 0 >/proc/sys/net/ipv4/conf/lo/arp_ignore
    echo 0 >/proc/sys/net/ipv4/conf/lo/arp_announce
    echo 0 >/proc/sys/net/ipv4/conf/all/arp_ignore
    echo 0 >/proc/sys/net/ipv4/conf/all/arp_announce

    rm -rf $LOCK
    echo "stopping LVS-TUN-RIP server is ok !"
}

status() {
    if [ -e $LOCK ];
    then
        echo "The LVS-TUN-RIP Server is already running !"
    else
        echo "The LVS-TUN-RIP Server is not running !"
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $1 {start|stop|restart|status}"
        exit 1
esac
exit 0
