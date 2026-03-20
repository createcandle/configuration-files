#!/bin/bash

if [ -f /boot/firmware/candle_ssh.txt ]; then
  systemctl start ssh.service
fi
