#!/bin/bash
set +e

#/bin/echo "in late" | sudo tee -a /dev/kmsg
echo "$(date) - In late" >> /dev/kmsg


# RUN POST BOOTUP SCRIPT IF IT EXISTS
# These scripts are allowed to run in paralel with the controller, for example so that their output can be shown in the UI
if [ -f /boot/post_bootup_actions.sh ]
then
  echo " "
  echo "Candle: late.sh: detected post_bootup_actions.sh file." >> /dev/kmsg
  echo "Candle: late.sh: detected post_bootup_actions.sh file." >> /boot/candle_log.txt


  if [ -f /boot/post_bootup_actions_failed.sh ]; then
    rm /boot/post_bootup_actions_failed.sh
  fi
  
  # Avoid bootloops
  mv -f /boot/post_bootup_actions.sh /boot/post_bootup_actions_failed.sh

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
      echo "Candle: late.sh doing post_bootup_actions: no network yet $i" >> /dev/kmsg
      echo "no network yet $i"
      sleep 1    
    else
      echo "Candle: late.sh doing post_bootup_actions: IP address detected: $(hostname -I)" >> /dev/kmsg
      break
    fi
  done

  # Start SSH if developer mode is active, or if we're handling a cutting edge post_bootup_action, which is more likely to fail
  if [ -f /boot/developer.txt ] || [ -f /boot/candle_cutting_edge.txt ];
  then
    systemctl start ssh.service
  fi

  # Force a synchronisation with a time server to avoid certificate issues
  if [ -f /boot/candle_hardware_clock.txt ]
  then
    echo "Candle: late.sh doing post_bootup_actions: hardware clock detected, forcing sync with NTP server" >> /dev/kmsg
    rm /boot/candle_hardware_clock.txt
    sudo systemctl start systemd-timesyncd
  fi
  
  echo "Candle: late.sh doing post_bootup_actions: STARTING" >> /dev/kmsg
  chmod +x /boot/post_bootup_actions_failed.sh
  /bin/bash /boot/post_bootup_actions_failed.sh
  
  echo "Candle: post_bootup_actions.sh file complete" >> /dev/kmsg
  echo "Candle: post_bootup_actions.sh file complete" >> /boot/candle_log.txt
  echo " " >> /dev/kmsg
  # rm /boot/post_bootup_actions_failed.sh # Scripts should clean themselves up. If the self-cleanup failed, power-settings addon uses that as an indicator the script failed.
 
  sleep 5
  #exit 0
fi



# Do aditional checks for missing files, and restore them if possible. rc.local does this too.
if [ -f /boot/restore_boot_backup.txt ] && [ ! -d /ro ]; then
    if [ -d /home/pi/candle/configuration-files-backup ]; then
        if rsync --ignore-existing --dry-run --inplace -vri /home/pi/candle/configuration-files-backup/ / | grep -q  +++++; then
            echo "Candle: ERROR, late.sh detected missing files. Attempting to fix" >> /dev/kmsg
            echo "$(date) - ERROR, late.sh detected missing files. Attempting to fix." >> /boot/candle_log.txt
            if [ -d /ro ]; then
                if [ -d /ro/home/pi/candle/configuration-files-backup ]; then
                    sudo mount -o remount,ro /rw
                    rsync --ignore-existing --inplace -vri /ro/home/pi/candle/configuration-files-backup/* /ro > /boot/candle_fix.txt
                    sudo mount -o remount,ro /ro
                fi
            else
                rsync -vr --ignore-existing --inplace /home/pi/candle/configuration-files-backup/ / >> /dev/kmsg
            fi

            sleep 2
            if rsync --ignore-existing --inplace --dry-run -vri /home/pi/candle/configuration-files-backup/ / | grep -q  +++++; then
                echo "Candle: ERROR, late.sh: missing files fix failed" >> /dev/kmsg
                echo "$(date) - ERROR, late.sh: missing files fix failed. See candle_fix_failed.txt" >> /boot/candle_log.txt
                rsync --ignore-existing --inplace --dry-run -vri /home/pi/candle/configuration-files-backup/ / > /boot/candle_fix_failed.txt
            else
                echo "Candle: late.sh: missing files fix succeeded" >> /dev/kmsg
                echo "$(date) - late.sh: missing files fix succeeded" >> /boot/candle_log.txt
                if [ -f /boot/candle_failed_fix.txt ]; then
                    rm /boot/candle_failed_fix.txt
                fi
            fi
        fi
    else
        echo "Candle: late.sh: warning, configuration files backup dir does not exist" >> /dev/kmsg
    fi
fi


    
# This can occur is developer mode is permanently enabled
if [ -f /var/log/syslog ]; then
    if [ "$(stat -c%s /var/log/syslog)" -gt 10000000 ]; then
        echo "Candle: Warning, deleted large syslog" >> /dev/kmsg
        rm /var/log/syslog
    fi
fi

# Also make sure the candle_log.txt file isn't getting too big
if [ -f /boot/candle_log.txt ]; then
    if [ "$(stat -c%s /boot/candle_log.txt)" -gt 5000000 ]; then
        echo "Candle: Warning, deleted large candle_log.txt" >> /dev/kmsg
        rm /boot/candle_log.txt
    fi
fi

# Clean up the journal
if [ ! -f /boot/developer.txt ]; then
  journalctl --vacuum-size=10K
fi


# Forget the wifi password
if [ -f /boot/candle_forget_wifi.txt ]; then
    rm /boot/candle_forget_wifi.txt
    echo -e 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=NL\n' > /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf
fi


# Try to upgrade security of the wifi password
if cat /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf | grep -q psk=; then
    current_ssid="$(cat /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf | grep 'ssid=' | cut -d'"' -f 2 )"
    current_pass="$(cat /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf | grep 'psk=' | cut -d'"' -f 2 )"
    if [ "$(echo -n $current_pass | wc -c)" -lt 64 ]; then
        echo "Candle: late.sh: upgrading wifi password security" >> /dev/kmsg
        echo "$current_pass" | wpa_passphrase "$current_ssid" > ./temporary
        phrase=$(cat ./temporary | grep -v '#psk=' | grep 'psk=' | cut -d'=' -f 2)
        rm ./temporary
        #phrase="$(wpa_passphrase '$current_ssid' '$current_pass' | grep -v '#psk=' | grep 'psk=' | cut -d'=' -f 2  )"
        sed -i "s'\\\"${current_pass}\\\"'${phrase}'" /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf
    else
        echo "Candle: late.sh: Wifi password seems to already be upgraded" >> /dev/kmsg
    fi
fi

# After booting it's not longer necessary to keep triggerhappy running
systemctl stop triggerhappy.socket
systemctl stop triggerhappy.service


echo "$(date) - end of late.sh" >> /dev/kmsg
