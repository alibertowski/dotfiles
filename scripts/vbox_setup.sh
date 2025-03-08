#!/bin/sh

arch-chroot /mnt pacman -S virtualbox-guest-utils
arch-chroot /mnt systemctl enable vboxservice.service
