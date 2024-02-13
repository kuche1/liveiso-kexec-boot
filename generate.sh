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

# copy preset

rm -rf "$ARCHLIVE"
cp -r /usr/share/archiso/configs/baseline "$ARCHLIVE"

# remove unneeded packages

sed -i -z 's%\nvirtualbox-guest-utils-nox\n%\n%' "$PACKAGES"
sed -i -z 's%\nqemu-guest-agent\n%\n%' "$PACKAGES"
sed -i -z 's%\nopen-vm-tools\n%\n%' "$PACKAGES"
sed -i -z 's%\nopenssh\n%\n%' "$PACKAGES"
sed -i -z 's%\nhyperv\n%\n%' "$PACKAGES"

# add repo

# https://github.com/archzfs/archzfs/wiki
#
# you will also need to add the repo on the host PC
# and you will need to trust the keys
#
# pacman-key -r DDF7DB817396A49B2A2723F7403BD972F75D9D76
# pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76

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

# add packages

(cat << EOF

# kexec
kexec-tools

# zfs dependencies
linux-headers

clonezilla
# for some reason "zfs satus" doesn't work without this and modprobe of zfs also doesn't work; it's probably 1 of the packages this depends on this

# zfs
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
