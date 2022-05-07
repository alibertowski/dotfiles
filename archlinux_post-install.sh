#!/bin/bash
# Run this script as root after the installation outside the boot medium

# TODO:
#   Fix for both BIOS/UEFI
#   Setup wayland
#   Add guide for multiple monitors

readonly VM="y"
readonly GPU="other"
readonly USER_NAME="alex"
INTERFACE=$(ls /sys/class/net/ | grep en)

systemctl enable dhcpcd@"${INTERFACE}".service
systemctl enable ufw.service

systemctl start dhcpcd@"${INTERFACE}".service

ufw default deny incoming
ufw default allow outgoing
ufw enable

sleep 5

if [ "$VM" = "y" ]; then
    useradd -mG games,wheel,sys,log,rfkill,ftp,http,vboxsf $USER_NAME
else
    useradd -mG games,wheel,sys,log,rfkill,ftp,http $USER_NAME
fi

timedatectl set-ntp true
sed -i "s/# deny = 3/deny = 0/" /etc/security/faillock.conf
echo '%wheel ALL=(ALL:ALL) ALL' | SUDO_EDITOR='tee -a' visudo

# Pacman configurations
sed -i "s/#Color/Color/" /etc/pacman.conf
sed -i "s/#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf
sed -i "s/#\[multilib\]/[multilib]/" /etc/pacman.conf
sed -i "s%#Include = /etc/pacman.d/mirrorlist%Include = /etc/pacman.d/mirrorlist%" /etc/pacman.conf
pacman -Syu --noconfirm
pacman -S --noconfirm --asexplicit pipewire lib32-pipewire wireplumber pipewire-alsa pipewire-pulse galculator kitty neofetch flameshot ttc-iosevka dunst

echo "Enter password for: ${USER_NAME}"
passwd $USER_NAME

install_dotfiles() {
    echo "Copying dotfiles configurations"
    cp -r ./configurations/. "/home/$USER_NAME"
}

xorg_install() {
    pacman -S --noconfirm --asexplicit xorg xorg-xinit bspwm sxhkd python-pywal picom feh rofi
}

install_dotfiles

echo "Installing yay"
git clone https://aur.archlinux.org/yay.git
(
    cd yay || exit
    sudo -u "$USER_NAME" makepkg -sic --noconfirm
)
rm -rf yay

# TODO: Make sure this is correct
if [ "$GPU" = "nvidia" ]; then
    sed -i "s/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/" /mnt/etc/mkinitcpio.conf
    KernelParameters[${#KernelParameters[@]}]="nvidia-drm.modeset=1"
    printf "[Trigger]\nOperation=Install\nOperation=Upgrade\nOperation=Remove\nType=Package\nTarget=nvidia\nTarget=linux\n# Change the linux part above and in the Exec line if a different kernel is used\n\n[Action]\nDescription=Update Nvidia module in initcpio\nDepends=mkinitcpio\nWhen=PostTransaction\nNeedsTargets\nExec=/bin/sh -c 'while read -r trg; do case \$trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'\n" > /mnt/etc/pacman.d/hooks/nvidia.hook
fi

echo "Insalling AUR packages"
sudo -u "$USER_NAME" yay -S polkit-dumb-agent-git polybar

if [ "$GPU" = "other" ]; then
    xorg_install
fi
