#!/bin/bash

echo "in reboot to recovery"
echo "reboot to recovery activated by holding ALT key" >> /dev/kmsg
echo "reboot to recovery activated by holding ALT key" >> /boot/candle_log.txt

# Make sure both command line files exist so we can also switch back once in recovery
if [ -f /boot/cmdline-update.txt ] && [ -f /boot/cmdline-candle.txt ]; then
  cp /boot/cmdline-update.txt /boot/cmdline.txt
  touch /boot/candle_ssh_once.txt
  reboot
else
  echo "Could not reboot to recovery because cmdline-update.txt or cmdline-candle.txt was missing" >> /dev/kmsg
fi

