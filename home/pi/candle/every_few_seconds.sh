#!/bin/bash

# limit the size of the dnsmasq log
if [ -f /home/pi/dnsmasq_log.txt ]; then
	cp /home/pi/dnsmasq_log.txt /home/pi/dnsmasq_now.txt
	chown pi:pi /home/pi/dnsmasq_now.txt
fi
echo "" > /home/pi/dnsmasq_log.txt
if ps aux | grep -q 'dnsmasq -k -d'; then
	kill -USR2 `pidof dnsmasq`
fi
