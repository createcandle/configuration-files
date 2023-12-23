#!/bin/bash

echo "Candle: in kiosk.sh" >> /dev/kmsg

BOOT_DIR="/boot"
if lsblk | grep -q $BOOT_DIR/firmware; then
    BOOT_DIR="$BOOT_DIR/firmware"
fi


if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/splash.png" ] && [ -f "$BOOT_DIR/splash180.png" ]; then
    if [ -e "$BOOT_DIR/rotate180.txt" ]; then
        /bin/ply-image $BOOT_DIR/splash180.png
    else
        /bin/ply-image $BOOT_DIR/splash.png
    fi
    #sleep 1
fi

#if [ -f $BOOT_DIR/post_bootup_actions.sh ]; then
#  if [ -f $BOOT_DIR/rotate180.txt ]; then
#    feh --bg-fill $BOOT_DIR/splash_updating180.png &
#  else
#    feh --bg-fill $BOOT_DIR/splash_updating.png &
#  fi
#fi

timeout --foreground -s TERM 30s bash -c \
   'while [[ "$(curl -s -o /dev/null -m 3 -L -w ''%{http_code}'' $CANDLE_URL)" != "200" ]];\
   do echo "Waiting for url" && sleep 2;\
   done;\
   echo "Server seems to be up: $CANDLE_URL"'



totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
#logger total memory: $totalk

if ls -l /dev/fb*; then

    # Start X server
    if [ -f $BOOT_DIR/candle_kiosk.txt ] && [ -f $BOOT_DIR/candle_first_run_complete.txt ]
    then

        echo "Candle: Enough memory to start X server" >> /dev/kmsg
        #logger Starting X

        pkill vlc
        pkill x
        sleep 1

        if [ -n "$(ls /dev/input/by-id/usb-ILITEK_ILITEK-TP-mouse 2>/dev/null)" ]
        then
          # Raspad touchscreen
          su - pi -c 'startx -- -nocursor &'
        else
          # any mouse
          if [ -n "$(ls /dev/input/by-id/*-mouse 2>/dev/null)" ]
          then
            su - pi -c 'startx &'
            #su - pi -c 'unclutter -idle 10 -root -display :0 &'
          else
            if [ ! -f $BOOT_DIR/hide_mouse_pointer.txt ]
            then
              su - pi -c 'startx &'
            else
              su - pi -c 'startx -- -nocursor &'
              #su - pi -c 'unclutter -idle 0 -root -display :0 &'
            fi
          fi
        fi
      
    fi
else
    echo "Candle: no display detected, not starting kiosk mode" >> /dev/kmsg
fi
