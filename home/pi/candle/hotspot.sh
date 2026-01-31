#!/bin/bash

if [ -f /boot/firmware/emergency.txt ]; then
	exit 0
fi

if [ ! -f /boot/firmware/candle_hotspot.txt ]; then
	echo "hotspot.sh: no candle_hotspot.txt, aborting"
	echo "hotspot.sh: no candle_hotspot.txt, aborting" >> /dev/kmsg
	sleep 20
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

#PHY="PHY1"
#if iw list | grep -q phy0; then
#    PHY="PHY0"
#fi
#echo "PHY: $PHY"




# Create an alias for 'mlan0' wifi to 'wlan0' if needed
if ip link show | grep -q "mlan0:" ; then
	echo "hotspot.sh: spotted mlan0"
	if ip link show | grep -q "uap0:" ; then
		echo "mlan0 and uap0 exist"
	else
		echo "uap0 does not exist yet"
		/sbin/iw dev mlan0 interface add uap0 type __ap
		sleep 1
		iw dev uap0 set power_save off
		sleep 1
	fi
        
elif ip link show | grep -q "wlan0:" ; then
    echo "wlan0 exists"
	if ip link show | grep -q "uap0:"; then
		echo "wlan0 and uap0 exist"
	else
		echo "uap0 does not exist yet"
		/sbin/iw dev wlan0 interface add uap0 type __ap
		sleep 1
		iw dev uap0 set power_save off
		sleep 1
	fi
fi

#if rfkill | grep -q ' blocked '; then
#	echo "Had to rfkll unblock early (1)"
#	rfkill unblock all
#	sleep 1
#fi

#if ip link show | grep "uap0:" | grep -q "state UP"; then
if ip link show | grep -q "uap0:"; then
	MAC=$(nmcli device show wlan0 | grep HWADDR | awk '{print $2}')
	if [[ $MAC =~ 0$ ]]; then
    	ZEROMAC=${MAC%?}1
	else
		ZEROMAC=${MAC%?}0
	fi
	
	
	#ip link set dev uap0 address "$ZEROMAC"
	#ip -6 addr add fd00:12::1 dev uap0
	
	if command -v iwctl &> /dev/null; then
		echo "iwctl exists, so iwd installed"
		if ! iwctl device list | grep -q uap0; then
			echo "WARNING, iwd does not see uap0 yet. Restarting IWD"
			sleep 1
			systemctl restart iwd
			#iwctl device uap0 set-property Mode ap
			sleep 1
			systemctl restart NetworkManager
			sleep 1
		fi
	fi
	
	
	SHORTMAC=${MAC: -2}
	#SHORTMAC="${SHORTMAC//:/}"
	#RANDOMCHARS=$(tr -dc A-Z0-9 </dev/urandom | head -c 2; echo '')
	#SHORTMAC=$(echo "$SHORTMAC$RANDOMCHARS")
	#RANDOMCHARS=$(tr -dc 'A-Z0-9' < /dev/urandom | head -c 2)
	RANDOMCHARS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 2 | head -n 1)
	
	SHORTMAC=$(echo "$SHORTMAC$RANDOMCHARS")
	
	#ifconfig br0 hw ether $MAC
	echo "hotspot.sh: short mac address: $SHORTMAC"
	#echo "hotspot.sh: short mac address: $SHORTMAC" >> /dev/kmsg

	SHORTMAC=$(echo "$(echo $SHORTMAC)_nomap");

	IP4=$(hostname -I | sed -r 's/192.168.12.1//' | xargs)
	echo "hotspot.sh: IPv4 address: $IP4"
	
	if iptables -t nat -L -v | grep -q "uap0"; then
		echo "uap0 already exists in iptables"
	else
	
		echo "hotspot.sh: adding iptables for uap0"
		
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
		#ip6tables -t nat -A PREROUTING -i uap0 -s fd00:12::/8 -p udp --dport 53 -j DNAT --to-destination fd00:12::1
		ip6tables -t nat -A PREROUTING -i uap0 -p udp --dport 53 -j DNAT --to-destination fd00:12::1
		
		echo "candle: hotspot.sh: adding iptables forwarding rules"
		iptables -A FORWARD -i uap0 -j ACCEPT
		ip6tables -A FORWARD -i uap0 -j ACCEPT
		iptables -A FORWARD -o uap0 -m state --state ESTABLISHED,RELATED -j ACCEPT
		ip6tables -A FORWARD -d ff02::1 -o uap0 -m state --state ESTABLISHED,RELATED -j ACCEPT
		#iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
		#iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE

		iptables -t nat -A POSTROUTING -s 192.168.12.0/24 ! -d 192.168.12.0/24  -j MASQUERADE
		ip6tables -t nat -A POSTROUTING -s ff02::1 ! -d ff02::1  -j MASQUERADE


		echo "candle: hotspot.sh: adding port redirect rules on hotspot side"
		iptables -I PREROUTING -p tcp -i uap0 -s 192.168.12.0/24 -d 192.168.12.1/32 --dport 80 -j REDIRECT --to-port 8080
		iptables -I PREROUTING -p tcp -i uap0 -s 192.168.12.0/24 -d 192.168.12.1/32 --dport 443 -j REDIRECT --to-port 4443

		ip6tables -I PREROUTING -p tcp -i uap0 -s fd00:12::/8 -d fd00:12::1 --dport 80 -j REDIRECT --to-port 8080
		ip6tables -I PREROUTING -p tcp -i uap0 -s fd00:12::/8 -d fd00:12::1 --dport 443 -j REDIRECT --to-port 4443
		
	
		# Block access to parent local networks
		if [ ! -f /boot/firmware/candle_hotspot_allow_traversal.txt ]; then
			iptables -I FORWARD -i uap0 -d 192.168.0.0/16 -m iprange --src-range 192.168.12.2-192.168.12.255 -j DROP
			iptables -I FORWARD -i uap0 -d 172.16.0.0/12 -m iprange --src-range 192.168.12.2-192.168.12.255 -j DROP
			iptables -I FORWARD -i uap0 -d 10.0.0.0/8 -m iprange --src-range 192.168.12.2-192.168.12.255 -j DROP

			ip6tables -I FORWARD -i uap0 -d fe80::/10 -m iprange --src-range 192.168.12.2-192.168.12.255 -j DROP
			
		fi


		# Redirect Candle UI ports
		iptables -t mangle -I PREROUTING -s 192.168.12.0/24 -p tcp -d 192.168.12.1 --dport 80 -j MARK --set-mark 2
		iptables -t mangle -I PREROUTING -s 192.168.12.0/24 -p tcp -d 192.168.12.1 --dport 443 -j MARK --set-mark 2
		iptables -t nat -I PREROUTING -s 192.168.12.0/24 -p tcp -d 192.168.12.1 --dport 80 -j REDIRECT --to-port 8080
		iptables -t nat -I PREROUTING -s 192.168.12.0/24 -p tcp -d 192.168.12.1 --dport 443 -j REDIRECT --to-port 4443
		iptables -I INPUT -s 192.168.12.0/24 -m state --state NEW -m tcp -p tcp -d 192.168.12.1 --dport 8080 -m mark --mark 2 -j ACCEPT
		iptables -I INPUT -s 192.168.12.0/24 -m state --state NEW -m tcp -p tcp -d 192.168.12.1 --dport 4443 -m mark --mark 2 -j ACCEPT

	fi

	
	
	#iptables -t nat -L -v

	#if rfkill | grep -q ' blocked '; then
	#	echo "Had to rfkll unblock (2)"
	#	rfkill unblock all
	#	sleep 1
	#fi

	
	FIRSTRUN=true
	if nmcli connection show | grep -q Hotspot; then
		FIRSTRUN=false
		echo "nmcli Hotspot item exists"
	else
		echo "No Hotspot item yet, generating it now"
		#if [ "$PASSWORD" -ge 8 ]; then
		if [[ $PASSWORD =~ ^........+ ]]; then
			nmcli dev wifi hotspot ifname uap0 ssid "Candle $SHORTMAC_nomap" password "$PASSWORD"
			nmcli con modify Hotspot wifi-sec.key-mgmt sae wifi-sec.psk "$PASSWORD"
		else
			nmcli dev wifi hotspot ifname uap0 ssid "Candle $SHORTMAC"
		fi
	
		if nmcli connection show --active | grep -q Hotspot; then
			echo "warning, Hotspot connection started up. Setting it to down before making lots of changes."
			nmcli connection down Hotspot
			sleep 1
		fi
		
		
		nmcli connection modify Hotspot 802-11-wireless.band bg
		nmcli connection modify Hotspot 802-11-wireless.channel 1
		nmcli connection modify Hotspot ipv4.addresses "192.168.12.1/24" ipv4.method manual ipv4.gateway "192.168.12.1" ipv4.dns "192.168.12.1" ipv4.dns-priority 1000
		nmcli connection modify Hotspot ipv6.addresses 'fd00::/8' ipv6.method manual ipv6.gateway 'fd00:12::1' ipv6.dns 'fd00:12::1' ipv6.dns-priority 1000
		
		nmcli connection modify Hotspot ipv4.never-default true
		nmcli connection modify Hotspot wifi.powersave 2
		

		
		nmcli connection modify Hotspot connection.autoconnect yes
		#nmcli connection modify Hotspot ipv6.method "ignore"
	fi
	
	#if [ "$PASSWORD" -ge 8 ]; then
	if [[ $PASSWORD =~ ^........+ ]]; then
		#nmcli dev wifi hotspot ifname uap0 ssid "Candle $SHORTMAC" password "$PASSWORD"
		echo "adding/updating password for hotspot"
		nmcli con modify Hotspot wifi-sec.key-mgmt sae wifi-sec.psk "$PASSWORD"
	else
		echo "password in candle_hotspot.txt was too short"
		nmcli connection modify Hotspot wifi-sec.psk ""
	fi
	
	if [ -f /boot/firmware/candle_wifi_power_save.txt ]; then
		#nmcli connection modify candle_hotspot wifi.powersave 1
		nmcli radio wifi powersave on
	fi
	

	# FOR TROUBLESHOOTING
	#nmcli con modify hotspot wifi-sec.pmf disable


	

	if [ -f /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf ]; then
		
		if [ -f /boot/firmware/candle_hotspot.txt ]; then
			echo "Candle: hotspot.sh: bringing up hotspot and starting dnsmasq"
			echo "Candle: hotspot.sh: bringing up hotspot and starting dnsmasq" >> /dev/kmsg
			if nmcli radio wifi | grep -q 'disabled'; then
				echo "hotspot.sh: had to being up wifi radio"
				nmcli radio wifi on
			fi
			if nmcli connection show --active | grep -q Hotspot; then
				echo "Hotspot connection is already up"
			else
				echo "warning, Hotspot connection exists, but wasn't up. Setting it to up now."
				nmcli connection up Hotspot
			fi

			if nmcli connection show --active | grep -q Hotspot; then
				echo "IPv6 address:"
				ip -6 addr show uap0
				
				# Start NTP time server
				if [ -f /boot/firmware/candle_no_time_server.txt ]; then
					echo "candle: hotspot.sh: not starting time server"
				elif [ -f /home/pi/candle/time_server.py ]; then
					
					if ps aux | grep 'python3 /home/pi/candle/time_server.py' | grep -q '192.168.12.1 123'; then
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
				
				dnsmasq -k -d --no-daemon --conf-file=/home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf 1> /dev/null

			else
				echo
				echo "ERROR, Hotspot was not active"
				echo
			fi

			
		else
			echo "Candle: hotspot.sh: not bringing up hotspot"
			#nmcli connection down candle_hotspot
			sleep 30
		fi
	else
		echo "Candle: hotspot.sh: ERROR, missing dnsmasq config file" >> /dev/kmsg
		sleep 30
	fi


fi

sleep 15
