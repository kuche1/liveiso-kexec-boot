#! /usr/bin/env bash

set -euo pipefail
set -x

# mount
zpool import -R /mnt -f bpool

# get name
VMLINUZ=$(basename $(readlink -f /mnt/boot/vmlinuz))

# set kexec
kexec -l /mnt/boot/vmlinuz --initrd=/mnt/boot/initrd.img --command-line="BOOT_IMAGE=/BOOT/ubuntu_7drhbs@/$VMLINUZ root=ZFS=rpool/ROOT/ubuntu_7drhbs ro noquiet nosplash"

# reboot
systemctl kexec
