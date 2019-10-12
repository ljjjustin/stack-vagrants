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

ensure_packages dnsmasq syslinux nfs-utils

systemctl enable dnsmasq nfs

# setup directories
TOPDIR=/pxeboot
TFTPBOOT=${TOPDIR}/images
mkdir -p ${TFTPBOOT}/pxelinux.cfg
cp -rf /usr/share/syslinux/{pxelinux.0,menu.c32,vesamenu.c32} ${TFTPBOOT}

# generate ssh key pair
if [ ! -d ~/.ssh ]; then
    mkdir ~/.ssh
fi
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
fi

# auto change work directory
workdir=$(cd $(dirname $0) && pwd); cd ${workdir}
if [ "${workdir}" != "${TOPDIR}" ]; then
    cp -af images ks.template pxerc setup.sh ${TOPDIR}
    exec ${TOPDIR}/setup.sh
fi

# config all components
source ./pxerc

## config dnsmasq
cat > /etc/dnsmasq.conf << EOF
port=0
interface=${DHCP_INTERFACE}
dhcp-range=${DHCP_RANGE},${DHCP_NETMASK}
dhcp-option=option:router,${DHCP_GATEWAY}

enable-tftp
tftp-root=${TFTPBOOT}

# PXEClient:Arch:00000
dhcp-match=set:bios_mode,option:client-arch,0
dhcp-boot=tag:bios_mode,pxelinux.0
pxe-service=tag:bios_mode,X86PC,"Boot BIOS PXE",pxelinux

# PXEClient:Arch:00006
dhcp-match=set:uefi_mode_v6,option:client-arch,6
dhcp-boot=tag:uefi_mode_v6,grubia32.efi
pxe-service=tag:uefi_mode_v6,IA32_EFI,"Boot 32 Bits EFI PXE",grubia32.efi

# PXEClient:Arch:00007
dhcp-match=set:uefi_mode_v7,option:client-arch,7
dhcp-boot=tag:uefi_mode_v7,grubx64.efi
pxe-service=tag:uefi_mode_v7,BC_EFI,"Boot 64 Bits UEFI PXE",grubx64.efi

# PXEClient:Arch:00009
dhcp-match=set:uefi_mode_v9,option:client-arch,9
dhcp-boot=tag:uefi_mode_v9,grubx64.efi
pxe-service=tag:uefi_mode_v9,X86-64_EFI,"Boot 64 Bits UEFI PXE",grubx64.efi
EOF
systemctl restart dnsmasq

# start services
nfshost=$(ip r get ${DHCP_GATEWAY} | grep -w src| awk '{print $NF}')

cat > bios_default <<  EOF
DEFAULT menu.c32
PROMPT 0
MENU TITLE LJJ PXE Server
TIMEOUT 600
ONTIMEOUT local

LABEL local
        MENU LABEL (local)
        MENU DEFAULT
        LOCALBOOT -1

EOF

cat > uefi_default <<  EOF
set default="0"
set timeout=60

insmod efi_gop
insmod efi_uga
insmod video_bochs
insmod video_cirrus
insmod all_video
insmod gzio
insmod part_gpt
insmod ext2

menuentry 'Boot from local disk' {
    set root=(hd0)
    chainloader +1
}

EOF

echo -n > /etc/exports

for iso in $(find /srv/ -name "*.iso" | sort)
do
	isofile=$(basename ${iso})
	isoname=${isofile%.iso}
        isomountdir=${TFTPBOOT}/${isoname}/iso
        ksconfig=${TFTPBOOT}/${isoname}/ks.cfg

	if [ ! -d ${isomountdir} ]; then
		mkdir -p ${isomountdir}
	fi
	if ! mount | grep -q -w "${isofile}"; then
		mount -o loop ${iso} ${isomountdir}
	fi
	cp -f ks.template ${ksconfig}
        pubkey=$(cat ~/.ssh/id_rsa.pub)
	sed -i "s|{{NFSHOST}}|${nfshost}|g" ${ksconfig}
	sed -i "s|{{ISODIR}}|${isomountdir}|g" ${ksconfig}
        sed -i "s|{{SSHPUBKEY}}|${pubkey}|g" ${ksconfig}

	echo "${TFTPBOOT}/${isoname} *(rw,sync,no_subtree_check,all_squash)" >> /etc/exports
	echo "${isomountdir} *(rw,sync,no_subtree_check,all_squash)" >> /etc/exports

	cat >> bios_default << EOS
LABEL ${isoname}
        MENU LABEL ${isoname}
        kernel ${isomountdir}/isolinux/vmlinuz
        append initrd=${isomountdir}/isolinux/initrd.img ks=nfs:${nfshost}:${ksconfig} ksdevice=bootif kssendmac
        ipappend 2
EOS

	cat >> uefi_default << EOS
menuentry 'Install ${isoname}' {
        linuxefi ${isomountdir}/images/pxeboot/vmlinuz ks=nfs:${nfshost}:${ksconfig} ksdevice=bootif kssendmac
        initrdefi ${isomountdir}/images/pxeboot/initrd.img
}

EOS
done

cat >> bios_default << EOF

MENU end
EOF

mv -f bios_default ${TFTPBOOT}/pxelinux.cfg/default
mv -f uefi_default ${TFTPBOOT}/grub.cfg

exportfs -au
systemctl restart nfs
exportfs -av
