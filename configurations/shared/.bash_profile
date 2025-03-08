export EDITOR=vi
systemctl --failed
journalctl -p 4 -x -b
grep -e Log -e tty Xorg.0.log
