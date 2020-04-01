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
    # setup advanced route
    cidr=$(ip a show dev eth1 | grep -w inet | head -1 | awk '{print $2}')
    /sbin/ip r flush table 200
    /sbin/ip r add default via ${ETH1_VIP} table 200
    /sbin/ip r add ${cidr} dev eth1 table 200
    ipaddr=$(ip r get ${ETH1_VIP} | grep -w src | awk '{print $NF}')
    if ! ip ru | grep -wq ${ipaddr}; then
        ip ru add from ${ipaddr} lookup 200
    fi
    /bin/touch $LOCK
    echo "starting LVS-TUN-RIP server is ok !"
}

stop() {
    ipaddr=$(ip r get ${ETH1_VIP} | grep -w src | awk '{print $NF}')
    if ip ru | grep -wq ${ipaddr}; then
        ip ru del from ${ipaddr} lookup 200
    fi
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
