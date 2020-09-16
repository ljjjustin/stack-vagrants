#!/bin/bash

# auto change work directory
workdir=$(cd $(dirname $0) && pwd)

cd ${workdir}

# change password
echo r00tme | passwd --stdin root
# setup ssh key
if [[ ! -d ~/.ssh ]]; then
    mkdir -p ~/.ssh
fi
if [[ ! -f ~/.ssh/config ]]; then
    cp -f ./ssh/ssh-config ~/.ssh/config
    chmod 0600 ~/.ssh/config
fi
if [[ ! -f ~/.ssh/id_rsa ]]; then
    cp -f ./ssh/id_rsa ~/.ssh/
    chmod 0400 ~/.ssh/id_rsa
fi
if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
    cp -f ./ssh/id_rsa.pub ~/.ssh/
    cat ./ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    chmod 0400 ~/.ssh/id_rsa.pub
fi

# change yum config
if ! grep -q ip_resolve /etc/yum.conf; then
    echo "ip_resolve=4" >> /etc/yum.conf
fi

# config hosts
cat > /etc/hosts << EOF
127.0.0.1     localhost
10.211.55.2   docker.io

192.168.55.31 openshift-master1
192.168.55.32 openshift-worker1
192.168.55.33 openshift-worker2
EOF
# shutdown firewalld and selinux
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
systemctl disable firewalld
systemctl stop firewalld

# close swap
swapoff -a
sed -i '/swap/d' /etc/fstab

# enable iptables
ensure_sysctl_config() {
    local key=$1
    local val=$2

    if ! grep -q "${key}" /etc/sysctl.conf; then
        echo "${key} = ${val}" >> /etc/sysctl.conf
    fi
    sysctl -p
}
modprobe br_netfilter
ensure_sysctl_config net.ipv4.ip_forward 1
ensure_sysctl_config net.bridge.bridge-nf-call-iptables 1
ensure_sysctl_config net.bridge.bridge-nf-call-ip6tables 1

# install docker
if rpm -q docker | grep -q 'not installed'; then
    yum -y install docker
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
    "insecure-registries":[
        "http://docker.io"
    ]
}
EOF
    systemctl daemon-reload
    systemctl enable docker
    systemctl restart docker
fi

if [ "$(hostname)" = "openshift-master1" ]; then
    images=(
        docker.io/cockpit/kubernetes
        docker.io/openshift/origin-haproxy-router
        docker.io/openshift/origin-service-catalog
        docker.io/openshift/origin-node
        docker.io/openshift/origin-deployer
        docker.io/openshift/origin-control-plane
        docker.io/openshift/origin-template-service-broker
        docker.io/openshift/origin-pod
        docker.io/cockpit/kubernetes
        docker.io/openshift/origin-web-console
        quay.io/coreos/etcd
    )
    for image in ${images[@]}; do docker pull $image; done

elif [[ "$(hostname)" =~ ^openshift-worker[0-9]$ ]]; then
    images=(
        docker.io/openshift/origin-haproxy-router
        docker.io/openshift/origin-node
        docker.io/openshift/origin-deployer
        docker.io/openshift/origin-pod
        docker.io/ansibleplaybookbundle/origin-ansible-service-broker
        docker.io/openshift/origin-docker-registry
    )
    for image in ${images[@]}; do docker pull $image; done
fi
