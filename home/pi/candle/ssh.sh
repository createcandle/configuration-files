#!/bin/bash

if [ -f /boot/candle_ssh.txt ] || [ -f /boot/candle_ssh_keep.txt ] || [ -f /boot/firmware/candle_ssh.txt ] || [ -f /boot/firmware/candle_ssh_keep.txt ]; then
  systemctl start ssh.service
fi
