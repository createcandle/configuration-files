#!/bin/bash
set +e

# This file gets copied to /boot when factory reset is requested.
# It is also called by the script that creates the Candle disk image
# /boot/candle_first_run.sh will only actually be run by a service if /boot/candle_first_run_complete does not exist.


# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (use sudo)"
  exit
fi


echo "in candle_first_run.sh"
echo "($date) - Candle: in candle_first_run.sh" >> /dev/kmsg
echo "($date) - Candle: doing first run" >> boot/candle_log.txt

if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/splash_updating.png" ] && [ -f "/boot/splash_updating180.png" ]; then
  if [ -e "/boot/rotate180.txt" ]; then
    /bin/ply-image /boot/splash_updating180.png
  else
    /bin/ply-image /boot/splash_updating.png
  fi
  sleep 2
fi


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
  echo "$(date) - Machine ID generated" >> /boot/candle_log.txt
  echo "Candle: generated machine ID" >> /dev/kmsg
fi


# Generate new SSH keys to improve security
/bin/dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096
/bin/sh -c "/bin/rm -f -v /etc/ssh/ssh_host_*_key*"
/usr/bin/ssh-keygen -A -v
echo "$(date) - candle_first_run.sh: new SSH security keys generated." >> /boot/candle_log.txt


# Re-enable the tunnel. For developer use only!
if [ -f /boot/tunnel.txt ]; then
  cp /home/pi/.webthings/etc/webthings_tunnel_default.js /home/pi/.webthings/etc/webthings_settings.js
  sqlite3 /home/pi/.webthings/config/db.sqlite3 "DELETE FROM settings WHERE key='tunneltoken'"
  sqlite3 /home/pi/.webthings/config/db.sqlite3 "DELETE FROM settings WHERE key='notunnel'"
  rm -rf /home/pi/.webthings/ssl/
  echo "$(date) - You have enabled the secret tunnel option. Please use this only for development reasons." >> /boot/candle_log.txt
else
  cp /home/pi/.webthings/etc/webthings_settings_backup.js /home/pi/.webthings/etc/webthings_settings.js
fi


# If the disk image was created on Windows or Mac, it may leaves behind cruft...
rm -rf /boot/'System Volume Information'
rm -rf /boot/.Spotlight*
if [ -f /boot/._cmdline.txt ]; then
    rm /boot/._cmdline.txt
fi

# Remember which version of Candle this SD card originally came with
if [ ! -f /boot/candle_original_version.txt ] && [ -f /boot/candle_version.txt ]; then
  cp /boot/candle_version.txt /boot/candle_original_version.txt
fi


# Create initial tar backup of controller
if [ ! -f /home/pi/controller_backup.tar ];
then
    if [ -f /home/pi/webthings/gateway/build/app.js ] \
    && [ -f /home/pi/webthings/gateway/build/static/index.html ] \
    && [ -f /home/pi/webthings/gateway/.post_upgrade_complete ] \
    && [ -d /home/pi/webthings/gateway/node_modules ] \
    && [ -d /home/pi/webthings/gateway/build/static/bundle ]; 
    then
        echo "Creating initial backup of webthings folder"
        echo "Candle: creating initial backup of controller" >> /dev/kmsg
        echo "Candle: creating initial backup of controller" >> /boot/candle_log.txt
        tar -czf ./controller_backup.tar ./webthings

    else
        echo
        echo "ERROR, NOT MAKING INITIAL BACKUP, MISSING WEBTHINGS DIRECTORY OR PARTS MISSING"
        echo "Candle: WARNING, the Candle controller installation seems to be incomplete. Will not create initial backup" >> /dev/kmsg
        echo "Candle: WARNING, the Candle controller installation seems to be incomplete. Will not create initial backup" >> /boot/candle_log.txt
        echo
    fi
fi

if [ -f /home/pi/controller_backup.tar ]; then
    chown pi:pi /home/pi/controller_backup.tar
fi

echo "($date) - first run done" >> boot/candle_log.txt

# Mark first run as complete and reboot
if [ ! -f /boot/candle_first_run_complete.txt ]; then
  touch /boot/candle_first_run_complete.txt
  reboot
fi

