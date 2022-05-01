#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
source ~/.config/git-prompt.sh

PS1='\u \e[36m\w\e[3m\e[32m\e[1m$(__git_ps1 " (%s)")\e(B\e[m\e[23m\n >> '

(cat ~/.cache/wal/sequences &)