#!/bin/bash

print_transitions() {
	echo -e "wipe\nwave\ngrow\ncenter\nany\nouter\nleft\nright\ntop\nbottom"
}

WALLPAPER1=$(find "/home/retro/media/images/wallpapers/" -type f | shuf -n 1)
WALLPAPER2=$(find "/home/retro/media/images/wallpapers/" -type f | shuf -n 1)
TRANSITION1=$(print_transitions | shuf -n 1)
TRANSITION2=$(print_transitions | shuf -n 1)

#wal -i "$WALLPAPER1" -s -t -n -q

swww img "$WALLPAPER1" --outputs DP-1 --transition-type "$TRANSITION1" --transition-fps 165 --resize fit
swww img "$WALLPAPER2" --outputs DP-2 --transition-type "$TRANSITION2" --transition-fps 144 --resize fit
