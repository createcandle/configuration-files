#!/bin/bash

# This script is run as normal user

#echo "Candle: in kiosk.sh" >> /dev/kmsg


BOOT_DIR="/boot"
if lsblk | grep -q $BOOT_DIR/firmware; then
    BOOT_DIR="$BOOT_DIR/firmware"
fi

if [ -f $BOOT_DIR/emergency.txt ]; then
	exit 0
fi



#if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ] && [ -f "$BOOT_DIR/splash.png" ] && [ -f "$BOOT_DIR/splash180.png" ]; then
#    if [ -e "$BOOT_DIR/rotate180.txt" ]; then
#        /bin/ply-image $BOOT_DIR/splash180.png
#    else
#        /bin/ply-image $BOOT_DIR/splash.png
#    fi
    #sleep 1
#fi

#if [ -f $BOOT_DIR/post_bootup_actions.sh ]; then
#  if [ -f $BOOT_DIR/rotate180.txt ]; then
#    feh --bg-fill $BOOT_DIR/splash_updating180.png &
#  else
#    feh --bg-fill $BOOT_DIR/splash_updating.png &
#  fi
#fi









kiosk_txt_file="$BOOT_DIR/candle_kiosk.txt"
CANDLE_URL=$(cat "$kiosk_txt_file")



# candle_kiosk_forced.txt

#totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
#logger total memory: $totalk

if ls -l /dev/fb*; then

	if [ -f "$BOOT_DIR/candle_kiosk_disabled.txt" ]; then

		# show Candle logo image
		if [ -e "/bin/ply-image" ] && [ -e /dev/fb0 ]; then
			if [ -f "$BOOT_DIR/splash.png" ] && [ -f "$BOOT_DIR/splash180.png" ]; then
				if [ -e "$BOOT_DIR/rotate180.txt" ]; then
					/bin/ply-image $BOOT_DIR/splash180.png
				else
					/bin/ply-image $BOOT_DIR/splash.png
				fi
				sleep 3
			fi
			while [ -e "$BOOT_DIR/candle_kiosk_disabled.txt" ]; do 

				
				if [ -f "/home/pi/.webthings/data/photo-frame/persistence.json" ] && cat /home/pi/.webthings/data/photo-frame/persistence.json | grep -q '"night_mode": true,'; then

					if [ -e /dev/fb0 ] && [ -e /sys/class/graphics/fb0/virtual_size ]; then
						DISPLAY_SIZE=$(cat /sys/class/graphics/fb0/virtual_size)
						
						if [ -n "$DISPLAY_SIZE" ] && [[ "$DISPLAY_SIZE" == *","* ]]; then
								
							DISPLAY_WIDTH=$(echo "$DISPLAY_SIZE" | awk -F ',' '{print $1}')
							DISPLAY_HEIGHT=$(echo "$DISPLAY_SIZE" | awk -F ',' '{print $2}')
										
							echo "<svg height=\"$DISPLAY_HEIGHT\" viewBox=\"0 0 $DISPLAY_WIDTH $DISPLAY_HEIGHT\" width=\"$DISPLAY_WIDTH\" xmlns=\"http://www.w3.org/2000/svg\"><path d=\"m0 $DISPLAY_HEIGHTh$DISPLAY_WIDTHv-$DISPLAY_HEIGHTh-$DISPLAY_WIDTHz\" fill-rule=\"evenodd\"/></svg>" > /tmp/clock_bg.svg
							
							#FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
							FONT=$(find /usr/share/fonts -name DejaVuSans-Bold.ttf)
							FONT=$(echo $FONT | tr -d '\n')
							# shadowcolor=black:shadowx=2:shadowy=1:text='%Y-%m-%d\ %H\\\\:%M\\\\:%S'"
							if [ -f /tmp/clock_bg.svg ] && [ -n "$FONT" ]; then
								ffmpeg -re -stream_loop -1 \
									-i /tmp/clock_bg.svg \
									-vf "drawtext=expansion=strftime:\
										text='%H\:%M':\
										fontfile='${FONT}':\
										fontcolor=red@0.3:\
										fontsize=150:\
										x=(w-text_w)/2:\
										y=(h-text_h)/2\
										,rotate=PI/1"\
									-pix_fmt rgb565le \
									-f fbdev /dev/fb0
									
							fi
						fi
					fi
						
				elif [ -d "/home/pi/.webthings/data/photo-frame/photos" ]; then
				
					if [ -z "$(ls -A /home/pi/.webthings/data/photo-frame/photos)" ]; then
						#echo "There are no photos"
						if [ -f color_clock ]; then
							timeout 1m ./color_clock
						else
							sleep 10
						fi
						
					else
				   		#echo "There appear to be some photos"
						if [ -e /sys/class/graphics/fb0/virtual_size ]; then
							DISPLAY_SIZE=$(cat /sys/class/graphics/fb0/virtual_size)
						
							if [ -n "$DISPLAY_SIZE" ]; then
								#echo "DISPLAY_SIZE: $DISPLAY_SIZE"
								if [[ "$DISPLAY_SIZE" == *","* ]]; then
								
									DISPLAY_WIDTH=$(echo "$DISPLAY_SIZE" | awk -F ',' '{print $1}')
									DISPLAY_HEIGHT=$(echo "$DISPLAY_SIZE" | awk -F ',' '{print $2}')
									#echo "DISPLAY_WIDTH: $DISPLAY_WIDTH"
									#echo "DISPLAY_HEIGHT: $DISPLAY_HEIGHT"
									
									BIG_DISPLAY_WIDTH=$((DISPLAY_WIDTH * 1000))
									#BIG_DISPLAY_HEIGHT=$((DISPLAY_HEIGHT * 100))
									#echo "BIG_DISPLAY_WIDTH: $BIG_DISPLAY_WIDTH"
									#echo "BIG_DISPLAY_HEIGHT $BIG_DISPLAY_HEIGHT"
									DISPLAY_RATIO=$((BIG_DISPLAY_WIDTH / DISPLAY_HEIGHT))
									#echo "DISPLAY_RATIO: $DISPLAY_RATIO"
								
									for photo_filename in /home/pi/.webthings/data/photo-frame/photos/*.*
									do 
										#echo ""
										#echo "-"
										#echo "photo_filename: $photo_filename"
										#file "$photo_filename"
										#echo ""
										RESOLUTION=$(file "$photo_filename" | sed 's/+1x/x/' | grep -Eo "[[:digit:]]+ *x *[[:digit:]]+" | tail -n 1)
										#echo "- photo resolution: $RESOLUTION"
										PHOTO_WIDTH=$(echo "$RESOLUTION" | awk -F 'x' '{print $1}')
										PHOTO_HEIGHT=$(echo "$RESOLUTION" | awk -F 'x' '{print $2}')
										#echo "- photo width: -->$PHOTO_WIDTH<--"
										#echo "- photo height: -->$PHOTO_HEIGHT<--"
										BIG_PHOTO_WIDTH=$((PHOTO_WIDTH * 1000))
										PHOTO_RATIO=$((BIG_PHOTO_WIDTH / PHOTO_HEIGHT))
										#echo "PHOTO_RATIO: $PHOTO_RATIO"
										
										if [[ "$PHOTO_RATIO" -eq "$DISPLAY_RATIO"  ]]; then
											#echo "same ratio, so only scaling the image"
											ffmpeg -y -hide_banner -loglevel error -i "$photo_filename" -vframes 1 -vf "scale=$DISPLAY_WIDTH:-1" /tmp/kiosk_photo.png
										else
											if [ "$PHOTO_RATIO" -gt "$DISPLAY_RATIO" ]; then
												ffmpeg -y -hide_banner -loglevel error -i "$photo_filename" -vframes 1 -vf "scale=-1:$DISPLAY_HEIGHT,crop=$DISPLAY_WIDTH:$DISPLAY_HEIGHT:0:0" /tmp/kiosk_photo.png
											else
												ffmpeg -y -hide_banner -loglevel error -i "$photo_filename" -vframes 1 -vf "scale=$DISPLAY_WIDTH:-1,crop=$DISPLAY_WIDTH:$DISPLAY_HEIGHT:0:0" /tmp/kiosk_photo.png
											fi
										fi
										if [ -f /tmp/kiosk_photo.png ]; then
											# Rotating is done in a separate step on purpose
											if [ -f "$BOOT_DIR/rotate180.txt" ]; then
												#echo "rotating the photo too"
												ffmpeg -y -hide_banner -loglevel error -i /tmp/kiosk_photo.png -vf "transpose=2,transpose=2" /tmp/kiosk_photo180.png
												/bin/ply-image /tmp/kiosk_photo180.png
												rm /tmp/kiosk_photo180.png
											else
												/bin/ply-image /tmp/kiosk_photo.png
											fi
											
											rm /tmp/kiosk_photo.png
										fi
										sleep 30
									done
								fi
							fi
						fi
						
					fi
					sleep 1
					
				elif [ -f color_clock ]; then
					timeout 60m ./color_clock
				fi
				
			done
			sleep 1
		fi
		
		
	else
		if [ -z "$CANDLE_URL" ]; then
		    #echo "Candle: kiosk.sh: CANDLE_URL: $CANDLE_URL" >> /dev/kmsg
		
		    #echo "Candle: kiosk.sh: doing curl until server is up: $CANDLE_URL" >> /dev/kmsg
		    #CURL_TEST="$(curl -s -o /dev/null -m 3 -L -w ''%{http_code}'' $CANDLE_URL)"
		    #echo "CURL_TEST: 200?: $CURL_TEST"
		
		    timeout --foreground -s TERM 30s bash -c \
		       'while [[ "$(curl -s -o /dev/null -m 3 -L -w ''%{http_code}'' $CANDLE_URL)" != "200" ]];\
		       do echo "Candle: kiosk.sh: waiting for url" && sleep 2;\
		       done;\
		       echo "Candle: kiosk.sh: server seems to be up: $CANDLE_URL"'
		fi
	
	
	
		if [ -f /usr/bin/labwc ] && [ -f /home/pi/candle/wayland_kiosk.sh ]; then 
			while true; do
	    		"XDG_RUNTIME_DIR=/run/user/$(d -u)" labwc -s '/home/pi/candle/wayland_kiosk.sh'
				sleep 1
			done
	   		
	   
	
		# if DMlight exists, then this is probably a Raspberry Pi disk image with a desktop environment. So no need to start Openbox first.
		elif [ -f /usr/sbin/lightdm ]; then
	        #echo "Candle: kiosk.sh: detected dmlight, so no need to start own window manager" >> /dev/kmsg
	        pkill vlc
	        pkill cvlc
	        sleep 1
	        /bin/bash /etc/X11/xinit/xinitrc &
	
	
	
	    # Start X server
	    elif [ -f $BOOT_DIR/candle_kiosk.txt ] && [ -f $BOOT_DIR/candle_first_run_complete.txt ]
	    then
	
	        #echo "Candle: kiosk.sh: detected a display, will start Xorg" >> /dev/kmsg
	        #logger Starting X
	
	        #pkill vlc
	        #pkill cvlc
	        #pkill x
	        #sleep .2
	
		    #dbus-launch
			#sleep .2
			
	        if [ ! -f $BOOT_DIR/candle_show_mouse_pointer.txt ]; then
	            echo "Candle: kiosk.sh:  spotted candle_show_mouse_pointer.txt,  starting X and showing mouse pointer"
				#if which unclutter; then
	            #    unclutter -idle 5 -root -display :0
	            #fi
	            startx
	
	        elif [ -f $BOOT_DIR/candle_hide_mouse_pointer.txt ]; then
	            echo "Candle: kiosk.sh:  spotted hide_mouse_pointer.txt,  starting X and hiding mouse pointer"
	            startx -- -nocursor
	
	        # Auto-detect
	
	        # Raspad touchscreen
	        elif [ -n "$(ls /dev/input/by-id/usb-ILITEK_ILITEK-TP-mouse 2>/dev/null)" ]; then
	          echo "Candle: kiosk.sh:  detected Raspad touchscreen, starting X and hiding mouse pointer"
	          startx -- -nocursor
	
	        # Generic touch screen
	        elif udevadm info -q all -n /dev/input/event* | grep -q "ID_INPUT_TOUCHSCREEN=1"; then
	            echo "Candle: kiosk.sh:  detected a touchscreen, starting X and hiding mouse pointer"
	            startx -- -nocursor
	
			# A mouse is plugged in
	        elif [ -n "$(ls /dev/input/by-id/*-mouse | grep -v ILITEK  2>/dev/null)" ]; then
	            echo "Candle: kiosk.sh:  detected mouse, starting X and allowing mouse pointer to be shown"
	            startx
	
	        else
	            if which unclutter; then
	                unclutter -idle 5 -root -display :0
	            fi
	            echo "Candle: kiosk.sh: starting X and allowing mouse pointer to be shown, but with auto-hide after 5 seconds"
	            startx
	        fi
	
	    fi
	
	fi

	

	
else
    echo "Candle: kiosk.sh: no display detected, not starting kiosk mode" 
    #echo "Candle: kiosk.sh: no display detected, not starting kiosk mode" >> /dev/kmsg
fi
