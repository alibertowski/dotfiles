#!/bin/bash
# Run this script as root after the installation outside the boot medium

# TODO:
#   Fix for both BIOS/UEFI
#   Setup xorg/wayland
#   Add guide for multiple monitors

readonly VM="y"
readonly USER_NAME="alex"
readonly INTERFACE
INTERFACE=$(ls /sys/class/net/en*)

systemctl enable dhcpcd@"${INTERFACE}".service
systemctl enable ufw.service

systemctl start dhcpcd@"${INTERFACE}".service

ufw default deny incoming
ufw default allow outgoing
ufw enable

if [ "$VM" = "y" ]; then
    pacman -S --noconfirm virtualbox-guest-utils
    systemctl enable vboxservice.service
    systemctl start vboxservice.service

    useradd -mG games,wheel,sys,log,rfkill,ftp,http,vboxsf $USER_NAME
else
    useradd -mG games,wheel,sys,log,rfkill,ftp,http $USER_NAME
fi

timedatectl set-ntp true
sed -i "s/# deny = 3/deny = 0/" /etc/security/faillock.conf
echo '%wheel ALL=(ALL:ALL) ALL' | SUDO_EDITOR='tee -a' visudo

# Pacman configurations
sed -i "s/#Color/Color/" /etc/pacman.conf
sed -i "s/#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf
sed -i "s/#[multilib]/[multilib]/" /etc/pacman.conf
sed -i "s%#Include = /etc/pacman.d/mirrorlist%Include = /etc/pacman.d/mirrorlist%" /etc/pacman.conf
pacman -Syu --noconfirm
pacman -S --noconfirm pipewire lib32-pipewire wireplumber pipewire-alsa pipewire-pulse galculator kitty neofetch

echo "Enter password for: ${USER_NAME}"
passwd $USER_NAME
