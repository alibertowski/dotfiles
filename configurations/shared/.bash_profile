#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

systemctl --failed
journalctl -p 4 -x -b
journalctl -p 4 -x -b -0
grep -e Log -e tty Xorg.0.log
