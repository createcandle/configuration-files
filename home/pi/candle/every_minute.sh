#!/bin/bash

if [ -f /boot/firmware/emergency.txt ]; then
	exit 0
fi

# Fix avahi sometimes appending "-2" or "-3" to its hostname is a Bonjour server is repeating it on the network, causing it to think the name already exists
HOSTNAME=$(hostname)
AVAHI_HOSTNAME=$(systemctl status avahi-daemon.service | grep "avahi-daemon: running \[" | cut -d "[" -f2| cut -d "]" -f1 | cut -d. -f1) 
#if [ "$AVAHI_HOSTNAME" != "$HOSTNAME" ] && [ "$HOSTNAME" != "candle" ]; then
if [ "$AVAHI_HOSTNAME" != "$HOSTNAME" ]; then
    echo "Candle: every_minute.sh: Hostname mismatch (hostname:$HOSTNAME, avahi:$AVAHI_HOSTNAME). Restarting avahi."
	echo "$(date) - Candle: every_minute.sh: hostname mismatch (hostname:$HOSTNAME, avahi:$AVAHI_HOSTNAME). Restarting avahi." >> /dev/kmsg
    systemctl restart avahi-daemon.service
fi

# keep the syslog smaller than 2 megabytes
if [ -f /var/log/syslog ]; then
    SYSLOG_FILESIZE=$(stat --printf="%s" /var/log/syslog)
    if [ "$SYSLOG_FILESIZE" -gt 2000000 ]; then
        echo "$(tail -200 /var/log/syslog)" > /var/log/syslog
    fi
fi

# Try to upgrade security of the wifi password
if cat /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf | grep -q psk=; then
    current_ssid="$(cat /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf | grep 'ssid=' | cut -d'"' -f 2 )"
    current_pass="$(cat /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf | grep 'psk=' | cut -d'"' -f 2 )"
    if [ "$(echo -n $current_pass | wc -c)" -lt 64 ]; then
        echo "Candle: every_minute.sh: upgrading wpa_supplicant wifi password security" >> /dev/kmsg
        echo "$current_pass" | wpa_passphrase "$current_ssid" > ./temporary
        phrase=$(cat ./temporary | grep -v '#psk=' | grep 'psk=' | cut -d'=' -f 2)
        rm ./temporary
        #phrase="$(wpa_passphrase '$current_ssid' '$current_pass' | grep -v '#psk=' | grep 'psk=' | cut -d'=' -f 2  )"
        sed -i "s'\\\"${current_pass}\\\"'${phrase}'" /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf
    fi
fi

# Kill Chromium if it uses too much memory
if [ -f /boot/firmware/candle_kiosk.txt ]; then
	CHROMIUM_MEMORY_USE=$(ps -eo size,pid,user,command --sort -size | awk '{ hr=$1/1024 ; printf("%13.2f Mb ",hr) } { for ( x=4 ; x<=NF ; x++ ) { printf("%s ",$x) } print "" }' |    cut -d "" -f2 | cut -d "-" -f1 | grep bin/chrom | cut -d. -f1 | xargs)
	echo "CHROMIUM_MEMORY_USE: $CHROMIUM_MEMORY_USE"
	if [ $CHROMIUM_MEMORY_USE -gt 2000 ]; then
		echo "Candle: every_minute.sh: restarting kiosk because Chromium is using too much memory: $CHROMIUM_MEMORY_USE MB" >> /dev/kmsg
		#printf "Chromium SIZE has exceeded.\nKilling the process......"
		#kill -9 "$procId"
		#echo "Killed the process"
		splash_video.sh &
		systemctl restart candle_kiosk.service
	fi
fi



#if ip link show wlan0 | grep -q DORMANT; then
#	echo "Candle: every minute: wlan0 was in DORMANT mode, setting to DEFAULT instead" >> /dev/kmsg
#	ip link set wlan0 mode default
#	#ifdown wlan0 && ifup wlan0
#fi


