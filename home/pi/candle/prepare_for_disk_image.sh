#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

echo "prepare_for_disk_image: STARTING"

BOOT_DIR="/boot"
if lsblk | grep -q $BOOT_DIR/firmware; then
    #echo "firmware partition is mounted at $BOOT_DIR/firmware"
    BOOT_DIR="$BOOT_DIR/firmware"
fi

# prepare for factory reset script
rm /home/pi/.webthings/candle.log
rm $BOOT_DIR/candle_log.txt
rm $BOOT_DIR/candle_issues.txt
rm $BOOT_DIR/candle_fix.txt
rm $BOOT_DIR/candle_fix_failed.txt
rm $BOOT_DIR/debug.txt
rm $BOOT_DIR/raspinfo.txt
rm $BOOT_DIR/candle_cutting_edge.txt
rm $BOOT_DIR/keep_z2m.txt
rm $BOOT_DIR/keep_bluetooth.txt
rm $BOOT_DIR/candle_first_run_complete.txt
rm $BOOT_DIR/candle_original_version.txt
rm $BOOT_DIR/candle_rw_keep.txt
rm $BOOT_DIR/candle_rw_once.txt
rm $BOOT_DIR/tunnel.txt
rm /etc/asound.conf
rm /var/log/*

if [ -d /etc/NetworkManager/system-connections ]; then
  rm -rf /etc/NetworkManager/system-connections/*
fi
if [ -d /home/pi/etc/NetworkManager/system-connections ]; then
  rm -rf /home/pi/etc/NetworkManager/system-connections/*
fi

# Clean NPM cache
export NVM_DIR="/home/pi/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
npm cache clean --force # already done in install_candle_controller script
#rm /home/pi/.npm/anonymous-cli-metrics.json 

if [ -f /home/pi/candle/candle_first_run.sh ]; then
  rm $BOOT_DIR/candle_first_run.sh
  cp /home/pi/candle/candle_first_run.sh $BOOT_DIR/candle_first_run.sh
else
  echo "ERROR, candle_first_run.sh is missing"
  exit 1
fi

rm /home/pi/.fehbg

rm /home/pi/.wget-hsts

rm -rf /home/pi/.pki

find /tmp -type f -atime +10 -delete

if [ -f /home/pi/.webthings/addons/power-settings/factory_reset.sh ] ; then
  touch $BOOT_DIR/developer.txt # will cause the real factory_reset script to also write zeroes to empty space. That script also calls SHUTDOWN, so nothing can be done after this.
  chmod +x /home/pi/.webthings/addons/power-settings/factory_reset.sh
  /home/pi/.webthings/addons/power-settings/factory_reset.sh
fi


