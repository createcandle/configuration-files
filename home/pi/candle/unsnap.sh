#/bin/bash

# This script helps fix "aw snap" browser crashes.
# Thanks to: https://github.com/dubnom/awsnap

export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority
xdotool getactivewindow key F5
