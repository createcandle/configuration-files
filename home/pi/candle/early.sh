#!/bin/bash
set +e

# This runs even before early.sh

echo "in Candle early"
echo "$(date) - in Candle early. Fixing hostname." >> /dev/kmsg

# Fix hostname
/usr/bin/hostname -F /home/pi/.webthings/etc/hostname
systemctl restart avahi-daemon.service


# Add firewall rules
if iptables --list | grep 4443; then
    echo "IPTABLES ALREADY ADDED"
else
    echo "Candle early: adding iptable rules" >> /dev/kmsg
    iptables -t mangle -A PREROUTING -p tcp --dport 80 -j MARK --set-mark 1
    iptables -t mangle -A PREROUTING -p tcp --dport 443 -j MARK --set-mark 1
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
    iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 4443
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -m mark --mark 1 -j ACCEPT
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 4443 -m mark --mark 1 -j ACCEPT
fi

# detect potential issues that can happen after an upgrade
if ifconfig | grep -q wlan0: ; then
    echo "wlan0 exists"
else
    echo "Candle: EARLY.SH: WLAN0 is not in ifconfig (yet?)" >> /dev/kmsg
    if cat /etc/systemd/system/dhcpcd.service.d/wait.conf | grep -q /usr/lib/dhcpcd5/dhcpcd ; then
        echo "($date) - early.sh had to apply dhcpcd fix to wait.conf" >> /boot/candle_log.txt
        sudo mount -o remount,rw /ro
        sed -i 's|/usr/lib/dhcpcd5/dhcpcd|/usr/sbin/dhcpcd|g' /ro/etc/systemd/system/dhcpcd.service.d/wait.conf
        sudo mount -o remount,ro /ro
        if [ -f /boot/developer.txt ] || [ -f /boot/candle_cutting_edge.txt ]; then
            systemctl start ssh.service
        fi
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/splash_updating.png" ] && [ -f "/boot/splash_updating180.png" ]; then
            if [ -e "/boot/rotate180.txt" ]; then
                /bin/ply-image /boot/splash_updating180.png
            else
               /bin/ply-image /boot/splash_updating.png
            fi
        fi
        sleep 10
        reboot
    else
        #echo "Early: starting wpa_supplicant" >> /dev/kmsg
        #sudo wpa_supplicant -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf -B
    fi
fi

# Do not show blinking cursor
echo 0 > /sys/class/graphics/fbcon/cursor_blink

# For bluetooth keyboard?
modprobe hidp

# Disable WiFi power save
if [ -f /boot/disable_wifi_power_save.txt ] || [ -d /home/pi/.webthings/addons/hotspot ];
then
  echo "Candle: rc.local: disabling wifi power saving" >> /dev/kmsg
  /sbin/iw dev wlan0 set power_save off
fi


# Create emergency backup
if [ -f /boot/candle_make_emergency_backup.txt ]; 
then
    rm /boot/candle_make_emergency_backup.txt
    if [ -d /home/pi/.webthings/data ] && [ -d /home/pi/.webthings/config ]; then
        echo "$(date) - creating candle_emergency_backup.tar"
        cd /home/pi/.webthings
        find ./config ./data -maxdepth 2 -name "*.json" -o -name "*.yaml" -o -name "*.sqlite3" | tar -cf /boot/candle_emergency_backup.tar -T -
    else
        echo "$(date) - ERROR, could not create emergency backup, config and data directories did not exist?"
    fi
fi


# If the emergency file is detected, stop here.
if [ -e /boot/emergency.txt ]; 
then
  systemctl start ssh.service
  echo "Emergency file detected. Stopping (120 minutes sleep)" >> /dev/kmsg
  sleep 7200
  exit 0
fi


# If it's provided, copy a controller_backup.tar file from the boot partition into the system partition
if [ -f /boot/controller_backup.tar ]; 
then
  if [ -d /ro ]; then
    sudo mount -o remount,rw /ro
    rm /ro/home/pi/boot/controller_backup.tar
    mv /boot/controller_backup.tar /ro/home/pi/controller_backup.tar
    sudo mount -o remount,ro /ro
  else
    rm /home/pi/boot/controller_backup.tar
    mv /boot/controller_backup.tar /home/pi/controller_backup.tar
  fi
fi


# Handle forced restore of early.sh
if [ -f /boot/restore_boot_backup.txt ];
then
  rm /boot/restore_boot_backup.txt
  echo "Detected /boot/restore_boot_backup.txt"
  
  if [ -f /boot/developer.txt ] || [ -f /boot/candle_cutting_edge.txt ]; then
    systemctl start ssh.service
  fi
  
  if [ -f /etc/early.sh.bak ];
  then
    cp /etc/early.sh.bak /etc/early.sh
    echo "$(date) - forced restored boot backup" >> /boot/candle_log.txt
    echo "$(date) - forced restored boot backup" >> /dev/kmsg

  else
    echo "$(date) - forced restoring boot backup: no backup found" >> /boot/candle_log.txt
    echo "$(date) - forced restoring boot backup: no backup found" >> /dev/kmsg
  fi
fi


# Handle forced restore of Candle Controller backup
if [ -f /boot/restore_controller_backup.txt ];
then
  rm /boot/restore_controller_backup.txt
  echo "Detected /boot/restore_controller_backup.txt"
  
  if [ -f /boot/developer.txt ] || [ -f /boot/candle_cutting_edge.txt ]; then
    systemctl start ssh.service
  fi
  
  if [ -f /home/pi/controller_backup.tar ];
  then
  
    # Show updating image
    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/splash_updating.png" ] && [ -f "/boot/splash_updating180.png" ]; then
      if [ -e "/boot/rotate180.txt" ]; then
        /bin/ply-image /boot/splash_updating180.png
      else
        /bin/ply-image /boot/splash_updating.png
      fi
    fi
    
    # Restore backup
    cd /home/pi || exit
    echo "$(date) - forced restoring controller backup..." >> /boot/candle_log.txt
    echo "$(date) - forced restoring controller backup..." >> /dev/kmsg
    rm -rf /home/pi/webthings
    tar -xvf controller_backup.tar
    echo "$(date) - forced restoring controller backup done" >> /boot/candle_log.txt
    echo "$(date) - forced restoring controller backup done" >> /dev/kmsg
  
  
    if [ -f /home/pi/webthings/gateway/build/app.js ] \
    && [ -f /home/pi/webthings/gateway/.post_upgrade_complete ] \
    && [ -f /home/pi/webthings/gateway/build/static/index.html ] \
    && [ -d /home/pi/webthings/gateway/node_modules ] \
    && [ -d /home/pi/webthings/gateway/build/static/bundle ];
    then
      echo "$(date) - forced restoring controller backup done" >> /boot/candle_log.txt
      echo "$(date) - forced restoring controller backup done" >> /dev/kmsg
      reboot now
      sleep 5
      
    else
      echo "$(date) - forced restoring controller backup failed" >> /boot/candle_log.txt
      echo "$(date) - forced restoring controller backup failed" >> /dev/kmsg
      
      # Show error image
      if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/error.png" ]; then
        /bin/ply-image /boot/error.png
      fi
      
      sleep 7200
      exit 1
    fi
  
  else
    # Record that no backup was found
    echo "$(date) - forced restoring controller backup: no backup found" >> /boot/candle_log.txt
    echo "$(date) - forced restoring controller backup: no backup found" >> /dev/kmsg
    
    # Show error image
    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/error.png" ]; then
      /bin/ply-image /boot/error.png
    fi
    
    sleep 7200
    exit 1
  fi


# If the user wants a forced rebuild, do that.
elif [ -f /boot/force_controller_rebuild.txt ];
then
  rm /boot/force_controller_rebuild.txt
  echo "Detected /boot/force_controller_rebuild.txt"
  
  if [ -f /boot/developer.txt ] || [ -f /boot/candle_cutting_edge.txt ]; then
    systemctl start ssh.service
  fi
  
  if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/splash_updating.png" ] && [ -f "/boot/splash_updating180.png" ]; then
    if [ -e "/boot/rotate180.txt" ]; then
      /bin/ply-image /boot/splash_updating180.png
    else
      /bin/ply-image /boot/splash_updating.png
    fi
  fi
  
  # Wait for IP address for at most 30 seconds
  echo "Waiting for IP address..."
  for i in {1..30}
  do
    #echo "current IP: $(hostname -I)"
    if [ "$(hostname -I)" = "" ]
    then
      echo "Candle: early.sh: no network yet $i" >> /dev/kmsg
      echo "no network yet $i"
      sleep 1    
    else
      echo "Candle: early.sh: IP address detected: $(hostname -I)" >> /dev/kmsg
      break
    fi
  done
  
  cd /home/pi || exit
  echo "$(date) - starting forced controller regeneration..." >> /boot/candle_log.txt
  echo "$(date) - starting forced controller regeneration..." >> /dev/kmsg


    if [ -f /boot/candle_cutting_edge ]; then
        wget https://raw.githubusercontent.com/createcandle/install-scripts/main/install_candle_controller.sh -O ./install_candle_controller.sh
    else
        curl -s https://api.github.com/repos/createcandle/install-scripts/releases/latest \
        | grep "tarball_url" \
        | cut -d : -f 2,3 \
        | tr -d \" \
        | sed 's/,*$//' \
        | wget -qi - -O install-scripts.tar

        tar -xf install-scripts.tar
        rm install-scripts.tar

        for directory in createcandle-install-scripts*; do
          [[ -d $directory ]] || continue
          echo "Directory: $directory"
          mv -- "$directory" ./install-scripts
        done

        mv ./install-scripts/install_candle_controller.sh ./install_candle_controller.sh
        rm -rf ./install-scripts
        #echo
        #echo "result:"
        #ls install_candle_controller.sh
    fi


    # Check if the install_candle_controller.sh file now exists
    if [ ! -f install_candle_controller.sh ]; then
        echo
        echo "ERROR, missing install_candle_controller.sh file"
        echo "$(date) - Failed to download install_candle_controller script" >> /boot/candle_log.txt
        echo

        # Show error image
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f /boot/error.png ]; then
            /bin/ply-image /boot/error.png
            sleep 7200
        fi

        exit 1
    fi

    chmod +x ./install_candle_controller.sh
    sudo -u pi ./install_candle_controller.sh
    wait
    rm ./install_candle_controller.sh


  if [ -f /home/pi/webthings/gateway/build/app.js ] \
  && [ -f /home/pi/webthings/gateway/.post_upgrade_complete ] \
  && [ -f /home/pi/webthings/gateway/build/static/index.html ] \
  && [ -d /home/pi/webthings/gateway/node_modules ] \
  && [ -d /home/pi/webthings/gateway/build/static/bundle ];
  then
    echo "$(date) - forced controller regeneration done" >> /boot/candle_log.txt
    echo "$(date) - forced controller regeneration done" >> /dev/kmsg
    reboot now
    sleep 5
      
  else
    echo "$(date) - forced controller regeneration failed" >> /boot/candle_log.txt
    echo "$(date) - forced controller regeneration failed" >> /dev/kmsg
    
    # Show error image
    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/error.png" ]; then
      /bin/ply-image /boot/error.png
    fi
    sleep 7200
    exit 1
  fi

fi



# Generate debug file if requested
if [ -f /boot/generate_debug.txt ]; then
  rm /boot/generate_debug.txt
  rm /boot/debug.txt
  sleep 15
  echo "Candle: generating debug file" >> /dev/kmsg
  /home/pi/candle/debug.sh > /boot/debug.txt
fi

# Generate debug file if requested
if [ -f /boot/generate_raspinfo.txt ]; then
  rm /boot/generate_raspinfo.txt
  rm /boot/raspinfo.txt
  sleep 15
  echo "Candle: generating raspinfo file" >> /dev/kmsg
  raspinfo > /boot/raspinfo.txt
fi

# Automatically generates a file that lists which files on the controller are missing.
if [ -f /home/pi/candle/files_check.sh ]; then
  if [ -n "$(/home/pi/candle/files_check.sh)" ]; then
    /home/pi/candle/files_check.sh > /boot/candle_issues.txt
  elif [ -f /boot/candle_issues.txt ]; then
    rm /boot/candle_issues.txt
  fi
fi

if [ -f /boot/candle_rw_once.txt ]; then
  echo "Candle: removing candle_rw_once.txt" >> /dev/kmsg
  rm /boot/candle_rw_once.txt
fi

# Forget the wifi password
if [ -f /boot/candle_forget_wifi.txt ]; then
  rm /boot/candle_forget_wifi.txt
  echo -e 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=NL\n' > /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf
fi


totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
#logger total memory: $totalk

if [ "$totalk" -lt 600000 ]
then
  echo "Candle: low memory, so enabling swap: $totalk" >> /dev/kmsg
  touch /boot/candle_swap_enabled.txt
  /usr/sbin/dphys-swapfile setup
  /usr/sbin/dphys-swapfile swapon
else
  echo "Candle: enough memory, no need to enable swap: $totalk" >> /dev/kmsg
  if [ -e /boot/candle_swap_enabled.txt ] 
  then
    rm /boot/candle_swap_enabled.txt
  fi
  /usr/sbin/dphys-swapfile swapoff
  if [ -e /home/pi/.webthings/swap ] 
  then
    rm /home/pi/.webthings/swap
  fi
fi

# RUN BOOTUP SCRIPT IF IT EXISTS
if [ -f /boot/bootup_actions.sh ]
then
  echo " "
  echo "Candle: early: detected bootup_actions.sh file." >> /dev/kmsg
  echo "$(date) - rc.local: detected bootup_actions.sh file." >> /boot/candle_log.txt
  
  
  # Avoid bootloops
  if [ -f /boot/bootup_actions_failed.sh ]; then
    rm /boot/bootup_actions_failed.sh
  fi
  mv -f /boot/bootup_actions.sh /boot/bootup_actions_failed.sh

  if [ -f /boot/rotate180.txt ]
  then
    /bin/ply-image /boot/splash_updating180.png
  else
    /bin/ply-image /boot/splash_updating.png
  fi

  # Wait for IP address for at most 30 seconds
  echo "waiting for IP address"
  for i in {1..30}
  do
    #echo "current hostname: $(hostname -I)"
    if [ "$(hostname -I)" = "" ]
    then
      echo "Candle: early doing bootup_actions: no network yet $i" >> /dev/kmsg
      echo "no network yet $i"
      sleep 1    
    else
      echo "Candle: early doing bootup_actions: IP address detected: $(hostname -I)" >> /dev/kmsg
      break
    fi
  done

  # Force a synchronisation with a time server to avoid certificate issues
  if [ -f /boot/candle_hardware_clock.txt ]
  then
    echo "Candle: early doing bootup_actions: hardware clock detected, forcing sync with NTP server" >> /dev/kmsg
    rm /boot/candle_hardware_clock.txt
    sudo systemctl start systemd-timesyncd
  fi

  if [ -f /boot/developer.txt ]
  then
    systemctl start ssh.service
  fi
  
  echo "Candle: early doing bootup_actions: STARTING" >> /dev/kmsg
  chmod +x /boot/bootup_actions_failed.sh
  
  /bin/bash /boot/bootup_actions_failed.sh
  echo "Candle: early: bootup_actions.sh file is done" >> /dev/kmsg
  echo "Candle: early: bootup_actions.sh file is done" >> /boot/candle_log.txt
  echo " " >> /dev/kmsg
  # rm /boot/bootup_actions_failed.sh # Scripts should clean themselves up. If the self-cleanup failed, power-settings addon uses that as an indicator the script failed.
 
  # if /boot/bootup_actions_failed.sh still exists now, that means the bootup_actions script didn't clean up after itself.
  if [ -f /boot/bootup_actions_failed.sh ];; then
      echo "warning, bootup_actions_failed.sh still existed after the script completed" >> /dev/kmsg
  fi
 
  sleep 1
  
  
fi

echo "$(date) - End of Candle early." >> /dev/kmsg

exit 0

