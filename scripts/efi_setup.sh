#!/bin/sh

mkdir -p /mnt/efi/EFI/Linux
mkdir -p /mnt/etc/cmdline.d
cat ./boot/root.conf > /mnt/etc/cmdline.d/root.conf
cat ./boot/linux.preset > /mnt/etc/mkinitcpio.d/linux.preset

sed -i "s/UUID=X/UUID=$(lsblk -dno UUID /dev/sda3)/" /mnt/etc/cmdline.d/root.conf
arch-chroot /mnt mkinitcpio -p linux

efibootmgr --create --disk /dev/sda --part 1 --label "Arch Linux" --loader '\EFI\Linux\arch-linux.efi' --unicode --verbose
efibootmgr --create --disk /dev/sda --part 1 --label "Arch Linux-Fallback" --loader '\EFI\Linux\arch-linux-fallback.efi' --unicode --verbose
