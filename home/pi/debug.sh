#!/bin/bash

# A quick way to find errors with a new Candle controller build
# None of these should be privacy infringing (no unique ID's)

# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (use sudo)"
  exit
fi

echo "Candle Controller debug information"
echo
echo "Date:          : $(Date)"
echo "Hostname       : $(cat /etc/hostname)"
echo "Candle version : $(cat /boot/candle_version.txt)"
echo "Python version : $(python3 --version)"
echo "Node version   : $(node --version)"
echo "NPM version    : $(npm --version)"
#echo "Machine ID     : $(cat /etc/machine-id)"

echo
echo "--------------------------------------------- ERRORS"
echo

# Links
if [ ! -L /etc/hosts ]; then
  echo "/etc/hosts is not a link"
fi
if [ ! -L /etc/timezone ]; then
  echo "/etc/timezone is not a link"
fi
if [ ! -L /etc/fake-hwclock.data ]; then
  echo "/etc/fake-hwclock.data is not a link"
fi

if [ ! -L /home/pi/.asoundrc ]; then
  echo "/home/pi/.asoundrc is not a link"
fi
if [ ! -L /etc/fake-hwclock.data ]; then
  echo "/etc/fake-hwclock.data is not a link"
fi


# Directories
if [ ! -d /etc/hostapd ]; then
  echo "/etc/hostapd dir is missing"
fi
if [ ! -d /home/pi/.npm ]; then
  echo "/home/pi/.npm dir is missing"
fi
if [ ! -d /etc/chromium ]; then
  echo "/etc/chromium dir is missing"
fi
if [ ! -d /etc/mosquitto ]; then
  echo "/etc/mosquitto dir is missing"
fi
if [ ! -d /etc/voicecard ]; then
  echo "/etc/voicecard dir is missing"
fi
if [ ! -d /etc/chromium/policies/managed/ ]; then
  echo "/etc/chromium/policies/managed/ dir is missing"
fi
if [ ! -d /home/pi/.webthings/var/lib/bluetooth ]; then
  echo "/home/pi/.webthings/var/lib/bluetooth dir is missing"
fi
if [ ! -d /home/pi/.webthings/addons/candleappstore ]; then
  echo "/home/pi/.webthings/addons/candleappstore dir is missing"
fi
if [ ! -d /home/pi/webthings/gateway/build/static/bundle ]; then
  echo "/home/pi/webthings/gateway/build/static/bundle dir is missing"
fi


# Files
if [ ! -f /home/pi/.webthings/config/db.sqlite3 ]; then
  echo "/home/pi/.webthings/config/db.sqlite3 is missing"
fi
if [ ! -f /home/pi/.webthings/floorplan.svg ]; then
  echo "/home/pi/.webthings/floorplan.svg is missing"
fi
if [ ! -f /home/pi/webthings/gateway/build/app.js ]; then
  echo "/home/pi/webthings/gateway/build/app.js is missing"
fi
if [ ! -f /home/pi/webthings/gateway/static/images/floorplan.svg ]; then
  echo "/home/pi/webthings/gateway/static/images/floorplan.svg is missing"
fi
if [ ! -f /home/pi/webthings/gateway/.post_upgrade_complete ]; then
  echo "/home/pi/webthings/gateway/.post_upgrade_complete is missing"
fi
if [ ! -f /home/pi/webthings/gateway/build/static/css/candle.css ]; then
  echo "/home/pi/webthings/gateway/build/static/css/candle.css is missing"
fi
if [ ! -f /home/pi/.webthings/etc/webthings_settings.js ]; then
  echo "/home/pi/.webthings/etc/webthings_settings.js is missing"
fi
if [ ! -f /boot/error.png ]; then
  echo "/boot/error.png is missing"
fi
if [ ! -f /etc/X11/xinit/xinitrc ]; then
  echo "/etc/X11/xinit/xinitrc is missing"
fi
if [ ! -f /home/pi/candle_requirements.txt ]; then
  echo "/home/pi/candle_requirements.txt is missing"
fi
if [ ! -f /home/pi/candle_requirements.txt ]; then
  echo "/home/pi/candle_requirements.txt is missing"
fi
if [ ! -f /home/pi/candle_packages.txt ]; then
  echo "/home/pi/candle_packages.txt is missing"
fi
if [ ! -f /etc/avahi/services/candlemqtt.service ]; then
  echo "/etc/avahi/services/candlemqtt.service is missing"
fi
if [ ! -f /etc/avahi/services/candle.service ]; then
  echo "/etc/avahi/services/candle.service is missing"
fi
if [ ! -f /etc/rc.local ]; then
  echo "/etc/rc.local is missing"
fi
if [ ! -f /home/pi/candle/early.sh ]; then
  echo "/home/pi/candle/early.sh is missing"
fi
if [ ! -f /etc/systemd/system/webthings-gateway.service ]; then
  echo "/etc/systemd/system/webthings-gateway.service is missing"
fi
if [ ! -f /etc/systemd/system/fake-hwclock-save.service ]; then
  echo "/etc/systemd/system/fake-hwclock-save.service is missing"
fi
if [ ! -f /etc/systemd/system/bluetooth.service.d/candle.conf ]; then
  echo "/etc/systemd/system/bluetooth.service.d/candle.conf is missing"
fi
if [ ! -f /usr/bin/bluealsa ]; then
  echo "/usr/bin/bluealsa is missing"
fi
if [ ! -f /opt/vc/lib/plugins/plugins/reader_metadata_id3.so ]; then
  echo "/opt/vc/lib/plugins/plugins/reader_metadata_id3.so is missing"
fi



# Backups
if [ ! -f /home/pi/candle/early.sh.bak ]; then
  echo "/home/pi/candle/early.sh.bak backup is missing"
fi
if [ ! -f /etc/rc.local.bak ]; then
  echo "/etc/rc.local.bak backup is missing"
fi
if [ ! -f /home/pi/controller_backup.tar ]; then
  echo "/home/pi/controller_backup.tar backup is missing"
fi

# Swap
if [ -f /var/swap ]; then
  echo "/var/swap file still exists"
fi




echo
echo "--------------------------------------------- systemctl"
echo 
systemctl list-units --failed

echo
journalctl --boot=0 --priority=0..3

echo
echo "NOTE:"
echo "- syslog.socket failing is expected, as Candle will only log to syslog if developer.txt is present"
echo "- This error is also not a problem: Failed to make bind mount source '/home/pi/.webthings/etc/hostname': File exists"

echo
echo "--------------------------------------------- dmesg"
echo 

echo "dmesg errors:"
dmesg --level=emerg,alert,crit,err

echo
echo "dmesg warnings:"
dmesg --level=warn

echo
echo "NOTE:"
echo "- Some warnings are to be expected, and they are not really indicative of a real problem"
echo "- Not all of these are even warnings, as Candle's processes also report when they start and stop".

echo
echo "--------------------------------------------- config"
echo

echo "/boot/config.txt:"
cat /boot/config.txt | grep -v "#" | grep .

echo "/boot/cmdline.txt:"
cat /boot/cmdline.txt

echo "/home/pi/.webthings/.node_version:"
cat /home/pi/.webthings/.node_version


echo
echo "--------------------------------------------- audio"
echo

aplay -l
echo
arecord -l

echo
echo "--------------------------------------------- other hardware"
echo

echo "Attached HMDI devices:"
cat /sys/class/drm/card0/*HDMI*/status

echo
echo "Libcamera installed?"
which libcamera-still


echo
echo "--------------------------------------------- memory"
echo

free -h

echo
echo "Allocated GPU memory: $(vcgencmd get_mem gpu)"

if [ -f /home/pi/.webthings/swap ]; then
  echo
  echo "/home/pi/.webthings/swap detected"
  ls -l /home/pi/.webthings/swap
fi

echo
echo "--------------------------------------------- disk"
echo

if [ -d /ro ]; then
  echo "overlay spotted"
  du /rw/upper --max-depth=1
else
  echo "no overlay spotted"
fi
echo

journalctl --disk-usage


echo
findmnt -t ext4

echo
df -h

echo
echo "NOTE:"
echo "- /dev/mmcblk0p1 is the boot partition, which is what you see when you plug the SD card into your computer. Candle.log and debug.txt are safe to delete from it."
echo "- /dev/mmcblk0p2 is the system partition. It this is (almost) full, that means an upgrade went very wrong."
echo "- /dev/mmcblk0p3 is the user partition, where your actual personal data is stored. If it's (almost) full, delete some logs or photos?"
echo
echo "Details:"
du /home/pi --max-depth=1 -h

echo
echo "NOTE:"
echo "- What matters is the memory under 'available'. It it's lower than 100, try uninstalling some addons."
echo "- Candle only enables swap memory on the Raspberry Pi Zero"

echo
echo "--------------------------------------------- /boot files"
echo
ls /boot -a -l -h

echo
echo "--------------------------------------------- startup"
echo
systemd-analyze critical-chain -h

echo
echo "NOTE:"
echo "- This shows how long it took the start the controller, and which parts of the process took a long time and/or kept other parts waiting"

echo
echo "--------------------------------------------- iptables (firewall)"
echo
iptables -t nat --list

echo
echo "--------------------------------------------- services"
echo

systemctl status candle_early.service 
echo
systemctl status rc-local.service 
echo
systemctl status webthings-gateway.service 
echo
systemctl status bluealsa.service 


