#!/bin/sh

arch-chroot /mnt pacman -S apparmor
arch-chroot /mnt systemctl enable apparmor.service
