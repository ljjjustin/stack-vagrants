#!/bin/bash

# change password
echo r00tme | passwd --stdin root

# change yum config
if ! grep -q ip_resolve /etc/yum.conf; then
    echo "ip_resolve=4" >> /etc/yum.conf
fi

# auto change work directory
workdir=$(cd $(dirname $0) && pwd)

cd ${workdir}

# shutdown firewalld and selinux
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
systemctl disable firewalld
systemctl stop firewalld

# close swap
swapoff -a
sed -i '/swap/d' /etc/fstab

# install docker
if rpm -q docker-ce | grep -q 'not installed'; then
    yum -y remove docker-client docker-client-latest docker-common docker-latest docker-logrotate docker-latest-logrotate docker-selinux docker-engine-selinux docker-engine
    yum -y install yum-utils lvm2 device-mapper-persistent-data nfs-utils xfsprogs wget
    yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    yum -y install docker-ce docker-ce-cli containerd.io
    mkdir -p /etc/systemd/system/docker.service.d/
    cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "registry-mirrors":[
        "https://docker.mirrors.ustc.edu.cn",
        "http://hub-mirror.c.163.com",
        "https://registry.docker-cn.com"
    ]
}
EOF
    systemctl daemon-reload
    systemctl enable docker
    systemctl restart docker
fi


yum install -y mariadb-server
systemctl enable mariadb
systemctl start mariadb
sleep 3

mysql -e "grant all on *.* to root identified by 'r00tme'"

# start node exporter
docker run -d -p 9100:9100 -v "/:/host:ro,rslave" --pid="host" quay.io/prometheus/node-exporter --path.rootfs /host
docker run -d -p 9104:9104 -e DATA_SOURCE_NAME="root:r00tme@(192.168.55.31:3306)/test" prom/mysqld-exporter
docker run -d -p 127.0.0.1:9090:9090 quay.io/prometheus/prometheus

#
if rpm -q grafana | grep -q 'not installed'; then
    cat > /etc/yum.repo.d/grafana.repo << EOF
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
    yum install -y grafana
    systemctl enable grafana-server
    systemctl start grafana-server
fi
