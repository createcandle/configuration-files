#!/bin/bash
set +e

# This file gets copied to /boot when factory reset is requested.
# It is also called by the script that creates the Candle disk image
# $BOOT_DIR/candle_first_run.sh will only actually be run by a service if $BOOT_DIR/candle_first_run_complete does not exist.


# Check if script is being run as root
if [ "$EUID" -ne 0 ]
then 
  echo "Please run as root (use sudo)"
  exit
fi

BOOT_DIR="/boot"
if lsblk | grep -q /boot/firmware; then
    #echo "firmware partition is mounted at /boot/firmware"
    BOOT_DIR="/boot/firmware"
fi

if [ -d /ro ]
then 
  echo "FIRST_RUN: Error, read only mode seems to be active" >> $BOOT_DIR/candle_log.txt
  exit 1
fi

# if wifi country is not set, use NL
if iw reg get | grep -q 'country 00'; then
	iw reg set NL
fi

# Just to be sure..
echo "Deleting NetworkManager Wifi connections"
nmcli --terse connection show | grep 802-11-wireless | cut -d : -f 1 | while read name; do nmcli connection delete "$name"; done



echo "in candle_first_run.sh"
echo "$(date) - Candle: in candle_first_run.sh" >> /dev/kmsg
echo "$(date) - FIRST_RUN: doing first run" >> $BOOT_DIR/candle_log.txt

if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/splash_preparing.png" ] && [ -f "$BOOT_DIR/splash_preparing180.png" ]; then
  if [ -e "$BOOT_DIR/rotate180.txt" ]; then
    /bin/ply-image $BOOT_DIR/splash_preparing180.png
  else
    /bin/ply-image $BOOT_DIR/splash_preparing.png
  fi
  sleep 2
fi

if [ -f $BOOT_DIR/candle_first_run_complete.txt ]; then
    echo "FIRST_RUN: warning, candle_first_run_complete.txt already exists! Will not automatically reboot once complete." >> $BOOT_DIR/candle_log.txt
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
    elif [ -f /home/pi/.webthings/etc/webthings_settings.js ]; then
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
WEBTHINGS_HOME="${WEBTHINGS_HOME:=/home/pi/.webthings}"
SSL_DIR="${WEBTHINGS_HOME}/ssl"
[ ! -d "${SSL_DIR}" ] && mkdir -p "${SSL_DIR}"

#openssl genrsa -out "${SSL_DIR}/privatekey.pem" 2048

current_year=$(date +%Y)
#future_year=$(($current_year + 10))

if [ -f "$BOOT_DIR/candle_ssl_2048.txt" ]; then
	openssl genrsa -out "${SSL_DIR}/privatekey.pem" 2048
elif [ -f "$BOOT_DIR/candle_ssl_3072.txt" ]; then
	openssl genrsa -out "${SSL_DIR}/privatekey.pem" 3072
elif [ -f "$BOOT_DIR/candle_ssl_4096.txt" ]; then
	openssl genrsa -out "${SSL_DIR}/privatekey.pem" 4096

elif [ "$current_year" -gt 2028 ]; then
	if [ "$current_year" -gt 2032 ]; then
		openssl genrsa -out "${SSL_DIR}/privatekey.pem" 4096
	else
		openssl genrsa -out "${SSL_DIR}/privatekey.pem" 3072
	fi
else
	openssl genrsa -out "${SSL_DIR}/privatekey.pem" 2048
fi



openssl req -new -sha256 -key "${SSL_DIR}/privatekey.pem" -out "${SSL_DIR}/csr.pem" -subj '/CN=www.sgnihtbew.com/O=Candle Controller/C=US'
openssl x509 -req -days 3650 -in "${SSL_DIR}/csr.pem" -signkey "${SSL_DIR}/privatekey.pem" -out "${SSL_DIR}/certificate.pem"



chown -R pi:pi "${SSL_DIR}"

# If the disk image was created on Windows or Mac, it may leave behind cruft
rm -rf $BOOT_DIR/'System Volume Information'
rm -rf $BOOT_DIR/.Spotlight*
rm -rf $BOOT_DIR/.Trashes
rm -rf $BOOT_DIR/.fseventsd
if [ -f $BOOT_DIR/._cmdline.txt ]; then
    rm $BOOT_DIR/._*
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
if [ ! -f /home/pi/controller_backup.tar ] && [ -f $BOOT_DIR/candle_make_controller_backup.txt ];
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

START_SECTOR=$(/usr/sbin/fdisk -l | grep mmcblk0p4 | awk '{print $2}' | tr -d '\n')
echo "Start sector:  $START_SECTOR"

if [ ! -f $BOOT_DIR/candle_user_partition_expanded.txt ]; then
    if fdisk -l | grep -q mmcblk0p4; then
        echo "Candle: FIRST_RUN: expanding user partition" >> /dev/kmsg
        echo "FIRST_RUN: expanding user partition" >> $BOOT_DIR/candle_log.txt
        #START_SECTOR=${/usr/sbin/fdisk -l | grep mmcblk0p4 | awk "{print $2}" | tr -d '\n'}
        echo -e "d\n4\nn\np\n$START_SECTOR\n\nN\nw\nq" | /usr/sbin/fdisk /dev/mmcblk0
        /usr/sbin/resize2fs /dev/mmcblk0p4
        touch $BOOT_DIR/candle_user_partition_expanded.txt
    else
        echo "Candle: FIRST_RUN: ERROR, cannot expand user partition: no 4th partition?" >> /dev/kmsg
        echo "FIRST_RUN: ERROR, cannot expand user partition: no 4th partition?" >> $BOOT_DIR/candle_log.txt
    fi

else
    echo "Candle: FIRST_RUN: not expanding user partition: candle_user_partition_expanded.txt already exists" >> /dev/kmsg
    echo "FIRST_RUN: not expanding user partition: candle_user_partition_expanded.txt already exists" >> $BOOT_DIR/candle_log.txt
fi

echo "$(date) - first run done" >> $BOOT_DIR/candle_log.txt

# Mark first run as complete and reboot
if [ ! -f $BOOT_DIR/candle_first_run_complete.txt ]; then
    touch $BOOT_DIR/candle_first_run_complete.txt
    #rm $BOOT_DIR/candle_first_run.sh
    reboot
fi

