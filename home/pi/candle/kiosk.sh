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


kiosk_txt_file="$BOOT_DIR/candle_kiosk.txt"
CANDLE_URL=$(cat "$kiosk_txt_file")


if [ -z "$CANDLE_URL" ]; then
    #echo "Candle: kiosk.sh: CANDLE_URL: $CANDLE_URL" >> /dev/kmsg

    echo "Candle: kiosk.sh: doing curl until server is up: $CANDLE_URL" >> /dev/kmsg
    #CURL_TEST="$(curl -s -o /dev/null -m 3 -L -w ''%{http_code}'' $CANDLE_URL)"
    #echo "CURL_TEST: 200?: $CURL_TEST"
    
    timeout --foreground -s TERM 30s bash -c \
       'while [[ "$(curl -s -o /dev/null -m 3 -L -w ''%{http_code}'' $CANDLE_URL)" != "200" ]];\
       do echo "Candle: kiosk: waiting for url" >> /dev/kmsg && sleep 2;\
       done;\
       echo "Candle: kiosk: server seems to be up: $CANDLE_URL"'
fi

# candle_kiosk_forced.txt

#totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
#logger total memory: $totalk

if ls -l /dev/fb*; then

	# if DMlight exists, then this is probably a Raspberry Pi disk image with a desktop environment. So no need to start Openbox first.
    if [ -f /usr/sbin/dmlight ]; then
	echo "Candle: kiosk.sh: detected dmlight, so no need to start own window manager" >> /dev/kmsg
	pkill vlc
        pkill cvlc
        sleep 1
	bash /etc/X11/xinit/xinitrc 



    # Start X server
    elif [ -f $BOOT_DIR/candle_kiosk.txt ] && [ -f $BOOT_DIR/candle_first_run_complete.txt ]
    then

        echo "Candle: kiosk.sh: detected a display, will start Xorg" >> /dev/kmsg
        #logger Starting X

        pkill vlc
        pkill cvlc
        #pkill x
        sleep .2

        if [ -f $BOOT_DIR/show_mouse_pointer.txt ]; then
            su - pi -c 'startx &'
        
        elif [ -f $BOOT_DIR/hide_mouse_pointer.txt ]; then
            su - pi -c 'startx -- -nocursor &'

        # Auto-detect
        
        # Raspad touchscreen
        elif [ -n "$(ls /dev/input/by-id/usb-ILITEK_ILITEK-TP-mouse 2>/dev/null)" ]; then
          su - pi -c 'startx -- -nocursor &'

        # Generic touch screen
        elif udevadm info -q all -n /dev/input/event* | grep -q 'ID_INPUT_TOUCHSCREEN=1'; then
            su - pi -c 'startx -- -nocursor &'

        elif [ -n "$(ls /dev/input/by-id/*-mouse 2>/dev/null)" ]; then
            su - pi -c 'startx &'

        else
            if which unclutter; then
                su - pi -c 'unclutter -idle 5 -root -display :0 &'
            fi
            su - pi -c 'startx &'
        fi
      
    fi
else
    echo "Candle: no display detected, not starting kiosk mode" >> /dev/kmsg
fi
