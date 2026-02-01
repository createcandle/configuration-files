#!/bin/bash
set +e


BOOT_DIR="/boot"
if lsblk | grep -q $BOOT_DIR/firmware; then
    #echo "firmware partition is mounted at $BOOT_DIR/firmware"
    BOOT_DIR="$BOOT_DIR/firmware"
fi

if [ -f $BOOT_DIR/emergency.txt ]; then
	exit 0
fi

#/bin/echo "in late" | sudo tee -a /dev/kmsg
echo "$(date) - Candle: in late" >> /dev/kmsg
echo "late.sh: initial hostname -i: "
hostname -I
echo

# Wait for IP address for at most 30 seconds
echo "Candle: late: waiting for IP address"
for i in {1..30}
do
    #echo "current hostname: $(hostname -I)"
	IPS=$(hostname -I | sed -r 's/192.168.12.1//' | xargs)
	if echo "$IPS" | grep -q "." ; then
		echo "Candle: late.sh: IP address detected: $(hostname -I)" >> /dev/kmsg
		break
	else
		echo "Candle: late.sh: no IP4 network address yet: $i" >> /dev/kmsg
		sleep 1    
	fi
done





# RUN POST BOOTUP SCRIPT IF IT EXISTS
# These scripts are allowed to run in paralel with the controller, for example so that their output can be shown in the UI
if [ -f $BOOT_DIR/post_bootup_actions.sh ]
then
  echo
  echo "Candle: late.sh: detected post_bootup_actions.sh file." >> /dev/kmsg
  echo "Candle: late.sh: detected post_bootup_actions.sh file." >> $BOOT_DIR/candle_log.txt


  if [ -f $BOOT_DIR/post_bootup_actions_failed.sh ]; then
    rm $BOOT_DIR/post_bootup_actions_failed.sh
  fi
  
  # Avoid bootloops
  mv -f $BOOT_DIR/post_bootup_actions.sh $BOOT_DIR/post_bootup_actions_failed.sh

  if [ -f $BOOT_DIR/rotate180.txt ]
  then
    /bin/ply-image $BOOT_DIR/splash_updating180.png
  else
    /bin/ply-image $BOOT_DIR/splash_updating.png
  fi

  # Start SSH if developer mode is active, or if we're handling a cutting edge post_bootup_action, which is more likely to fail
  if [ -f $BOOT_DIR/developer.txt ] || [ -f $BOOT_DIR/candle_cutting_edge.txt ];
  then
    systemctl start ssh.service
  fi

  # Force a synchronisation with a time server to avoid certificate issues
  if [ -f $BOOT_DIR/candle_hardware_clock.txt ]
  then
    echo "Candle: late.sh doing post_bootup_actions: hardware clock detected, forcing sync with NTP server" >> /dev/kmsg
    rm $BOOT_DIR/candle_hardware_clock.txt
    sudo systemctl start systemd-timesyncd
  fi
  
  echo "Candle: late.sh doing post_bootup_actions: STARTING" >> /dev/kmsg
  chmod +x $BOOT_DIR/post_bootup_actions_failed.sh
  /bin/bash $BOOT_DIR/post_bootup_actions_failed.sh
  
  echo "Candle: late: post_bootup_actions.sh file complete" >> /dev/kmsg
  echo "Candle: late: post_bootup_actions.sh file complete" >> $BOOT_DIR/candle_log.txt
  echo " " >> /dev/kmsg
  # rm $BOOT_DIR/post_bootup_actions_failed.sh # Scripts should clean themselves up. If the self-cleanup failed, power-settings addon uses that as an indicator the script failed.
 
  sleep 5
  #exit 0
fi



# Do aditional checks for missing files, and restore them if possible. rc.local does this too.
#if [ -f $BOOT_DIR/restore_boot_backup.txt ] && [ ! -d /ro ]; then
#    if [ -d /home/pi/candle/configuration-files-backup ]; then
#        if rsync --ignore-existing --dry-run --inplace -vri /home/pi/candle/configuration-files-backup/ / | grep -q  +++++; then
#            echo "Candle: ERROR, late.sh detected missing files. Attempting to fix" >> /dev/kmsg
#            echo "$(date) - ERROR, late.sh detected missing files. Attempting to fix." >> $BOOT_DIR/candle_log.txt
#            if [ -d /ro ]; then
#                if [ -d /ro/home/pi/candle/configuration-files-backup ]; then
#                    sudo mount -o remount,ro /rw
#                    rsync --ignore-existing --inplace -vri /ro/home/pi/candle/configuration-files-backup/* /ro > $BOOT_DIR/candle_fix.txt
#                    sudo mount -o remount,ro /ro
#                fi
#            else
#                rsync -vr --ignore-existing --inplace /home/pi/candle/configuration-files-backup/ / >> /dev/kmsg
#            fi
#
#            sleep 2
#            if rsync --ignore-existing --inplace --dry-run -vri /home/pi/candle/configuration-files-backup/ / | grep -q  +++++; then
#                echo "Candle: ERROR, late.sh: missing files fix failed" >> /dev/kmsg
#                echo "$(date) - ERROR, late.sh: missing files fix failed. See candle_fix_failed.txt" >> $BOOT_DIR/candle_log.txt
#                rsync --ignore-existing --inplace --dry-run -vri /home/pi/candle/configuration-files-backup/ / > $BOOT_DIR/candle_fix_failed.txt
#            else
#                echo "Candle: late.sh: missing files fix succeeded" >> /dev/kmsg
#                echo "$(date) - late.sh: missing files fix succeeded" >> $BOOT_DIR/candle_log.txt
#                if [ -f $BOOT_DIR/candle_failed_fix.txt ]; then
#                    rm $BOOT_DIR/candle_failed_fix.txt
#                fi
#            fi
#        fi
#    else
#        echo "Candle: late.sh: warning, configuration files backup dir does not exist" >> /dev/kmsg
#    fi
#fi


    
# This can occur if developer mode is permanently enabled
if [ -f /var/log/syslog ]; then
    if [ "$(stat -c%s /var/log/syslog)" -gt 10000000 ]; then
        echo "Candle: Warning, deleted large syslog" >> /dev/kmsg
        rm /var/log/syslog
    fi
fi

# Also make sure the candle_log.txt file isn't getting too big
if [ -f $BOOT_DIR/candle_log.txt ]; then
    if [ "$(stat -c%s $BOOT_DIR/candle_log.txt)" -gt 5000000 ]; then
        echo "Candle: Warning, deleted large candle_log.txt" >> /dev/kmsg
        rm $BOOT_DIR/candle_log.txt
    fi
fi

# Clean up the journal
if [ ! -f $BOOT_DIR/developer.txt ]; then
  journalctl --vacuum-size=100K
fi



# After booting it's not longer necessary to keep triggerhappy running
if [ -f /usr/sbin/thd ]; then
	systemctl stop triggerhappy.socket
	systemctl stop triggerhappy.service
fi

# Stop the serial console once the system is safely up and running
#if [ ! -f $BOOT_DIR/developer.txt ]; then
    #sleep 60
    #systemctl stop getty@tty3.service 
#fi

echo "$(date) - end of late.sh" >> /dev/kmsg
