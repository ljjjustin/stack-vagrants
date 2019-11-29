#!/bin/bash

REALM=ybj
ZONEGROUP=zg1
ZONE=$(hostname)

radosgw-admin realm delete --rgw-realm=default
radosgw-admin zonegroup delete --rgw-zonegroup=default
radosgw-admin zone delete --rgw-zone=default


radosgw-admin realm pull --url=http://ceph1:7480 --access-key=admin --secret=admin
radosgw-admin realm default --rgw-realm=${REALM}
radosgw-admin period pull --url=http://ceph1:7480 --access-key=admin --secret=admin
radosgw-admin zone create --rgw-zonegroup=${ZONEGROUP} --rgw-zone=${ZONE} --endpoints=http://$(hostname):7480 --access-key=admin --secret=admin

radosgw-admin period update --commit

cat >> /etc/ceph/ceph.conf << EOC
[client.rgw.${ZONE}]
rgw_zone = ${ZONE}
rgw_zonegroup = ${ZONEGROUP}
rgw_realm = ${REALM}
EOC

systemctl restart ceph-radosgw@rgw.$(hostname -s)
