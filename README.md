# dotfiles
Just my attempt at a dotfiles. This repository contains two scripts that will fully install Arch Linux on your system. 'archlinux-install.sh' is meant to be run inside the Arch ISO and 'archlinux-post_install.sh' is meant to be run as root in the system after boot.

## Installation
1. Boot up in the arch ISO
2. Clone or use a USB to copy this repository into the root folder
3. Open 'archlinux-install.sh' and modify any variables (Validation will check if they're correct)
4. Run the 'archlinux-install.sh' and follow any prompts that pop up
5. Reboot into the newly installed system
6. Follow step #2 but into the newly installed systems root folder
7. Open 'archlinux-post_install.sh' and modify any variables (Validation will check if they're correct)
8. Run the 'archlinux-post_install.sh' and follow any prompts that pop up
9. And you're done!

## Post-Install Description
* Nvidia drivers will always use xorg with the BSPWM setup included
* AMD drivers will always use Wayland with the Swap setup included

## TODO
* Finish up the wayland setup
* Finish extended partitions for BIOS
* Support Wi-Fi
* Add guide for multi-monitor setups