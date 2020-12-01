#!/bin/bash
set -ex

##################################################################
RGW_USER=${RGW_USER:-admin}
RGW_ACCESSKEY=${RGW_ACCESSKEY:-admin}
RGW_SECRET=${RGW_SECRET:-admin}
RGW_BUCKET=${RGW_BUCKET:-demobkt}
##################################################################
# change work directory
mkdir -p /opt/ceph-deploy; cd /opt/ceph-deploy

# change root login password
echo "root:r00tme" | chpasswd

## setup hosts file
DEFAULTIP=$(ip r get 1 | grep src | awk '{print $NF}')
cat > /etc/hosts << HOSTS
127.0.0.1  localhost
${DEFAULTIP} $(hostname) $(hostname)
HOSTS

ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
touch ~/.ssh/config
cat > ~/.ssh/config << CFG
LogLevel error
ServerAliveInterval 30
ServerAliveCountMax 6
StrictHostKeyChecking no
UserKnownHostsFile /dev/null
CFG
pushd ~/.ssh/ > /dev/null
cat id_rsa.pub > authorized_keys
popd > /dev/null

sed -e 's/^#PermitRootLogin .*$/PermitRootLogin yes/g' \
    -e 's/^PasswordAuthentication .*$/PasswordAuthentication yes/g' \
    -e 's/^#UseDNS .*/UseDNS no/g' \
    -e 's/^GSSAPIAuthentication .*/GSSAPIAuthentication no/g' \
    -i /etc/ssh/sshd_config
systemctl restart sshd

# disable selinux
setenforce 0
sed -i -e 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

# set timezone
timedatectl set-timezone Asia/Shanghai

# set language
echo "LANG=en_US.UTF-8" > /etc/environment
echo "LC_ALL=C" > /etc/environment

## disable ipv6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
echo 1 > /proc/sys/net/ipv6/conf/default/disable_ipv6

cat > /etc/sysctl.d/disable_ipv6.conf  <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

## config yum repo
echo > /etc/yum.repos.d/ceph.repo << REPO
[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm-jewel/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
REPO
export CEPH_DEPLOY_REPO_URL=http://mirrors.aliyun.com/ceph/rpm-jewel/el7
export CEPH_DEPLOY_GPG_URL=http://mirrors.aliyun.com/ceph/keys/release.asc
export CEPH_NODE=$(hostname -s)

## install base packages
yum install -y epel-release
yum clean all
yum install -y net-tools python-pip
pip install 'ceph-deploy===1.5.39'

## install ceph packages
ceph-deploy install $CEPH_NODE

## generate config file
ceph-deploy new $CEPH_NODE
echo "osd crush chooseleaf type = 0" >> ceph.conf
echo "osd pool default size = 1" >> ceph.conf

## install ceph monitor
ceph-deploy mon create-initial

## format and add osd
mkdir -p /var/lib/ceph/osd/osd{0..2}
ceph-deploy osd prepare  $CEPH_NODE:/var/lib/ceph/osd/osd0
ceph-deploy osd prepare  $CEPH_NODE:/var/lib/ceph/osd/osd1
ceph-deploy osd prepare  $CEPH_NODE:/var/lib/ceph/osd/osd2
sudo chown ceph:ceph /var/lib/ceph/osd/osd0/
sudo chown ceph:ceph /var/lib/ceph/osd/osd1/
sudo chown ceph:ceph /var/lib/ceph/osd/osd2/
ceph-deploy osd activate $CEPH_NODE:/var/lib/ceph/osd/osd0
ceph-deploy osd activate $CEPH_NODE:/var/lib/ceph/osd/osd1
ceph-deploy osd activate $CEPH_NODE:/var/lib/ceph/osd/osd2

## check ceph status
ceph -s

## deploy radosgw
ceph-deploy rgw create $CEPH_NODE
radosgw-admin user create --uid=${RGW_USER} --display-name=${RGW_USER} --access-key=${RGW_ACCESSKEY} --secret=${RGW_SECRET}

## config rgw client
cat > ${HOME}/.s3cfg << CFG
[default]
host_base = ${CEPH_NODE}:7480
host_bucket = ${CEPH_NODE}:7480
access_key = ${RGW_ACCESSKEY}
secret_key = ${RGW_SECRET}
use_https = False
signature_v2 = True
CFG

## test rgw functions
pip install s3cmd
s3cmd mb s3://${RGW_BUCKET}
s3cmd put $0 s3://${RGW_BUCKET}/
s3cmd ls s3://${RGW_BUCKET}/
