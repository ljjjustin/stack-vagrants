#!/bin/bash

#vagrant up

ssh root@192.168.56.11 /bin/bash  << EOF
/vagrant/setup-yum-repo.sh

sleep 3

yum install -y tbds-portal

tbds-portal setup-gaiastack eth1

tbds-portal start
EOF

clush -g all --copy TBDS.repo --dest /etc/yum.repos.d/
