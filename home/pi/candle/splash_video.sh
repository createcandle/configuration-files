#!/bin/bash

BOOT_DIR="/boot"
if lsblk | grep -q $BOOT_DIR/firmware; then
    BOOT_DIR="$BOOT_DIR/firmware"
fi

totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
#logger total memory: $totalk

if [ -f $BOOT_DIR/bootup_actions.sh ] || [ -f $BOOT_DIR/post_bootup_actions.sh ]; then

  # show update image
  if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/splash.png" ] && [ -f "$BOOT_DIR/splash180.png" ]; then
    if [ -e "$BOOT_DIR/rotate180.txt" ]; then
        /bin/ply-image $BOOT_DIR/splash_updating180.png
    else
        /bin/ply-image $BOOT_DIR/splash_updating.png
    fi
    sleep 1
  fi

else

  # show logo video
  if ls -l /dev/fb* && [ -f /usr/bin/vlc ] && [ ! -f $BOOT_DIR/post_bootup_actions.sh ]; then
    if [ -f $BOOT_DIR/candle_kiosk.txt ] && [ -f $BOOT_DIR/candle_first_run_complete.txt ]; then
      if [ "$totalk" -gt 800000 ] || [ -f $BOOT_DIR/candle_kiosk_forced.txt ]; then
        
        if [ -f $BOOT_DIR/rotate180.txt ]; then
          /usr/bin/vlc -L -f --no-osd --no-audio --fullscreen --no-audio --video-filter='transform{type="180"}' $BOOT_DIR/splash.mp4
          #startx /usr/bin/vlc -I dummy -L -f --no-osd --no-audio --fullscreen --video-on-top --no-audio --video-filter='transform{type="180"}' $BOOT_DIR/splash.mp4 -- &
      	else
          /usr/bin/vlc -L -f --no-osd --no-audio --fullscreen --no-audio $BOOT_DIR/splash.mp4
      	fi
       
      fi
    fi
  fi
  
fi
