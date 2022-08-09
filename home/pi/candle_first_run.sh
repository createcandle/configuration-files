#!/bin/bash

if [ -s /ro/etc/machine-id ]
then
  mount -o remount,rw /ro
  systemd-machine-id-setup --commit
  cp /etc/machine-id /ro/etc/machine-id
  #systemd-machine-id-setup --commit --root=/ro
  #touch /boot/machineid_generated.txt
  mount -o remount,ro /ro
else
  touch /boot/no_machine_id_generated.txt
fi

# Generate new SSH keys to improve security
/bin/dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096
/bin/sh -c "/bin/rm -f -v /etc/ssh/ssh_host_*_key*"
/usr/bin/ssh-keygen -A -v

# Re-enable the tunnel. For developer use only!
if [ -f /boot/tunnel.txt ]; then
  cp /home/pi/.webthings/etc/webthings_tunnel_default.js /home/pi/.webthings/etc/webthings_settings.js
  sqlite3 /home/pi/.webthings/config/db.sqlite3 "DELETE FROM settings WHERE key='tunneltoken'"
  sqlite3 /home/pi/.webthings/config/db.sqlite3 "DELETE FROM settings WHERE key='notunnel'"
  rm -rf /home/pi/.webthings/ssl/
else
  cp /home/pi/.webthings/etc/webthings_settings_backup.js /home/pi/.webthings/etc/webthings_settings.js
fi


# mark first run as complete and reboot
if [ ! -f /boot/candle_first_run_complete.txt ]; then
  touch /boot/candle_first_run_complete.txt
  reboot
fi
