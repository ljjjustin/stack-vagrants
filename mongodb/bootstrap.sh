#!/bin/bash

# change password
echo r00tme | passwd --stdin root

# disable firewall
#systemctl stop firewalld
#systemctl disable firewalld
firewall-cmd --add-port=27017/tcp --permanent
firewall-cmd --add-port=27018/tcp --permanent
firewall-cmd --add-port=27019/tcp --permanent
firewall-cmd --add-port=27077/tcp --permanent
firewall-cmd --add-port=27088/tcp --permanent
firewall-cmd --reload

# disable selinux
setenforce 0
sed -i -e 's/^SELINUX=.*$/SELINUX=disabled/g' /etc/selinux/config

# change yum config
if ! grep -q ip_resolve /etc/yum.conf; then
    echo "ip_resolve=4" >> /etc/yum.conf
fi
# auto change work directory
workdir=$(cd $(dirname $0) && pwd)
myip=$(ip a show dev eth1 | grep -w inet | awk '{print $2}' | cut -d/ -f1)

# make directories
mkdir -p /etc/mongodb/conf
mkdir -p /var/lib/mongodb/{mongos,config}/{data,log}
mkdir -p /var/lib/mongodb/shard{1..3}/{data,log}

# install redis
if rpm -q mongodb-org | grep -q 'not installed'; then
    yum install -y https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-4.0.3-1.el7.x86_64.rpm \
                   https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-mongos-4.0.3-1.el7.x86_64.rpm \
                   https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-server-4.0.3-1.el7.x86_64.rpm \
                   https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-shell-4.0.3-1.el7.x86_64.rpm \
                   https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-tools-4.0.3-1.el7.x86_64.rpm
fi

# config mongo shards
for i in $(seq 1 3)
do
    shard="shard${i}"
    port=$((27016+i))
cat > /etc/mongodb/conf/${shard}.conf <<EOF
systemLog:
  destination: file
  logAppend: true
  path: /var/lib/mongodb/${shard}/log/mongod.log

# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb/${shard}/data
  journal:
    enabled: true

# how the process runs
processManagement:
  fork: true
  pidFilePath: /var/lib/mongodb/${shard}/log/mongod.pid

# network interfaces
net:
  port: ${port}
  bindIp: 0.0.0.0

replication:
  replSetName: ${shard}

sharding:
    clusterRole: "shardsvr"
EOF

cat > /usr/lib/systemd/system/mongod-${shard}.service <<EOF
[Unit]
Description=MongoDB Database ${shard} Service
Wants=network.target
After=network.target

[Service]
Type=forking
PIDFile=/var/lib/mongodb/${shard}/log/mongod.pid
ExecStart=/usr/bin/mongod -f /etc/mongodb/conf/${shard}.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF

done


# enable mongo shards
systemctl enable mongod-shard1 mongod-shard2 mongod-shard3
systemctl start mongod-shard1 mongod-shard2 mongod-shard3
sleep 5

get_shard_status() {
    local port=$1
    mongo --quiet --port ${port} -- "admin" <<EOS
rs.status();
EOS
}

if [ "${myip}" = "192.168.55.31" ]; then
    for i in $(seq 1 3); do
        port=$((27016+i))
        shard_status=$(get_shard_status ${port} | grep -w ok | awk '{print $NF}')
        if [ "${shard_status}" != "1," ]; then
            shard="shard${i}"
            mongo --port ${port} -- "admin" <<EOS
use admin
config = { _id: "${shard}",
	   members : [
		{_id: 0, host: "192.168.55.31:${port}" },
	 	{_id: 1, host: "192.168.55.32:${port}" },
		{_id: 2, host: "192.168.55.33:${port}" }
	 ] };
rs.initiate(config);
rs.status();
EOS
        fi
        sleep 1
    done
fi

# config mongo config servers
cat  > /etc/mongodb/conf/config.conf <<EOF
systemLog:
  destination: file
  logAppend: true
  path: /var/lib/mongodb/config/log/mongod.log

# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb/config/data
  journal:
    enabled: true

# how the process runs
processManagement:
  fork: true  # fork and run in background
  pidFilePath: /var/lib/mongodb/config/log/mongod.pid  # location of pidfile

# network interfaces
net:
  port: 27077
  bindIp: 0.0.0.0  # Listen to local interface only, comment to listen on all interfaces.
replication:
  replSetName: config
sharding:
    clusterRole: "configsvr"
EOF

cat > /usr/lib/systemd/system/mongod-config.service <<EOF
[Unit]
Description=MongoDB Database config Service
Wants=network.target
After=network.target

[Service]
Type=forking
PIDFile=/var/lib/mongodb/config/log/mongod.pid
ExecStart=/usr/bin/mongod -f /etc/mongodb/conf/config.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF

# enable mongo config server
systemctl enable mongod-config
systemctl start mongod-config
sleep 5

get_config_status() {
    mongo --quiet --port 27077 -- "admin" <<EOS
rs.status();
EOS
}

if [ "${myip}" = "192.168.55.31" ]; then
    config_status=$(get_config_status | grep -w ok | awk '{print $NF}')
    if [ "${config_status}" != "1," ]; then
        mongo --port 27077 -- "admin" <<EOS
use admin
config = { _id: "config",
	   members: [
		{_id: 0, host: "192.168.55.31:27077" },
	 	{_id: 1, host: "192.168.55.32:27077" },
		{_id: 2, host: "192.168.55.33:27077" }
           ] };
rs.initiate(config);
rs.status();
EOS
    fi
fi

# config mongo routers
cat > /etc/mongodb/conf/mongos.conf <<EOF
systemLog:
  destination: file
  logAppend: true
  path: /var/lib/mongodb/mongos/log/mongod.log

# how the process runs
processManagement:
  fork: true  # fork and run in background
  pidFilePath: /var/lib/mongodb/mongos/log/mongod.pid  # location of pidfile

# network interfaces
net:
  port: 27088
  bindIp: 0.0.0.0  # Listen to local interface only, comment to listen on all interfaces.
sharding:
    configDB: "config/192.168.55.31:27077,192.168.55.32:27077,192.168.55.33:27077"
EOF

cat > /usr/lib/systemd/system/mongos.service <<EOF
[Unit]
Description=MongoDB Database mongos Service
Wants=network.target
After=network.target

[Service]
Type=forking
PIDFile=/var/lib/mongodb/mongos/log/mongod.pid
ExecStart=/usr/bin/mongos -f /etc/mongodb/conf/mongos.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF

# enable mongo routers
systemctl enable mongos
systemctl restart mongos

get_router_status() {
    mongo --quiet --port 27088 -- "admin" <<EOS
sh.status()
EOS
}

if [ "${myip}" = "192.168.55.31" ]; then
    router_status=$(get_router_status | grep -w ok | awk '{print $NF}')
    if [ "${router_status}" != "1," ]; then
        mongo --port 27088 -- "admin" <<EOS
use admin
sh.addShard("shard1/192.168.55.31:27017,192.168.55.32:27017,192.168.55.33:27017")
sh.addShard("shard2/192.168.55.31:27018,192.168.55.32:27018,192.168.55.33:27018")
sh.addShard("shard3/192.168.55.31:27019,192.168.55.32:27019,192.168.55.33:27019")
sh.status()
EOS
    fi
fi
