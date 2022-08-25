#!/bin/bash

# A quick way to find errors with a new Candle controller build
# None of these should be privacy infringing (no unique ID's)

# Check if script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit
fi

echo "Candle Controller debug information"
echo
echo "Date:          : $(date)"
echo "Hostname       : $(cat /etc/hostname)"
echo "IP address     : $(hostname -I)"
echo "Nameserver     : $(cat /etc/resolv.conf | grep -v resolv | cut -d " " -f2-)"
echo "Candle version : $(cat /boot/candle_version.txt)"
echo "Orig. version  : $(cat /boot/candle_original_version.txt)"
echo "Python version : $(python3 --version)"
echo "Python version : $(python3 --version)"
echo "SQLite version : $(sqlite3 --version | cut -d' ' -f1)"
echo "Node version   : $(sudo -i -u pi node --version)"
echo "NPM version    : $(sudo -i -u pi npm --version)"
echo "Chromium vers. : $(sudo -i -u pi chromium-browser --version | grep -v BlueALSA)"
#echo "Machine ID     : $(cat /etc/machine-id)"

echo
echo "--------------------------------------------- ERRORS"
echo

# The files_check.sh script should exist..
if [ ! -f /home/pi/candle/files_check.sh ]; then
  echo "/home/pi/candle/files_check.sh is missing"
fi

# Run the sub-script that checks for missing files
if [ -f /home/pi/candle/files_check.sh ]; then
  chmod +x /home/pi/candle/files_check.sh
  /home/pi/candle/files_check.sh
else
  echo "/home/pi/candle/files_check.sh is missing"
fi


# These are not "essential" to functioning, so are here instead of in the files_check script
if [ -f /boot/bootup_actions_failed.sh ]; then
  echo "/boot/bootup_actions_failed.sh file exists"
fi
if [ -f /boot/._cmdline.txt ]; then
  echo "/boot/._cmdline.txt file exists"
fi


# programs that should be running
echo
if ! ps aux | grep -q dhcpcd ; then
    echo "dhcpcd is not running"
fi
if ! ps aux | grep -q mosquitto ; then
    echo "mosquitto is not running"
fi

if ! cat /etc/hosts | grep -q "$(cat /etc/hostname)"; then
    echo "hostname was not in /etc/hosts"
fi

echo
echo
echo "--------------------------------------------- warnings"
echo 

if ! lsblk | grep -q 'mmcblk0p4'; 
then
  echo "NO FOURTH PARTITION. This must be an older Candle controller."
fi

if [ -f /boot/bootup_actions.sh ]; then
  echo "/boot/bootup_actions.sh file exists"
fi
if [ -f /boot/debug.txt ]; then
  echo "/boot/debug.txt file exists"
fi
if [ -f /boot/candle_rw_keep.txt ]; then
  echo "boot/candle_rw_keep.txt file exists"
fi
if [ -f /boot/developer.txt ]; then
  echo "boot/developer.txt file exists"
fi
if [ -f /boot/emergency.txt ]; then
  echo "boot/emergency.txt file exists"
fi


echo
if ! ps aux | grep -q wpa_supplicant ; then
    echo "wpa_supplicant is not running"
fi

echo
if [[ $(vcgencmd get_throttled) != "throttled=0x0" ]]; then
    echo "Your power supply is too weak"
fi

echo
echo
echo "--------------------------------------------- systemctl"
echo 
systemctl list-units --failed --no-pager

echo
timeout 2s journalctl --boot=0 --priority=0..3 --no-pager

echo
echo "NOTE:"
echo "- syslog.socket failing is expected, as Candle will only log to syslog if developer.txt is present"
echo "- This error is also not a problem: Failed to make bind mount source '/home/pi/.webthings/etc/hostname': File exists"

echo
echo
echo "--------------------------------------------- dmesg"
echo 

echo "Last 100 dmesg errors:"
dmesg --level=emerg,alert,crit,err | tail -100

echo
echo "Last 100 dmesg warnings:"
dmesg --level=warn | tail -100

echo
echo "NOTE:"
echo "- Some warnings are to be expected, and they are not really indicative of a real problem"
echo "- Not all of these are even warnings, as Candle's processes also report when they start and stop".

echo
echo
echo "--------------------------------------------- config"
echo

echo "/boot/config.txt:"
cat /boot/config.txt | grep -v "#" | grep .

echo
echo "/boot/cmdline.txt:"
cat /boot/cmdline.txt

echo
echo "/home/pi/.webthings/.node_version:"
cat /home/pi/.webthings/.node_version

echo
echo "package sources:"
cat /etc/apt/sources.list
cat /etc/apt/sources.list.d/raspi.list



echo
echo
echo "--------------------------------------------- Linux"
echo

uname -a
echo
cat /etc/os-release
echo
echo "/etc/modules (kernel):"
cat /etc/modules
echo
echo
echo "--------------------------------------------- Apt"
echo

apt policy 

echo
echo
echo "--------------------------------------------- time"
echo

timedatectl --no-pager


echo
echo
echo "--------------------------------------------- audio"
echo

aplay -l
echo
arecord -l

echo
echo
echo "--------------------------------------------- other hardware"
echo

echo "Attached HMDI devices:"
cat /sys/class/drm/card0/*HDMI*/status

echo
echo "Libcamera:"
libcamera-still --list-cameras
#libcamera-still 2>&1 | tee output

echo
echo "Plugged in USB devices:"
lsusb

echo
echo "I2C:"
lsmod|grep i2c
echo
i2cdetect -y 1

echo
echo "Speeds:"
vcgencmd get_config int

echo
# Temperature
vcgencmd measure_temp

echo "CPU:"
cat /proc/cpuinfo | grep 'Revision'

echo
echo "Watchdog:"
wdctl


echo
echo
echo "--------------------------------------------- network"
echo

ifconfig

echo
echo "Wi-Fi:"
wpa_cli -i wlan0 status | grep wpa_state
wpa_cli -i wlan0 status | grep mode
echo
rfkill list
echo
iwconfig

echo
echo
echo "--------------------------------------------- iptables (firewall)"
echo

iptables -t nat --list


echo
echo
echo "--------------------------------------------- lsmod"
echo

lsmod

echo
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
echo "NOTE:"
echo "- What matters is the memory under 'available'. It it's lower than 100, try uninstalling some addons."
echo "- Candle only enables swap memory on the Raspberry Pi Zero"
echo
echo
echo "--------------------------------------------- disk"
echo

if [ -d /ro ]; then
  echo "overlay spotted"
  du /rw/upper --max-depth=1 -h
else
  echo "no overlay spotted"
fi
echo

journalctl --disk-usage --no-pager

echo
echo "Bytes written to system partition: $(cat /sys/fs/ext4/mmcblk0p2/lifetime_write_kbytes)"


echo
findmnt -t ext4
echo
findmnt

echo
mount

echo
df -h

echo
echo "NOTE:"
echo "- /dev/mmcblk0p1 is the boot partition, which is what you see when you plug the SD card into your computer. Candle.log and debug.txt are safe to delete from it."
echo "- /dev/mmcblk0p2 is the system partition. It this is (almost) full, that means an upgrade went very wrong."
echo "- /dev/mmcblk0p3 is the user partition, where your actual personal data is stored. If it is (almost) full, delete some logs or photos?"
echo
echo "Details:"
du /home/pi --max-depth=1 -h


echo
echo
echo "--------------------------------------------- /boot files"
echo

ls /boot -a -l -h

echo
echo
echo "--------------------------------------------- startup"
echo
systemd-analyze critical-chain

echo
echo "NOTE:"
echo "- This shows how long it took the start the controller, and which parts of the process took a long time and/or kept other parts waiting"



echo
echo
echo "--------------------------------------------- services"
echo

systemctl --no-pager status candle_early.service 
echo
systemctl --no-pager status rc-local.service 
echo
systemctl --no-pager status candle_late.service 
echo
systemctl --no-pager status webthings-gateway.service 
echo
systemctl --no-pager status bluealsa.service 
echo
systemctl --no-pager status mosquitto.service 
