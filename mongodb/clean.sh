#!/bin/bash

# stop services
systemctl stop mongos
systemctl stop mongod-config
systemctl stop mongod-shard1 mongod-shard2 mongod-shard3

# remove config and data
rm -fr /etc/mongodb/conf /var/lib/mongodb
