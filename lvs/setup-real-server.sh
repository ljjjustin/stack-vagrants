#!/bin/sh

VIP=192.168.55.200

LOCK=/var/lock/ipvsadm.lock
. /etc/rc.d/init.d/functions

start() {
     PID=`ifconfig | grep tunl0 | wc -l`
     if [ $PID -ne 0 ];
     then
         echo "The LVS-TUN-RIP Server is already running !"
     else
         #Load the tun mod
         /sbin/modprobe tun
         /sbin/modprobe ipip
         #Set the tun Virtual IP Address
         /sbin/ifconfig tunl0 $VIP netmask 255.255.255.255 broadcast $VIP up
         /sbin/route add -host $VIP dev tunl0
         echo "1" >/proc/sys/net/ipv4/conf/tunl0/arp_ignore
         echo "2" >/proc/sys/net/ipv4/conf/tunl0/arp_announce
         echo "1" >/proc/sys/net/ipv4/conf/all/arp_ignore
         echo "2" >/proc/sys/net/ipv4/conf/all/arp_announce
         echo "0" > /proc/sys/net/ipv4/conf/tunl0/rp_filter
         echo "0" > /proc/sys/net/ipv4/conf/all/rp_filter
         /bin/touch $LOCK
         echo "starting LVS-TUN-RIP server is ok !"
     fi
}

stop() {
         /sbin/ifconfig tunl0 down
         echo "0" >/proc/sys/net/ipv4/conf/tunl0/arp_ignore
         echo "0" >/proc/sys/net/ipv4/conf/tunl0/arp_announce
         echo "0" >/proc/sys/net/ipv4/conf/all/arp_ignore
         echo "0" >/proc/sys/net/ipv4/conf/all/arp_announce
         #Remove the tun mod
         /sbin/modprobe -r tun
         /sbin/modprobe -r ipip
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
