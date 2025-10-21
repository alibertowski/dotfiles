#!/bin/bash

readonly YES=y
readonly NO=n
virtual_box=$NO

user_services=("pipewire-pulse.service") # audio

systemctl --user enable "${user_services[@]}"

if [ $virtual_box == $YES ]; then
    sed -i "s/#VBOX://" ../configurations/xorg/.config/bspwm/bspwmrc
fi

# This script is meant to run in the created user on first boot
mkdir -p ~/.config/bspwm
mkdir -p ~/.config/polybar
mkdir -p ~/.config/sxhkd
mkdir -p ~/.config/dunst

cat ../configurations/xorg/.xinitrc > ~/.xinitrc
cat ../configurations/xorg/.config/bspwm/bspwmrc > ~/.config/bspwm/bspwmrc 
cat ../configurations/xorg/.config/polybar/config.ini > ~/.config/polybar/config.ini
cat ../configurations/xorg/.config/polybar/launch.sh > ~/.config/polybar/launch.sh
cat ../configurations/xorg/.config/sxhkd/sxhkdrc > ~/.config/sxhkd/sxhkdrc
cat ../configurations/xorg/.config/dunst/dunstrc > ~/.config/dunst/dunstrc


chmod u+x ~/.config/bspwm/bspwmrc
chmod +x "$HOME/.config/polybar/launch.sh"
