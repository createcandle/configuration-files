#!/bin/bash

# A quick way to find errors with a new Candle controller build

# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (use sudo)"
  exit
fi

echo "Hostname:"
cat /etc/hostname

echo
echo "ERRORS:"

if [ ! -L /dev/hosts ]; then
  echo "/dev/hosts is not a link"
fi
if [ ! -L /home/pi/.asoundrc ]; then
  echo "/home/pi/.asoundrc is not a link"
fi

if [ ! -d /etc/hostapd ]; then
  echo "/etc/hostapd is missing"
fi
if [ ! -d /etc/hostapd ]; then
  echo "/etc/hostapd is missing"
fi

if [ ! -f /home/pi/.webthings/floorplan.svg ]; then
  echo "/home/pi/.webthings/floorplan.svg is missing"
fi
if [ ! -f /home/pi/webthings/gateway/build/app.js ]; then
  echo "/home/pi/webthings/gateway/build/app.js is missing"
fi
if [ ! -f /home/pi/webthings/gateway/.post_upgrade_complete ]; then
  echo "/home/pi/webthings/gateway/.post_upgrade_complete is missing"
fi
if [ ! -f /home/pi/webthings/gateway/build/static/css/candle.css ]; then
  echo "/home/pi/webthings/gateway/build/static/css/candle.css is missing"
fi

echo "Machine ID:"
cat /etc/machine-id

echo
echo "---------------------------------------------"
echo 
systemctl list-units --failed

echo
journalctl --boot=0 --priority=0..3

echo
echo "---------------------------------------------"
echo

echo "/boot/config.txt:"
cat /boot/config.txt | grep -v "#" | grep .


echo
echo "---------------------------------------------"
echo
journalctl --disk-usage

echo
systemd-analyze critical-chain

echo
findmnt -t ext4

echo
df
