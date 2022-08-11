#!/bin/bash
set +e

#/bin/echo "in late" | sudo tee -a /dev/kmsg
echo "In late. Starting X." >> /dev/kmsg

if [ -f /boot/candle_kiosk.txt ]
then
  if [ "$totalk" -gt 1500000 ]
  then
    echo "Candle: Enough memory to start X server" >> /dev/kmsg
    logger Starting X
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
        if [ ! -f /boot/hide_mouse_pointer.txt ]
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

if [ -f /boot/generate_debug.txt ]; then
  rm /boot/generate_debug.txt
  sleep 5
  echo "Candle: generating debug file" >> /dev/kmsg
  /home/pi/debug.sh > /boot/debug.txt
fi
