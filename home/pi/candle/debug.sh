#!/bin/bash

# A quick way to find errors with a new Candle controller build
# None of these should be privacy infringing (no unique ID's)

# Check if script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit
fi

BOOT_DIR="/boot"
if lsblk | grep -q $BOOT_DIR/firmware; then
    #echo "firmware partition is mounted at $BOOT_DIR/firmware"
    BOOT_DIR="$BOOT_DIR/firmware"
fi

#WEBTHINGS_HOME="${WEBTHINGS_HOME:=${HOME}/.webthings}"
#CONTROLLER_NODE_VERSION_FILE_PATH="${WEBTHINGS_HOME}/.node_version"
#_current_controller_version=$(cat ${CONTROLLER_NODE_VERSION_FILE_PATH})

# Make NVM available in this script
#NVM_DIR="/home/pi/.nvm"
#source $NVM_DIR/nvm.sh

export NVM_DIR="/home/pi/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

echo "Candle Controller debug information"
echo
echo "Date:          : $(date)"
echo "Hostname       : $(cat /etc/hostname)"
echo "IP address     : $(hostname -I)"
echo "Model          : $(tr -d '\0' < /proc/device-tree/model)"
echo "Nameserver     : $(cat /etc/resolv.conf | grep -v resolv | cut -d " " -f2-)"
echo "Candle version : $(cat $BOOT_DIR/candle_version.txt)"
echo "Orig. version  : $(cat $BOOT_DIR/candle_original_version.txt)"
echo "Node build v.  : $(cat /home/pi/.webthings/.node_version)"
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
if [ -f $BOOT_DIR/bootup_actions_failed.sh ]; then
  echo "$BOOT_DIR/bootup_actions_failed.sh file exists"
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

if lsblk | grep -q 'mmcblk0p4'; then
  if ! cat /etc/fstab | grep -q 'mmcblk0p4'; then
    echo "/etc/fstab does not reference fourth partition"
  fi
else
  if ! cat /etc/fstab | grep -q 'mmcblk0p3'; then
    echo "/etc/fstab does not reference third partition"
  fi
fi
#if ! lsb_release -i -s | grep -q Raspbian; then
#    echo "OS string is not Raspbian, it is: $(lsb_release -i -s)" 
#fi



echo
echo
echo "--------------------------------------------- warnings"
echo 

if [ -f $BOOT_DIR/._cmdline.txt ]; then
  echo "$BOOT_DIR/._cmdline.txt file exists"
fi

if ! lsblk | grep -q 'mmcblk0p4'; 
then
  echo "NO FOURTH PARTITION. This must be an older Candle controller."
fi

if [ -f $BOOT_DIR/bootup_actions.sh ]; then
  echo "$BOOT_DIR/bootup_actions.sh file exists"
fi
if [ -f $BOOT_DIR/debug.txt ]; then
  echo "$BOOT_DIR/debug.txt file exists"
fi
if [ -f $BOOT_DIR/candle_rw_keep.txt ]; then
  echo "boot/candle_rw_keep.txt file exists"
fi
if [ -f $BOOT_DIR/developer.txt ]; then
  echo "boot/developer.txt file exists"
fi
if [ -f $BOOT_DIR/emergency.txt ]; then
  echo "boot/emergency.txt file exists"
fi

if [ -d /home/pi/.webthings/data/zigbee2mqtt/zigbee2mqtt ]; then
  echo "/home/pi/.webthings/data/zigbee2mqtt/zigbee2mqtt directory does not exist"
fi


echo
if ! ps aux | grep -q wpa_supplicant ; then
    echo "wpa_supplicant is not running"
fi

echo
if [[ $(vcgencmd get_throttled) != "throttled=0x0" ]]; then
    echo "Your power supply is too weak, or the controller gets too warm (or both)"
	vcgencmd get_throttled
fi

echo
echo "--------------------------------------------- firmware"
echo
rpi-eeprom-update
echo
vcgencmd bootloader_version
echo
vcgencmd bootloader_config

echo
echo
echo "--------------------------------------------- systemctl"
echo
echo "systemd timers"
systemctl list-timers --no-pager
echo
echo
echo "systemd enabled services"
systemctl list-unit-files --state=enabled --no-pager
echo
echo 
echo "systemd failed"
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
dmesg --level=emerg,alert,crit,err | tail -100 | cat

echo
echo "Last 100 dmesg warnings:"
dmesg --level=warn | tail -100 | cat

echo
echo "NOTE:"
echo "- Some warnings are to be expected, and they are not really indicative of a real problem"
echo "- Not all of these are even warnings, as Candle's processes also report when they start and stop".

echo
echo
echo "--------------------------------------------- config"
echo

echo "$BOOT_DIR/config.txt:"
cat $BOOT_DIR/config.txt | grep -v "#" | grep .

echo
echo "$BOOT_DIR/cmdline.txt:"
cat $BOOT_DIR/cmdline.txt

echo
echo "/home/pi/.webthings/.node_version:"
cat /home/pi/.webthings/.node_version

echo
echo "package sources.list:"
cat /etc/apt/sources.list
echo
echo "debian.sources:"
cat /etc/apt/sources.list.d/debian.sources
echo
echo "raspi.sources:"
cat /etc/apt/sources.list.d/raspi.sources


echo
echo
echo "--------------------------------------------- shell environment"
echo

echo "printenv: "
printenv

echo
echo "declare -p: "
declare -p

echo
echo
echo "--------------------------------------------- linux"
echo

uname -a
echo
cat /etc/os-release
echo
echo "/etc/modules (kernel):"
cat /etc/modules
echo
echo "/lib/modules (kernel)"
ls -l /lib/modules/ | awk -F" " '{print $9}'
echo
echo "active kernel modules"
awk '{ print $1 }' /proc/modules | xargs modinfo | grep filename | awk '{ print $2 }' | sort

echo
echo
echo "--------------------------------------------- user"
echo
loginctl user-status --no-pager

echo
export -p
echo
systemctl --user show-environment --no-pager


echo
echo
echo "--------------------------------------------- apt"
echo

apt policy | cat

echo
echo
echo "--------------------------------------------- time"
echo

timedatectl --no-pager


echo
echo
echo "--------------------------------------------- audio"
echo

echo
lsof /dev/snd/*
echo
aplay -l
echo
arecord -l





echo
echo
echo "--------------------------------------------- display"
echo

echo "Attached HMDI devices:"
cat /sys/class/drm/card0/*HDMI*/status

echo "kmsprint:"
kmsprint | cat


echo
echo "fbset:"
fbset -i -v | cat

echo
#xrandr -d :0  
DISPLAY=:0 xrandr --verbose

echo
echo "vcgencmd get_config:"
vcgencmd get_config int
echo
vcgencmd get_config str
echo
echo
echo "/var/log/Xorg.0.log:"
cat /var/log/Xorg.0.log

echo
echo "Touch screen input:"
udevadm info -q all -n /dev/input/event4 | grep ''





echo
echo
echo "--------------------------------------------- camera"
echo



echo
echo "Libcamera:"
#libcamera-still --list-cameras
#libcamera-still 2>&1 | tee output
echo
LIBCAMERA_LOG_LEVELS=*:DEBUG cam -l
echo
v4l2-ctl --all
echo
v4l2-compliance 


echo
echo
echo "--------------------------------------------- pgio"
echo

pinctrl


echo
echo
echo "--------------------------------------------- other hardware"
echo

echo
echo "Plugged in USB devices:"
lsusb

echo
echo "I2C:"
ls /dev/i2c*
echo
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
grep . /sys/class/watchdog/*/*


echo
echo "Voltages:"
vcgencmd pmic_read_adc

echo
echo
echo "--------------------------------------------- network"

echo
echo "ifconfig:"
ifconfig

echo
echo "netstat:"
netstat -i

echo
# NetworkManager has been removed for now
echo
echo "nmcli overview:"
nmcli -o | cat

echo
echo "Wi-Fi:"
wpa_cli -i wlan0 status | grep wpa_state
wpa_cli -i wlan0 status | grep mode
echo
rfkill list
echo
iwconfig
echo "wifi power save?"
iw wlan0 get power_save
echo
echo "WiFi regulatory country settings:"
iw reg get
echo
echo "Allowed interface combinations (e.g. wlan0 and uap0 simultaneously):"
iw list | grep -A 4 'valid interface'

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
sysctl -a


echo
echo
echo "--------------------------------------------- cpu"
echo
echo "vmstat -s: "
vmstat -s




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
echo "ulimit -a pi"
ulimit -a pi

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
echo "- /dev/mmcblk0p2 is the system partition. If this is (almost) full, that means an upgrade went very wrong."
echo "- /dev/mmcblk0p3 Is a rescue partition. It has a very small linux version that can be started, and then sets the first and third partition to the latest available versions."
echo "- /dev/mmcblk0p4 is the user partition, where your actual personal data is stored. If it is (almost) full, delete some logs or photos?"
echo
echo "Details:"
du /home/pi --max-depth=1 -h


echo
echo
echo "--------------------------------------------- /boot files"
echo

ls $BOOT_DIR -a -l -h

echo
echo
echo "--------------------------------------------- startup"
echo
systemd-analyze --no-pager critical-chain

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



echo
echo
echo "--------------------------------------------- matter"
echo

sysctl net.ipv6.conf.all.forwarding
sysctl net.ipv6.conf.wlan0.accept_ra
sysctl net.ipv6.conf.wlan0.accept_ra_rt_info_max_plen=64

sysctl net.ipv4.conf.all.arp_ignore

echo
echo
echo "--------------------------------------------- software"
echo

dpkg -l --no-pager

