#!/bin/sh

arch-chroot /mnt pacman -S ufw
arch-chroot /mnt systemctl enable ufw.service

INTERFACE=$(find /sys/class/net/en* | awk -F/ '{print $NF}')
arch-chroot /mnt ufw default deny incoming
arch-chroot /mnt ufw default allow outgoing
arch-chroot /mnt ufw allow in on "$INTERFACE" from 192.168.0.0/24
arch-chroot /mnt ufw enable
