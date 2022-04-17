#!/bin/sh
# Run this script as root after the installation outside the boot medium

# TODO: virtualbox-guest-utils is only needed in VM mode
# TODO: polkit is needed
# pacman -S virtualbox-guest-utils

readonly USER_NAME="alex"

readonly INTERFACE=$(ls /sys/class/net | grep en)
systemctl enable dhcpcd@${INTERFACE}.service
systemctl enable ufw.service

systemctl start dhcpcd@${INTERFACE}.service
systemctl start ufw.service

ufw default deny incoming
ufw default allow outgoing
useradd -mG games,wheel,sys,log,rfkill,ftp,http $USER_NAME
timedatectl set-ntp true

echo "Enter password for: ${USER_NAME}"
passwd $USER_NAME
