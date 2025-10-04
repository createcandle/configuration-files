#!/bin/bash

# This script is run as root

if [ cat /proc/device-tree/model | grep -q "Microsoft Surface RT" ]; then
  if [ -f /boot/firmware/candle_developer.txt ]; then
    echo "Candle: every_hour: preventively turning WiFi off and on again to avoid WiFi issues on Surface RT" >> /dev/kmsg
  fi
  ip link set mlan0 down
  ip link set mlan0 up
fi
