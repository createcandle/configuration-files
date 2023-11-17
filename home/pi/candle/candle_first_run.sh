#!/bin/bash
set +e

# This file gets copied to /boot when factory reset is requested.
# It is also called by the script that creates the Candle disk image
# $BOOT_DIR/candle_first_run.sh will only actually be run by a service if $BOOT_DIR/candle_first_run_complete does not exist.


# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (use sudo)"
  exit
fi


BOOT_DIR="/boot"
if lsblk | grep /boot/firmware; then
    echo "firmware partition is mounted at /boot/firmware"
    BOOT_DIR="/boot/firmware"
fi


echo "in candle_first_run.sh"
echo "$(date) - Candle: in candle_first_run.sh" >> /dev/kmsg
echo "$(date) - FIRST_RUN: doing first run" >> boot/candle_log.txt

if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/splash_preparing.png" ] && [ -f "$BOOT_DIR/splash_preparing180.png" ]; then
  if [ -e "$BOOT_DIR/rotate180.txt" ]; then
    /bin/ply-image $BOOT_DIR/splash_preparing180.png
  else
    /bin/ply-image $BOOT_DIR/splash_preparing.png
  fi
  sleep 2
fi


# Set machine ID
if [ -s /etc/machine-id ];
then

  if [ -f /home/pi/.webthings/machine-id ]; then
    cp /home/pi/.webthings/machine-id /etc/machine-id 
  else
    systemd-machine-id-setup --commit
    cp /etc/machine-id /home/pi/.webthings/machine-id
    if [ -d /ro ];
    then
      mount -o remount,rw /ro
      cp /etc/machine-id /ro/etc/machine-id
      mount -o remount,ro /ro
    fi
    echo "FIRST_RUN: Machine ID generated" >> $BOOT_DIR/candle_log.txt
    echo "Candle: generated machine ID" >> /dev/kmsg
    
    # Re-enable the tunnel. For developer use only!
    if [ -f $BOOT_DIR/tunnel.txt ]; then
      cp /home/pi/.webthings/etc/webthings_tunnel_default.js /home/pi/.webthings/etc/webthings_settings.js
      sqlite3 /home/pi/.webthings/config/db.sqlite3 "DELETE FROM settings WHERE key='tunneltoken'"
      sqlite3 /home/pi/.webthings/config/db.sqlite3 "DELETE FROM settings WHERE key='notunnel'"
      rm -rf /home/pi/.webthings/ssl/
      echo "FIRST_RUN: - You have enabled the secret tunnel option. Please use this only for development reasons." >> $BOOT_DIR/candle_log.txt
    else
      cp /home/pi/.webthings/etc/webthings_settings_backup.js /home/pi/.webthings/etc/webthings_settings.js
    fi
    
    
  fi
  
fi


# Generate new SSH keys to improve security
/bin/dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096
/bin/sh -c "/bin/rm -f -v /etc/ssh/ssh_host_*_key*"
/usr/bin/ssh-keygen -A -v
echo "FIRST_RUN: new SSH security keys generated." >> $BOOT_DIR/candle_log.txt


# Generate SSL keys
WEBTHINGS_HOME="${WEBTHINGS_HOME:=${HOME}/.webthings}"
SSL_DIR="${WEBTHINGS_HOME}/ssl"
[ ! -d "${SSL_DIR}" ] && mkdir -p "${SSL_DIR}"
openssl genrsa -out "${SSL_DIR}/privatekey.pem" 2048
openssl req -new -sha256 -key "${SSL_DIR}/privatekey.pem" -out "${SSL_DIR}/csr.pem" -subj '/CN=www.sgnihtbew.com/O=Candle Controller/C=US'
openssl x509 -req -in "${SSL_DIR}/csr.pem" -signkey "${SSL_DIR}/privatekey.pem" -out "${SSL_DIR}/certificate.pem"


# If the disk image was created on Windows or Mac, it may leaves behind cruft
rm -rf $BOOT_DIR/'System Volume Information'
rm -rf $BOOT_DIR/.Spotlight*
rm -rf $BOOT_DIR/.Trashes
rm -rf $BOOT_DIR/.fseventsd
if [ -f $BOOT_DIR/._cmdline.txt ]; then
    rm $BOOT_DIR/._cmdline.txt
fi


# Remember which version of Candle this SD card originally came with
if [ -f /home/pi/.webthings/candle_original_version.txt ]; then
  cp /home/pi/.webthings/candle_original_version.txt $BOOT_DIR/candle_original_version.txt
else
  if [ ! -f $BOOT_DIR/candle_original_version.txt ] && [ -f $BOOT_DIR/candle_version.txt ]; then
    cp $BOOT_DIR/candle_version.txt $BOOT_DIR/candle_original_version.txt
    cp $BOOT_DIR/candle_version.txt /home/pi/.webthings/candle_original_version.txt
  fi
fi


# Create initial tar backup of controller
if [ ! -f /home/pi/controller_backup.tar ];
then
    cd /home/pi
    if [ -f /home/pi/webthings/gateway/build/app.js ] \
    && [ -f /home/pi/webthings/gateway/build/static/index.html ] \
    && [ -f /home/pi/webthings/gateway/.post_upgrade_complete ] \
    && [ -d /home/pi/webthings/gateway/node_modules ] \
    && [ -d /home/pi/webthings/gateway/build/static/bundle ]; 
    then
        echo "Creating initial backup of webthings folder"
        echo "Candle: creating initial backup of controller" >> /dev/kmsg
        echo "FIRST_RUN: creating initial backup of controller" >> $BOOT_DIR/candle_log.txt
        tar -czf ./controller_backup.tar ./webthings

    else
        echo
        echo "ERROR, NOT MAKING INITIAL BACKUP, MISSING WEBTHINGS DIRECTORY OR PARTS MISSING"
        echo "Candle: WARNING, the Candle controller installation seems to be incomplete. Will not create initial backup" >> /dev/kmsg
        echo "FIRST_RUN: WARNING, the Candle controller installation seems to be incomplete. Will not create initial backup" >> $BOOT_DIR/candle_log.txt
        echo
    fi
fi

if [ -f /home/pi/controller_backup.tar ]; then
    chown pi:pi /home/pi/controller_backup.tar
fi

echo "$(date) - first run done" >> $BOOT_DIR/candle_log.txt

# Mark first run as complete and reboot
if [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then
  touch $BOOT_DIR/candle_first_run_complete.txt
  reboot
fi

