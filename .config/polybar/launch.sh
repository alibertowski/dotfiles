#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar
# If all your bars have ipc enabled, you can also use 
# polybar-msg cmd quit

# Launch all bars
echo "---" | tee -a /tmp/mon-one-bar.log /tmp/mon-two-bar.log 
polybar mon-one 2>&1 | tee -a /tmp/mon-one-bar.log & disown 
polybar mon-two  2>&1 | tee -a /tmp/mon-two-bar.log & disown

echo "Bars launched..."
