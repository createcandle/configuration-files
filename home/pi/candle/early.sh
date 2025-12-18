#!/bin/bash
set +e

# This runs before rc.local

BOOT_DIR="/boot"
if lsblk | grep -q $BOOT_DIR/firmware; then
    BOOT_DIR="$BOOT_DIR/firmware"
fi

echo "in Candle early"
echo "$(date) - in Candle early. Fixing hostname." >> /dev/kmsg


sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.ip_forward=1

if [ -f /home/pi/.webthings/dnsmasq_log.txt ]; then
	rm /home/pi/.webthings/dnsmasq_log.txt
fi


PHY="PHY1"

if iw list | grep -q phy0; then
    PHY="PHY0"
fi

echo "PHY: $PHY"


# Create an alias for 'mlan0' wifi to 'wlan0' if needed
if ip link show | grep -q "mlan0:" ; then
	echo "whoa, spotted mlan0"
	if ! ip link show | grep -q "wlan0:" ; then
			echo "Candle: adding wifi wlan0 alias for mlan0" >> /dev/kmsg
			ip link property add dev mlan0 altname wlan0
	fi
        
elif ip link show | grep -q "wlan0:" ; then
	echo "wlan0 exists"
	if ! ip link show | grep -q "br0:" ; then
		echo "br0 does not exist yet"
		#/sbin/iw dev wlan0 interface add uap0 type __ap
	fi
fi

if ip link show | grep -q "br0:" ; then
MAC=$(nmcli device show wlan0 | grep HWADDR | awk '{print $2}')
MAC=${MAC%?}0
#ifconfig br0 hw ether $MAC
echo "early: mac ending with zero: $MAC"
fi







# If a hostname.txt file exists, use its contents to set the hostname, then remove the file
if [ -s $BOOT_DIR/hostname.txt ] && [ -s /home/pi/.webthings/etc/hostname ] && [ -s /home/pi/.webthings/etc/hosts ]; 
then
    OLD_HOSTNAME=$(head -1 /home/pi/.webthings/etc/hostname)
    NEW_HOSTNAME=$(head -1 $BOOT_DIR/hostname.txt)
    
    if [ "$OLD_HOSTNAME" == "$NEW_HOSTNAME" ]; then
        echo "hostname.txt is the same as the current hostname file" >> /dev/kmsg
    else
        echo "new hostname from hostname.txt: $OLD_HOSTNAME to $NEW_HOSTNAME" >> /dev/kmsg
        if [ -f $BOOT_DIR/candle_first_run_complete.txt ]; then
            echo "new hostname from hostname.txt: $OLD_HOSTNAME to $NEW_HOSTNAME" >> $BOOT_DIR/candle_log.txt
        fi
        sed -i -E -e "s/127\\.0\\.1\\.1[ \\t]+.*/127\\.0\\.1\\.1 \\t$NEW_HOSTNAME/g" /home/pi/.webthings/etc/hosts
        echo "$NEW_HOSTNAME" > /home/pi/.webthings/etc/hostname
        #rm $BOOT_DIR/hostname.txt
    fi
    
fi

# Fix hostname
/usr/bin/hostname -F /home/pi/.webthings/etc/hostname
systemctl restart avahi-daemon.service

if [ -e /usr/sbin/resolvconf ]; then
    echo "Candle: early: manually calling resolvconf -u" >> /dev/kmsg
	/usr/sbin/resolvconf -u
fi

# remove Chromium singleton lock if it exists
if [ -e /home/pi/.webthings/chromium/SingletonLock ]; then
    echo "Candle: early: removing Chromium singletonLock"
    echo "Candle: early: removing Chromium singletonLock" >> /dev/kmsg
	rm /home/pi/.webthings/chromium/Singleton*
fi
if [ -L /home/pi/.webthings/chromium/SingletonLock ]; then
    echo "Candle: early: removing Chromium singletonLock"
    echo "Candle: early: removing Chromium singletonLock" >> /dev/kmsg
	rm /home/pi/.webthings/chromium/Singleton*
fi



# Do not show blinking cursor
echo 0 > /sys/class/graphics/fbcon/cursor_blink

if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/splash.png" ] && [ -f "$BOOT_DIR/splash180.png" ]; then
	chvt 6
	if [ ! -f /boot/firmware/candle_developer.txt ] ; then
		if [ -e "$BOOT_DIR/rotate180.txt" ]; then
	        /bin/ply-image $BOOT_DIR/splash180.png
	    else
	        /bin/ply-image $BOOT_DIR/splash.png
	    fi
	    sleep 1
	fi
fi

# Add firewall rules
if [ -f /usr/sbin/iptables ] ; then
	if iptables --list | grep 4443; then
	    echo "IPTABLES ALREADY ADDED"
		echo "Candle early: iptables seem already added" >> /dev/kmsg
	else
	    echo "Candle early: adding iptable rules" >> /dev/kmsg
	    iptables -t mangle -A PREROUTING -p tcp --dport 80 -j MARK --set-mark 1
	    iptables -t mangle -A PREROUTING -p tcp --dport 443 -j MARK --set-mark 1
	    iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
	    iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 4443
	    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -m mark --mark 1 -j ACCEPT
	    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 4443 -m mark --mark 1 -j ACCEPT
	fi
else
	echo "Candle early: iptables not installed?" >> /dev/kmsg
fi


# Set DHCPCD value
#sysctl -w net.ipv6.neigh.wlan0.retrans_time_ms=1000

if [ -f $BOOT_DIR/candle_island.txt ] && [ -f /home/pi.webthings/addons/hotspot/island.sh ]
then
    echo "Candle: early: starting Island mode" >> /dev/kmsg
	chmod +x /home/pi.webthings/addons/hotspot/island.sh
    /home/pi.webthings/addons/hotspot/island.sh &
    #sleep 60
    #systemctl stop getty@tty3.service 
fi

# For bluetooth keyboard
if lsmod | grep hidp &> /dev/null ; then
  echo "candle early: hidp kernel module already loaded" >> /dev/kmsg
else
  echo "candle early: manually loading modprobe hidp" >> /dev/kmsg
  modprobe hidp
fi

# Delete addons
if [ -f $BOOT_DIR/candle_delete_these_addons.txt ]; then
    echo "candle early: spotted candle_delete_these_addons.txt" >> /dev/kmsg
    while read addon; do
      if [ -d "/home/pi/.webthings/addons/$addon" ]; then
          rm -rf "/home/pi/.webthings/addons/$addon"
          echo "deleting addon: $addon" >> /dev/kmsg
          echo "deleting addon: $addon" >> $BOOT_DIR/candle_log.txt
      else
          echo "addon not found, cannot delete: $addon" >> /dev/kmsg
          echo "addon not found, cannot delete: $addon" >> $BOOT_DIR/candle_log.txt
      fi
    done <$BOOT_DIR/candle_delete_these_addons.txt
    rm $BOOT_DIR/candle_delete_these_addons.txt
fi


# Install and manage Github addons
if [ -f $BOOT_DIR/candle_install_these_addons.txt ]; then
    echo "candle early: spotted candle_install_these_addons.txt" >> /dev/kmsg
    if [ -d /home/pi/.webthings/addons ]; then
        
        while read addon_git; do
            cd /home/pi/.webthings/addons
            if [ -n "$addon_git" ]; then
                if ! [[ ${addon_git} = http* ]]; then
                    addon_git="https://github.com/createcandle/$addon_git.git"
                    # This only works with Candle addons
                    echo "candle: early: modified addon name into git url: $addon_git" >> /dev/kmsg
                fi
                
                addon=$(basename "$addon_git" .git)
                if [ -n "$addon" ]; then
                    if [ -d "/home/pi/.webthings/addons/$addon" ]; then
                        if ! [ -d "/home/pi/.webthings/addons/$addon/.git" ]; then
                            echo "deleting old non-git addon folder first: $addon" >> /dev/kmsg
                            rm -rf "/home/pi/.webthings/addons/$addon"
                            git clone "$addon_git"
                        else
                            cd "/home/pi/.webthings/addons/$addon"
                            git pull
                        fi
                    else
                        echo "candle: early: addon not found, installing via git clone: $addon_git" >> /dev/kmsg
                        echo "candle: early: addon not found, installing via git clone: $addon_git" >> $BOOT_DIR/candle_log.txt
                        git clone "$addon_git"
                    fi
                fi
            fi
        done <$BOOT_DIR/candle_install_these_addons.txt
    else
        echo "Error, the entire addons folder could not be found" >> $BOOT_DIR/candle_log.txt
    fi
fi



# Enable WiFi power save
if [ -f $BOOT_DIR/candle_wifi_power_save.txt ] && [ ! -d /home/pi/.webthings/addons/hotspot ] ;
then
  if [ -f /sbin/iw ]; then
  	echo "Candle: early: enabling wifi power saving" >> /dev/kmsg
  	/sbin/iw dev wlan0 set power_save on
  fi
else
  if [ -f /sbin/iw ]; then
    echo "Candle: early: disabling wifi power saving" >> /dev/kmsg

    if ip link show | grep -q "mlan0:" ; then
      /sbin/iw dev mlan0 set power_save off
    fi
    
    if ip link show | grep -q "wlan0:" ; then
      /sbin/iw dev wlan0 set power_save off
    fi
	
  fi
fi


# Create emergency backup
if [ -f $BOOT_DIR/candle_make_emergency_backup.txt ]; 
then
    rm $BOOT_DIR/candle_make_emergency_backup.txt
    if [ -d /home/pi/.webthings/data ] && [ -d /home/pi/.webthings/config ]; then
        echo "$(date) - creating candle_emergency_backup.tar"
        cd /home/pi/.webthings
        find ./config ./data -maxdepth 2 -name "*.json" -o -name "*.yaml" -o -name "*.sqlite3" | tar -cf $BOOT_DIR/candle_emergency_backup.tar -T -
    else
        echo "$(date) - ERROR, could not create emergency backup, config and data directories did not exist?"
    fi
fi


# If the emergency file is detected, stop here.
if [ -e $BOOT_DIR/emergency.txt ]; 
then
  systemctl start ssh.service
  echo "Emergency file detected. Stopping (120 minutes sleep)" >> /dev/kmsg
  sleep 7200
  exit 0
fi



# Enable SSH once
if [ -e $BOOT_DIR/candle_ssh_once.txt ]; 
then
  systemctl start ssh.service
  rm $BOOT_DIR/candle_ssh_once.txt
else
  # Just enable SSH
  if [ -e $BOOT_DIR/candle_ssh.txt ] || [ -e $BOOT_DIR/candle_ssh_keep.txt ]; 
  then
    systemctl start ssh.service
  fi
fi



# If it's provided, copy a controller_backup.tar file from the boot partition into the system partition
if [ -f $BOOT_DIR/controller_backup.tar ]; 
then
  if [ -d /ro ]; then
    sudo mount -o remount,rw /ro
    rm /ro/home/pi/boot/controller_backup.tar
    mv $BOOT_DIR/controller_backup.tar /ro/home/pi/controller_backup.tar
    sudo mount -o remount,ro /ro
  else
    rm /home/pi/boot/controller_backup.tar
    mv $BOOT_DIR/controller_backup.tar /home/pi/controller_backup.tar
  fi
fi


# TODO: temporarily disabled to test if cookies can remain for login
#if [ -d /home/pi/.webthings/chromium/BrowserMetrics ]; then
#    rm -rf /home/pi/.webthings/chromium/BrowserMetrics/*
#fi

# Handle forced restore of Candle Controller backup
if [ -f $BOOT_DIR/restore_controller_backup.txt ];
then
  rm $BOOT_DIR/restore_controller_backup.txt
  echo "Detected $BOOT_DIR/restore_controller_backup.txt"
  
  if [ -f $BOOT_DIR/developer.txt ] || [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
    systemctl start ssh.service
  fi
  
  if [ -f /home/pi/controller_backup.tar ];
  then
  
    # Show updating image
    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/splash_updating.png" ] && [ -f "$BOOT_DIR/splash_updating180.png" ]; then
      if [ -e "$BOOT_DIR/rotate180.txt" ]; then
        /bin/ply-image $BOOT_DIR/splash_updating180.png
      else
        /bin/ply-image $BOOT_DIR/splash_updating.png
      fi
    fi
    
    # Restore backup
    cd /home/pi || exit
    echo "$(date) - forced restoring controller backup..." >> $BOOT_DIR/candle_log.txt
    echo "$(date) - forced restoring controller backup..." >> /dev/kmsg
    rm -rf /home/pi/webthings
    tar -xvf controller_backup.tar
    echo "$(date) - forced restoring controller backup done" >> $BOOT_DIR/candle_log.txt
    echo "$(date) - forced restoring controller backup done" >> /dev/kmsg
  
  
    if [ -f /home/pi/webthings/gateway/build/app.js ] \
    && [ -f /home/pi/webthings/gateway/.post_upgrade_complete ] \
    && [ -f /home/pi/webthings/gateway/build/static/index.html ] \
    && [ -d /home/pi/webthings/gateway/node_modules ] \
    && [ -d /home/pi/webthings/gateway/build/static/bundle ];
    then
      echo "$(date) - forced restoring controller backup done" >> $BOOT_DIR/candle_log.txt
      echo "$(date) - forced restoring controller backup done" >> /dev/kmsg
      reboot now
      sleep 5
      
    else
      echo "$(date) - forced restoring controller backup failed" >> $BOOT_DIR/candle_log.txt
      echo "$(date) - forced restoring controller backup failed" >> /dev/kmsg
      
      # Show error image
      if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/error.png" ]; then
        /bin/ply-image $BOOT_DIR/error.png
      fi
      
      sleep 7200
      exit 1
    fi
  
  else
    # Record that no backup was found
    echo "$(date) - forced restoring controller backup: no backup found" >> $BOOT_DIR/candle_log.txt
    echo "$(date) - forced restoring controller backup: no backup found" >> /dev/kmsg
    
    # Show error image
    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/error.png" ]; then
      /bin/ply-image $BOOT_DIR/error.png
    fi
    
    sleep 7200
    exit 1
  fi


# If the user wants a forced rebuild, do that.
elif [ -f $BOOT_DIR/force_controller_rebuild.txt ];
then
  rm $BOOT_DIR/force_controller_rebuild.txt
  echo "Detected $BOOT_DIR/force_controller_rebuild.txt"
  
  if [ -f $BOOT_DIR/developer.txt ] || [ -f $BOOT_DIR/candle_cutting_edge.txt ]; then
    systemctl start ssh.service
  fi
  
  if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/splash_updating.png" ] && [ -f "$BOOT_DIR/splash_updating180.png" ]; then
    if [ -e "$BOOT_DIR/rotate180.txt" ]; then
      /bin/ply-image $BOOT_DIR/splash_updating180.png
    else
      /bin/ply-image $BOOT_DIR/splash_updating.png
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
  echo "$(date) - starting forced controller regeneration..." >> $BOOT_DIR/candle_log.txt
  echo "$(date) - starting forced controller regeneration..." >> /dev/kmsg


    if [ -f $BOOT_DIR/candle_cutting_edge ]; then
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
        echo "$(date) - Failed to download install_candle_controller script" >> $BOOT_DIR/candle_log.txt
        echo

        # Show error image
        if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f $BOOT_DIR/error.png ]; then
            /bin/ply-image $BOOT_DIR/error.png
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
    echo "$(date) - forced controller regeneration done" >> $BOOT_DIR/candle_log.txt
    echo "$(date) - forced controller regeneration done" >> /dev/kmsg
    reboot now
    sleep 5
      
  else
    echo "$(date) - forced controller regeneration failed" >> $BOOT_DIR/candle_log.txt
    echo "$(date) - forced controller regeneration failed" >> /dev/kmsg
    
    # Show error image
    if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/error.png" ]; then
      /bin/ply-image $BOOT_DIR/error.png
    fi
    sleep 7200
    exit 1
  fi

fi



# Generate debug.sh output if requested
if [ -f $BOOT_DIR/generate_debug.txt ]; then
  rm $BOOT_DIR/generate_debug.txt
  rm $BOOT_DIR/debug.txt
  sleep 15
  echo "Candle: generating debug file" >> /dev/kmsg
  /home/pi/candle/debug.sh > $BOOT_DIR/debug.txt
fi

# Generate raspinfo debug output if requested
if [ -f $BOOT_DIR/generate_raspinfo.txt ]; then
  rm $BOOT_DIR/generate_raspinfo.txt
  rm $BOOT_DIR/raspinfo.txt
  sleep 15
  echo "Candle: generating raspinfo file" >> /dev/kmsg
  raspinfo > $BOOT_DIR/raspinfo.txt
fi

# Automatically generates a file that lists which files on the controller are missing.
if [ -f /home/pi/candle/files_check.sh ]; then
  if [ -n "$(/home/pi/candle/files_check.sh)" ]; then
    /home/pi/candle/files_check.sh > $BOOT_DIR/candle_missing_files.txt
  elif [ -f $BOOT_DIR/candle_issues.txt ]; then
    rm $BOOT_DIR/candle_issues.txt
  fi
fi

if [ -f $BOOT_DIR/candle_rw_once.txt ]; then
  echo "Candle: removing candle_rw_once.txt" >> /dev/kmsg
  rm $BOOT_DIR/candle_rw_once.txt
fi

# Forget the wifi password
if [ -f $BOOT_DIR/candle_forget_wifi.txt ]; then
  rm $BOOT_DIR/candle_forget_wifi.txt
  echo -e 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=NL\n' > /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf
fi

# Forget all users
if [ -f $BOOT_DIR/candle_forget_users.txt ]; then
  rm $BOOT_DIR/candle_forget_users.txt
  sqlite3 "/home/pi/.webthings/config/db.sqlite3" "DELETE FROM users"
fi


totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
#logger total memory: $totalk


if [ "$totalk" -lt 600000 ]
then
  echo "Candle: low memory, so enabling swap: $totalk" >> /dev/kmsg
  
  if [ -f /usr/sbin/dphys-swapfile ]; then
    touch $BOOT_DIR/candle_swap_enabled.txt
    /usr/sbin/dphys-swapfile setup
    /usr/sbin/dphys-swapfile swapon
  fi
else
  echo "Candle: early: enough memory, no need to enable swap: $totalk" >> /dev/kmsg
  if [ -e $BOOT_DIR/candle_swap_enabled.txt ] 
  then
    rm $BOOT_DIR/candle_swap_enabled.txt
  fi
  if [ -f /usr/sbin/dphys-swapfile ]; then
  	/usr/sbin/dphys-swapfile swapoff
  fi
  if [ -e /home/pi/.webthings/swap ] 
  then
    rm /home/pi/.webthings/swap
  fi
fi





# RUN BOOTUP SCRIPT IF IT EXISTS
if [ -f $BOOT_DIR/bootup_actions.sh ]
then
  echo " "
  echo "Candle: early: detected bootup_actions.sh file." >> /dev/kmsg
  echo "$(date) - early: detected bootup_actions.sh file." >> $BOOT_DIR/candle_log.txt
  
  
  # Avoid bootloops
  if [ -f $BOOT_DIR/bootup_actions_failed.sh ]; then
    rm $BOOT_DIR/bootup_actions_failed.sh
  fi
  mv -f $BOOT_DIR/bootup_actions.sh $BOOT_DIR/bootup_actions_failed.sh

  if [ -f $BOOT_DIR/rotate180.txt ]
  then
    /bin/ply-image $BOOT_DIR/splash_updating180.png
  else
    /bin/ply-image $BOOT_DIR/splash_updating.png
  fi

  # Wait for IP address for at most 30 seconds
  echo "waiting for IP address"
  for i in {1..30}
  do
    #echo "current hostname: $(hostname -I)"
    if [ "$(hostname -I)" = "" ]
    then
      echo "Candle: early: doing bootup_actions: no network yet $i" >> /dev/kmsg
      echo "no network yet $i"
      sleep 1    
    else
      echo "Candle: early doing bootup_actions: IP address detected: $(hostname -I)" >> /dev/kmsg
      break
    fi
  done

  # Force a synchronisation with a time server to avoid certificate issues
  if [ -f $BOOT_DIR/candle_hardware_clock.txt ]
  then
    echo "Candle: early: doing bootup_actions: hardware clock detected, forcing sync with NTP server" >> /dev/kmsg
    rm $BOOT_DIR/candle_hardware_clock.txt
    sudo systemctl start systemd-timesyncd
  fi

  if [ -f $BOOT_DIR/developer.txt ]
  then
    systemctl start ssh.service
  fi
  
  echo "Candle: early doing bootup_actions: STARTING" >> /dev/kmsg
  chmod +x $BOOT_DIR/bootup_actions_failed.sh
  
  /bin/bash $BOOT_DIR/bootup_actions_failed.sh
  echo "Candle: early: bootup_actions.sh file is done" >> /dev/kmsg
  echo "Candle: early: bootup_actions.sh file is done" >> $BOOT_DIR/candle_log.txt
  echo " " >> /dev/kmsg
  # rm $BOOT_DIR/bootup_actions_failed.sh # Scripts should clean themselves up. If the self-cleanup failed, power-settings addon uses that as an indicator the script failed.
 
  # if $BOOT_DIR/bootup_actions_failed.sh still exists now, that means the bootup_actions script didn't clean up after itself.
  if [ -f $BOOT_DIR/bootup_actions_failed.sh ]; then
      echo "warning, bootup_actions_failed.sh still existed after the script completed" >> /dev/kmsg
  fi
 
  sleep 1
  
  
fi

# make tty accessible for startx
#chown pi /dev/tty0
#chown pi /dev/tty1
#chown pi /dev/tty2
#chown pi /dev/tty3


loginctl enable-linger pi

#chown pi /dev/tty0
#chown pi /dev/tty1
#chown pi /dev/tty2
#chown pi /dev/tty3

chmod 0660 /dev/tty0
#chmod 0660 /dev/tty1
chmod 0660 /dev/tty2
chmod 0660 /dev/tty3

echo "End of Candle early"
echo "$(date) - End of Candle early." >> /dev/kmsg

exit 0
