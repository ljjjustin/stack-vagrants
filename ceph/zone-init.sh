#!/bin/bash

REALM=r1
ZONEGROUP=zg1
ZONE=$(hostname)

radosgw-admin realm delete --rgw-realm=default
radosgw-admin zonegroup delete --rgw-zonegroup=default
radosgw-admin zone delete --rgw-zone=default


radosgw-admin realm create --rgw-realm=${REALM} --default
radosgw-admin zonegroup create --rgw-zonegroup=${ZONEGROUP} --endpoints=http://ceph1:7480 --master --default
radosgw-admin zone create --rgw-zonegroup=${ZONEGROUP} --rgw-zone=${ZONE} --endpoints=http://$(hostname):7480 --access-key=admin --secret=admin --default --master

radosgw-admin period update --commit

radosgw-admin user create --uid=zone.user --display-name="Zone User" --access-key=admin --secret=admin --system
