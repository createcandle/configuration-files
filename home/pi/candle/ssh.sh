#!/bin/bash

if [ -f /boot/candle_ssh.txt ] || [ -f /boot/firmware/candle_ssh.txt ] || [ -f /boot/firmware/candle_ssh.txt ]; then
  systemctl start ssh.service
fi
