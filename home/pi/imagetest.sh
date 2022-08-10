#!/bin/bash

# A quick way to find errors with a new Candle controller build

# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (use sudo)"
  exit
fi



echo "ERRORS:"

if [ ! -L /dev/hosts ]; then
  echo "/dev/hosts is not a link"
fi
if [ ! -L /home/pi/.asoundrc ]; then
  echo "/home/pi/.asoundrc is not a link"
fi

echo
echo "---------------------------------------------"
echo 
systemctl list-units --failed

echo
journalctl --boot=0 --priority=0..3


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
