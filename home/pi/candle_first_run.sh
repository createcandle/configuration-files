#!/bin/bash
set +e

# This file gets copied to /boot when factory reset is requested.
# It is also called by the script that creates the Candle disk image
# /boot/candle_first_run.sh will only actually be run by a service if /boot/candle_first_run_complete does not exist.


# Set machine ID
if [ -s /etc/machine-id ];
then
  systemd-machine-id-setup --commit

  if [ -d /ro ];
  then
    mount -o remount,rw /ro
    cp /etc/machine-id /ro/etc/machine-id
    mount -o remount,ro /ro
  fi
  echo "$(date) - Machine ID generated" >> /boot/candle.log
fi


# Generate new SSH keys to improve security
/bin/dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096
/bin/sh -c "/bin/rm -f -v /etc/ssh/ssh_host_*_key*"
/usr/bin/ssh-keygen -A -v
echo "$(date) - New SSH security keys generated." >> /boot/candle.log


# Re-enable the tunnel. For developer use only!
if [ -f /boot/tunnel.txt ]; then
  cp /home/pi/.webthings/etc/webthings_tunnel_default.js /home/pi/.webthings/etc/webthings_settings.js
  sqlite3 /home/pi/.webthings/config/db.sqlite3 "DELETE FROM settings WHERE key='tunneltoken'"
  sqlite3 /home/pi/.webthings/config/db.sqlite3 "DELETE FROM settings WHERE key='notunnel'"
  rm -rf /home/pi/.webthings/ssl/
  echo "$(date) - You have enabled the secret tunnel option. Please use this only for development reasons." >> /boot/candle.log
else
  cp /home/pi/.webthings/etc/webthings_settings_backup.js /home/pi/.webthings/etc/webthings_settings.js
fi


# Because the disk image is created on Windows, it leaves behind a directory...
rm -rf /boot/'System Volume Information'


# Mark first run as complete and reboot
if [ ! -f /boot/candle_first_run_complete.txt ]; then
  touch /boot/candle_first_run_complete.txt
  reboot
fi
