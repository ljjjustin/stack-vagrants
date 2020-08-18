#!/bin/bash

# change password
echo r00tme | passwd --stdin root

# change yum config
if ! grep -q ip_resolve /etc/yum.conf; then
    echo "ip_resolve=4" >> /etc/yum.conf
fi

# config hosts
cat > /etc/hosts << EOF
192.168.55.31 k8s-master1
192.168.55.32 k8s-worker1
192.168.55.33 k8s-worker2

192.168.55.31 master1.k8s.com
EOF
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

# enable iptables
ensure_sysctl_config() {
    local key=$1
    local val=$2

    if ! grep -q "${key}" /etc/sysctl.conf; then
        echo "${key} = ${val}" >> /etc/sysctl.conf
    fi
    sysctl -p
}
modprobe net_brfilter
ensure_sysctl_config net.ipv4.ip_forward 1
ensure_sysctl_config net.bridge.bridge-nf-call-iptables 1
ensure_sysctl_config net.bridge.bridge-nf-call-ip6tables 1

# install docker
if rpm -q docker-ce | grep -q 'not installed'; then
    yum -y remove docker-client docker-client-latest docker-common docker-latest docker-logrotate docker-latest-logrotate docker-selinux docker-engine-selinux docker-engine
    yum -y install yum-utils lvm2 device-mapper-persistent-data nfs-utils xfsprogs wget
    yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    yum -y install docker-ce docker-ce-cli containerd.io
    mkdir -p /etc/systemd/system/docker.service.d/
    cat /etc/systemd/system/docker.service.d/http-proxy.conf << EOF
[Service]
Environment="HTTP_PROXY=http://10.211.55.2:6152" "HTTPS_PROXY=http://10.211.55.2:6152"
EOF
    cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "registry-mirrors":[
        "http://hub-mirror.c.163.com",
        "https://docker.mirrors.ustc.edu.cn",
        "https://registry.docker-cn.com"
    ]
}
EOF
    systemctl daemon-reload
    systemctl enable docker
    systemctl restart docker
fi

# install k8s
if rpm -q kubelet | grep -q 'not installed'; then
    yum -y remove kubelet kubadm kubctl
    cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
EOF
    yum -y install kubelet kubeadm kubectl
    systemctl enable kubelet
fi

# install k8s master
cat > k8s.env.sh << EOF
export MASTER_IP=192.168.55.31
export APISERVER_NAME=master1.k8s.com
EOF
sh k8s.env.sh

if [ "$(hostname)" = "k8s-master1" ]; then
    kubeadm init --config=init.yaml --upload-certs
    if [ ! -d $HOME/.kube ]; then
        mkdir -p $HOME/.kube
        chown $(id -u):$(id -g) $HOME/.kube/config
    fi
    if ! grep -q 'KUBECONFIG' ~/.kube/config; then
            echo export KUBECONFIG=~/.kube/config >> ~/.bashrc
    fi
    source ~/.bashrc
    rm -f $HOME/.kube/config
    cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    kubeadm token create --print-join-command > node.join.sh
    # copy to all workers
    kubectl apply -f calico.yaml
    kubectl -n kube-system get secret $(kubectl -n kube-system get secret | grep kuboard-user | awk '{print $1}') -o go-template='{{.data.token}}' | base64 -d > admin-token
elif [[ "$(hostname)" =~ ^k8s-worker[0-9]$ ]]; then
    for ((i=0; i < 60; i++)); do
        if [ -f node.join.sh ]; then
            source ./k8s.env.sh
            source ./node.join.sh
            break
        fi
        sleep 5
    done
fi
