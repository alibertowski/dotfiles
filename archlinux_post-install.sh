#!/bin/bash
# Run this script as root after the installation outside the boot medium

# TODO:
#   Add guide for multiple monitors
#   Remove pywal setting in wayland
#   Fix screenshots for wayland
#   Fix wireless interfaces

readonly VM="y"
readonly GPU="vbox"
readonly USER_NAME="alex"
readonly ETHERNET="y"
INTERFACE=$(ls /sys/class/net/ | grep en)

pre-install_setup() {
    systemctl enable ufw.service
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow in on "$INTERFACE" from 192.168.0.0/24
    ufw enable

    if [ "$ETHERNET" = "y" ]; then
        systemctl enable dhcpcd@"$INTERFACE".service
        systemctl start dhcpcd@"$INTERFACE".service
    fi

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
    sed -i "s%#\[multilib\]%[multilib]\nInclude = /etc/pacman.d/mirrorlist%" /etc/pacman.conf
    pacman -Syu --noconfirm
    pacman -S --noconfirm --asexplicit pipewire lib32-pipewire wireplumber pipewire-alsa pipewire-pulse galculator kitty neofetch flameshot dunst vulkan-icd-loader lib32-vulkan-icd-loader thunar gvfs thunar-archive-plugin xarchiver tumbler

    echo "Enter password for: ${USER_NAME}"
    passwd $USER_NAME

    echo "Installing yay"
    (
        cd "/home/$USER_NAME" || exit
        git clone https://aur.archlinux.org/yay.git
        chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME"

        cd yay || exit
        sudo -u "$USER_NAME" makepkg -sic --noconfirm
    )
    rm -rf /home/"$USER_NAME"/yay

    echo "Insalling AUR packages"
    (
        cd /home/"$USER_NAME" || exit
        sudo -u "$USER_NAME" yay -S polkit-dumb-agent-git all-repository-fonts
    )
}

install_dotfiles() {
    echo "Copying shared dotfiles configurations"
    cp -r ./configurations/shared/. "/home/$USER_NAME"
}

xorg_install() {
    install_dotfiles

    cp -r ./configurations/xorg/. "/home/$USER_NAME"
    chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME"

    pacman -S --noconfirm --asexplicit xorg xorg-xinit bspwm sxhkd python-pywal feh rofi polybar
    sudo -u "$USER_NAME" wal -n -i "/home/$USER_NAME/pictures/space.jpg"
}

wayland_install() {
    install_dotfiles

    cp -r ./configurations/wayland/. "/home/$USER_NAME"
    chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME"

    pacman -S --noconfirm --asexplicit sway glfw-wayland xorg-xwayland waybar
    (
        cd /home/"$USER_NAME" || exit
        sudo -u "$USER_NAME" yay -S sway-launcher-desktop
    )
}

pre-install_setup

if [ "$VM" = "y" ]; then
    sed -i "s/MODULES=()/MODULES=(vmwgfx)/" /etc/mkinitcpio.conf
    wayland_install
elif [ "$GPU" = "nvidia" ]; then
    pacman -S --noconfirm --asexplicit nvidia nvidia-utils lib32-nvidia-utils
    sed -i "s/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/" /etc/mkinitcpio.conf
    printf "[Trigger]\nOperation=Install\nOperation=Upgrade\nOperation=Remove\nType=Package\nTarget=nvidia\nTarget=linux\n# Change the linux part above and in the Exec line if a different kernel is used\n\n[Action]\nDescription=Update Nvidia module in initcpio\nDepends=mkinitcpio\nWhen=PostTransaction\nNeedsTargets\nExec=/bin/sh -c 'while read -r trg; do case \$trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'\n" > /etc/pacman.d/hooks/nvidia.hook

    xorg_install
elif [ "$GPU" = "amd" ]; then
    pacman -S --noconfirm --asexplicit mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau
    sed -i "s/MODULES=()/MODULES=(amdgpu)/" /etc/mkinitcpio.conf
    wayland_install
fi

chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME"
pacman -S --noconfirm linux

echo "Post-installation complete. Reboot to finalize any changes and log into your new user."