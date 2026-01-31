#!/bin/bash

if [ -f /boot/firmware/emergency.txt ]; then
	exit 0
fi

if [ -f /boot/firmware/candle_emergency_hotspot.txt ]; then
	exit 0
fi
#nmcli dev wifi hotspot ifname uap0 ssid "Candle x" password "testje"


WIFI_COUNTRY="NL"
if [ -f /boot/firmware/candle_wifi_country_code.txt ]; then
	SPOTTED_WIFI_COUNTRY=$(cat /boot/firmware/candle_wifi_country_code.txt)
	if [ "${#SPOTTED_WIFI_COUNTRY}" -eq 2 ]; then 
		WIFI_COUNTRY="$SPOTTED_WIFI_COUNTRY"
	else
		echo "hotspot.sh: ERROR, country code in boot/firmware/candle_wifi_country_code.txt was of invalid length: $WIFI_COUNTRY"
		echo "hotspot.sh: ERROR, country code in boot/firmware/candle_wifi_country_code.txt was of invalid length: $WIFI_COUNTRY" >> /dev/kmsg
	fi
fi

echo "hotspot.sh: WIFI_COUNTRY: -->$WIFI_COUNTRY<--"

if iw reg get | grep -q "country $WIFI_COUNTRY:"; then
	echo "hotspot.sh: OK, wifi regulatory country is already set to: $WIFI_COUNTRY"
else
	echo "hotspot.sh: WARNING, changing WiFi regulatory country to: $WIFI_COUNTRY"
	echo "hotspot.sh: WARNING, changing WiFi regulatory country to: $WIFI_COUNTRY" >> /dev/kmsg
fi

# Setting it (again) seems to solve issues with starting the hotspot with iwd
iw reg set "$WIFI_COUNTRY"
sleep 1


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




#systemctl status iwd.service | cat





start_dnsmasq () {
	echo "in start_dnsmasq"
	
	if [ -f /boot/firmware/candle_hotspot.txt ]; then
		echo "hotspot.sh: bringing up hotspot and starting dnsmasq"
		
		echo
		echo "ifconfig uap0:"
		ifconfig uap0
		echo
		
		
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

			echo "candle: hotspot.sh: enablng masquerade"
			iptables -t nat -A POSTROUTING -s 192.168.12.0/24 ! -d 192.168.12.0/24  -j MASQUERADE
			ip6tables -t nat -A POSTROUTING -s ff02::1 ! -d ff02::1  -j MASQUERADE


			echo "candle: hotspot.sh: step 1 of adding port redirect rules on hotspot side"
			iptables -I PREROUTING -p tcp -i uap0 -s 192.168.12.0/24 -d 192.168.12.1/32 --dport 80 -j REDIRECT --to-port 8080
			iptables -I PREROUTING -p tcp -i uap0 -s 192.168.12.0/24 -d 192.168.12.1/32 --dport 443 -j REDIRECT --to-port 4443

			ip6tables -I PREROUTING -p tcp -i uap0 -s fd00:12::/8 -d fd00:12::1 --dport 80 -j REDIRECT --to-port 8080
			ip6tables -I PREROUTING -p tcp -i uap0 -s fd00:12::/8 -d fd00:12::1 --dport 443 -j REDIRECT --to-port 4443
		
	
			# Block access to parent local networks
			if [ ! -f /boot/firmware/candle_hotspot_allow_traversal.txt ]; then
				echo "candle: hotspot.sh: blocking traversal to local network"
				iptables -I FORWARD -i uap0 -d 192.168.0.0/16 -m iprange --src-range 192.168.12.2-192.168.12.255 -j DROP
				iptables -I FORWARD -i uap0 -d 172.16.0.0/12 -m iprange --src-range 192.168.12.2-192.168.12.255 -j DROP
				iptables -I FORWARD -i uap0 -d 10.0.0.0/8 -m iprange --src-range 192.168.12.2-192.168.12.255 -j DROP

				ip6tables -I FORWARD -i uap0 -d fe80::/10 -s fd00:12::/8 -j DROP
			
			fi

		
			# Redirect Candle UI ports
			echo "candle: hotspot.sh: step 2 of adding port redirect rules on hotspot side"
			iptables -t mangle -I PREROUTING -s 192.168.12.0/24 -p tcp -d 192.168.12.1 --dport 80 -j MARK --set-mark 2
			iptables -t mangle -I PREROUTING -s 192.168.12.0/24 -p tcp -d 192.168.12.1 --dport 443 -j MARK --set-mark 2
			iptables -t nat -I PREROUTING -s 192.168.12.0/24 -p tcp -d 192.168.12.1 --dport 80 -j REDIRECT --to-port 8080
			iptables -t nat -I PREROUTING -s 192.168.12.0/24 -p tcp -d 192.168.12.1 --dport 443 -j REDIRECT --to-port 4443
			iptables -I INPUT -s 192.168.12.0/24 -m state --state NEW -m tcp -p tcp -d 192.168.12.1 --dport 8080 -m mark --mark 2 -j ACCEPT
			iptables -I INPUT -s 192.168.12.0/24 -m state --state NEW -m tcp -p tcp -d 192.168.12.1 --dport 4443 -m mark --mark 2 -j ACCEPT

		fi
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		echo "Candle: hotspot.sh: bringing up hotspot and starting dnsmasq" >> /dev/kmsg
		if nmcli radio wifi | grep -q 'disabled'; then
			echo "hotspot.sh: WARNING, had to bring up wifi radio (2)"
			echo "candle: hotspot.sh: WARNING, had to bring up wifi radio (2)" >> /dev/kmsg
			nmcli radio wifi on
		fi
		if nmcli connection show --active | grep -q Hotspot; then
			echo "hotspot.sh: OK, Hotspot connection is already up"
		else
			echo "hotspot.sh: warning, Hotspot connection exists, but wasn't up. Attempting to set it to up now. This is expected to fail"
			nmcli connection up Hotspot
		fi

		if nmcli connection show --active | grep -q Hotspot; then
			echo "IPv6 address:"
			ip -6 addr show uap0
	
			# Start NTP time server
			if [ -f /boot/firmware/candle_no_time_server.txt ]; then
				echo "candle: hotspot.sh: not starting time server"
			elif [ -f /home/pi/candle/time_server.py ]; then

				if ifconfig | grep -q '192.168.12.1'; then
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

					echo "STARTING DNSMASQ"
					dnsmasq -k -d --no-daemon --conf-file=/home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf 1> /dev/null


				else
					echo "ERROR, uap0 interface does not have 192.168.12.1 ip address (yet). Cannot start NTP server. ifconfig:"
					ifconfig uap0
			
				fi
			fi
	
	
		else
			echo
			echo "hotspot.sh: ERROR, Hotspot was not active (attempt to bring it up failed as expected)"
			echo
		fi

		
	else
		echo "hotspot.sh: not bringing up hotspot"
		echo "candle: hotspot.sh: no candle_hotspot.txt spotted, not bringing up hotspot" >> /dev/kmsg
		#nmcli connection down candle_hotspot
		sleep 30
		exit 0
	fi

	
	sleep 15
	
	exit 1
	
}


if rfkill | grep -q ' blocked '; then
	echo "Had to rfkll unblock all (1)"
	echo "candle: hotspot.sh: Had to rfkll unblock all (1)" >> /dev/kmsg
	rfkill unblock all
	sleep 1
fi

if nmcli radio wifi | grep -q 'disabled'; then
	echo "hotspot.sh: WARNING, had to bring up wifi radio (1)"
	echo "candle: hotspot.sh: WARNING, had to bring up wifi radio (1)" >> /dev/kmsg
	nmcli radio wifi on
	sleep 1
fi


# Create virtual UAP0 interface for hotspot
if ip link show | grep -q "mlan0:" ; then
	echo "hotspot.sh: spotted mlan0"
	if ip link show | grep -q "uap0:" ; then
		echo "mlan0 and uap0 exist"
	else
		echo "uap0 does not exist yet"
		/sbin/iw dev mlan0 interface add uap0 type __ap
		sleep 1
		ip address add 192.168.12.1/24 dev uap0
		ifconfig uap0 192.168.12.1 netmask 255.255.255.0
		ip -6 addr add fd00:12::1 dev uap0
		#iw dev uap0 set power_save off
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
		ip address add 192.168.12.1/24 dev uap0
		ifconfig uap0 192.168.12.1 netmask 255.255.255.0
		ip -6 addr add fd00:12::1 dev uap0
		#iw dev uap0 set power_save off
		sleep 1
	fi
fi




#if ip link show | grep "uap0:" | grep -q "state UP"; then
if ip link show | grep -q "uap0:"; then
	
	echo
	echo "ifconfig uap0:"
	ifconfig uap0
	echo
	
	
	MAC=$(nmcli device show wlan0 | grep HWADDR | awk '{print $2}')
	if [[ "$MAC" =~ 0$ ]]; then
    	ZEROMAC=${MAC%?}1
	else
		ZEROMAC=${MAC%?}0
	fi
	ip link set dev uap0 address "$ZEROMAC"
	
	if ip link show uap0 | grep -q DORMANT; then
		echo "hotspot.sh: uap0 was in DORMANT mode, setting to DEFAULT instead" >> /dev/kmsg
		ip link set uap0 mode default
	fi
	
	sleep 1
	
	#echo
	#echo "ifconfig uap0:"
	#ifconfig uap0
	#echo
	
	
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

	
	# PREPARE SSID

	SHORTMAC=$(echo "$(echo $SHORTMAC)_nomap")
	echo "hotspot.sh: short mac address with _nomap: $SHORTMAC"
	
	SSID="Candle"
	if [ -n "$SHORTMAC" ]; then
		SSID="Candle $(echo $SHORTMAC)"
	fi
	
	# check if there is an existing SSID to re-use instead
	OLD_SSID=$(nmcli c s Hotspot | grep 802-11-wireless.ssid | awk '{print $2}')
	#if [[ "$OLD_SSID" == *"_nomap"* ]]; then
	if [ -n "$OLD_SSID" ]; then	
	    echo "spotted existing Hotspot connection. Existing SSID: $OLD_SSID"
		SSID=$(echo "$OLD_SSID")
	fi
	
	
	# Allow the user to override the SSID
	if [ -f /boot/firmware/candle_hotspot_name.txt ]; then
		SPOTTED_HOTSPOT_SSID=$(cat /boot/firmware/candle_hotspot_name.txt)
		if [ -n "$SPOTTED_HOTSPOT_SSID" ]; then 
			echo "Spotted a prefered hotspot SSID in candle_hotspot_name.txt: $SPOTTED_HOTSPOT_SSID"
			SSID=$(echo "$SPOTTED_HOTSPOT_SSID")
		fi
	fi
	
	
	
	echo "hotspot.sh: final SSID: $SSID"
	
	

	
	
	#iptables -t nat -L -v

	#if rfkill | grep -q ' blocked '; then
	#	echo "Had to rfkll unblock (2)"
	#	rfkill unblock all
	#	sleep 1
	#fi



	if nmcli connection show --active | grep -q Hotspot; then
		echo "hotspot.sh: WARNING, the Hotspot connection is already up. Did dnsmasq crash?"
		echo "candle: hotspot.sh: WARNING, the Hotspot connection is already up. Did dnsmasq crash?" >> /dev/kmsg
		start_dnsmasq
		exit 1
	else
		
		
		echo
		echo "ifconfig uap0:"
		ifconfig uap0
		echo
		
		if ifconfig uap0 | grep -q '192.168.12.1'; then
			echo "OK, uap0 still has the correct IP address"
		else
			echo "forcing ip address for uap0 again"
			ip address add 192.168.12.1/24 dev uap0
		fi	
		
		
		echo
		echo "ifconfig uap0:"
		ifconfig uap0
		echo
		
		if nmcli connection show | grep -q Hotspot; then
			
			
			echo "What is the interface name of the not-active Hotspot connection? (0)"
			nmcli connection show Hotspot | grep connection.interface-name
			
			echo "deleting old Hotspot connection before creating a new one"
			#nmcli connection delete Hotspot
			sleep 1
			
		else
			#nmcli connection add con-name "Hotspot" \
			#    ifname uap0 wifi.mode ap wifi.ssid "$SSID" \
			#	wifi-sec.key-mgmt wpa-psk \
			#    wifi-sec.proto rsn wifi-sec.pairwise ccmp \
			#    wifi-sec.psk "$PASSWORD" \
			#	connection.autoconnect yes
			
			if [[ $PASSWORD =~ ^........+ ]]; then
				
                nmcli connection add \
                    con-name wifi_hotspot \
                    ifname uap0 \
                    type wifi \
                    autoconnect yes \
                    ipv4.method manual ipv4.addresses "192.168.12.1/24" \
                    802-11-wireless.band bg \
                    802-11-wireless.mode ap \
                    802-11-wireless.ssid "$SSID" \
                    802-11-wireless-security.key-mgmt wpa-psk \
                    802-11-wireless-security.proto rsn \
                    wifi-sec.pairwise ccmp \
                    802-11-wireless-security.psk "$PASSWORD" \
                    ipv6.method manual ipv6.addresses 'fd00::/8' 802-11-wireless.band bg 802-11-wireless.channel 1
			
			
			
			else
                nmcli connection add \
                    con-name wifi_hotspot \
                    ifname uap0 \
                    type wifi \
                    autoconnect yes \
                    ipv4.method manual ipv4.addresses "192.168.12.1/24" \
                    802-11-wireless.band bg \
                    802-11-wireless.mode ap \
                    802-11-wireless.ssid "$SSID" \
                    ipv6.method manual ipv6.addresses 'fd00::/8' 802-11-wireless.band bg 802-11-wireless.channel 1
				
			fi
			#nmcli con modify wifi_hotspot wifi-sec.pmf disable
			nmcli con modify wifi_hotspot 802-11-wireless.mode ap
			nmcli con modify wifi_hotspot wifi.cloned-mac-address "$ZEROMAC"
			
			
		fi
	
		if [ -f /boot/firmware/developer.txt ]; then
			echo "Will try to start Hotspot with: "
			echo " - SSID: $SSID"
			echo " - PASS: $PASSWORD"
		fi
		
		#nmcli connection add type wifi ifname uap0 con-name Hotspot
	
		#nmcli con add con-name Hotspot ifname uap0 type dummy
		#nmcli con add con-name Hotspot ifname uap0 type wifi connection.autoconnect yes 802-11-wireless.ssid "$SSID" ipv4.method manual ipv4.addresses "192.168.12.1/24" ipv6.method manual ipv6.addresses 'fd00::/8' 802-11-wireless.band bg 802-11-wireless.channel 1
		#nmcli con add type wifi ifname wlan0 con-name <your_hotspot_name> autoconnect yes ssid <your_ssid>
		
		echo "What is the interface name of the (still down) Hotspot connection that was just created?"
		nmcli connection show Hotspot | grep connection.interface-name
		
		#nmcli connection modify Hotspot wifi.cloned-mac-address "$ZEROMAC"
		#nmcli connection modify Hotspot 802-11-wireless.band bg 802-11-wireless.channel 1
		
		
		#nmcli connection modify Hotspot ipv4.addresses "192.168.12.1/24" ipv4.method manual 
		nmcli connection modify Hotspot ipv4.gateway "192.168.12.1" 
		nmcli connection modify Hotspot ipv4.dns "192.168.12.1" ipv4.dns-priority 1000
		nmcli connection modify Hotspot ipv4.never-default true
		
		#nmcli connection modify Hotspot ipv6.addresses 'fd00::/8' ipv6.method manual 
		nmcli connection modify Hotspot ipv6.gateway 'fd00:12::1' 
		nmcli connection modify Hotspot ipv6.dns 'fd00:12::1' ipv6.dns-priority 1000
		nmcli connection modify Hotspot ipv6.never-default true
		#nmcli connection modify Hotspot ipv6.method "ignore"
		
		nmcli connection modify Hotspot wifi.powersave 2
		
		nmcli connection modify Hotspot connection.autoconnect yes
		
		#nmcli connection modify Hotspot connection.interface-name uap0
		
	
		if [[ $PASSWORD =~ ^........+ ]]; then
			echo "Setting hotspot password"
			
			nmcli con modify Hotspot 802-11-wireless-security.key-mgmt wpa-psk \
                802-11-wireless-security.proto rsn \
                wifi-sec.pairwise ccmp \
                802-11-wireless-security.psk "$PASSWORD" \
			
			#nmcli dev wifi hotspot ifname uap0 ssid "$SSID" password "$PASSWORD" 
			#sleep 1
			#echo "Basic hotspot command run, with basic security. Did it work?"
			echo
			echo "nmcli connection show --active:"
			nmcli connection show --active
			echo
			
			
			
			#if nmcli connection show --active | grep -q Hotspot; then
				#nmcli con modify Hotspot wifi-sec.key-mgmt sae wifi-sec.psk "$PASSWORD"
				#sleep 1
				#echo "upgraded security to WPA3. Is it still working?"
			#else
				#echo "hotspot.sh: failed to start Hotspot!"
				#echo "candle: hotspot.sh: ERROR, failed to start Hotspot!" >> /dev/kmsg
				#sleep 10
				#exit 1
			#fi
		
		else
			#nmcli con modify Hotspot wifi-sec.key-mgmt sae wifi-sec.psk ""
			nmcli con modify Hotspot wifi-sec.psk ""
			echo "Warning, creating open hotspot without any security"
			#nmcli dev wifi hotspot ifname uap0 ssid "$SSID"
		fi
	
		
		
	
		# Protected Management Frames can lead to connectivity issues with some WiFi devices
		if [ -f /boot/firmware/candle_disable_wifi_pmf.txt ]; then
			echo "candle: hotspot.sh: spotted candle_disable_wifi_pmf.txt -> disabling wifi protected management frames"
			#nmcli connection modify candle_hotspot wifi.powersave 1
			nmcli con modify Hotspot wifi-sec.pmf disable
		fi
	
	
		# POWER SAVE
	
		if [ -f /boot/firmware/candle_wifi_power_save.txt ]; then
			echo "candle: hotspot.sh: spotted candle_wifi_power_save.txt -> forcing wifi powersave to on"
			#nmcli connection modify candle_hotspot wifi.powersave 1
			nmcli radio wifi powersave on
		fi
	
		echo
		echo
		echo "HERE WE GO, turning on the hotspot"
		echo
		echo
		
		HOTSPOT_UP_OUTPUT=$(nmcli con up Hotspot)
		echo "HOTSPOT_UP_OUTPUT: $HOTSPOT_UP_OUTPUT"
		
	
		start_dnsmasq
		
	fi
		
	
	

else
	echo "ERROR, no uap0 after it was just created"
	echo "candle: hotspot.sh: ERROR, no uap0 after it was just created" >> /dev/kmsg
fi

echo "Sleeping 15 seconds..."
sleep 15
echo "Sleeping 15 seconds done"
