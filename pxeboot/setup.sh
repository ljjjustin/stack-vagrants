#!/bin/bash

# ensure packages
ensure_packages() {
    for pkg in $@
    do
        rpm -q ${pkg} > /dev/null
        if [ $? -ne 0 ]; then
            yum install -y ${pkg}
        fi
    done
}

ensure_packages dnsmasq xinetd syslinux nfs-utils tftp-server

systemctl enable dnsmasq xinetd nfs

# setup directories
mkdir -p /var/lib/tftpboot/{images,pxelinux.cfg}
touch /var/lib/tftpboot/pxelinux.cfg/default
cp -rf /usr/share/syslinux/* /var/lib/tftpboot

# generate ssh key pair
if [ ! -d ~/.ssh ]; then
    mkdir ~/.ssh
fi
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
fi

# auto change work directory
workdir=$(cd $(dirname $0) && pwd); cd ${workdir}
if [ "${workdir}" != "/var/lib/tftpboot" ]; then
    cp -f pxerc ks.template setup.sh /var/lib/tftpboot
    exec /var/lib/tftpboot/setup.sh
fi

# config all components
source ./pxerc

## config dnsmasq
cat > /etc/dnsmasq.conf << EOF
port=0
interface=${DHCP_INTERFACE}
dhcp-range=${DHCP_RANGE},${DHCP_NETMASK}
dhcp-option=3,${DHCP_GATEWAY}
pxe-service=x86PC, "PXE Boot Menu", pxelinux
dhcp-boot=pxelinux.0
enable-tftp
tftp-root=/var/lib/tftpboot
EOF
systemctl restart dnsmasq

# config tftp
cat > /etc/xinetd.d/tftp <<EOF
service tftp
{
    disable = no
    socket_type = dgram
    protocol = udp
    wait = yes
    user = root
    server = /usr/sbin/in.tftpd
    server_args = -s /var/lib/tftpboot
    per_source = 11
    cps = 100 2
    flags = IPv4
}
EOF
systemctl restart dnsmasq

# start services
nfshost=$(ip r get ${DHCP_GATEWAY} | grep -w src| awk '{print $NF}')

cat > default <<  EOF
DEFAULT menu.c32
PROMPT 0
MENU TITLE LJJ PXE Server
TIMEOUT 200
TOTALTIMEOUT 6000
ONTIMEOUT local

LABEL local
        MENU LABEL (local)
        MENU DEFAULT
        LOCALBOOT -1

EOF

echo -n > /etc/exports

for iso in $(find /srv/ -name "*.iso" | sort)
do
	isofile=$(basename ${iso})
	isodir=${isofile%.iso}
	if [ ! -d ${isodir} ]; then
		mkdir -p images/${isodir}/iso
	fi
	if ! mount | grep -q -w "${isofile}"; then
		mount -o loop ${iso} images/${isodir}/iso
	fi
	cp -f ks.template images/${isodir}/ks.cfg
	sed -i "s|{{NFSHOST}}|${nfshost}|g" images/${isodir}/ks.cfg
	sed -i "s|{{ISODIR}}|/var/lib/tftpboot/images/${isodir}/iso|g" images/${isodir}/ks.cfg

        pubkey=$(cat ~/.ssh/id_rsa.pub)
        sed -i "s|{{SSHPUBKEY}}|${pubkey}|g" images/${isodir}/ks.cfg

	echo "/var/lib/tftpboot/images/${isodir} *(rw,sync,no_subtree_check,all_squash)" >> /etc/exports
	echo "/var/lib/tftpboot/images/${isodir}/iso *(rw,sync,no_subtree_check,all_squash)" >> /etc/exports

	cat >> default << EOS
LABEL ${isodir}
        MENU LABEL ${isodir}
        kernel /images/${isodir}/iso/isolinux/vmlinuz
        append initrd=/images/${isodir}/iso/isolinux/initrd.img ksdevice=bootif kssendmac ks=nfs:${nfshost}:/var/lib/tftpboot/images/${isodir}/ks.cfg
        ipappend 2

EOS
done

cat >> default << EOF

MENU end
EOF

mv -f default pxelinux.cfg
exportfs -au
systemctl restart nfs
exportfs -av
