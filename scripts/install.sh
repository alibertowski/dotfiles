#!/bin/bash

echo -e "Boot Mode: $(cat /sys/firmware/efi/fw_platform_size)\n"

# TODO: Last to check
# https://wiki.archlinux.org/title/Improving_performance#Storage_devices and SSDs

# Found from checking:
# Update README
# https://wiki.archlinux.org/title/Xorg#Rootless_Xorg
# Verify nvidia-open-lts works on lts
# Test if DRM needs modules or not with kms hook - https://wiki.archlinux.org/title/Kernel_mode_setting#Early_KMS_start
# https://wiki.archlinux.org/title/NVIDIA#Early_loading
# Commit git
# Check lines dont have typos
# Xorg configs need tuning
# systemctl --user enable for user services like pipewire, and check existing services to see if any were mistaken as global service
# (POST-MVP) DNS over TLS and DNSSEC
# https://wiki.archlinux.org/title/Silent_boot
# (Post-MVP) https://wiki.archlinux.org/title/System_backup#Automation
# (Post-MVP) https://wiki.archlinux.org/title/Improving_performance#Watchdogs
# Look at https://wiki.archlinux.org/title/Pacman#dry_run
# Set mirrors using sync tool - https://wiki.archlinux.org/title/Mirrors#Official_mirrors
# PAM User account stuff - https://wiki.archlinux.org/title/Security#User_setup

# Maintenance to do:
# Pacfiles - https://wiki.archlinux.org/title/Pacman/Pacnew_and_Pacsave#Managing_.pac*_files
# Useful - https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Identify_files_not_owned_by_any_package
# Useful - https://wiki.archlinux.org/title/System_maintenance#Be_careful_with_unofficial_packages

# TODO: linux-lts for fallback, fsck on boot
# TODO: TRIM
# TODO: (Post-MVP) Verify power usage on windows, then test on linux
# todo: (Post-MVP) https://wiki.archlinux.org/title/Laptop

# All recommondations to check on first boot
# Check out https://www.privacyguides.org/en/os/linux-overview/
# Fonts: https://www.reddit.com/r/linuxmint/comments/1lqpnh0/comment/n15u6ur/
# https://wiki.archlinux.org/title/System_maintenance#Check_for_orphans_and_dropped_packages
# https://wiki.archlinux.org/title/Improving_performance#Storage_devices
# https://wiki.archlinux.org/title/Solid_state_drive#Frozen_mode
# https://wiki.archlinux.org/title/Hdparm#Power_management_configuration
# https://wiki.archlinux.org/title/Hdparm#Write_cache
# https://wiki.archlinux.org/title/Improving_performance#Systemd_Watchdog
# https://wiki.archlinux.org/title/Dm-crypt/Device_encryption#Cryptsetup_usage
# https://wiki.archlinux.org/title/Advanced_Format#Partition_alignment
# https://www.reddit.com/r/archlinux/comments/1me8xpt/installing_arch_with_secure_boot_encryption_and/

# Constants
readonly AMD="amd"
readonly NVIDIA="nvidia"
readonly VIRTUAL_BOX="vbox"
readonly YES="y"
readonly NO="n"

# Partioning Variables
efi_partition_number=3
efi_drive=sda

root_partition_number=1
root_drive=sda

swap_partition_number=2
swap_drive=sda

# nvme testing
#/dev/nvme0n2p1
nvme_controller=0
nvme_drive=2
nvme_partition=1

pc_hostname=misato

# Other Variables
encrypt=$NO
cpu=$VIRTUAL_BOX
gpu=$VIRTUAL_BOX

# Install Parameters (Do not touch)
readonly IFS=","

# TODO: Write print statements for debugging before using these like before enabling the services
# modules=""
groups=("games" "wheel" "sys" "log" "rfkill" "ftp" "http")
services=("systemd-timesyncd.service" "paccache.timer")
packages=("base" "linux" "linux-lts" "linux-firmware" "mkinitcpio" "man-db" "man-pages" "texinfo" "vim" "pacman-contrib" "ttf-liberation" "sudo" "nftables" "iptables-nft" "polkit" "btop")
declare -a drives

packages+=("ufw") # ufw
services+=("ufw.service") # ufw

packages+=("apparmor" "python-notify2" "python-psutil") # apparmor # TODO: download the python modules with --asdeps
services+=("apparmor.service" "auditd.service") # apparmor

packages+=("xorg" "xorg-xinit" "vulkan-icd-loader" "lib32-vulkan-icd-loader" "bspwm" "sxhkd" "rofi" "polybar" "kitty" "feh" "dunst" "flameshot") # xorg
services+=("systemd-networkd.service" "systemd-resolved.service") # ethernet
packages+=("pipewire" "lib32-pipewire" "wireplumber" "pavucontrol" "pipewire-pulse" "pipewire-audio" "pipewire-alsa" "pipewire-jack" "lib32-pipewire-jack") # audio # TODO: Run pactl info

packages+=("reflector") # mirrors
services+=("reflector.timer") # mirrors

packages+=("adobe-source-han-sans-jp-fonts") # fonts

packages+=("xss-lock" "i3lock") # session locking
# user-services+=("pipewire-pulse.service") # audio

# TODO: Document allowed values and what return codes mean
verify_input() {
    if [ "$encrypt" != $YES ] && [ "$encrypt" != $NO ]; then
        echo "User input parameters have incorrect values"
        exit 1
    fi

    if [ "$cpu" != $AMD ] && [ "$cpu" != $VIRTUAL_BOX ]; then
        echo "User input parameters have incorrect values"
        exit 1
    fi

    if [ "$gpu" != $NVIDIA ] && [ "$gpu" != $AMD ] && [ "$gpu" != $VIRTUAL_BOX ]; then
        echo "User input parameters have incorrect values"
        exit 1
    fi
}

verify_input
echo "Passed input test"

# Functions to pre-set variables that are system dependent
# kernel_mode_setting_config_setup() {
#     # https://wiki.archlinux.org/title/Kernel_mode_setting
#     if [ $gpu == $VIRTUAL_BOX ]; then
#         modules="vmwgfx"
#     elif [ $gpu == $NVIDIA ]; then
#         modules="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
#     elif [ $gpu == $AMD ]; then
#         modules="amdgpu"
#     fi
# }

cpu_config_setup() {
    if [ $cpu == $AMD ]; then
        packages+=("amd-ucode")
    elif [ $cpu == $VIRTUAL_BOX ]; then
        packages+=("virtualbox-guest-utils")
        services+=("vboxservice.service")
        groups+=("vboxsf")
    fi
}

gpu_setup() {
    if [ $gpu == $NVIDIA ]; then
        packages+=("nvidia-open" "nvidia-open-lts" "nvidia-utils" "lib32-nvidia-utils")
    elif [ $gpu == $AMD ]; then
        packages+=("mesa" "lib32-mesa" "xf86-video-amdgpu" "vulkan-radeon" "lib32-vulkan-radeon")
    fi
}

array_contains() {
    local value="$1"
    local array=("${@:2}") # All parameters after the first one are the array
    for element in "${array[@]}"; do
    if [ "$element" == "$value" ]; then
        echo "$value exists"
        return 0 # Value found (true)
    fi
    done

    return 1 # Value not found (false)
}

erase_drives() {
    for drive in "${drives[@]}"; do
        wipefs -a "/dev/$drive"
        echo "wipefs Return Code: $?"

        sgdisk -Zo "/dev/$drive"
        echo "Zap Return Code: $?"
    done
}

print_drives() {
    for drive in "${drives[@]}"; do
        sgdisk -p "/dev/$drive"
    done
}

# Util Functions -------------------------------------------------------
setup_firewall() {
    INTERFACE=$(find /sys/class/net/en* | awk -F/ '{print $NF}') # TODO: May not work with laptop that uses Wifi
    arch-chroot /mnt ufw default deny incoming
    arch-chroot /mnt ufw default allow outgoing
    arch-chroot /mnt ufw allow in on "$INTERFACE" from 192.168.0.0/24
    arch-chroot /mnt ufw enable
}

setup_ethernet() {
    cat ./boot/20-wired.network > /mnt/etc/systemd/network/20-wired.network # TODO: Set internal ethernet/wireless interface
    ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
}

setup_secureboot() {
    uuidgen --random > GUID.txt

    # PK
    openssl req -newkey rsa:4096 -noenc -keyout PK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Platform Key/" -out PK.crt
    openssl x509 -outform DER -in PK.crt -out PK.cer
    cert-to-efi-sig-list -g "$(< GUID.txt)" PK.crt PK.esl
    sign-efi-sig-list -g "$(< GUID.txt)" -k PK.key -c PK.crt PK PK.esl PK.auth

    # KEK
    openssl req -newkey rsa:4096 -noenc -keyout KEK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Key Exchange Key/" -out KEK.crt
    openssl x509 -outform DER -in KEK.crt -out KEK.cer
    cert-to-efi-sig-list -g "$(< GUID.txt)" KEK.crt KEK.esl
    sign-efi-sig-list -g "$(< GUID.txt)" -k PK.key -c PK.crt KEK KEK.esl KEK.auth

    # DB
    openssl req -newkey rsa:4096 -noenc -keyout db.key -new -x509 -sha256 -days 3650 -subj "/CN=my Signature Database key/" -out db.crt
    openssl x509 -outform DER -in db.crt -out db.cer
    cert-to-efi-sig-list -g "$(< GUID.txt)" db.crt db.esl
    sign-efi-sig-list -g "$(< GUID.txt)" -k KEK.key -c KEK.crt db db.esl db.auth

    # Sign EFI binary
    # TODO: Place signing file in mkinitcpio spot - https://wiki.archlinux.org/title/Unified_kernel_image#Signing_the_UKIs_for_Secure_Boot
}

setup_apparmor() {
    sed -i "s/log_group = root/log_group = wheel/" /mnt/etc/audit/auditd.conf
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

    mkfs.fat -F 32 -n ESP /dev/$efi_drive$efi_partition_number
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

    echo Drives: "${drives[@]}" >> debug.txt
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
    arch-chroot /mnt mkinitcpio -P # TODO: Check why this was -p linux?

    efibootmgr --create --disk /dev/$efi_drive --part $efi_partition_number --label "Arch Linux-Fallback" --loader '\EFI\Linux\arch-linux-fallback.efi' --unicode --verbose
    efibootmgr --create --disk /dev/$efi_drive --part $efi_partition_number --label "Arch Linux" --loader '\EFI\Linux\arch-linux.efi' --unicode --verbose
}

system_install() {
    echo Packages: "${packages[@]}" >> debug.txt
    echo "Starting pacstrap"

    sed -i "s%#\[multilib\]%[multilib]\nInclude = /etc/pacman.d/mirrorlist%" /etc/pacman.conf
    pacstrap -K /mnt "${packages[@]}" > pac.txt 2>&1
    genfstab -U /mnt >> /mnt/etc/fstab

    ln -sf /usr/share/zoneinfo/America/New_York /mnt/etc/localtime
    arch-chroot /mnt hwclock --systohc

    sed -i "s/#en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen

    echo 'LANG=en_US.UTF-8' > /mnt/etc/locale.conf
    echo "$pc_hostname" > /mnt/etc/hostname

    # kernel_mode_setting_config_setup
    # echo Modules: "$modules" >> debug.txt
    # sed -i "s/MODULES=()/MODULES=($modules)/" /mnt/etc/mkinitcpio.conf

    sed -i "s/# deny = 3/deny = 10/" /mnt/etc/security/faillock.conf # TODO: Organize this properly

    echo Services: "${services[@]}" >> debug.txt
    arch-chroot /mnt systemctl enable "${services[@]}"
}

cpu_config_setup
gpu_setup

partitioning
system_install

# # echo '%wheel ALL=(ALL:ALL) ALL' | arch-chroot /mnt SUDO_EDITOR='tee -a' visudo TODO: This (maybe just do this manually)

./configurations.sh
setup_apparmor
setup_firewall
setup_ethernet
efi_setup

echo Groups: "${groups[*]}" >> debug.txt
arch-chroot /mnt useradd -m -G "${groups[*]}" main
echo "Create a password for 'main' and 'root'"

# TODO: Things to verify on successful install:
# Microcode was ran successful - https://wiki.archlinux.org/title/Microcode#mkinitcpio
# Resizeable BAR - https://wiki.archlinux.org/title/Improving_performance#Enabling_PCIe_resizable_BAR
# Apparmor and notifying system - https://wiki.archlinux.org/title/AppArmor#Display_current_status
# Verify and install needed firmware - https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages
# If dual-booting - https://wiki.archlinux.org/title/System_time#UTC_in_Microsoft_Windows
# `timedatectl status` for time check
# Set monitor resolution and hertz
# Set mouse acceleration - https://wiki.archlinux.org/title/Mouse_acceleration
# Verify Vulkan - https://wiki.archlinux.org/title/Vulkan#Verification
# Hardware acceleration - https://wiki.archlinux.org/title/Hardware_video_acceleration#Verification
# For AMD - https://wiki.archlinux.org/title/AMDGPU#Loading
# Verify firewall
# Verify ZSwap
# Verify notifications - https://wiki.archlinux.org/title/Desktop_notifications#Send_notifications_to_another_user
# Verify DNS - https://wiki.archlinux.org/title/Systemd-resolved#Setting_DNS_servers
# Verify no driver issues for ethernet/wifi - https://wiki.archlinux.org/title/Network_configuration/Ethernet# and https://wiki.archlinux.org/title/Network_configuration/Wireless#
# Insults and set wheel - https://wiki.archlinux.org/title/Sudo#Enable_insults
# Verify session lock occurs on sleep via xss-lock
