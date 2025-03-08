#!/bin/sh

arch-chroot /mnt pacman -S pipewire lib32-pipewire pavucontrol pipewire-pulse pipewire-audio pipewire-alsa pipewire-jack lib32-pipewire-jack

# TODO: Run pactl info
