#!/bin/bash

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
