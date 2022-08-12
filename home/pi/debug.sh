#!/bin/bash

# A quick way to find errors with a new Candle controller build

# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (use sudo)"
  exit
fi
echo "Candle version : $(cat /boot/candle_version.txt)"
echo "Hostname       : $(cat /etc/hostname)"
#echo "Machine ID     : $(cat /etc/machine-id)"

echo
echo "--------------------------------------------- ERRORS"

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


if [ ! -d /etc/hostapd ]; then
  echo "/etc/hostapd dir is missing"
fi
if [ ! -d /etc/mosquitto ]; then
  echo "/etc/mosquitto dir is missing"
fi
if [ ! -d /etc/voicecard ]; then
  echo "/etc/voicecard dir is missing"
fi
if [ ! -d /etc/chromium ]; then
  echo "/etc/chromium dir is missing"
fi
if [ ! -d /usr/bin/bluealsa ]; then
  echo "/usr/bin/bluealsa dir is missing"
fi



if [ ! -f /home/pi/.webthings/floorplan.svg ]; then
  echo "/home/pi/.webthings/floorplan.svg is missing"
fi
if [ ! -f /home/pi/webthings/gateway/build/app.js ]; then
  echo "/home/pi/webthings/gateway/build/app.js is missing"
fi
if [ ! -f /home/pi/webthings/gateway/.post_upgrade_complete ]; then
  echo "/home/pi/webthings/gateway/.post_upgrade_complete is missing"
fi
if [ ! -f /home/pi/webthings/gateway/build/static/css/candle.css ]; then
  echo "/home/pi/webthings/gateway/build/static/css/candle.css is missing"
fi



echo
echo "--------------------------------------------- systemctl"
echo 
systemctl list-units --failed
echo
journalctl --boot=0 --priority=0..3
echo "(syslog.socket failing is expected, as Candle will only log to syslog if developer.txt is present")


echo
echo "--------------------------------------------- dmesg"
echo 

echo "dmesg errors:"
dmesg --level=emerg,alert,crit,err

echo
echo "dmesg warnings:"
dmesg --level=warn



echo
echo "--------------------------------------------- config"
echo

echo "/boot/config.txt:"
cat /boot/config.txt | grep -v "#" | grep .

echo "/boot/cmdline.txt:"
cat /boot/cmdline.txt


echo
echo "--------------------------------------------- disk"
echo

if [ -d /ro ]; then
  echo "overlay spotted"
else
  echo "no overlay spotted"
fi
echo

journalctl --disk-usage


echo
findmnt -t ext4

echo
df

echo
echo "--------------------------------------------- memory"
echo
free -h
echo "Allocated GPU memory: $(vcgencmd get_mem gpu)"


echo
echo "--------------------------------------------- startup"
echo
systemd-analyze critical-chain



