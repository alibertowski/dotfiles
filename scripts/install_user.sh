#!/bin/sh

# This script is meant to run in the created user on first boot
mkdir -p ~/.config/bspwm
mkdir -p ~/.config/polybar
mkdir -p ~/.config/sxhkd

cat ../configurations/xorg/.xinitrc > ~/.xinitrc
cat ../configurations/xorg/.config/bspwm/bspwmrc > ~/.config/bspwm/bspwmrc 
cat ../configurations/xorg/.config/polybar/config > ~/.config/polybar/config
cat ../configurations/xorg/.config/polybar/launch.sh > ~/.config/polybar/launch.sh
cat ../configurations/xorg/.config/sxhkd/sxhkdrc > ~/.config/sxhkd/sxhkdrc

# TODO: Do this with cat
cp -r ../configurations/shared/pictures ~/pictures
