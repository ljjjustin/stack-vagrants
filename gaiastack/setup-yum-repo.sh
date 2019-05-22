#!/bin/bash

yum install -y httpd

if ! cat /etc/fstab | grep -qw nfs; then
    mkdir -p /data/mirror
    echo "192.168.121.1:/data/  /data/mirror  nfs defaults 0 0" >> /etc/fstab
    mount -a
fi

sed -ie 's/^Listen .*$/Listen 0.0.0.0:9091/g' /etc/httpd/conf/httpd.conf

ln -sf /data/mirror/gaiastack/gaia-mirror-2.8 /var/www/html/gaia-mirror

systemctl enable httpd
systemctl start httpd

netstat -ntlp | grep 9091
