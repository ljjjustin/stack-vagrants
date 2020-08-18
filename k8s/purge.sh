#!/bin/bash


stop_all_k8s_services() {
    while true
    do
        if docker ps | grep -q k8s_; then
            for d in $(docker ps | grep k8s_ | awk '{print $1}'); do docker stop $d; done
            sleep 3
            continue
        fi
        break
    done
}

remove_all_k8s_services() {
    for d in $(docker ps -a | grep k8s_ | awk '{print $1}'); do docker rm $d; done
}

clear_iptable_rules() {
    for table in $(echo filter nat mangle raw)
    do
        iptables -t $table -F
        iptables -t $table -X
    done
}
systemctl stop kubelet
stop_all_k8s_services
remove_all_k8s_services
clear_iptable_rules

rm -fr /etc/kubernetes/
rm -fr /var/lib/etcd/
rm -fr /var/lib/kubelet/

systemctl restart docker
