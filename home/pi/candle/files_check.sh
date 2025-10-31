#!/bin/bash

BOOT_DIR="/boot"
if lsblk | grep -q /boot/firmware; then
    BOOT_DIR="/boot/firmware"
fi

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
#if [ ! -d /etc/voicecard ]; then
#  echo "/etc/voicecard dir is missing"
#fi
if [ ! -d /etc/chromium/policies/managed/ ]; then
  echo "/etc/chromium/policies/managed/ dir is missing"
fi
if [ ! -d /home/pi/.webthings/var/lib/bluetooth ]; then
  echo "/home/pi/.webthings/var/lib/bluetooth dir is missing"
fi
if [ ! -d /home/pi/.webthings/var/lib/bluetooth ]; then
  echo "/home/pi/.webthings/var/lib/bluetooth dir is missing"
fi
if [ ! -d /home/pi/.webthings/etc/ssh/ssh_config.d ]; then
  echo "/home/pi/.webthings/etc/ssh/ssh_config.d dir is missing"
fi
if [ ! -d /home/pi/.webthings/addons/candleappstore ]; then
  echo "/home/pi/.webthings/addons/candleappstore dir is missing"
fi
if [ ! -d /home/pi/.webthings/addons/power-settings ]; then
  echo "/home/pi/.webthings/addons/power-settings dir is missing"
fi
if [ ! -d /home/pi/webthings/gateway/build/static/bundle ]; then
  echo "/home/pi/webthings/gateway/build/static/bundle dir is missing"
fi

if [ -d /usr/local/lib/python3.9 ]; then
    if [ ! -d /usr/local/lib/python3.9/dist-packages/gateway_addon ] && [ ! -d /home/pi/.local/lib/python3.9/site-packages/gateway_addon ]; then
      if [ ! -d /usr/local/lib/python3.9/dist-packages/gateway_addon ]; then
        echo "/usr/local/lib/python3.9/dist-packages/gateway_addon dir is missing"
      fi
      if [ ! -d /home/pi/.local/lib/python3.9/site-packages/gateway_addon ]; then 
        echo "/home/pi/.local/lib/python3.9/site-packages/gateway_addon dir is missing"
      fi
    fi
fi

if [ -d /usr/local/lib/python3.11 ]; then
    if [ ! -d /usr/local/lib/python3.11/dist-packages/gateway_addon ] && [ ! -d /home/pi/.local/lib/python3.11/site-packages/gateway_addon ]; then
      if [ ! -d /usr/local/lib/python3.11/dist-packages/gateway_addon ]; then
        echo "/usr/local/lib/python3.11/dist-packages/gateway_addon dir is missing"
      fi
      if [ ! -d /home/pi/.local/lib/python3.11/site-packages/gateway_addon ]; then 
        echo "/home/pi/.local/lib/python3.11/site-packages/gateway_addon dir is missing"
      fi
    fi
fi

# Files

# /home/pi files

if [ ! -f /usr/bin/edid-decode ]; then
  echo "/usr/bin/edid-decode is missing"
fi
if [ ! -f /home/pi/.webthings/floorplan.svg ]; then
  echo "/home/pi/.webthings/floorplan.svg is missing"
fi
if [ ! -f /home/pi/.webthings/config/db.sqlite3 ]; then
  echo "/home/pi/.webthings/config/db.sqlite3 is missing"
fi
if [ ! -f /home/pi/webthings/gateway/build/app.js ]; then
  echo "/home/pi/webthings/gateway/build/app.js is missing"
fi
if [ ! -f /etc/mosquitto/mosquitto.conf ]; then
  echo "/etc/mosquitto/mosquitto.conf is missing"
fi
if [ ! -f /home/pi/webthings/gateway/.post_upgrade_complete ]; then
  echo "/home/pi/webthings/gateway/.post_upgrade_complete is missing"
fi
if [ ! -f /home/pi/.webthings/etc/webthings_settings.js ]; then
  echo "/home/pi/.webthings/etc/webthings_settings.js is missing"
fi
if [ ! -f /home/pi/.webthings/etc/webthings_settings_backup.js ]; then
  echo "/home/pi/.webthings/etc/webthings_settings_backup.js is missing"
fi
if [ ! -f /home/pi/webthings/gateway/static/images/floorplan.svg ]; then
  echo "/home/pi/webthings/gateway/static/images/floorplan.svg is missing"
fi
if [ ! -f /home/pi/candle/installed_respeaker_version.txt ]; then
  echo "/home/pi/candle/installed_respeaker_version.txt is missing"
fi
if [ ! -f /home/pi/candle/creation_date.txt ]; then
  echo "/home/pi/candle/creation_date.txt is missing"
fi
if [ ! -f /home/pi/.webthings/addons/power-settings/factory_reset.sh ]; then
  echo "/home/pi/.webthings/addons/power-settings/factory_reset.sh is missing"
fi
if [ ! -f /home/pi/webthings/gateway/build/static/css/candle.css ]; then
  echo "/home/pi/webthings/gateway/build/static/css/candle.css is missing"
fi
if [ ! -f /home/pi/.webthings/etc/webthings_settings.js ]; then
  echo "/home/pi/.webthings/etc/webthings_settings.js is missing"
fi
if [ ! -f /home/pi/.webthings/etc/fake-hwclock.data ]; then
  echo "/home/pi/.webthings/etc/fake-hwclock.data is missing"
fi
if [ ! -f /home/pi/candle/candle_requirements.txt ]; then
  echo "/home/pi/candle/candle_requirements.txt is missing"
fi
#if [ ! -f /home/pi/candle/candle_packages.txt ]; then
#  echo "/home/pi/candle/candle_packages.txt is missing"
#fi
if [ ! -f /home/pi/candle/early.sh ]; then
  echo "/home/pi/candle/early.sh is missing"
fi
if [ ! -f /bin/chromium-browser ] && [ ! -f /bin/chromium ]; then
  echo "chromium is missing"
fi
if [ ! -f /bin/ply-image ]; then
  echo "/bin/ply-image is missing"
fi
if [ ! -f /bin/sqlite3 ]; then
  echo "/bin/sqlite3 is missing"
fi



#/boot files
if [ ! -f $BOOT_DIR/error.png ]; then
  echo "$BOOT_DIR/error.png is missing"
fi



#/etc files
if [ ! -f /etc/rc.local ]; then
  echo "/etc/rc.local is missing"
fi
if [ ! -f /etc/X11/xinit/xinitrc ]; then
  echo "/etc/X11/xinit/xinitrc is missing"
fi
#if [ ! -f /etc/alsa/conf.d/20-bluealsa.conf ]; then
#  echo "/etc/alsa/conf.d/20-bluealsa.conf is missing"
#fi
if [ ! -f /etc/avahi/services/candle.service ]; then
  echo "/etc/avahi/services/candle.service is missing"
fi
if [ ! -f /etc/avahi/services/candlemqtt.service ]; then
  echo "/etc/avahi/services/candlemqtt.service is missing"
fi
if [ ! -f /etc/systemd/system/fake-hwclock-save.service ]; then
  echo "/etc/systemd/system/fake-hwclock-save.service is missing"
fi
if [ ! -f /etc/systemd/system/webthings-gateway.service ]; then
  echo "/etc/systemd/system/webthings-gateway.service is missing"
fi
if [ ! -f /etc/systemd/system/bluetooth.service.d/candle.conf ]; then
  echo "/etc/systemd/system/bluetooth.service.d/candle.conf is missing"
fi


# Other files
if [ ! -f /usr/bin/pip3 ]; then
  echo "/usr/bin/pip3 is missing"
fi
#if [ ! -f /usr/bin/bluealsa ]; then
#  echo "/usr/bin/bluealsa is missing"
#fi
if [ ! -d /var/run/mosquitto ]; then
  echo "/var/run/mosquitto dir is missing"
fi


# Backups
#if [ -f $BOOT_DIR/candle_first_run_complete.txt ]; then
#  if [ ! -f /home/pi/controller_backup.tar ]; then
#    echo "/home/pi/controller_backup.tar backup is missing"
#  fi
#fi
#if [ ! -f /home/pi/candle/early.sh.bak ]; then
#  echo "/home/pi/candle/early.sh.bak backup is missing"
#fi
#if [ ! -f /etc/rc.local.bak ]; then
#  echo "/etc/rc.local.bak backup is missing"
#fi


# Files that should not exist
if [ -f /var/swap ]; then
  echo "/var/swap file exists"
fi
if [ -f /zero.fill ]; then
  echo "/zero.fill file exists"
  rm /zero.fill
fi
if [ -f /home/pi/.webthings/zero.fill ]; then
  echo "/home/pi/.webthings/zero.fill file exists"
  rm /home/pi/.webthings/zero.fill
fi
if [ -d /opt/vc/lib ]; then
  echo "/opt/vc/lib directory still exists"
fi
