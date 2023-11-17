#!/bin/bash

BOOT_DIR="/boot"
if lsblk | grep $BOOT_DIR/firmware; then
    echo "firmware partition is mounted at $BOOT_DIR/firmware"
    BOOT_DIR="$BOOT_DIR/firmware"
fi

echo "in reboot to recovery"
echo "reboot to recovery activated by holding ALT key" >> /dev/kmsg
echo "reboot to recovery activated by holding ALT key" >> $BOOT_DIR/candle_log.txt

# Make sure both command line files exist so we can also switch back once in recovery
if [ -f $BOOT_DIR/cmdline-update.txt ] && [ -f $BOOT_DIR/cmdline-candle.txt ]; then
  cp $BOOT_DIR/cmdline-update.txt $BOOT_DIR/cmdline.txt
  touch $BOOT_DIR/candle_ssh_once.txt
  if [ -e /dev/fb0 ]; then
    timeout 2 cat /dev/urandom > /dev/fb0
  fi
  reboot -f
else
  echo "Could not reboot to recovery because cmdline-update.txt or cmdline-candle.txt was missing" >> /dev/kmsg
fi

