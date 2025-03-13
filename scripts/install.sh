#!/bin/bash

echo "Boot Mode: $(cat /sys/firmware/efi/fw_platform_size)"

# TODO: organize script, --asexplicit, nvme support
# TODO: linux-lts for fallback, fsck on boot
# TODO: Hardware Specific: drivers, microcode, TRIM
# TODO: Testing Wise: Test without to make sure all packages are being installed without confusion, timedatectl status
# TODO: Hardware temperature in UI xorg/wayland
# TODO: https://wiki.archlinux.org/title/Desktop_notifications

# All recommondations to check on first boot
# https://wiki.archlinux.org/title/System_maintenance#Check_for_orphans_and_dropped_packages
# https://wiki.archlinux.org/title/Xorg#General
# https://wiki.archlinux.org/title/AppArmor#Display_current_status
# https://wiki.archlinux.org/title/Xorg#Rootless_Xorg
# https://wiki.archlinux.org/title/Improving_performance#Storage_devices
# https://wiki.archlinux.org/title/Hardware_video_acceleration
# https://wiki.archlinux.org/title/Improving_performance#Enabling_PCIe_resizable_BAR
# https://wiki.archlinux.org/title/Solid_state_drive#Frozen_mode
# https://wiki.archlinux.org/title/Hdparm#Power_management_configuration
# https://wiki.archlinux.org/title/Hdparm#Write_cache
# https://wiki.archlinux.org/title/Improving_performance#Systemd_Watchdog
# https://wiki.archlinux.org/title/Dm-crypt/Device_encryption#Cryptsetup_usage
# https://wiki.archlinux.org/title/Advanced_Format#Partition_alignment

# Cool things: Autostarting

efi_partition_number=3
efi_drive=sda

root_partition_number=1
root_drive=sda

swap_partition_number=2
swap_drive=sda

drives=()

encrypt=n

array_contains() {
    local value="$1"
    local array=("${@:2}") # All parameters after the first one are the array
    for element in "${array[@]}"; do
    if [[ "$element" == "$value" ]]; then
        echo "$value exists"
        return 0 # Value found (true)
    fi
    done

    return 1 # Value not found (false)
}

erase_drives() {
    for drive in "${drives[@]}"; do
        sgdisk -Zog "/dev/$drive"
        echo "Zap Return Code: $?"
    done
}

print_drives() {
    for drive in "${drives[@]}"; do
        sgdisk -p "/dev/$drive"
    done
}

# Requirements:
# Boot Partition (optional)
# EFI Partition
# Root Partition
# Extra partitions/drives
# Encryption (optional)
# TPM Login (optional)
# Backup LUKS header

encrypt_partition_drives() {
    sgdisk -I -n $efi_partition_number:-1G:0 -c $efi_partition_number:"EFI System Partition" -t $efi_partition_number:C12A7328-F81F-11D2-BA4B-00A0C93EC93B /dev/$efi_drive
    sgdisk -I -n $swap_partition_number:-8G:0 -c $swap_partition_number:"Swap Partition" -t $swap_partition_number:0657FD6D-A4AB-43C4-84E5-0933C84B4F4F /dev/$swap_drive
    sgdisk -I -n $root_partition_number:0:0 -c $root_partition_number:"Root Partition" -t $root_partition_number:4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709 /dev/$root_drive

    modprobe dm_crypt

    cryptsetup luksFormat --label RootLUKS /dev/$root_drive$root_partition_number
    cryptsetup open /dev/$root_drive$root_partition_number root
    mkfs.ext4 -L Root /dev/mapper/root
    mount /dev/mapper/root /mnt

    mkfs.fat -F 32 -n ESP   /dev/$efi_drive$efi_partition_number
    mount --mkdir /dev/$efi_drive$efi_partition_number /mnt/efi

    mkfs.ext2 -L CryptSwap /dev/$swap_drive$swap_partition_number 1M
}

partition_drives() {
    sgdisk -I -n $efi_partition_number:-1G:0 -c $efi_partition_number:"EFI System Partition" -t $efi_partition_number:C12A7328-F81F-11D2-BA4B-00A0C93EC93B /dev/$efi_drive
    sgdisk -I -n $swap_partition_number:-8G:0 -c $swap_partition_number:"Swap Partition" -t $swap_partition_number:0657FD6D-A4AB-43C4-84E5-0933C84B4F4F /dev/$swap_drive
    sgdisk -I -n $root_partition_number:0:0 -c $root_partition_number:"Root Partition" -t $root_partition_number:4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709 /dev/$root_drive

    mkfs.fat -F 32 -n ESP /dev/$efi_drive$efi_partition_number
    mkswap -L SWAP /dev/$swap_drive$swap_partition_number
    mkfs.ext4 -L Root /dev/$root_drive$root_partition_number

    swapon /dev/$swap_drive$swap_partition_number
    mount -v /dev/$root_drive$root_partition_number /mnt
    mount --mkdir /dev/$efi_drive$efi_partition_number /mnt/efi
}

partitioning() {
    if ! array_contains $efi_drive "${drives[@]}"; then
        drives+=("$efi_drive")
    fi

    if ! array_contains $root_drive "${drives[@]}"; then
        drives+=("$root_drive")
    fi

    if ! array_contains $swap_drive "${drives[@]}"; then
        drives+=("$swap_drive")
    fi

    erase_drives

    if [[ $encrypt == "y" ]]; then
        encrypt_partition_drives
    else
        partition_drives
    fi
    
    print_drives
    lsblk -f
}

efi_setup() {
    rm /mnt/boot/initramfs-*.img

    mkdir -p /mnt/efi/EFI/Linux
    mkdir -p /mnt/etc/cmdline.d

    cat ./boot/linux.preset > /mnt/etc/mkinitcpio.d/linux.preset

    if [[ $encrypt == "y" ]]; then
        sed -i "s/block/block encrypt/" /mnt/etc/mkinitcpio.conf
        cat ./boot/encrypted_root.conf > /mnt/etc/cmdline.d/root.conf
        cat ./boot/crypttab > /mnt/etc/crypttab
        sed -i "s/UUID=$(lsblk -dno UUID /dev/mapper/root)/\/dev\/mapper\/root/" /mnt/etc/fstab
        echo "/dev/mapper/swap  none    swap defaults 0 0" >> /mnt/etc/fstab
    else
        cat ./boot/root.conf > /mnt/etc/cmdline.d/root.conf
    fi

    sed -i "s/UUID=X/UUID=$(lsblk -dno UUID /dev/$root_drive$root_partition_number)/" /mnt/etc/cmdline.d/root.conf
    arch-chroot /mnt mkinitcpio -p linux

    efibootmgr --create --disk /dev/$efi_drive --part $efi_partition_number --label "Arch Linux" --loader '\EFI\Linux\arch-linux.efi' --unicode --verbose
    efibootmgr --create --disk /dev/$efi_drive --part $efi_partition_number --label "Arch Linux-Fallback" --loader '\EFI\Linux\arch-linux-fallback.efi' --unicode --verbose
}

system_install() {
    pacstrap -K /mnt base linux linux-lts linux-firmware mkinitcpio man-db man-pages texinfo vim pacman-contrib ttf-liberation sudo nftables iptables-nft polkit
    genfstab -U /mnt >> /mnt/etc/fstab

    ln -sf /mnt/usr/share/zoneinfo/America/New_York /mnt/etc/localtime
    arch-chroot /mnt hwclock --systohc
    arch-chroot /mnt systemctl enable systemd-timesyncd.service

    sed -i "s/#en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen

    echo 'LANG=en_US.UTF-8' > /mnt/etc/locale.conf
    echo retro-desktop > /mnt/etc/hostname
}

partitioning
system_install

# # echo '%wheel ALL=(ALL:ALL) ALL' | arch-chroot /mnt SUDO_EDITOR='tee -a' visudo

./configurations.sh
./vbox_setup.sh
./ethernet.sh
./audio.sh
./firewall.sh
# ./apparmor.sh
./xorg.sh

efi_setup

arch-chroot /mnt useradd -m -G games,wheel,sys,log,rfkill,ftp,http,vboxsf alex
# echo "Enter password for: "
