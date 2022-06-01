# dotfiles
Just my attempt at a dotfiles. This repository contains two scripts that will fully install Arch Linux on your system. 'archlinux-install.sh' is meant to be run inside the Arch ISO and 'archlinux-post_install.sh' is meant to be run as root in the system after boot.

## Pre-Install
* For encryption, be sure to fully [wipe](https://wiki.archlinux.org/title/Dm-crypt/Drive_preparation#Generic_methods) your drives
* If dual-booting Windows, make sure to disable fast boot, hibernation, create an ESP that's a good size before starting (500-600MiB) and set the default hardware time to UTC
* If installing with secure boot, make sure to delete any pre-existing keys in the BIOS and turn it off

## Installation
1. Boot up in the arch ISO
2. Clone or use a USB to copy this repository into the root folder
3. Make sure you're connected to the internet
4. Open 'archlinux-install.sh' and modify any variables (Validation will check if they're correct)
5. Run the 'archlinux-install.sh' and follow any prompts that pop up
6. Reboot into the newly installed system
7. Follow step #2 but into the newly installed systems root folder
8. Open 'archlinux-post_install.sh' and modify any variables (Validation will check if they're correct)
9. Connect to the internet depending if you're on Wi-Fi or ethernet
10. Run the 'archlinux-post_install.sh' and follow any prompts that pop up
11. And you're done!

## Post-Install Description
* If secure boot was installed, sync it using sbsync or manually through the UEFI. After that, turn secure boot on
* Nvidia drivers will always use xorg with the BSPWM setup included
* AMD drivers will always use Wayland with the Swap setup included

## Limitations
* Dual-booting with Windows only works on UEFI/GPT
* When setting up your partitions, you must know if your partitions are correct because they won't be validated

# Tested Setups
* UEFI/GPT, No Encryption, No Secure Boot - Works
* UEFI/GPT, Encryption, No Secure Boot - Works
* UEFI/GPT, Encryption, Secure Boot - Works
* BIOS/MBR, No Encryption (TODO)
* BIOS/MBR, Encryption (TODO)

## TODO
* Finish extended partitions for BIOS
* Add guide for multi-monitor setups
* Finish Validation
* Organize the bash scripts