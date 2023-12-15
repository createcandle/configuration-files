#!/bin/bash

BOOT_DIR="/boot"
if lsblk | grep -q $BOOT_DIR/firmware; then
    BOOT_DIR="$BOOT_DIR/firmware"
fi


if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "/boot/splash.png" ] && [ -f "/boot/splash180.png" ]; then
    if [ -e "/boot/rotate180.txt" ]; then
        /bin/ply-image /boot/splash180.png
    else
        /bin/ply-image /boot/splash.png
    fi
    sleep 1
fi

sleep 5


totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
#logger total memory: $totalk

if fbset | grep -q "No such file or directory"; then
    echo "Candle: no display detected, not starting kiosk mode" >> /dev/kmsg
else
    # Start X server
    if [ -f $BOOT_DIR/candle_kiosk.txt ] && [ -f $BOOT_DIR/candle_first_run_complete.txt ]
    then
      if [ "$totalk" -gt 1500000 ] || [ -f $BOOT_DIR/candle_kiosk_forced.txt ]
      then
        echo "Candle: Enough memory to start X server" >> /dev/kmsg
        #logger Starting X
        if [ -n "$(ls /dev/input/by-id/usb-ILITEK_ILITEK-TP-mouse 2>/dev/null)" ]
        then
          # Raspad touchscreen
          su - pi -c 'startx -- -nocursor &'
        else
          # any mouse
          if [ -n "$(ls /dev/input/by-id/*-mouse 2>/dev/null)" ]
          then
            su - pi -c startx &
            #su - pi -c 'unclutter -idle 10 -root -display :0 &'
          else
            if [ ! -f $BOOT_DIR/hide_mouse_pointer.txt ]
            then
              su - pi    startx &
            else
              su - pi -c 'startx -- -nocursor &'
              #su - pi -c 'unclutter -idle 0 -root -display :0 &'
            fi
          fi
        fi
      fi
    fi
fi

