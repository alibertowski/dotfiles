#!/bin/sh

echo "Boot Mode: $(cat /sys/firmware/efi/fw_platform_size)"

# TODO: Swap file and zram, organize scripts
# TODO: polkit, PAM, read su, clamav, linux-lts for fallback, read Silent boot, fsck on boot
# TODO: Hardware Specific: drivers, microcode, verify resizeable bar
# TODO: Testing Wise: Test without to make sure all packages are being installed without confusion, timedatectl status
# TODO: https://wiki.archlinux.org/title/System_maintenance#Check_for_orphans_and_dropped_packages
# TODO: https://wiki.archlinux.org/title/Xorg#General
# https://wiki.archlinux.org/title/Security#Hardware_vulnerabilities
# https://wiki.archlinux.org/title/AppArmor#Display_current_status
# https://wiki.archlinux.org/title/Xorg#Rootless_Xorg
# https://wiki.archlinux.org/title/Improving_performance#Storage_devices
# https://wiki.archlinux.org/title/Hardware_video_acceleration

# Cool things: Autostarting

# ./partition.sh '/dev/sda' dos "-,8G,S,-\n-,+,L,+"
./partition.sh '/dev/sda' gpt "-,8G,S,-\n-,1G,U,-\n-,+,L,-"

mkfs.fat -F 32 -n ESP '/dev/sda1'
mkswap -L SWAP '/dev/sda2'
mkfs.ext4 -L Root '/dev/sda3'

swapon '/dev/sda2'
mount -v '/dev/sda3' /mnt
mount --mkdir '/dev/sda1' /mnt/efi

pacstrap -K /mnt base linux linux-firmware mkinitcpio man-db man-pages texinfo vi pacman-contrib ttf-liberation sudo nftables iptables-nft polkit
genfstab -U /mnt >> /mnt/etc/fstab

ln -sf /mnt/usr/share/zoneinfo/America/New_York /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt systemctl enable systemd-timesyncd.service

sed -i "s/#en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen

echo 'LANG=en_US.UTF-8' > /mnt/etc/locale.conf
echo retro-desktop > /mnt/etc/hostname

# echo '%wheel ALL=(ALL:ALL) ALL' | arch-chroot /mnt SUDO_EDITOR='tee -a' visudo

echo "Enter the root users password"
# arch-chroot /mnt passwd

./configurations.sh
./vbox_setup.sh
./ethernet.sh
./audio.sh
./firewall.sh
# ./apparmor.sh
./xorg.sh
./efi_setup.sh

arch-chroot /mnt useradd -m -G games,wheel,sys,log,rfkill,ftp,http,vboxsf alex
echo "Enter password for: Alex"
