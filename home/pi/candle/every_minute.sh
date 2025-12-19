#!/bin/bash

# Fix avahi sometimes appending "-2" or "-3" to its hostname is a Bonjour server is repeating it on the network, causing it to think the name already exists
HOSTNAME=$(hostname)
AVAHI_HOSTNAME=$(systemctl status avahi-daemon.service | grep "avahi-daemon: running \[" | cut -d "[" -f2| cut -d "]" -f1 | cut -d. -f1) 
#if [ "$AVAHI_HOSTNAME" != "$HOSTNAME" ] && [ "$HOSTNAME" != "candle" ]; then
if [ "$AVAHI_HOSTNAME" != "$HOSTNAME" ]; then
    echo "Hostname mismatch (hostname:$HOSTNAME, avahi:$AVAHI_HOSTNAME). Restarting avahi."
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
        echo "Candle: every minute: upgrading wifi password security" >> /dev/kmsg
        echo "$current_pass" | wpa_passphrase "$current_ssid" > ./temporary
        phrase=$(cat ./temporary | grep -v '#psk=' | grep 'psk=' | cut -d'=' -f 2)
        rm ./temporary
        #phrase="$(wpa_passphrase '$current_ssid' '$current_pass' | grep -v '#psk=' | grep 'psk=' | cut -d'=' -f 2  )"
        sed -i "s'\\\"${current_pass}\\\"'${phrase}'" /home/pi/.webthings/etc/wpa_supplicant/wpa_supplicant.conf
    fi
fi

if [ -f /home/pi/dnsmasq_log.txt ]; then
	tail -n 1000 /home/pi/dnsmasq_log.txt > tmp.txt && mv tmp.txt /home/pi/dnsmasq_log.txt
fi
