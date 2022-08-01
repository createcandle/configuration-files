#!/bin/bash
echo "in Candle early"

# fix hostname
/usr/bin/hostname -F /home/pi/.webthings/etc/hostname
systemctl restart avahi-daemon.service
