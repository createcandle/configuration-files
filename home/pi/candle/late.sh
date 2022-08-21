#!/bin/bash
set +e

#/bin/echo "in late" | sudo tee -a /dev/kmsg
echo "In late" >> /dev/kmsg


# RUN POST BOOTUP SCRIPT IF IT EXISTS
# These scripts are allowed to run in paralel with the controller, for example so that their output can be shown in the UI
if [ -f /boot/post_bootup_actions.sh ]
then
  echo " "
  echo "Candle: late.sh: detected post_bootup_actions.sh file." >> /dev/kmsg
  echo "Candle: late.sh: detected post_bootup_actions.sh file." >> /boot/candle_log.txt

  # Avoid bootloops
  if [ -f /boot/post_bootup_actions_failed.sh ]; then
    rm /boot/post_bootup_actions_failed.sh
  fi
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
      echo "Candle: rc.local doing post_bootup_actions: no network yet $i" >> /dev/kmsg
      echo "no network yet $i"
      sleep 1    
    else
      echo "Candle: rc.local doing post_bootup_actions: IP address detected: $(hostname -I)" >> /dev/kmsg
      break
    fi
  done

  # Force a synchronisation with a time server to avoid certificate issues
  if [ -f /boot/candle_hardware_clock.txt ]
  then
    echo "Candle: rc.local doing post_bootup_actions: hardware clock detected, forcing sync with NTP server" >> /dev/kmsg
    rm /boot/candle_hardware_clock.txt
    sudo systemctl start systemd-timesyncd
  fi
 
  if [ -f /boot/developer.txt ] || [ -f /boot/candle_cutting_edge.txt ];
  then
    systemctl start ssh.service
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



# Do aditional checks for missing files, and restore them if possible.
if [ -d /home/pi/candle/configuration-files-backup ]; then
    if rsync --ignore-existing --dry-run -vri /home/pi/candle/configuration-files-backup/* / | grep -q  +++++; then
        echo "Candle: ERROR, late.sh detected missing files. Attempting to fix" >> /dev/kmsg
        echo "$(date) - ERROR, late.sh detected missing files. Attempting to fix." >> /boot/candle_log.txt
        if [ -d /ro ]; then
            if [ -d /ro/home/pi/candle/configuration-files-backup ]; then
                sudo mount -o remount,ro /rw
                rsync --ignore-existing -vr /ro/home/pi/candle/configuration-files-backup/* /ro >> /dev/kmsg
                sudo mount -o remount,ro /ro
            fi
        else
            rsync --ignore-existing -vr /home/pi/candle/configuration-files-backup/* / >> /dev/kmsg
        fi
        
        sleep 2
        if rsync --ignore-existing --dry-run -vri /home/pi/candle/configuration-files-backup/* / | grep -q  +++++; then
            echo "Candle: ERROR, late.sh: missing files fix failed" >> /dev/kmsg
            echo "$(date) - ERROR, late.sh: missing files fix failed" >> /boot/candle_log.txt
        else
            echo "Candle: late.sh: missing files fix succeeded" >> /dev/kmsg
            echo "$(date) - late.sh: missing files fix succeeded" >> /boot/candle_log.txt
        fi
    fi
else
    echo "Candle: warning, configuration files backup dir does not exist" >> /dev/kmsg
fi
