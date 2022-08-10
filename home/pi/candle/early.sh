#!/bin/bash
echo "in Candle early"
echo "in Candle early" >> /dev/kmsg

# fix hostname
/usr/bin/hostname -F /home/pi/.webthings/etc/hostname
systemctl restart avahi-daemon.service

#rm /boot/candle_rw_once.txt

if iptables --list | grep 4443; then
    echo "IPTABLES ALREADY ADDED"
else
    echo "Candle early: adding iptable rules" >> /dev/kmsg
    iptables -t mangle -A PREROUTING -p tcp --dport 80 -j MARK --set-mark 1
    iptables -t mangle -A PREROUTING -p tcp --dport 443 -j MARK --set-mark 1
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
    iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 4443
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -m mark --mark 1 -j ACCEPT
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 4443 -m mark --mark 1 -j ACCEPT
fi


