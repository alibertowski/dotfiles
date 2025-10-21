# dotfiles
Just my attempt at a dotfiles. This repository contains two scripts that will fully install Arch Linux on your system. 'archlinux-install.sh' is meant to be run inside the Arch ISO and 'archlinux-post_install.sh' is meant to be run as root in the system after boot.

## Pre-Install
* For encryption, be sure to fully [wipe](https://wiki.archlinux.org/title/Dm-crypt/Drive_preparation#Generic_methods) your drives
* If dual-booting Windows, make sure to disable fast boot, hibernation, create an ESP that's a good size before starting (500-600MiB) and set the default hardware time to UTC
* If installing with secure boot, make sure to delete any pre-existing keys in the BIOS and turn it off

## Post-Install Description
* If secure boot was installed, sync it using sbsync or manually through the UEFI. After that, turn secure boot on
* Xorg only currently

## Limitations
* Dual-booting with Windows only works on UEFI/GPT
* When setting up your partitions, you must know if your partitions are correct because they won't be validated

# Tested Setups
* UEFI/GPT, No Encryption
* UEFI/GPT, Encryption
