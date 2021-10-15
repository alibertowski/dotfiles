#!/bin/sh

echo "Copying and setting links for configurations"
cp -rl ./.config $HOME/
cp -l ./.bashrc $HOME/.bashrc
cp -l ./.vimrc $HOME/.vimrc
cp -l ./.xinitrc $HOME/.xinitrc

# TODO: Setup pre-requisite instructions once configs are copied over