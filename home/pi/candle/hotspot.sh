#!/bin/bash

BOOT_DIR="/boot"
if lsblk | grep -q /boot/firmware; then
    BOOT_DIR="$BOOT_DIR/firmware"
fi

if [ ! -f $BOOT_DIR/candle_log.txt ]; then
	echo "$(date) - Candle hotspot.sh: created missing log file" > $BOOT_DIR/candle_log.txt
fi

if [ -f $BOOT_DIR/candle_emergency_hotspot.txt ]; then
	exit 0
fi

# most basc command to create a hotspot:
# nmcli dev wifi hotspot ifname uap0 ssid "Candle" password "smarthome"

TOTAL_MEMORY=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [ "$TOTAL_MEMORY" -lt "800000" ] && [ -f $BOOT_DIR/candle_hotspot_5G.txt ]; then
    echo "hotspot.sh: on a Raspberry Pi zero, which has no 5Ghz radio. Deleting candle_hotspot_5G.txt"
	echo "candle hotspot.sh: on a Raspberry Pi zero, which has no 5Ghz radio. Deleting candle_hotspot_5G.txt" >> /dev/kmsg
	rm "$BOOT_DIR/candle_hotspot_5G.txt"
fi


# Setting it (again) seems to solve issues with starting the hotspot with iwd
#iw reg set "$WIFI_COUNTRY"
#sleep 1


if [ ! -f $BOOT_DIR/candle_hotspot.txt ]; then
	echo "hotspot.sh: no candle_hotspot.txt, aborting"
	echo "hotspot.sh: no candle_hotspot.txt, aborting" >> /dev/kmsg
	sleep 20
	exit 0
fi
echo "$(date) - Candle hotspot.sh: starting"
echo "$(date) - Candle hotspot.sh: starting" >> /dev/kmsg

#if [ ! -f $BOOT_DIR/candle_hotspot.txt ]; then
#	echo "candle: hotspot.sh: not starting hotspot"
#	echo "Candle: hotspot.sh: not starting hotspot" >> /dev/kmsg
#	exit 0
#fi

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

PASSWORD=""
if [ -f $BOOT_DIR/candle_hotspot_password.txt ]; then
	PASSWORD=$(cat $BOOT_DIR/candle_hotspot_password.txt)
	#echo "Updating hotspot password" >> candle_log.txt 
fi
#echo "" > $BOOT_DIR/candle_hotspot.txt

#PHY="PHY1"
#if iw list | grep -q phy0; then
#    PHY="PHY0"
#fi
#echo "PHY: $PHY"




#systemctl status iwd.service | cat

if [ -f /usr/sbin/wpa_cli ] ; then
	if wpa_cli interface_list | grep -q "Selected interface 'uap0'" ; then
		wpa_cli interface wlan0
	fi
	if [ -f /var/run/wpa_supplicant/uap0 ] ; then
		rm /var/run/wpa_supplicant/uap0
	fi
	if [ -f run/wpa_supplicant/uap0 ] ; then
		rm /run/wpa_supplicant/uap0
	fi
fi




start_dnsmasq () {
	echo "in start_dnsmasq"
	
	if [ -f $BOOT_DIR/candle_hotspot.txt ]; then
		echo "hotspot.sh: bringing up hotspot and starting dnsmasq"
		
		
		IP4S=$(hostname -I | sed -r 's/192.168.12.1//' | xargs)
		echo "hotspot.sh: IPv4 address(es): $IP4S"
	
		if iptables -t nat -L -v | grep -q "uap0"; then
			echo "uap0 already exists in iptables"
		else
	
			echo "hotspot.sh: adding iptables for uap0"
		
			# optionally, drop DHCP requests to get an IPV6 address.
			if [ -f $BOOT_DIR/candle_hotspot_no_ipv6.txt ]; then
				ip6tables -A INPUT -m state --state NEW -m udp -p udp -s fd00:12::/8 --dport 546 -j DROP
			fi
		
			if [ ! -f $BOOT_DIR/candle_hotspot_allow_access_to_main_network.txt ]; then
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
			if [ ! -f $BOOT_DIR/candle_hotspot_allow_traversal.txt ]; then
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
		if nmcli connection show --active | grep -q Candle_hotspot; then
			echo "hotspot.sh: OK, Candle_hotspot connection is still up"
		else
			echo "hotspot.sh: warning, Candle_hotspot connection exists, but still wasn't up anymore. Attempting to set it to up again. This is expected to fail"
			nmcli connection up Candle_hotspot
			sleep 1
		fi

		if nmcli connection show --active | grep -q Candle_hotspot; then
			
			echo "IPv6 address(es):"
			ip -6 addr show uap0
	
			# Start NTP time server
			if [ -f $BOOT_DIR/candle_no_time_server.txt ]; then
				echo "candle: hotspot.sh: not starting time server"
			elif [ -f /home/pi/candle/time_server.py ]; then

				if ip addr show uap0 | grep -q '192.168.12.1'; then
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


				else
					echo "ERROR, uap0 interface does not have 192.168.12.1 ip address (yet). Cannot start NTP server. ifconfig:"
				fi
				
				
				echo "active connections right before starting dnsmasq:"
				nmcli connection show --active
				
				
				if nmcli connection show --active | grep -q Candle_hotspot; then
					echo "FINAL STEP: STARTING DNSMASQ"
					dnsmasq -k -d --no-daemon --conf-file=/home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf 1> /dev/null
				fi
				
			fi
	
	
		else
			echo
			echo "hotspot.sh: ERROR, Candle_hotspot was not active (attempt to bring it up failed as expected)"
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


# Create virtual UAP0 interface for hotspot
if ip link show | grep -q "mlan0:" ; then
	echo "hotspot.sh: spotted mlan0"
	if ip link show | grep -q "uap0:" ; then
		echo "mlan0 and uap0 exist"
	else
		echo "uap0 does not exist yet"
		/sbin/iw dev mlan0 interface add uap0 type __ap
		sleep 1
		#ip address add 192.168.12.1/24 dev uap0
		#ifconfig uap0 192.168.12.1 netmask 255.255.255.0
		#ip -6 addr add fd00:12::1 dev uap0
		#iw dev uap0 set power_save off
		#sleep 1
	fi
        
elif ip link show | grep -q "wlan0:" ; then
    echo "wlan0 exists"
	if ip link show | grep -q "uap0:"; then
		echo "wlan0 and uap0 exist"
	else
		echo "uap0 does not exist yet"
		/sbin/iw dev wlan0 interface add uap0 type __ap
		sleep 1
		#ip address add 192.168.12.1/24 dev uap0
		#ifconfig uap0 192.168.12.1 netmask 255.255.255.0
		#ip -6 addr add fd00:12::1 dev uap0
		#iw dev uap0 set power_save off
		#sleep 1
	fi
fi



# Purge any connections, other than Candle_hotspot, that are set to use uap0


nmcli -t -f NAME connection | while read name; do
	if [[ "$name" != "Candle_hotspot" ]] ; then
		if nmcli -t connection show "$name" | grep -q "connection.interface-name:uap0" ; then
			WASUP="false"
			if nmcli -f GENERAL.STATE con show "$name" | grep -q activated ; then
				echo "hotspot.sh: bringing down a connection that was using uap0, but was not Candle_hotspot: $name"
				echo "hotspot.sh: bringing down a connection that was using uap0, but was not Candle_hotspot: $name" >> /dev/kmsg
				nmcli connection down "$name"
				WASUP="true"
			fi
			if ip link show | grep -q "wlan0:" ; then
				nmcli connection modify "$name" ifname wlan0
				if nmcli -t connection show "$name" | grep -q "connection.interface-name:wlan0" ; then
					# Connection was succesfully modified to use wlan0 instead
					if [ "$WASUP" == "true" ] ; then
						if nmcli -t -f DEVICE c s --active | grep -q "wlan0" ; then
							echo "hotspot.sh: connection pruning: want to bring up the modified connection, but another connection is already using wlan0"
						else
							nmcli connection up "$name"
							echo "hotspot.sh: connection pruning: succesfully moved active connection from uap0 to wlan0 interface"
							echo "hotspot.sh: connection pruning: succesfully moved active connection from uap0 to wlan0 interface" >> /dev/kmsg
						fi
					fi
				else
					nmcli connection delete "$name"
				fi
			else
				nmcli connection delete "$name"
				#REMAINING_ACTIVE_CONNECTIONS=$(nmcli -t -f DEVICE c s --active | grep -v lo)
				#echo "hotspot.sh: connection pruning:  REMAINING_ACTIVE_CONNECTIONS: $REMAINING_ACTIVE_CONNECTIONS"
				#if [ -n "$REMAINING_ACTIVE_CONNECTIONS" ] ; then
				#	nmcli connection delete "$name"
				#	echo "hotspot.sh: had to delete a connection that was set to use uap0: $name" >> /dev/kmsg
				#else:
				#	echo "hotspot.sh: a connection is already using uap0, and it can't be moved to wlan0, and there is no other connection either. So it will have to remain this way." >> /dev/kmsg
				#fi
			fi
		fi
	fi
done





#if ip link show | grep "uap0:" | grep -q "state UP"; then
if ip link show | grep -q "uap0:"; then
	
	echo
	echo "ifconfig uap0:"
	ifconfig uap0
	echo
	
	# Generate a slightly different MAC address for UAP0. Ending it with zero might even help creating a hotspot.
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
	#RANDOMCHARS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 2 | head -n 1)
	
	RANDOMCHARS=""
	chars=1234567890ABCDEF
	for i in {1..2}; do
		RANDOMCHARS=$(echo -n "$RANDOMCHARS${chars:RANDOM%${#chars}:1}")
	done
	echo "RANDOMCHARS: $RANDOMCHARS"
	
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
	OLD_SSID=$(nmcli c s Candle_hotspot | grep 802-11-wireless.ssid | awk '{print $2}')
	#if [[ "$OLD_SSID" == *"_nomap"* ]]; then
	if [ -n "$OLD_SSID" ]; then	
	    echo "spotted existing Candle_hotspot connection. Existing SSID: $OLD_SSID"
		SSID=$(echo "$OLD_SSID")
	fi
	
	
	# Allow the user to override the SSID
	if [ -f $BOOT_DIR/candle_hotspot_name.txt ]; then
		SPOTTED_HOTSPOT_SSID=$(cat $BOOT_DIR/candle_hotspot_name.txt)
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

	
	

	if nmcli connection show --active | grep -q Candle_hotspot; then
		echo "hotspot.sh: WARNING, the Candle_hotspot connection is already up. Did dnsmasq crash?"
		echo "candle: hotspot.sh: WARNING, the Candle_hotspot connection is already up. Did dnsmasq crash?" >> /dev/kmsg
		start_dnsmasq
		exit 1
	else
		
		
		echo
		echo "ifconfig uap0:"
		ifconfig uap0
		echo
		
		#if ifconfig uap0 | grep -q '192.168.12.1'; then
		#	echo "OK, uap0 still has the correct IP address"
		#else
		#	echo "forcing ip address for uap0 again"
		#	ip address add 192.168.12.1/24 dev uap0
		#fi	
		
		
		#echo
		#echo "ifconfig uap0:"
		#ifconfig uap0
		#echo
		
		if nmcli connection show | grep -q 'Candle_hotspot'; then
			echo "Candle_hotspot connection already exists"
			
			echo "What is the interface name of the not-active Candle_hotspot connection? (0)"
			nmcli connection show Candle_hotspot | grep connection.interface-name
			

		else
			#nmcli connection add con-name "Candle_hotspot" \
			#    ifname uap0 wifi.mode ap wifi.ssid "$SSID" \
			#	wifi-sec.key-mgmt wpa-psk \
			#    wifi-sec.proto rsn wifi-sec.pairwise ccmp \
			#    wifi-sec.psk "$PASSWORD" \
			#	connection.autoconnect yes
			
			if [[ $PASSWORD =~ ^........+ ]]; then
				
                nmcli connection add \
                    con-name Candle_hotspot \
                    ifname uap0 \
                    type wifi \
                    autoconnect yes \
                    ipv4.method manual ipv4.addresses "192.168.12.1/24" \
                    802-11-wireless.band bg \
                    802-11-wireless.channel 1 \
                    802-11-wireless.mode ap \
                    802-11-wireless.ssid "$SSID" \
                    802-11-wireless-security.key-mgmt wpa-psk \
                    802-11-wireless-security.proto rsn \
                    802-11-wireless-security.pairwise ccmp \
                    802-11-wireless-security.psk "$PASSWORD" \
                    ipv6.method manual ipv6.addresses 'fd00:12::1/8'

					#wifi-sec.pairwise ccmp \
			
			
			else
                nmcli connection add \
                    con-name Candle_hotspot \
                    ifname uap0 \
                    type wifi \
                    autoconnect yes \
                    ipv4.method manual ipv4.addresses "192.168.12.1/24" \
                    802-11-wireless.band bg \
                    802-11-wireless.channel 1 \
                    802-11-wireless.mode ap \
                    802-11-wireless.ssid "$SSID" \
                    ipv6.method manual ipv6.addresses 'fd00:12::1/8'
				
			fi
			
			nmcli con modify Candle_hotspot 802-11-wireless.mode ap
			nmcli con modify Candle_hotspot wifi.cloned-mac-address "$ZEROMAC"
			nmcli con modify Candle_hotspot connection.autoconnect-priority 10

			#nmcli con modify Candle_hotspot wifi-sec.pmf disable
			nmcli con modify Candle_hotspot 802-11-wireless-security.pmf optional
			
			nmcli connection modify Candle_hotspot ipv4.gateway "192.168.12.1" 
			nmcli connection modify Candle_hotspot ipv4.dns "192.168.12.1" ipv4.dns-priority 1000
			nmcli connection modify Candle_hotspot ipv4.never-default true
		
			#nmcli connection modify Candle_hotspot ipv6.addresses 'fd00::/8' ipv6.method manual 
			nmcli connection modify Candle_hotspot ipv6.gateway 'fd00:12::1' 
			nmcli connection modify Candle_hotspot ipv6.dns 'fd00:12::1' ipv6.dns-priority 1000
			nmcli connection modify Candle_hotspot ipv6.never-default true
			#nmcli connection modify Candle_hotspot ipv6.method "ignore"
		
			nmcli connection modify Candle_hotspot wifi.powersave 2
		
			nmcli connection modify Candle_hotspot connection.autoconnect yes
			
		fi
	
		if [ -f $BOOT_DIR/developer.txt ]; then
			echo "Will try to start Candle_hotspot with: "
			echo " - SSID: $SSID"
			echo " - PASS: $PASSWORD"
		fi
		
		#nmcli connection add type wifi ifname uap0 con-name Candle_hotspot
	
		#nmcli con add con-name Candle_hotspot ifname uap0 type dummy
		#nmcli con add con-name Candle_hotspot ifname uap0 type wifi connection.autoconnect yes 802-11-wireless.ssid "$SSID" ipv4.method manual ipv4.addresses "192.168.12.1/24" ipv6.method manual ipv6.addresses 'fd00::/8' 802-11-wireless.band bg 802-11-wireless.channel 1
		#nmcli con add type wifi ifname wlan0 con-name <your_hotspot_name> autoconnect yes ssid <your_ssid>
		
		
		
		#nmcli connection modify Candle_hotspot wifi.cloned-mac-address "$ZEROMAC"
		#nmcli connection modify Candle_hotspot 802-11-wireless.band bg 802-11-wireless.channel 1
		
		
		#nmcli connection modify Candle_hotspot ipv4.addresses "192.168.12.1/24" ipv4.method manual 
		
		
		#nmcli connection modify Candle_hotspot connection.interface-name uap0
		
		if nmcli connection show | grep -q Candle_hotspot; then
			
			echo "What is the interface name of the Candle_hotspot connection?"
			nmcli connection show Candle_hotspot | grep connection.interface-name


			# TODO: check if there is a normal wireless connection too, and if so, follow that connection's band (5G / 2.4G) to keep the radio happy
			# TODO: maybe also explain that to the user, or automatically switch to a 5G/2.4G version of the SSID if available? That may be a security risk though..
			
			if [ -f $BOOT_DIR/candle_hotspot_5G.txt ]; then
				nmcli con modify Candle_hotspot 802-11-wireless.band a 802-11-wireless.channel 44
			else
				nmcli con modify Candle_hotspot 802-11-wireless.band bg 802-11-wireless.channel 1
			fi

			

			
			if [[ $PASSWORD =~ ^........+ ]]; then
				echo "Setting hotspot password"
			
				nmcli con modify Candle_hotspot \
	                802-11-wireless-security.key-mgmt wpa-psk \
	                802-11-wireless-security.proto rsn \
	                802-11-wireless-security.pairwise ccmp \
	                802-11-wireless-security.psk "$PASSWORD"

					# wifi-sec.pairwise ccmp \
			
				#nmcli dev wifi hotspot ifname uap0 ssid "$SSID" password "$PASSWORD" 
				#sleep 1
				#echo "Basic hotspot command run, with basic security. Did it work?"
				echo
				echo "nmcli connection show --active:"
				nmcli connection show --active
				echo
			
			
			
				#if nmcli connection show --active | grep -q Candle_hotspot; then
					#nmcli con modify Candle_hotspot wifi-sec.key-mgmt sae wifi-sec.psk "$PASSWORD"
					#sleep 1
					#echo "upgraded security to WPA3. Is it still working?"
				#else
					#echo "hotspot.sh: failed to start Candle_hotspot!"
					#echo "candle: hotspot.sh: ERROR, failed to start Candle_hotspot!" >> /dev/kmsg
					#sleep 10
					#exit 1
				#fi
		
			else
				#nmcli con modify Candle_hotspot wifi-sec.key-mgmt sae wifi-sec.psk ""
				nmcli con modify Candle_hotspot \
	                802-11-wireless-security.key-mgmt "" \
	                802-11-wireless-security.proto "" \
	                802-11-wireless-security.pairwise "" \
	                802-11-wireless-security.psk ""
				echo "Warning, creating open hotspot without any security"
				#nmcli dev wifi hotspot ifname uap0 ssid "$SSID"
			fi
	
		
		
	
			# Protected Management Frames can lead to connectivity issues with some WiFi devices
			if [ -f $BOOT_DIR/candle_disable_wifi_pmf.txt ]; then
				echo "candle: hotspot.sh: spotted candle_disable_wifi_pmf.txt -> disabling wifi protected management frames"
				#nmcli connection modify candle_hotspot wifi.powersave 1
				nmcli con modify Candle_hotspot wifi-sec.pmf disable
			fi
			
			
			
			# POWER SAVE
	
			if [ -f $BOOT_DIR/candle_wifi_power_save.txt ]; then
				echo "candle: hotspot.sh: spotted candle_wifi_power_save.txt -> forcing wifi powersave to on"
				#nmcli connection modify candle_hotspot wifi.powersave 1
				nmcli radio wifi powersave on
			fi
	
	
			
	
			echo
			echo
			echo "HERE WE GO, turning on the hotspot"
			echo "HERE WE GO, turning on the hotspot" >> /dev/kmsg
			echo
			echo


			if nmcli radio wifi | grep -q 'disabled'; then
				echo "hotspot.sh: WARNING, had to bring up wifi radio (1)"
				echo "candle: hotspot.sh: WARNING, had to bring up wifi radio (1)" >> /dev/kmsg
				nmcli radio wifi on
				sleep 1
			fi
			
			

			# Make sure no other connection is using the UAP0 interface
			# nmcli dev dis uap0
		
			if nmcli connection show --active | grep -q uap0; then
				echo "Strange, the Candle_hotspot was already active?"
				start_dnsmasq
				
			else
				if ip link show | grep -q "uap0:"; then
					
					
					if ip link show uap0 | grep -q DORMANT; then
						echo "hotspot.sh: uap0 was in DORMANT mode, setting to DEFAULT instead" >> /dev/kmsg
						ip link set uap0 mode default
					fi
					
					if ip link show uap0 | grep -q 'state DOWN'; then
						if nmcli device status | grep uap0 | grep -q unmanaged ; then
							nmcli device set uap0 managed true
						fi
					fi
					
					
					HOTSPOT_UP_OUTPUT=$(nmcli con up Candle_hotspot)
					echo "HOTSPOT_UP_OUTPUT: $HOTSPOT_UP_OUTPUT"
					echo "candle: HOTSPOT_UP_OUTPUT: $HOTSPOT_UP_OUTPUT" >> /dev/kmsg
			
					if echo "$HOTSPOT_UP_OUTPUT" | grep -q "successfully activated" ; then
						sleep 1
						if nmcli connection show --active | grep -q Candle_hotspot; then
							start_dnsmasq
						else
							echo "ERROR, Candle_hotspot seemed to be succesfully actvated, but is not in active connections list"
						fi
					else
						echo "ERROR, bringing Candle_hotspot connection up failed"
						echo "candle: hotspot.sh: ERROR, starting Candle_hotspot connection failed. Try rebooting." >> /dev/kmsg
					fi
				else
					echo "ERROR, uap0 has disappeared..."
					exit 1
					
				fi
				
				
			fi
				
			
			
		else
			echo "ERROR, failed to create hotspot connection?"
			
		fi
		
	fi
		
	
	

else
	echo "ERROR, no uap0 after it was just created"
	echo "candle: hotspot.sh: ERROR, no uap0 after it was just created" >> /dev/kmsg
fi

echo "Sleeping 15 seconds..."
sleep 15
echo "Sleeping 15 seconds done"
exit 0
