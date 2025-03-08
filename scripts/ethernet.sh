#!/bin/sh

cat ./boot/20-wired.network > /mnt/etc/systemd/network/20-wired.network
arch-chroot /mnt systemctl enable systemd-networkd.service
arch-chroot /mnt systemctl enable systemd-resolved.service
