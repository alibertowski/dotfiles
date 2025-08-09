#!/bin/sh

systemctl --failed
journalctl -p 4 -x -b # Current boot warnings + errors
journalctl -p 4 -x -b -1 # Last boot warnings + errors

grep -e EE -e tty ~/.local/share/xorg/Xorg.0.log # Xorg logs

