#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

# prepare for factory reset script
touch /boot/developer.txt # will cause the real factory_reset script to also write zeroes to empty space
rm /home/pi/.webthings/candle.log
rm /boot/keep_z2m.txt
rm /boot/keep_bluetooth.txt
rm /boot/candle_first_run_complete.txt
rm /boot/tunnel.txt
rm /etc/asound.conf
cp /home/pi/candle_first_run.sh /boot/candle_first_run.sh


chmod +x /home/pi/.webthings/addons/power-settings/factory_reset.sh
/home/pi/.webthings/addons/power-settings/factory_reset.sh
