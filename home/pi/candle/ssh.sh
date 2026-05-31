#!/bin/bash

BOOT_DIR="/boot"
if lsblk | grep -q $BOOT_DIR/firmware; then
    BOOT_DIR="$BOOT_DIR/firmware"
fi

if [ -f $BOOT_DIR/candle_ssh.txt ] || [ -f $BOOT_DIR/candle_ssh_keep.txt ] || [ -f $BOOT_DIR/firmware/candle_ssh.txt ] || [ -f $BOOT_DIR/firmware/candle_ssh_keep.txt ] || [ ! -f $BOOT_DIR/firmware/candle_first_run_complete.txt ]; then
  systemctl start ssh.service
fi
