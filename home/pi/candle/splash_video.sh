#!/bin/bash

BOOT_DIR="/boot"
if lsblk | grep -q $BOOT_DIR/firmware; then
    BOOT_DIR="$BOOT_DIR/firmware"
fi

totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
#logger total memory: $totalk

 if ls -l /dev/fb* && [ -f /usr/bin/vlc ]; then
    if [ -f $BOOT_DIR/candle_kiosk.txt ] && [ -f $BOOT_DIR/candle_first_run_complete.txt ]; then
      if [ "$totalk" -gt 800000 ] || [ -f $BOOT_DIR/candle_kiosk_forced.txt ]; then
        if [ -f $BOOT_DIR/rotate180.txt ];l then
          /usr/bin/vlc -L -f --no-osd --no-audio --fullscreen --no-audio --video-filter='transform{type="180"}' $BOOT_DIR/splash.mp4
          #startx /usr/bin/vlc -I dummy -L -f --no-osd --no-audio --fullscreen --video-on-top --no-audio --video-filter='transform{type="180"}' $BOOT_DIR/splash.mp4 -- &
      	else
          /usr/bin/vlc -L -f --no-osd --no-audio --fullscreen --no-audio $BOOT_DIR/splash.mp4
      	fi
      fi
    fi
  fi
fi
