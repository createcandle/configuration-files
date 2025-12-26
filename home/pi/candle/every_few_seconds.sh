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



#IP4=$(hostname -I | awk '{print $1}')
IP4=$(hostname -I | sed -r 's/192.168.12.1//' | xargs)

if [ -n "$IP4" ]; then

	# Add additional firewall rules
	if [ -f /usr/sbin/iptables ] ; then

		if iptables -S | grep -q "$IP4" ; then
			echo "Candle every_few_seconds: IP4 address already in iptables: -->$IP4<--"

		else
			echo "Candle every_few_seconds: adding iptables port 80 and 433 redirect rules for IP4: $IP4" 
			echo "Candle every_few_seconds: adding iptables port 80 and 433 redirect rules for IP4: $IP4" >> /dev/kmsg

			iptables -t mangle -I PREROUTING -s $IP4/24 -p tcp -d $IP4 --dport 80 -j MARK --set-mark 1
			iptables -t mangle -I PREROUTING -s $IP4/24 -p tcp -d $IP4 --dport 443 -j MARK --set-mark 1
			iptables -t nat -I PREROUTING -s $IP4/24 -p tcp -d $IP4 --dport 80 -j REDIRECT --to-port 8080
			iptables -t nat -I PREROUTING -s $IP4/24 -p tcp -d $IP4 --dport 443 -j REDIRECT --to-port 4443
			iptables -I INPUT -s $IP4/24 -m state --state NEW -m tcp -p tcp -d $IP4 --dport 8080 -m mark --mark 1 -j ACCEPT
			iptables -I INPUT -s $IP4/24 -m state --state NEW -m tcp -p tcp -d $IP4 --dport 4443 -m mark --mark 1 -j ACCEPT

			if [ -d /boot/firmware ]; then
				echo $IP4 > /boot/firmware/candle_last_known_ip_address.txt
			fi
		fi


	else
		echo "Candle every_few_seconds: error: iptables not installed?"
		echo "Candle every_few_seconds: error: iptables not installed?" >> /dev/kmsg
	fi

fi
