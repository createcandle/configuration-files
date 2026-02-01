#!/bin/bash

# limit the size of the dnsmasq log
if [ -f /home/pi/dnsmasq_log.txt ] && [ -s /home/pi/dnsmasq_log.txt ]; then
	cp /home/pi/dnsmasq_log.txt /home/pi/dnsmasq_now.txt
	chown pi:pi /home/pi/dnsmasq_now.txt
	chmod 755 /home/pi/dnsmasq_now.txt
	rm /home/pi/dnsmasq_log.txt
	DNSMASQ_PID=$(pidof dnsmasq | tr -d '\n')
	if [ -n "$DNSMASQ_PID" ]; then
		kill -USR2 $DNSMASQ_PID &> /dev/null
	fi
fi


# Make sure uaop0 always exists
if ip link show | grep -q "mlan0:" ; then
	if ip link show | grep -q "uap0:" ; then
		:
	else
		echo "every_few_seconds: possibly missing uap0" >> /dev/kmsg
		sleep 1
		if nmcli | grep -q "uap0:" ; then
			:
		else
			echo "every_few_seconds: fixing missing uap0"
			echo "candle: every_few_seconds.sh: fixing missing uap0" >> /dev/kmsg
			/sbin/iw dev mlan0 interface add uap0 type __ap
		fi
	fi
        
elif ip link show | grep -q "wlan0:" ; then
	if ip link show | grep -q "uap0:"; then
		:
	else
		echo "every_few_seconds: possibly missing uap0" >> /dev/kmsg
		sleep 1
		if nmcli | grep -q "uap0:" ; then
			:
		else
			echo "every_few_seconds: fixing missing uap0"
			echo "candle: every_few_seconds.sh: fixing missing uap0" >> /dev/kmsg
			/sbin/iw dev wlan0 interface add uap0 type __ap
		fi
	fi
fi




#IP4=$(hostname -I | awk '{print $1}')
IP4S=$(hostname -I | sed -r 's/192.168.12.1//' | xargs)

if [ -n "$IP4S" ]; then
	for IP4 in $IP4S; do
		#echo "every_few_seconds: IP4: -->$IP4<--"
		
		# Check if the variable is a valid IP address
		if [[ $IP4 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		
	  		# Add additional firewall rules
			if [ -f /usr/sbin/iptables ] ; then
		
				if iptables -S | grep -q "$IP4" ; then
					#echo "Candle every_few_seconds: IP4 address already in iptables: -->$IP4<--"
					:
				else
					echo "Candle every_few_seconds: adding iptables port 80 and 433 redirect rules for IP4: -->$IP4<--" 
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
			fi
		fi
	done
fi
