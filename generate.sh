#! /usr/bin/env bash

set -euo pipefail
#set -x

HERE=$(dirname "$BASH_SOURCE")

ARCHLIVE="$HERE/archlive"
WORK="/tmp/liveiso-kexec-boot"
OUT="$HERE/out"
ZFSER_KEXECER="$HERE/zfser-kexecer.sh"

PACKAGES="$ARCHLIVE/packages.x86_64"
PACMAN="$ARCHLIVE/pacman.conf"
PROFILEDEF="$ARCHLIVE/profiledef.sh"
SYSLINUX="$ARCHLIVE/syslinux/syslinux-linux.cfg"
SYSTEMD_SERVICES_DIR="/etc/systemd/system"
SERVICES_DIR="$ARCHLIVE/airootfs/$SYSTEMD_SERVICES_DIR"
SERVICES_ENABLED_DIR="$ARCHLIVE/airootfs/etc/systemd/system/multi-user.target.wants"
SERVICE_NAME="boot-into-other-os-using-kexec"

# main

rm -rf "$ARCHLIVE"
cp -r /usr/share/archiso/configs/baseline "$ARCHLIVE"

{
	echo '[archzfs]'
	echo '# Origin Server - Finland'
	echo 'Server = http://archzfs.com/$repo/$arch'
	echo '# Mirror - Germany'
	echo 'Server = http://mirror.sum7.eu/archlinux/archzfs/$repo/$arch'
	echo '# Mirror - Germany'
	echo 'Server = http://mirror.sunred.org/archzfs/$repo/$arch'
	echo '# Mirror - Germany'
	echo 'Server = https://mirror.biocrafting.net/archlinux/archzfs/$repo/$arch'
	echo '# Mirror - India'
	echo 'Server = https://mirror.in.themindsmaze.com/archzfs/$repo/$arch'
	echo '# Mirror - US'
	echo 'Server = https://zxcvfdsa.com/archzfs/$repo/$arch'
} >> "$PACMAN"

# {
# 	#echo squashfs-tools
# 	echo kexec-tools
# 	echo linux-headers
# 	echo zfs-dkms
# } >> "$PACKAGES"
(cat << EOF

# we need one of these for the zfs dkms to work
base
bcachefs-tools
bind
bolt
brltty
broadcom-wl
btrfs-progs
clonezilla
cloud-init
cryptsetup

# the important stuff
kexec-tools
linux-headers
zfs-dkms

EOF
) >> "$PACKAGES"

# faster ISO generation
sed -i -z 's%\nairootfs_image_type="erofs"\n%\nairootfs_image_type="squashfs"\n%' "$PROFILEDEF"
sed -i -z "s%\nairootfs_image_tool_options=('-zlzma,109' -E 'ztailpacking,fragments,dedupe')\n%\nairootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')\n%" "$PROFILEDEF"

# copytoram
sed -i -z 's$\nAPPEND archisobasedir=%INSTALL_DIR% archisodevice=UUID=%ARCHISO_UUID%\n$\nAPPEND archisobasedir=%INSTALL_DIR% archisodevice=UUID=%ARCHISO_UUID% copytoram=y\n$' "$SYSLINUX"

# copy the executable

cp "$ZFSER_KEXECER" "$ARCHLIVE/airootfs/boot-other-os.sh"

# add the service

(cat << EOF

[Unit]
Description=Boot into the other operating system using kexec

[Service]
ExecStart=/bin/bash -c 'chmod +x /boot-other-os.sh && /boot-other-os.sh'

[Install]
WantedBy=multi-user.target

EOF
) > "$SERVICES_DIR/$SERVICE_NAME.service"

# enable the service

ln -s "$SYSTEMD_SERVICES_DIR/$SERVICE_NAME.service" "$SERVICES_ENABLED_DIR"

# compile the ISO file

sudo rm -rf "$WORK"
sudo mkarchiso -v -w "$WORK" -o "$OUT" "$ARCHLIVE"

# run in vm

echo
echo "To run in VM use: run_archiso -i $OUT/archlinux-*-x86_64.iso"
