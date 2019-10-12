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
mkdir -p /pxeboot/{images,pxelinux.cfg}
cp -rf /usr/share/syslinux/{pxelinux.0,menu.c32,vesamenu.c32} /pxeboot

# generate ssh key pair
if [ ! -d ~/.ssh ]; then
    mkdir ~/.ssh
fi
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
fi

# auto change work directory
workdir=$(cd $(dirname $0) && pwd); cd ${workdir}
if [ "${workdir}" != "/pxeboot" ]; then
    cp -f * /pxeboot
    exec /pxeboot/setup.sh
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
tftp-root=/pxeboot

dhcp-match=set:bios_mode,option:client-arch,0
dhcp-boot=tag:bios_mode,pxelinux.0

dhcp-match=set:efi_mode_v6,option:client-arch,6
dhcp-boot=tag:efi_mode_v6,BOOTIA32.EFI

dhcp-match=set:efi_mode_v7,option:client-arch,7
dhcp-boot=tag:efi_mode_v7,BOOTX64.EFI

dhcp-match=set:efi_mode_v9,option:client-arch,9
dhcp-boot=tag:efi_mode_v9,BOOTX64.EFI

# PXEClient:Arch:00000
pxe-service=tag:bios_mode,X86PC, "Boot BIOS PXE", pxelinux

# PXEClient:Arch:00006
pxe-service=tag:efi_mode_v6, IA32_EFI, "Boot IA32_EFI PXE", BOOTIA32.EFI

# PXEClient:Arch:00007
pxe-service=tag:efi_mode_v7, BC_EFI, "Boot UEFI PXE-BC", BOOTX64.EFI

# PXEClient:Arch:00009
pxe-service=tag:efi_mode_v9, X86-64_EFI, "Boot UEFI PXE-64", BOOTX64.EFI
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

function load_video {
  insmod efi_gop
  insmod efi_uga
  insmod video_bochs
  insmod video_cirrus
  insmod all_video
}

load_video
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
	isodir=${isofile%.iso}
	if [ ! -d ${isodir} ]; then
		mkdir -p images/${isodir}/iso
	fi
	if ! mount | grep -q -w "${isofile}"; then
		mount -o loop ${iso} images/${isodir}/iso
	fi
	cp -f ks.template images/${isodir}/ks.cfg
	sed -i "s|{{NFSHOST}}|${nfshost}|g" images/${isodir}/ks.cfg
	sed -i "s|{{ISODIR}}|/pxeboot/images/${isodir}/iso|g" images/${isodir}/ks.cfg

        pubkey=$(cat ~/.ssh/id_rsa.pub)
        sed -i "s|{{SSHPUBKEY}}|${pubkey}|g" images/${isodir}/ks.cfg

	echo "/pxeboot/images/${isodir} *(rw,sync,no_subtree_check,all_squash)" >> /etc/exports
	echo "/pxeboot/images/${isodir}/iso *(rw,sync,no_subtree_check,all_squash)" >> /etc/exports

	cat >> bios_default << EOS
LABEL ${isodir}
        MENU LABEL ${isodir}
        kernel /images/${isodir}/iso/isolinux/vmlinuz
        append initrd=/images/${isodir}/iso/isolinux/initrd.img ksdevice=bootif kssendmac ks=nfs:${nfshost}:/pxeboot/images/${isodir}/ks.cfg
        ipappend 2
EOS

	cat >> uefi_default << EOS
menuentry 'Install ${isodir}' {
        linuxefi /images/${isodir}/iso/images/pxeboot/vmlinuz ksdevice=bootif kssendmac ks=nfs:${nfshost}:/pxeboot/images/${isodir}/ks.cfg
        initrdefi /images/${isodir}/iso/images/pxeboot/initrd.img
}

EOS
done

cat >> bios_default << EOF

MENU end
EOF

mv -f bios_default pxelinux.cfg/default
mv -f uefi_default grub.cfg

exportfs -au
systemctl restart nfs
exportfs -av
