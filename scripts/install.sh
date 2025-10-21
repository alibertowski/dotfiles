#!/bin/bash

echo -e "Boot Mode: $(cat /sys/firmware/efi/fw_platform_size)\n"

# Last to check
# advanced format (before installing)
# Check if ssd supports trim before enabling
# secure boot (before installing)
# tpm (before installiog)
# test nvidia
# benchmark cryptsetup (before installing)
# Backup LUKS header (needs to be done after installation)
# search discard in https://man.archlinux.org/man/crypttab.5.en
# https://wiki.archlinux.org/title/Power_management#Network_interfaces

# Found from checking:
# Verify nvidia-open-lts works on lts
# Test if DRM needs modules or not with kms hook - https://wiki.archlinux.org/title/Kernel_mode_setting#Early_KMS_start
# https://wiki.archlinux.org/title/NVIDIA#Early_loading
# Check lines dont have typos

# (Post-MVP) https://wiki.archlinux.org/title/System_backup#Automation
# (Post-MVP) https://wiki.archlinux.org/title/Improving_performance#Watchdogs
# (POST-MVP) DNS over TLS and DNSSEC
# (Post-MVP) Verify power usage on windows, then test on linux (Watts)
# (Post-MVP) https://wiki.archlinux.org/title/Laptop

# Maintenance to do:
# Pacfiles - https://wiki.archlinux.org/title/Pacman/Pacnew_and_Pacsave#Managing_.pac*_files
# Useful - https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Identify_files_not_owned_by_any_package
# Useful - https://wiki.archlinux.org/title/System_maintenance#Be_careful_with_unofficial_packages

# TPM crap
# tpm2-tss installed
# tpm2-measure-pcr=yes and tpm2-device=auto kernel parameters
# enroll recovery key
# wipe-slot password, and --tpm2-device=auto --tpm2-pcrs=7+15:sha256=0000000000000000000000000000000000000000000000000000000000000000

# Windows crap
# Pre-create an EFI partition with 500MiB
# Disable hibernation and fast startup, https://wiki.archlinux.org/title/Dual_boot_with_Windows#Disable_Fast_Startup_and_disable_hibernation
# UTC time in hardware, https://wiki.archlinux.org/title/System_time#UTC_in_Microsoft_Windows
# Disable NTP in windows, https://wiki.archlinux.org/title/System_time#Multi-NTP_interaction

# Constants
readonly AMD="amd"
readonly NVIDIA="nvidia"
readonly VIRTUAL_BOX="vbox"
readonly YES="y"
readonly NO="n"

# Partioning Variables
efi_partition_number=1
efi_drive=nvme0n1
efi_full_drive=
efi_size=500M
efi_windows=nvme0n1

root_partition_number=1
root_drive=sda
root_full_drive=

swap_partition_number=2
swap_drive=sda
swap_full_drive=
swap_size=1G

declare -a extra_full_drives
extra_drives=("nvme0n2")
extra_names=("yatta")

# Other Variables
encrypt=$YES
cpu=$AMD
gpu=$NVIDIA

pc_hostname=robot
pc_user=main

# Install Parameters (Do not touch)
readonly IFS=","

groups=("games" "wheel" "sys" "log" "rfkill" "ftp" "http")
services=("systemd-timesyncd.service" "paccache.timer" "fstrim.timer")
packages=("man-db" "man-pages" "texinfo" "vim" "pacman-contrib" "sudo" "polkit" "btop")
declare -a drives
declare -a optional_packages

packages+=("ufw") # ufw
services+=("ufw.service") # ufw

packages+=("apparmor") # apparmor
optional_packages+=("python-notify2" "python-psutil" "python-gobject" "sqlite" "tk") # apparmor
services+=("apparmor.service" "auditd.service") # apparmor

packages+=("xorg" "xorg-xinit" "vulkan-icd-loader" "lib32-vulkan-icd-loader" "bspwm" "sxhkd" "rofi" "polybar" "kitty" "feh" "dunst" "flameshot") # xorg
services+=("systemd-networkd.service" "systemd-resolved.service") # ethernet

packages+=("pipewire" "lib32-pipewire" "wireplumber" "pavucontrol" "pipewire-pulse" "pipewire-audio" "pipewire-alsa" "pipewire-jack" "lib32-pipewire-jack") # audio

packages+=("reflector") # mirrors
services+=("reflector.timer") # mirrors

packages+=("ttf-liberation" "adobe-source-han-sans-jp-fonts") # fonts

packages+=("xss-lock" "i3lock") # session locking

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

    if [ ! -b "/dev/$efi_drive" ]; then
        echo "Device not found: $efi_drive"
        exit 1
    fi

    if [ ! -b "/dev/$root_drive" ]; then
        echo "Device not found: $root_drive"
        exit 1
    fi

    if [ ! -b "/dev/$swap_drive" ]; then
        echo "Device not found: $swap_drive"
        exit 1
    fi

    for drive in "${extra_drives[@]}"; do
        if [ ! -b "/dev/$drive" ]; then
            echo "Device not found: $drive"
            exit 1
        fi
    done
}

setup_full_drive_names() {
    if [[ "$efi_drive" == sd* ]]; then
        efi_full_drive=$efi_drive$efi_partition_number
    elif [[ "$efi_drive" == nvme* ]]; then
        efi_full_drive="$efi_drive"p$efi_partition_number
    else
        echo "Unknown device type: $efi_drive"
        exit 2
    fi

    if [[ "$root_drive" == sd* ]]; then
        root_full_drive=$root_drive$root_partition_number
    elif [[ "$root_drive" == nvme* ]]; then
        root_full_drive="$root_drive"p$root_partition_number
    else
        echo "Unknown device type: $root_drive"
        exit 2
    fi

    if [[ "$swap_drive" == sd* ]]; then
        swap_full_drive=$swap_drive$swap_partition_number
    elif [[ "$swap_drive" == nvme* ]]; then
        swap_full_drive="$swap_drive"p$swap_partition_number
    else
        echo "Unknown device type: $swap_drive"
        exit 2
    fi

    for drive in "${extra_drives[@]}"; do
        if [[ "$drive" == sd* ]]; then
            local full_drive="$drive"1
            extra_full_drives+=("$full_drive")
        elif [[ "$drive" == nvme* ]]; then
            local full_drive="$drive"p1
            extra_full_drives+=("$full_drive")
        else
            echo "Unknown device type: $drive"
            exit 2
        fi
    done

    echo "EFI Full Drive: $efi_full_drive"
    echo "Root Full Drive: $root_full_drive"
    echo "Swap Full Drive: $swap_full_drive"

    for drive in "${extra_full_drives[@]}"; do
        echo "Extra Full Drive: $drive"
    done
}

verify_input
setup_full_drive_names
echo "Passed input test"

# Functions to pre-set variables that are system dependent
# kernel_mode_setting_config_setup() {
#     # https://wiki.archlinux.org/title/Kernel_mode_setting
#     if [ $gpu == $VIRTUAL_BOX ]; then
#         modules="vmwgfx"
#     elif [ $gpu == $NVIDIA ]; then
#         modules="nvidia nvidia_modeset nvidia_uvm nvidia_drm" TODO: This is needed for nvidia for early KMS
#     elif [ $gpu == $AMD ]; then
#         modules="amdgpu"
#     fi
# }

cpu_setup() {
    if [ $cpu == $AMD ]; then
        packages+=("amd-ucode")
    elif [ $cpu == $VIRTUAL_BOX ]; then
        packages+=("virtualbox-guest-utils" "efibootmgr")
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
        if [ ! "$drive" == $efi_windows ]; then
            wipefs -a "/dev/$drive"
            echo "wipefs Return Code: $?"

            sgdisk -Zo "/dev/$drive"
            echo "Zap Return Code: $?"
        fi
    done
}

print_drives() {
    for drive in "${drives[@]}"; do
        sgdisk -p "/dev/$drive"
    done
}

# Util Functions -------------------------------------------------------
setup_firewall() {
    INTERFACE=$(find /sys/class/net/en* | awk`` -F/ '{print $NF}') # TODO: May not work with laptop that uses Wifi
    arch-chroot /mnt ufw default deny incoming
    arch-chroot /mnt ufw default allow outgoing
    arch-chroot /mnt ufw allow in on "$INTERFACE" from 192.168.0.0/24 # TODO: Lapto has a better configuration
    arch-chroot /mnt ufw enable
}

setup_ethernet() {
    cat ./boot/20-wired.network > /mnt/etc/systemd/network/20-wired.network # TODO: Set internal ethernet/wireless interface
    ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
}

setup_apparmor() {
    sed -i "s/log_group = root/log_group = wheel/" /mnt/etc/audit/auditd.conf
}

encrypt_partition_drives() {
    if [ ! $efi_drive == $efi_windows ]; then
        sgdisk -I -n $efi_partition_number:-$efi_size:0 -c $efi_partition_number:"EFI System Partition" -t $efi_partition_number:ef00 /dev/$efi_drive
    fi

    sgdisk -I -n $swap_partition_number:-$swap_size:0 -c $swap_partition_number:"Swap Partition" -t $swap_partition_number:8200 /dev/$swap_drive
    sgdisk -I -n $root_partition_number:0:0 -c $root_partition_number:"Root Partition" -t $root_partition_number:8304 /dev/$root_drive

    modprobe dm_crypt

    cryptsetup luksFormat --label root_luks /dev/$root_full_drive
    cryptsetup open /dev/$root_full_drive root
    mkfs.ext4 -L root_fs /dev/mapper/root
    mount /dev/mapper/root /mnt

    if [ ! $efi_drive == $efi_windows ]; then
        mkfs.fat -F 32 -n ESP /dev/$efi_full_drive
    fi

    mount -o dmask=0077,fmask=0077 --mkdir /dev/$efi_full_drive /mnt/efi
    mkfs.ext2 -L swap_luks /dev/$swap_full_drive 1M

    for i in "${!extra_drives[@]}"; do
        local drive_partition_number=1
        local drive_device=${extra_drives[i]}
        local drive_name=${extra_names[i]}
        local drive_full_device=${extra_full_drives[i]}
        sgdisk -I -n $drive_partition_number:0:0 -c $drive_partition_number:"$drive_name" -t $drive_partition_number:8300 /dev/"$drive_device"
        
        mkdir -p /mnt/etc/cryptsetup-keys.d
        dd bs=512 count=4 if=/dev/random iflag=fullblock | install -m 0600 /dev/stdin /mnt/etc/cryptsetup-keys.d/"$drive_name".key

        cryptsetup luksFormat --label "$drive_name"_luks /dev/"$drive_full_device" /mnt/etc/cryptsetup-keys.d/"$drive_name".key
        cryptsetup open /dev/"$drive_full_device" "$drive_name" --key-file /mnt/etc/cryptsetup-keys.d/"$drive_name".key
        mkfs.ext4 -L "$drive_name"_fs /dev/mapper/"$drive_name"

        mkdir -p "/mnt/mnt/$drive_name"
        mount /dev/mapper/"$drive_name" "/mnt/mnt/$drive_name"

        echo "$drive_name UUID=$(lsblk -dno UUID /dev/"$drive_full_device") /etc/cryptsetup-keys.d/$drive_name.key nofail" >> /mnt/etc/crypttab
    done
}

partition_drives() {
    sgdisk -I -n $efi_partition_number:-$efi_size:0 -c $efi_partition_number:"EFI System Partition" -t $efi_partition_number:ef00 /dev/$efi_drive
    sgdisk -I -n $swap_partition_number:-$swap_size:0 -c $swap_partition_number:"Swap Partition" -t $swap_partition_number:8200 /dev/$swap_drive
    sgdisk -I -n $root_partition_number:0:0 -c $root_partition_number:"Root Partition" -t $root_partition_number:8304 /dev/$root_drive

    mkfs.fat -F 32 -n ESP /dev/$efi_full_drive
    mkswap -L SWAP /dev/$swap_full_drive
    mkfs.ext4 -L root_fs /dev/$root_full_drive

    swapon /dev/$swap_full_drive
    mount -v /dev/$root_full_drive /mnt
    mount -o dmask=0077,fmask=0077 --mkdir /dev/$efi_full_drive /mnt/efi

    for i in "${!extra_drives[@]}"; do
        local drive_partition_number=1
        local drive_device=${extra_drives[i]}
        local drive_name=${extra_names[i]}
        local drive_full_device=${extra_full_drives[i]}
        sgdisk -I -n $drive_partition_number:0:0 -c $drive_partition_number:"$drive_name" -t $drive_partition_number:8300 /dev/"$drive_device"

        mkfs.ext4 -L "$drive_name"_fs "/dev/$drive_full_device"
        mkdir -p "/mnt/mnt/$drive_name"
        mount -v "/dev/$drive_full_device" "/mnt/mnt/$drive_name"
    done
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

    for drive in "${extra_drives[@]}"; do
        drives+=("$drive")
    done

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
    mkdir -p /mnt/efi/EFI/Linux
    mkdir -p /mnt/etc/cmdline.d

    cat ./boot/linux.preset > /mnt/etc/mkinitcpio.d/linux.preset
    cat ./boot/linux-lts.preset > /mnt/etc/mkinitcpio.d/linux-lts.preset

    if [[ $encrypt == "y" ]]; then
        sed -i "s/HOOKS=(base udev autodetect microcode/HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck) #/" /mnt/etc/mkinitcpio.conf # TODO: Delete kms for nvidia
        cat ./boot/encrypted_root.conf > /mnt/etc/cmdline.d/root.conf
        
        echo "swap LABEL=swap_luks /dev/urandom swap,offset=2048,cipher=aes-xts-plain64,size=512" >> /mnt/etc/crypttab
        echo "/dev/mapper/swap  none    swap defaults 0 0" >> /mnt/etc/fstab

        # sed -i "s/rw/rw,nofail,x-systemd.device-timeout=300/" /mnt/etc/fstab # TODO for optional drives (I think from future me?)
    else
        cat ./boot/root.conf > /mnt/etc/cmdline.d/root.conf
    fi

    echo "KEYMAP=us" > /mnt/etc/vconsole.conf
    echo "FONT=default8x16" >> /mnt/etc/vconsole.conf

    sed -i "s/X/$(lsblk -dno UUID /dev/$root_full_drive)/" /mnt/etc/cmdline.d/root.conf # todo: rd.luks.options=discard
    arch-chroot /mnt mkinitcpio -P

    rm /mnt/boot/initramfs-*.img

    efibootmgr --create --disk /dev/$efi_drive --part $efi_partition_number --label "Arch Linux-lts-Fallback" --loader '\EFI\Linux\arch-linux-lts-fallback.efi' --unicode --verbose
    efibootmgr --create --disk /dev/$efi_drive --part $efi_partition_number --label "Arch Linux" --loader '\EFI\Linux\arch-linux.efi' --unicode --verbose
}

system_install() {
    echo "Starting pacstrap"

    pacstrap -K /mnt base linux linux-firmware linux-lts mkinitcpio nftables iptables-nft # > pac.txt 2>&1
    genfstab -U /mnt >> /mnt/etc/fstab

    sed -i "s%#\[multilib\]%[multilib]\nInclude = /etc/pacman.d/mirrorlist%" /mnt/etc/pacman.conf
    sed -i "s/#ParallelDownloads/ParallelDownloads/" /mnt/etc/pacman.conf
    arch-chroot /mnt pacman -Syu

    echo Packages: "${packages[@]}" >> debug.txt
    arch-chroot /mnt pacman -S "${packages[@]}"
    
    echo Optional Packages: "${optional_packages[@]}" >> debug.txt
    arch-chroot /mnt pacman -S --asdeps "${optional_packages[@]}"

    ln -sf /usr/share/zoneinfo/America/New_York /mnt/etc/localtime
    arch-chroot /mnt hwclock --systohc

    sed -i "s/#en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen

    echo 'LANG=en_US.UTF-8' > /mnt/etc/locale.conf
    echo "$pc_hostname" > /mnt/etc/hostname

    # kernel_mode_setting_config_setup
    # echo Modules: "$modules" >> debug.txt
    # sed -i "s/MODULES=()/MODULES=($modules)/" /mnt/etc/mkinitcpio.conf

    sed -i "s/# deny = 3/deny = 10/" /mnt/etc/security/faillock.conf

    echo Services: "${services[@]}" >> debug.txt
    arch-chroot /mnt systemctl enable "${services[@]}"
}

setup_configurations() {
    {
        printf "127.0.0.1\tlocalhost\n"
        printf "::1\tlocalhost\n"
        printf "127.0.1.1\t%s\n" "$pc_hostname"
    } > /mnt/etc/hosts

    echo EDITOR=vim >> /mnt/etc/environment
    echo PACCACHE_ARGS='-k2' >> /mnt/etc/environment
}

cpu_setup
gpu_setup

partitioning
system_install

setup_configurations
setup_apparmor
setup_firewall
setup_ethernet
efi_setup

echo Groups: "${groups[*]}" >> debug.txt
arch-chroot /mnt useradd -m -G "${groups[*]}" $pc_user
echo "Create a password for '$pc_user' and 'root'"

## Things to verify on successful install:
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
# Verify audio: `pactl info`
# visudo
# Missing firmware - https://wiki.archlinux.org/title/Mkinitcpio#Possibly_missing_firmware_for_module_XXXX
