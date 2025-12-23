#!/bin/bash

if [ -f /boot/firmware/emergency.txt ]; then
	exit 0
fi

#if [ ! -f /boot/firmware/candle_hotspot.txt ]; then
#	echo "candle: hotspot.sh: not starting hotspot"
#	echo "Candle: hotspot.sh: not starting hotspot" >> /dev/kmsg
#	exit 0
#fi

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

PASSWORD=""
if [ -f /boot/firmware/candle_hotspot_password.txt ]; then
	PASSWORD=$(cat /boot/firmware/candle_hotspot_password.txt)
	#echo "Updating hotspot password" >> candle_log.txt 
fi
#echo "" > /boot/firmware/candle_hotspot.txt

PHY="PHY1"

if iw list | grep -q phy0; then
    PHY="PHY0"
fi

echo "PHY: $PHY"


# Create an alias for 'mlan0' wifi to 'wlan0' if needed
if ip link show | grep -q "mlan0:" ; then
        echo "hotspot.sh: spotted mlan0"
        if ! ip link show | grep -q "uap0:" ; then
                echo "uap0 does not exist yet"
                /sbin/iw dev mlan0 interface add uap0 type __ap
        fi
        
elif ip link show | grep -q "wlan0:" ; then
        echo "wlan0 exists"
        if ! ip link show | grep -q "uap0:" ; then
                echo "uap0 does not exist yet"
                /sbin/iw dev wlan0 interface add uap0 type __ap
        fi
fi

if ip link show | grep -q "uap0:" ; then
	MAC=$(nmcli device show wlan0 | grep HWADDR | awk '{print $2}')
	SHORTMAC=${MAC: -5}
	SHORTMAC="${SHORTMAC//:/}"
	ZEROMAC=${MAC%?}0
	#ifconfig br0 hw ether $MAC
	echo "hotspot.sh: short mac address: $SHORTMAC"

	IP4=$(hostname -I | sed -En "s/(.*) 192.168.12.1/\1/p" | xargs)
	echo "hotspot.sh: IPv4 address: $IP4"
	
	if iptables -t nat -L -v | grep -q "uap0"; then
		echo "uap0 already exists in iptables"
	else
	
		
		
		# optionally, drop DHCP requests to get an IPV6 address.
		if [ -f /boot/firmware/candle_hotspot_no_ipv6.txt ]; then
			ip6tables -A INPUT -m state --state NEW -m udp -p udp -s fe80::/10 --dport 546 -j DROP
		fi
		
		if [ ! -f /boot/firmware/candle_hotspot_allow_access_to_main_network.txt ]; then
			echo "blocking access of hotspot network to main network"
			#iptables -A FORWARD -d 192.168.2.2 -m iprange --src-range 192.168.12.2-192.168.12.255 -j DROP
			#iptables -I INPUT -i uap0 -d <main_network_IP> -j DROP
			
			#iptables -A FORWARD -i uap0 -m iprange --src-range 192.168.12.2-192.168.12.255 -o eth0 -d 192.168.0.0/16 -j DROP
			#iptables -A FORWARD -i uap0 -m iprange --src-range 192.168.12.2-192.168.12.255 -o wlan0 -d 192.168.0.0/16 -j DROP
		fi
		
		
		
		
		
		# Force all DNS traffic on the hotspot network to go to/through the Candle Controller
		iptables -t nat -A PREROUTING -i uap0 -s 192.168.12.0/24 -p udp --dport 53 -j DNAT --to-destination 192.168.12.1:53
		
		echo "candle: hotspot.sh: adding iptables forwarding rules"
		iptables -A FORWARD -i uap0 -j ACCEPT
		iptables -A FORWARD -o uap0 -m state --state ESTABLISHED,RELATED -j ACCEPT
		ip6tables -A FORWARD -d ff02::1 -o uap0 -m state --state ESTABLISHED,RELATED -j ACCEPT
		#iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
		#iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE

		iptables -t nat -A POSTROUTING -s 192.168.12.0/24 ! -d 192.168.12.0/24  -j MASQUERADE
		ip6tables -t nat -A POSTROUTING -s ff02::1 ! -d ff02::1  -j MASQUERADE


		echo "candle: hotspot.sh: adding port redirect rules on hotspot side"
		iptables -I PREROUTING -p tcp -i uap0 -s 192.168.12.0/24 -d 192.168.12.1/32 --dport 80 -j REDIRECT --to-port 8080
		iptables -I PREROUTING -p tcp -i uap0 -s 192.168.12.0/24 -d 192.168.12.1/32 --dport 443 -j REDIRECT --to-port 4443

		# Block access to parent local networks
		if [ ! -f /boot/firmware/candle_hotspot_allow_traversal.txt ]; then
			iptables -I FORWARD -d 192.168.0.0/16 -m iprange --src-range 192.168.12.2-192.168.12.255 -j DROP
			iptables -I FORWARD -d 172.16.0.0/12 -m iprange --src-range 192.168.12.2-192.168.12.255 -j DROP
			iptables -I FORWARD -d 10.0.0.0/8 -m iprange --src-range 192.168.12.2-192.168.12.255 -j DROP
		fi
		

	fi

	if [ -f /boot/firmware/candle_no_time_server.txt ]; then
		echo "candle: hotspot.sh: not starting time server"
	elif [ -f /home/pi/candle/time_server.py ]; then
		
		if ps aux | grep -q 'python3 /home/pi/candle/time_server.py 192.168.12.1 123'; then
			echo "timeserver is already running"
		else
			echo "starting NTP server"
			
			if iptables -t nat -L -v | grep -q "192.168.12.1:123"; then
				echo "NTP server iptables rule seems to already exist"
			else
				echo "adding NTP server iptables rule"
				iptables -t nat -A PREROUTING -i uap0 -p udp --dport 123 -j DNAT --to-destination 192.168.12.1:123
			fi
			python3 /home/pi/candle/time_server.py 192.168.12.1 123 &
		fi
	fi
	
	iptables -t nat -L -v

	
	if nmcli c show | grep -q 'candle_hotspot'; then
		echo "NetworkManager candle_hotspot seems to already exist"
	else
		#nmcli c del candle_hotspot
		#sleep 1
		
		nmcli connection add con-name 'candle_hotspot' ifname uap0 type wifi wifi.mode ap wifi.ssid "Candle $SHORTMAC"
		
		nmcli connection modify candle_hotspot ipv4.addresses "192.168.12.1/24" ipv4.method manual ipv4.gateway "192.168.12.1" ipv4.dns "192.168.12.1" ipv4.dns-priority 1000 ipv6.dns-priority 1000
		
		# this was necessary for hostapd to keep the connection stable. Is it needed for NetworkManager too?
		#nmcli con modify candle_hotspot wifi.cloned-mac-address $ZEROMAC

		nmcli connection modify candle_hotspot ipv4.never-default true
		nmcli connection modify candle_hotspot wifi.powersave 2
	fi

	if [ -f /boot/firmware/candle_wifi_power_save.txt ]; then
		#nmcli connection modify candle_hotspot wifi.powersave 1
		nmcli radio wifi powersave on
	fi
	

	# FOR TROUBLESHOOTING
	#nmcli con modify hotspot wifi-sec.pmf disable


	#if [ "$PASSWORD" -ge 8 ]; then
	if [[ $PASSWORD =~ ^........+ ]]; then
		echo "adding/updating password for hotspot"
		nmcli con modify candle_hotspot wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASSWORD"
	else
		echo "password in candle_hotspot.txt was too short"
	fi

	if [ -f /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf ]; then
		
		if [ -f /boot/firmware/candle_hotspot.txt ]; then
			echo "Candle: hotspot.sh: bringing up hotspot and starting dnsmasq"
			echo "Candle: hotspot.sh: bringing up hotspot and starting dnsmasq" >> /dev/kmsg
			nmcli connection up candle_hotspot
			dnsmasq -k -d --no-daemon --conf-file=/home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf 1> /dev/null
		else
			echo "Candle: hotspot.sh: not bringing up hotspot"
			nmcli connection down candle_hotspot
			sleep 5
		fi
	else
		echo "Candle: hotspot.sh: missing dnsmasq config file" >> /dev/kmsg
		sleep 30
	fi

fi
