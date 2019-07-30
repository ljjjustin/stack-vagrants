#!/bin/bash

REALM=r1
ZONEGROUP=zg1
ZONE=$(hostname)

radosgw-admin realm delete --rgw-realm=default
radosgw-admin zonegroup delete --rgw-zonegroup=default
radosgw-admin zone delete --rgw-zone=default

radosgw-admin zone delete --rgw-zone=${ZONE}
radosgw-admin zonegroup delete --rgw-zonegroup=${ZONEGROUP}
radosgw-admin realm delete --rgw-realm=${REALM}
