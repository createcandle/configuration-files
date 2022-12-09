#!/bin/bash

# Check if script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (use sudo)"
  exit
fi


echo "backing up all files in /boot to /boot/candle"
rm -rf candle
mkdir -p candle
rsync -avr ./  ./candle/ --exclude=candle --exclude=picore

echo "removing candle files and overlay"
rm -rf overlays
rm *

echo "copying picore files into place"
rsync -avr ./picore/  ./

echo "done"
