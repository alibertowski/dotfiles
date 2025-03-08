#!/bin/sh

arch-chroot /mnt pacman -S syslinux

mkdir /mnt/boot/syslinux
cp /mnt/usr/lib/syslinux/bios/*.c32 /mnt/boot/syslinux/
arch-chroot /mnt extlinux --install /boot/syslinux
dd bs=440 count=1 conv=notrunc if=/mnt/usr/lib/syslinux/bios/mbr.bin of=/dev/sda

# Broken for now vvvv
# syslinux-install_update -i -a -m -c /mnt

cp ../configurations/syslinux/syslinux.cfg /mnt/boot/syslinux
sed -i "s/UUID=X/UUID=$(lsblk -dno UUID /dev/sda2)/" /mnt/boot/syslinux/syslinux.cfg

# TODO: Bootloader password?
