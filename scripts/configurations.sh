#!/bin/sh

sed -i "s%#\[multilib\]%[multilib]\nInclude = /etc/pacman.d/mirrorlist%" /mnt/etc/pacman.conf
sed -i "s/#ParallelDownloads/ParallelDownloads/" /mnt/etc/pacman.conf
arch-chroot /mnt pacman -Syu

arch-chroot /mnt systemctl enable paccache.timer

{
    printf "127.0.0.1\tlocalhost\n"
    printf "::1\tlocalhost\n"
    printf "127.0.1.1\tretro-desktop\n"
} >> /mnt/etc/hosts
