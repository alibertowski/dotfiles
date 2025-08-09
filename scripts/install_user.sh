#!/bin/sh

# This script is meant to run in the created user on first boot
mkdir -p ~/.config/bspwm
mkdir -p ~/.config/polybar
mkdir -p ~/.config/sxhkd
mkdir -p ~/.config/dunst
mkdir -p ~/.config/kitty

cat ../configurations/xorg/.xinitrc > ~/.xinitrc
cat ../configurations/xorg/.config/bspwm/bspwmrc > ~/.config/bspwm/bspwmrc 
cat ../configurations/xorg/.config/polybar/config.ini > ~/.config/polybar/config.ini
cat ../configurations/xorg/.config/polybar/launch.sh > ~/.config/polybar/launch.sh
cat ../configurations/xorg/.config/sxhkd/sxhkdrc > ~/.config/sxhkd/sxhkdrc
cat ../configurations/xorg/.config/dunst/dunstrc > ~/.config/dunst/dunstrc
cat ../configurations/shared/.config/kitty/kitty.conf > ~/.config/kitty/kitty.conf

# TODO: Do this with cat
cp -r ../configurations/shared/pictures ~/pictures

chmod u+x ~/.config/bspwm/bspwmrc
chmod +x "$HOME/.config/polybar/launch.sh"
