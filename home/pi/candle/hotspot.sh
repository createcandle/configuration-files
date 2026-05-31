#!/bin/bash

# WPA Supplicant configuration options:
# https://github.com/sensepost/wpa_sycophant/blob/master/wpa_supplicant/wpa_supplicant.conf

# 
# https://waltsworkbench.com/securing-a-wifi-hotspot-with-wpa2-using-networkmanager-on-a-raspberry-pi-running-bookworm-aka-debian-12/


# https://unix.stackexchange.com/questions/765116/remove-p2p-dev-wlp1s0-device-network-manager



BOOT_DIR="/boot"
if lsblk | grep -q /boot/firmware; then
    BOOT_DIR="$BOOT_DIR/firmware"
fi

if [ ! -f $BOOT_DIR/candle_log.txt ]; then
	echo "$(date) - Candle hotspot.sh: created missing log file" > $BOOT_DIR/candle_log.txt
fi

if [ -f $BOOT_DIR/candle_emergency_hotspot.txt ]; then
	echo "candle: hotspot.sh: spotted candle_emergency_hotspot.txt, aborting!" >> /dev/kmsg
	exit 0
fi

if [ ! -f $BOOT_DIR/candle_hotspot.txt ]; then
	echo "candle: hotspot.sh: no candle_hotspot.txt, aborting!"
	echo "candle: hotspot.sh: no candle_hotspot.txt, aborting!" >> /dev/kmsg
	sleep 10
	exit 0
fi

#echo "$(date) - Candle hotspot.sh: starting"
#echo "$(date) - Candle hotspot.sh: starting" >> /dev/kmsg

echo "candle: hotspot.sh: $(date) - Start"
echo "candle: hotspot.sh: $(date) - Start" >> /dev/kmsg




#
#  PREPARATION
#



IFNAME="uap0"
if [ ! -f $BOOT_DIR/candle_hotspot_force_uap0.txt ]; then
	if ip link show | grep -q "wlan1:"; then
		IFNAME="wlan1"
		echo "candle: hotspot.sh: detected a second radio, will use it for hotspot: $IFNAME"
		echo "candle: hotspot.sh: detected a second radio, will use it for hotspot: $IFNAME" >> /dev/kmsg
	elif ip link show | grep -q "mlan1:"; then
		IFNAME="mlan1"
		echo "candle: hotspot.sh: detected a second radio, will use it for hotspot: $IFNAME"
		echo "candle: hotspot.sh: detected a second radio, will use it for hotspot: $IFNAME" >> /dev/kmsg
	fi
else
	echo "candle: hotspot.sh: forcing use of uap0 interface for hotspot"
	echo "candle: hotspot.sh: forcing use of uap0 interface for hotspot" >> /dev/kmsg
fi

echo "candle: hotspot.sh:  IFNAME: $IFNAME"
echo "candle: hotspot.sh:  IFNAME: $IFNAME" >> /dev/kmsg



REALMAC=""

# TODO: support for MLAN0 is not fully implemented at the moment.

if ip link show | grep -q "wlan0"; then
	REALMAC=$(nmcli device show wlan0 | grep HWADDR | awk '{print $2}')
	echo "candle: hotspot.sh: wlan0 REAL MAC: $REALMAC"
elif ip link show | grep -q "mlan0"; then
	REALMAC=$(nmcli device show mlan0 | grep HWADDR | awk '{print $2}')
	echo "candle: hotspot.sh: mlan0 REAL MAC: $REALMAC"
fi

echo "candle: hotspot.sh:  REALMAC: $REALMAC"
echo "candle: hotspot.sh:  REALMAC: $REALMAC" >> /dev/kmsg




ZEROMAC="$REALMAC"

if [ "$IFNAME" == "uap0" ]; then
	# Generate a slightly different MAC address for $IFNAME. Ending it with zero might even help creating a hotspot.
	
	if [[ "$REALMAC" =~ 0$ ]]; then
    	ZEROMAC=${REALMAC%?}1
	else
		ZEROMAC=${REALMAC%?}0
	fi
	#ip link set dev $IFNAME address "$ZEROMAC"
fi

echo "candle: hotspot.sh:  ZEROMAC: $ZEROMAC"
echo "candle: hotspot.sh:  ZEROMAC: $ZEROMAC" >> /dev/kmsg




#
#  PREPARE SSID
#




# Allow the user to override the SSID
if [ -f $BOOT_DIR/candle_hotspot_name.txt ]; then
	SPOTTED_HOTSPOT_SSID=$(cat $BOOT_DIR/candle_hotspot_name.txt | tr -d '\n')
	if [ -n "$SPOTTED_HOTSPOT_SSID" ]; then 
		echo "candle: hotspot.sh: Spotted a prefered hotspot SSID in candle_hotspot_name.txt: $SPOTTED_HOTSPOT_SSID"
		echo "candle: hotspot.sh: Spotted a prefered hotspot SSID in candle_hotspot_name.txt: $SPOTTED_HOTSPOT_SSID" >> /dev/kmsg
		SSID="$SPOTTED_HOTSPOT_SSID"
	fi
fi

# If a connection already exists, re-use it's SSID
if [ -z "$OLD_SSID" ]; then	
	if nmcli c s | grep -q 'Candle_hotspot'; then
		# check if there is an existing SSID to re-use instead
		#OLD_SSID=$(nmcli c s Candle_hotspot | grep '802-11-wireless.ssid' | awk '{print $2}')
		OLD_SSID=$(nmcli c s Candle_hotspot | grep '802-11-wireless.ssid:' | sed 's/802-11-wireless.ssid://' | xargs)
	
		echo "candle: hotspot.sh: SSID from existing Candle_hotspot connection: -->$OLD_SSID<--"
		echo "candle: hotspot.sh: SSID from existing Candle_hotspot connection: -->$OLD_SSID<--" >> /dev/kmsg
	
		#if [[ "$OLD_SSID" == *"_nomap"* ]]; then
		if [ -n "$OLD_SSID" ]; then	
		    echo "spotted existing Candle_hotspot connection, setting SSID to OLD_SSID: $SSID -> $OLD_SSID"
			SSID="$OLD_SSID"
		fi
	fi
fi

# If no existing SSID is available, generate a new one
if [ -z "$OLD_SSID" ]; then	
	
	# Create a semi-unique 4 character code for the hotspot's SSID, 
	# based on the last two characters from the MAC address plus 2 random characters
	
	SHORTMAC=${MAC: -2}
	echo "candle: hotspot.sh: last two characters from MAC: $SHORTMAC"
	
	RANDOMCHARS=""
	chars=1234567890ABCDEF
	for i in {1..2}; do
		RANDOMCHARS=$(echo -n "$RANDOMCHARS${chars:RANDOM%${#chars}:1}")
	done
	echo "candle: hotspot.sh: two random characters: $RANDOMCHARS"

	SHORTMAC="$SHORTMAC$RANDOMCHARS"

	echo "candle: hotspot.sh: semi-unique 4 character code for SSID: $SHORTMAC"
	echo "candle: hotspot.sh: semi-unique 4 character code for SSID: $SHORTMAC" >> /dev/kmsg

	SSID="Candle $(echo $SHORTMAC)_nomap" # SIC
	echo "candle: hotspot.sh: freshly generated SSID: $SSID"
	echo "candle: hotspot.sh: freshly generated SSID: $SSID" >> /dev/kmsg
fi


echo "candle: hotspot.sh:  SSID: $SSID"
echo "candle: hotspot.sh:  SSID: $SSID" >> /dev/kmsg



echo ""
echo "-------------------"
echo ""
echo "candle: hotspot.sh: iw reg get: $(iw reg get)"
echo "candle: hotspot.sh: iw reg get: $(iw reg get)" >> /dev/kmsg
echo ""
echo "candle: hotspot.sh: regdom: $(journalctl -b | grep REGDOM)"
echo "candle: hotspot.sh: regdom: $(journalctl -b | grep REGDOM)" >> /dev/kmsg
echo ""
echo "candle: hotspot.sh: rfkill: $(rfkill)"
echo "candle: hotspot.sh: rfkill: $(rfkill)" >> /dev/kmsg
echo ""
echo "candle: hotspot.sh: nmcli radio: $(nmcli radio)"
echo "candle: hotspot.sh: nmcli radio: $(nmcli radio)" >> /dev/kmsg
echo ""
echo "candle: hotspot.sh: nmcli dev: $(nmcli dev)"
echo "candle: hotspot.sh: nmcli dev: $(nmcli dev)" >> /dev/kmsg
echo ""
echo "candle: hotspot.sh: nmcli connection show: $(nmcli connection show)"
echo "candle: hotspot.sh: nmcli connection show: $(nmcli connection show)" >> /dev/kmsg
echo ""
echo "-------------------"
echo ""




# Generate a random ip4/16 octet. The aim is that each hotspot has a separate range.
# In the future they could more perhaps be meshed together in a virtual private network between the Candle Controllers
# as a way to create a larger wifi network with multiple access points that is still walled off from the rest of the network
NETID=$((20 + $RANDOM % 220))
if [ -f $BOOT_DIR/candle_hotspot_net_number.txt ]; then
	NETID=$(cat "$BOOT_DIR/candle_hotspot_net_number.txt" | tr -d '\n')
else
	echo $NETID > $BOOT_DIR/candle_hotspot_net_number.txt
fi

echo "candle: hotspot.sh:  NETID: $NETID"
echo "candle: hotspot.sh:  NETID: $NETID" >> /dev/kmsg


OWN_IP4="172.16.$NETID.1"
OWN_IP6="fd00:$NETID::1"

echo "candle: hotspot.sh:  OWN_IP4: $OWN_IP4"
echo "candle: hotspot.sh:  OWN_IP4: $OWN_IP4" >> /dev/kmsg
echo "candle: hotspot.sh:  OWN_IP6: $OWN_IP6"
echo "candle: hotspot.sh:  OWN_IP6: $OWN_IP6" >> /dev/kmsg





TOTAL_MEMORY=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [ "$TOTAL_MEMORY" -lt "800000" ] && [ -f $BOOT_DIR/candle_hotspot_5G.txt ]; then
    echo "hotspot.sh: on a Raspberry Pi zero, which has no 5Ghz radio. Deleting candle_hotspot_5G.txt"
	echo "candle hotspot.sh: on a Raspberry Pi zero, which has no 5Ghz radio. Deleting candle_hotspot_5G.txt" >> /dev/kmsg
	rm "$BOOT_DIR/candle_hotspot_5G.txt"
fi



# Setting it (again) seems to solve issues with starting the hotspot with iwd
#iw reg set "$WIFI_COUNTRY"
#sleep 1



#if [ ! -f $BOOT_DIR/candle_hotspot.txt ]; then
#	echo "candle: hotspot.sh: not starting hotspot"
#	echo "Candle: hotspot.sh: not starting hotspot" >> /dev/kmsg
#	exit 0
#fi

if [ -f $BOOT_DIR/candle_hotspot_block_ip4_internet.txt ]; then
	echo "Candle: hotspot.sh: ensuring ip4 forwarding is disabled" >> /dev/kmsg
	sysctl -w net.ipv4.ip_forward=0
else
	echo "Candle: hotspot.sh: ensuring ip4 forwarding is enabled" >> /dev/kmsg
	sysctl -w net.ipv4.ip_forward=1
fi

if [ -f $BOOT_DIR/candle_hotspot_block_ip6_internet.txt ]; then
	echo "Candle: hotspot.sh: ensuring ip6 forwarding is disabled" >> /dev/kmsg
	sysctl -w net.ipv6.conf.all.forwarding=0
else
	echo "Candle: hotspot.sh: ensuring ip6 forwarding is enabled" >> /dev/kmsg
	sysctl -w net.ipv6.conf.all.forwarding=1
fi

PASSWORD=""
if [ -f $BOOT_DIR/candle_hotspot_password.txt ]; then
	PASSWORD=$(cat $BOOT_DIR/candle_hotspot_password.txt | tr -d '\n')
	#echo "Updating hotspot password" >> candle_log.txt 
fi

if [ -f "$BOOT_DIR/developer.txt" ]; then
	echo "candle: hotspot.sh: DEVELOPER:  PASSWORD: -->$PASSWORD<--"
	echo "candle: hotspot.sh: DEVELOPER:  PASSWORD: -->$PASSWORD<--" >> /dev/kmsg
fi







#
#  PRUNE 
#

#removes connections, other than Candle_hotspot, that are set to use $IFNAME
start_prune () {
	echo "candle: hotspot.sh: in start_prune"
	echo "candle: hotspot.sh: in start_prune" >> /dev/kmsg
	
	nmcli -t -f NAME connection | while read -r name; do
		if [[ "$name" != "Candle_hotspot" ]] ; then
			if nmcli -t connection show "$name" | grep -q "connection.interface-name:$IFNAME" ; then
				WASUP="false"
				if nmcli -f GENERAL.STATE con show "$name" | grep -q activated ; then
					echo "candle: hotspot.sh: bringing down a connection that was using $IFNAME, but was not Candle_hotspot: $name"
					echo "candle: hotspot.sh: bringing down a connection that was using $IFNAME, but was not Candle_hotspot: $name" >> /dev/kmsg
					nmcli connection down "$name"
					WASUP="true"
				fi
				if ip link show | grep -q "wlan0:" ; then
					nmcli connection modify "$name" ifname wlan0
					if nmcli -t connection show "$name" | grep -q "connection.interface-name:wlan0" ; then
						# Connection was succesfully modified to use wlan0 instead
						if [ "$WASUP" == "true" ] ; then
							if nmcli -t -f DEVICE c s --active | grep -q "wlan0" ; then
								echo "candle: hotspot.sh: connection pruning: want to bring up the modified connection, but another connection is already using wlan0"
							else
								nmcli connection up "$name"
								echo "candle: hotspot.sh: connection pruning: succesfully moved active connection from $IFNAME to wlan0 interface"
								echo "candle: hotspot.sh: connection pruning: succesfully moved active connection from $IFNAME to wlan0 interface" >> /dev/kmsg
							fi
						fi
					else
						echo "candle: hotspot.sh: connection pruning: removing a duplicate connection with name: $name"
						echo "candle: hotspot.sh: connection pruning: removing a duplicate connection with name: $name" >> /dev/kmsg
						nmcli connection delete "$name"
					fi
				else
					echo "candle: hotspot.sh: connection pruning: removing a duplicate connection with name: $name"
					echo "candle: hotspot.sh: connection pruning: removing a duplicate connection with name: $name" >> /dev/kmsg
					nmcli connection delete "$name"
					#REMAINING_ACTIVE_CONNECTIONS=$(nmcli -t -f DEVICE c s --active | grep -v lo)
					#echo "hotspot.sh: connection pruning:  REMAINING_ACTIVE_CONNECTIONS: $REMAINING_ACTIVE_CONNECTIONS"
					#if [ -n "$REMAINING_ACTIVE_CONNECTIONS" ] ; then
					#	nmcli connection delete "$name"
					#	echo "hotspot.sh: had to delete a connection that was set to use $IFNAME: $name" >> /dev/kmsg
					#else:
					#	echo "hotspot.sh: a connection is already using $IFNAME, and it can't be moved to wlan0, and there is no other connection either. So it will have to remain this way." >> /dev/kmsg
					#fi
				fi
			fi
		fi
	done

}













#echo "" > $BOOT_DIR/candle_hotspot.txt

#PHY="PHY1"
#if iw list | grep -q phy0; then
#    PHY="PHY0"
#fi
#echo "PHY: $PHY"




#systemctl status iwd.service | cat

#if [ -f /usr/sbin/wpa_cli ] ; then
#	echo "getting wpa_cli interface_list"
#	if wpa_cli interface_list | grep -q "Selected interface '$IFNAME'" ; then
#		echo "wpa_supplicant was using $IFNAME as the main selected interface, attempting to fix"
#		echo "wpa_supplicant was using $IFNAME as the main selected interface, attempting to fix" >> /dev/kmsg
#		wpa_cli interface wlan0
#	fi
#	if [ -f "/var/run/wpa_supplicant/$IFNAME" ] ; then
#		rm "/var/run/wpa_supplicant/$IFNAME"
#	fi
#	if [ -f "run/wpa_supplicant/$IFNAME" ] ; then
#		rm "/run/wpa_supplicant/$IFNAME"
#	fi
#fi




#
#  START DNSMASQ FUNCTION
#

start_dnsmasq () {
	echo "candle: hotspot.sh: in start_dnsmasq"
	echo "candle: hotspot.sh: in start_dnsmasq" >> /dev/kmsg
	
	if [ -f $BOOT_DIR/candle_hotspot.txt ]; then
		echo "candle: hotspot.sh: OK, still bringing up hotspot and starting dnsmasq"
		
		
		#IP4S=$(hostname -I | sed -r 's/172.16.$NETID.1//' | xargs)
		IPS=$(hostname -I | sed -r 's/172.16.[0-9]\+.1//' | xargs)
		echo "candle: hotspot.sh: IP address(es): $IPS"
	
		if iptables -t nat -L -v | grep -q "$IFNAME"; then
			echo "$IFNAME already exists in iptables"
		else
	
			echo "hotspot.sh: adding iptables for $IFNAME"
		
			# optionally, drop DHCP requests to get an IPV6 address.
			if [ -f $BOOT_DIR/candle_hotspot_no_ipv6.txt ]; then
				ip6tables -A INPUT -m state --state NEW -m udp -p udp -s "fd00:$NETID::/8" --dport 546 -j DROP
			fi
		
			#if [ ! -f $BOOT_DIR/candle_hotspot_allow_access_to_main_network.txt ]; then
			#	echo "blocking access of hotspot network to main network"
				#iptables -A FORWARD -d "172.16.$NETID.2" -m iprange --src-range "172.16.$NETID.2-172.16.$NETID.255" -j DROP
				#iptables -I INPUT -i $IFNAME -d <main_network_IP> -j DROP
			
				#iptables -A FORWARD -i $IFNAME -m iprange --src-range "172.16.$NETID.2-172.16.$NETID.255" -o eth0 -d 172.16.0.0/16 -j DROP
				#iptables -A FORWARD -i $IFNAME -m iprange --src-range "172.16.$NETID.2-172.16.$NETID.255" -o wlan0 -d 172.16.0.0/16 -j DROP
			#fi
		

			# Force all DNS traffic on the hotspot network to go to/through the Candle Controller
			iptables -t nat -A PREROUTING -i "$IFNAME" -s "172.16.$NETID.0/24" -p udp --dport 53 -j DNAT --to-destination "172.16.$NETID.1:53"
			#ip6tables -t nat -A PREROUTING -i $IFNAME -s "fd00:$NETID::/8" -p udp --dport 53 -j DNAT --to-destination "fd00:$NETID::1"
			ip6tables -t nat -A PREROUTING -i "$IFNAME" -p udp --dport 53 -j DNAT --to-destination "fd00:$NETID::1"
		
			echo "candle: hotspot.sh: adding iptables forwarding rules"
			iptables -A FORWARD -i "$IFNAME" -j ACCEPT
			ip6tables -A FORWARD -i "$IFNAME" -j ACCEPT
			iptables -A FORWARD -o "$IFNAME" -m state --state ESTABLISHED,RELATED -j ACCEPT
			ip6tables -A FORWARD -d ff02::1 -o "$IFNAME" -m state --state ESTABLISHED,RELATED -j ACCEPT
			#iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
			#iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE

			echo "candle: hotspot.sh: enablng masquerade"
			iptables -t nat -A POSTROUTING -s "172.16.$NETID.0/24" ! -d "172.16.$NETID.0/24"  -j MASQUERADE
			ip6tables -t nat -A POSTROUTING -s "ff02:$NETID::1" ! -d "ff02:$NETID::1"  -j MASQUERADE


			echo "candle: hotspot.sh: step 1 of adding port redirect rules on hotspot side"
			iptables -I PREROUTING -p tcp -i "$IFNAME" -s "172.16.$NETID.0/24" -d "172.16.$NETID.1/32" --dport 80 -j REDIRECT --to-port 8080
			iptables -I PREROUTING -p tcp -i "$IFNAME" -s "172.16.$NETID.0/24" -d "172.16.$NETID.1/32" --dport 443 -j REDIRECT --to-port 4443

			ip6tables -I PREROUTING -p tcp -i $IFNAME -s "fd00:$NETID::/8" -d "fd00:$NETID::1" --dport 80 -j REDIRECT --to-port 8080
			ip6tables -I PREROUTING -p tcp -i $IFNAME -s "fd00:$NETID::/8" -d "fd00:$NETID::1" --dport 443 -j REDIRECT --to-port 4443
		
	
			# Block access to parent local networks
			if [ ! -f $BOOT_DIR/candle_hotspot_allow_access_to_main_network.txt ]; then
				echo "candle: hotspot.sh: blocking traversal to local network"
				iptables -I FORWARD -i $IFNAME -d 172.16.0.0/16 -m iprange --src-range "172.16.$NETID.2-172.16.$NETID.255" -j DROP
				iptables -I FORWARD -i $IFNAME -d 172.16.0.0/12 -m iprange --src-range "172.16.$NETID.2-172.16.$NETID.255" -j DROP
				iptables -I FORWARD -i $IFNAME -d 10.0.0.0/8 -m iprange --src-range "172.16.$NETID.2-172.16.$NETID.255" -j DROP

				ip6tables -I FORWARD -i $IFNAME -d "fe80:$NETID::/10" -s "fd00:$NETID::/8" -j DROP
			fi
		
			# Redirect Candle UI ports
			echo "candle: hotspot.sh: step 2 of adding port redirect rules on hotspot side"
			iptables -t mangle -I PREROUTING -s "172.16.$NETID.0/24" -p tcp -d "172.16.$NETID.1" --dport 80 -j MARK --set-mark 2
			iptables -t mangle -I PREROUTING -s "172.16.$NETID.0/24" -p tcp -d "172.16.$NETID.1" --dport 443 -j MARK --set-mark 2
			iptables -t nat    -I PREROUTING -s "172.16.$NETID.0/24" -p tcp -d "172.16.$NETID.1" --dport 80 -j REDIRECT --to-port 8080
			iptables -t nat    -I PREROUTING -s "172.16.$NETID.0/24" -p tcp -d "172.16.$NETID.1" --dport 443 -j REDIRECT --to-port 4443
			iptables -I INPUT -s "172.16.$NETID.0/24" -m state --state NEW -m tcp -p tcp -d "172.16.$NETID.1" --dport 8080 -m mark --mark 2 -j ACCEPT
			iptables -I INPUT -s "172.16.$NETID.0/24" -m state --state NEW -m tcp -p tcp -d "172.16.$NETID.1" --dport 4443 -m mark --mark 2 -j ACCEPT
		fi
		
		if rfkill | grep -q ' blocked '; then
			echo "Had to rfkll unblock all (1)"
			echo "candle: hotspot.sh: start_dnsmasq: had to rfkll unblock all" >> /dev/kmsg
			rfkill unblock all
			sleep 1
		fi
		
		
		echo "any p2p-dev sockets in /var/run/wpa_supplicant?:"
		ls /var/run/wpa_supplicant/p2p-dev-*
		echo "deleting any p2p-dev sockets in /var/run/wpa_supplicant"
		rm -rf /var/run/wpa_supplicant/p2p-dev-*
		
		echo "Candle: hotspot.sh: bringing up hotspot before starting dnsmasq" >> /dev/kmsg
		if nmcli radio wifi | grep -q 'disabled'; then
			echo "candle: hotspot.sh: doing nmcli radio wifi on"
			echo "candle: hotspot.sh: doing nmcli radio wifi on" >> /dev/kmsg
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
			ip -6 addr show "$IFNAME"
	
			# Start NTP time server
			if [ -f $BOOT_DIR/candle_no_time_server.txt ]; then
				echo "candle: hotspot.sh: not starting time server"
			elif [ -f /home/pi/candle/time_server.py ]; then

				if ip addr show $IFNAME | grep -q "172.16.$NETID.1"; then
					if ps aux | grep 'python3 /home/pi/candle/time_server.py' | grep -q "172.16.$NETID.1 123"; then
						echo "timeserver is already running"
					else
						echo "starting NTP server"
				
						if iptables -t nat -L -v | grep -q "172.16.$NETID.1:123"; then
							echo "NTP server iptables rule seems to already exist"
						else
							echo "adding NTP server iptables rule"
							iptables -t nat -A PREROUTING -i "$IFNAME" -p udp --dport 123 -j DNAT --to-destination "172.16.$NETID.1:123"
						fi
						python3 /home/pi/candle/time_server.py "172.16.$NETID.1" 123 &
					fi


				else
					echo "ERROR, $IFNAME interface does not have 172.16.$NETID.1 ip address (yet). Cannot start NTP server. ifconfig:"
				fi
				
				echo "active connections right before starting dnsmasq:"
				nmcli connection show --active
				
				
				if nmcli connection show --active | grep -q Candle_hotspot; then
					echo "FINAL STEP: STARTING DNSMASQ"

					#sed -i -E -e "s|127\.0\.1\.1[ \t]+.*|127\.0\.1\.1 \t$hostname|" /home/pi/.webthings/etc/hosts
					if [ -f /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf ]; then
						if cat /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf | grep -q "172.16.$NETID."; then
							echo "local-DNS.conf seems to already have been updated with the current NETID: $NETID"
						else
							echo "local-DNS.conf needs to be updated to use the current NETID: $NETID"
							cat /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf | sed -E "s/172.16.([0-9]+)./172.16.$NETID./g" > /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf.partial
							if [ -f /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf.partial ]; then
								cat /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf.partial | sed -E "s/fd00:([0-9]+)::/fd00:$NETID::/g" > /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf.updated
							fi
							if [ -f /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf.updated ]; then
								if [ -s /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf.updated ]; then
									echo "copying updated local-DNS.conf over the old version"
									cp /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf.updated /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf
								fi
								rm /home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf.updated
							else
								echo "ERROR, home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf.updated did not exist"
								echo "ERROR, home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf.updated did not exist" >> /dev/kmsg
							fi
						fi
					fi
					dnsmasq -k -d --no-daemon --conf-file=/home/pi/.webthings/etc/NetworkManager/dnsmasq.d/local-DNS.conf 1> /dev/null
				fi
				
			fi
	
	
		else
			echo
			echo "hotspot.sh: ERROR, Candle_hotspot was not active (attempt to bring it up failed as expected)"
			echo
		fi

		
	else
		echo "candle: hotspot.sh: WARNING: candle_hotspot.txt vanished, not bringing up interface and dnsmasq" >> /dev/kmsg
		echo "candle: hotspot.sh: WARNING: candle_hotspot.txt vanished, not bringing up interface and dnsmasq" >> /dev/kmsg
		#nmcli connection down candle_hotspot
		sleep 30
		exit 0
	fi
	
	sleep 15
	
	exit 1
	
}





if [ "$IFNAME" == "uap0" ]; then
	
	if ip link show | grep -q "$IFNAME:" ; then
		echo "candle: hotspot.sh: OK, virtual uap0 interface already exists"
		echo "candle: hotspot.sh: OK, virtual uap0 interface already exists" >> /dev/kmsg
	else
		echo "candle: hotspot.sh: creating virtual uap0 interface"
		echo "candle: hotspot.sh: creating virtual uap0 interface" >> /dev/kmsg
		/sbin/iw dev mlan0 interface add uap0 type __ap
		nmcli device set "$IFNAME" managed false
		
	fi

fi














if ip link show | grep -q "$IFNAME:"; then
	
	echo
	echo "candle: hotspot.sh: preparation done.  continueing with interface: $IFNAME"
	#echo "ifconfig $IFNAME:"
	#ifconfig $IFNAME
	echo
	
	# Bring down existing connection
	if nmcli connection show | grep -q 'Candle_hotspot'; then
		echo "candle: hotspot.sh: connection already exists, setting autoconnect to no"
		echo "candle: hotspot.sh: connection already exists, setting autoconnect to no" >> /dev/kmsg
		nmcli connection modify Candle_hotspot connection.autoconnect no
	fi
	if nmcli connection show --active | grep -q Candle_hotspot; then
		echo "candle: hotspot.sh: WARNING, the Candle_hotspot connection is already up. Bringing it down first"
		echo "candle: hotspot.sh: WARNING, the Candle_hotspot connection is already up. Bringing it down first" >> /dev/kmsg
		mcli connection down Candle_hotspot
		sleep 1
	fi
	
	# Bring down the interface
	nmcli device set "$IFNAME" managed false
	ip link set "$IFNAME" down
	
	if ip link show | grep "$IFNAME:" | grep -q "state UP"; then
		echo "candle: hotspot.sh: WARNING, the $IFNAME interface is still up. Forcing it down again using ip"
		echo "candle: hotspot.sh: WARNING, the $IFNAME interface is still up. Forcing it down again using ip" >> /dev/kmsg
		ip link set "$IFNAME" down
		sleep 1
	fi

	# Ensure the interface has the correct IP addresses
	current_ips=$(ip addr show "$IFNAME")
	echo "candle: hotspot.sh: verify current_ips: $current_ips"
	if [[ "$current_ips" == "*$OWN_IP4*" ]]; then
		echo "candle: hotspot.sh: ip4 $OWN_IP4 seems already set for interface $IFNAME"
		echo "candle: hotspot.sh: ip4 $OWN_IP4 seems already set for interface $IFNAME" >> /dev/kmsg
	else
		echo "candle: hotspot.sh: added ip4 $OWN_IP4 to interface $IFNAME"
		echo "candle: hotspot.sh: added ip4 $OWN_IP4 to interface $IFNAME" >> /dev/kmsg
		ip addr add "$OWN_IP4"/24 dev "$IFNAME"
	fi
	if [[ "$current_ips" == "*$OWN_IP6*" ]]; then
		echo "candle: hotspot.sh: ip6 $OWN_IP6 seems already set for interface $IFNAME"
		echo "candle: hotspot.sh: ip6 $OWN_IP6 seems already set for interface $IFNAME" >> /dev/kmsg
	else
		echo "candle: hotspot.sh: added ip6 $OWN_IP6 to interface $IFNAME"
		echo "candle: hotspot.sh: added ip6 $OWN_IP6 to interface $IFNAME" >> /dev/kmsg
		ip -6 addr add "$OWN_IP6"/32 dev "$IFNAME"
	fi
	
	
	
	
	
	
	

	
	

	
	
	#iptables -t nat -L -v

	#if rfkill | grep -q ' blocked '; then
	#	echo "Had to rfkll unblock (2)"
	#	rfkill unblock all
	#	sleep 1
	#fi

	
	

	


	
	#echo
	#echo "ifconfig $IFNAME:"
	#ifconfig "$IFNAME"
	#echo
	
	#if ifconfig $IFNAME | grep -q '172.16.$NETID.1'; then
	#	echo "OK, $IFNAME still has the correct IP address"
	#else
	#	echo "forcing ip address for $IFNAME again"
	#	ip address add 172.16.$NETID.1/24 dev $IFNAME
	#fi	
	
	
	#echo
	#echo "ifconfig $IFNAME:"
	#ifconfig $IFNAME
	#echo
	
	if nmcli connection show | grep -q 'Candle_hotspot'; then
		echo "candle: hotspot.sh: connection already exists"
		echo "candle: hotspot.sh: connection already exists" >> /dev/kmsg
		
		
		
		
		sleep 1
		
		if nmcli connection show --active | grep -q $IFNAME; then
			echo "candle: hotspot.sh: ERROR: connection already exists, and was still active"
			echo "candle: hotspot.sh: ERROR: connection already exists, and was still active" >> /dev/kmsg
			nmcli connection modify Candle_hotspot connection.autoconnect no
			mcli connection down Candle_hotspot
			sleep 1
		fi
		
		nmcli connection modify Candle_hotspot connection.autoconnect no
			

	else
		
		
		#nmcli connection add con-name "Candle_hotspot" \
		#    ifname $IFNAME wifi.mode ap wifi.ssid "$SSID" \
		#	wifi-sec.key-mgmt wpa-psk \
		#    wifi-sec.proto rsn wifi-sec.pairwise ccmp \
		#    wifi-sec.psk "$PASSWORD" \
		#	connection.autoconnect yes
		
		if [[ $PASSWORD =~ ^........+ ]]; then
			
			echo "candle hotspot.sh: Creating initial Candle_hotspot connection with a password"
			echo "candle hotspot.sh: Creating initial Candle_hotspot connection with a password" >> /dev/kmsg
			if [ -f "$BOOT_DIR/developer.txt" ]; then
				echo "candle: hotspot.sh: DEVELOPER: password on new Candle_hotspot connection is: -->$PASSWORD<--"
				echo "candle: hotspot.sh: DEVELOPER: password on new Candle_hotspot connection is: -->$PASSWORD<--" >> /dev/kmsg
			fi
			
			nmcli connection add \
				con-name Candle_hotspot \
				ifname "$IFNAME" \
				type wifi \
				autoconnect no \
				ipv4.method manual ipv4.addresses "172.16.$NETID.1/24" \
				802-11-wireless.band bg \
				802-11-wireless.channel 1 \
				802-11-wireless.mode ap \
				802-11-wireless.ssid "$SSID" \
				802-11-wireless-security.key-mgmt wpa-psk \
				802-11-wireless-security.proto rsn \
				802-11-wireless-security.pairwise ccmp \
				802-11-wireless-security.psk "$PASSWORD" \
				ipv6.method manual ipv6.addresses "fd00:$NETID::1/32"
			
				# 802-11-wireless-security.group ccmp \

			
			
				#wifi-sec.pairwise ccmp \
				# ip link set dev <interface_name> down
		
		else
			
			echo "candle hotspot.sh: Creating initial Candle_hotspot connection without a password"
			echo "candle hotspot.sh: Creating initial Candle_hotspot connection without a password" >> /dev/kmsg
			
			nmcli connection add \
				con-name Candle_hotspot \
				ifname $IFNAME \
				type wifi \
				autoconnect no \
				ipv4.method manual ipv4.addresses "172.16.$NETID.1/24" \
				802-11-wireless.band bg \
				802-11-wireless.channel 1 \
				802-11-wireless.mode ap \
				802-11-wireless.ssid "$SSID" \
				ipv6.method manual ipv6.addresses "fd00:$NETID::1/32"
			
		fi
		
		
		# -999 to 999
		nmcli con modify Candle_hotspot connection.autoconnect-priority 10
		
		# Infinite retries
		nmcli con modify Candle_hotspot connection.autoconnect-retries 0
		
		#nmcli con modify Candle_hotspot wifi-sec.pmf disable
		nmcli con modify Candle_hotspot 802-11-wireless-security.pmf optional
		
		# Mac OS will apparently only connect if Fast PSK is enabled
		# https://www.networkmanager.dev/docs/api/latest/settings-802-11-wireless-security.html
		nmcli con modify Candle_hotspot 802-11-wireless-security.fils 2
		
		nmcli connection modify Candle_hotspot ipv4.gateway "172.16.$NETID.1" 
		nmcli connection modify Candle_hotspot ipv4.dns "172.16.$NETID.1" ipv4.dns-priority 1000
		
		# The hotspot is not the default route out of the network
		nmcli connection modify Candle_hotspot ipv4.never-default true
	
		#nmcli connection modify Candle_hotspot ipv6.addresses 'fd00::/8' ipv6.method manual 
		nmcli connection modify Candle_hotspot ipv6.gateway "fd00:$NETID::1"
		nmcli connection modify Candle_hotspot ipv6.dns "fd00:$NETID::1" ipv6.dns-priority 1000
		nmcli connection modify Candle_hotspot ipv6.never-default true
		
		if [ -f $BOOT_DIR/developer.txt ]; then
			echo ""
			echo ""
			echo "full initial Candle_hotspot: "
			nmcli connection show Candle_hotspot | cat
			echo ""
			echo ""
		fi

	fi



	#
	#  UPDATE HOTSPOT IF NEEDED
	#
	
	# The Candle_hotspot connection should now exist
	if nmcli connection show | grep -q Candle_hotspot; then


		connection_interface_name=$(nmcli connection show Candle_hotspot | grep 'connection.interface-name:' | sed 's/connection.interface-name://' | xargs)
		echo "candle: hotspot.sh: verify interface: -->$IFNAME<-- -vs- -->$connection_interface_name<--"
		
		
		# Update interface name
		if [ "$IFNAME" == "$connection_interface_name" ]; then
			echo "candle: hotspot.sh: OK, the Candle_hotspot connection has the correct interface set: $IFNAME"
			echo "candle: hotspot.sh: OK, the Candle_hotspot connection has the correct interface set: $IFNAME" >> /dev/kmsg
		else
			echo "candle: hotspot.sh: WARNING, the Candle_hotspot connection does not have the correct interface set:  old: $connection_interface_name -> new: $IFNAME"
			echo "candle: hotspot.sh: WARNING, the Candle_hotspot connection does not have the correct interface set:  old: $connection_interface_name -> new: $IFNAME" >> /dev/kmsg
			nmcli con modify Candle_hotspot connection.interface-name "$IFNAME"
		fi
		
		
		# Update power save
		
		if [ -f $BOOT_DIR/candle_wifi_power_save.txt ]; then
			if nmcli c s Candle_hotspot | grep '802-11-wireless.powersave' | grep -q 'disable'; then
				echo "candle: hotspot.sh: changing Candle_hotspot 802-11-wireless.powersave setting to disabled"
				echo "candle: hotspot.sh: changing Candle_hotspot 802-11-wireless.powersave setting to disabled" >> /dev/kmsg
				nmcli connection modify Candle_hotspot 802-11-wireless.powersave enable
				iw "$IFNAME" set power_save on
			fi
		else
			if nmcli c s Candle_hotspot | grep '802-11-wireless.powersave' | grep -q 'enable'; then
				echo "candle: hotspot.sh: changing Candle_hotspot 802-11-wireless.powersave setting to enabled"
				echo "candle: hotspot.sh: changing Candle_hotspot 802-11-wireless.powersave setting to enabled" >> /dev/kmsg
				nmcli connection modify Candle_hotspot 802-11-wireless.powersave disable
				iw "$IFNAME" set power_save off
			fi
		fi
		
		

		if [ "$IFNAME" == uap0 ]; then
			if [ -n "$ZEROMAC" ]; then
				
				# Not setting the Candle_hotspot connection's mac at the moment
				current_nmcli_mac=$(nmcli c s Candle_hotspot | grep '802-11-wireless.mac-address:' | sed 's/802-11-wireless.mac-address://' | xargs)
				echo "candle: hotspot.sh: current_nmcli_mac: $current_nmcli_mac"
				echo "candle: hotspot.sh: current_nmcli_mac: $current_nmcli_mac" >> /dev/kmsg
				if [[ $current_nmcli_mac = "*$ZEROMAC*" ]]
				then
				    echo "OK, Candle_hotspot connection's MAC is already the correct zeromac:"
					echo "ZEROMAC: $ZEROMAC"
					echo "$current_nmcli_mac"
					echo "candle: hotspot.sh: mac is already the correct zeromac: $ZEROMAC"
					echo "candle: hotspot.sh: mac is already the correct zeromac: $ZEROMAC" >> /dev/kmsg
				
				else
					#nmcli con modify Candle_hotspot wifi.mac-address "$ZEROMAC"
					nmcli con modify Candle_hotspot wifi.cloned-mac-address "$ZEROMAC"
					echo "candle: hotspot.sh: had to set Candle_hotspot mac to the correct zeromac: $ZEROMAC (blocked)"
					echo "candle: hotspot.sh: had to set Candle_hotspot mac to the correct zeromac: $ZEROMAC (blocked)" >> /dev/kmsg
				fi
			
				if iw dev uap0 info | grep "addr " | grep -q "$ZEROMAC"; then
					echo "candle: hotspot.sh: OK, uap0's MAC is already the correct zeromac: $ZEROMAC"
					echo "candle: hotspot.sh: OK, uap0's MAC is already the correct zeromac: $ZEROMAC" >> /dev/kmsg
					iw dev uap0 info
				else
					echo "candle: hotspot.sh: WARNING, setting uap0's MAC to the correct zeromac: $ZEROMAC"
					echo "candle: hotspot.sh: WARNING, setting uap0's MAC to the correct zeromac: $ZEROMAC" >> /dev/kmsg
					ip link set dev uap0 address "$ZEROMAC"
					iw dev uap0 info
				fi
			fi
		fi

		# TODO: check if there is a normal wireless connection too, and if so, follow that connection's band (5G / 2.4G) to keep the radio happy
		# TODO: maybe also explain that to the user, or automatically switch to a 5G/2.4G version of the SSID if available? That may be a security risk though..
		
		current_nmcli_band=$(nmcli c s Candle_hotspot | grep '802-11-wireless.band:' | sed 's/802-11-wireless.band://' | xargs)
		echo "candle: hotspot.sh: verify current_nmcli_band: -->$current_nmcli_band<--"
		if [ -f "$BOOT_DIR/candle_hotspot_5G.txt" ]; then
			if [ "$current_nmcli_band" == "a" ]; then
				echo "candle: hotspot.sh: connection is already set to the correct band: $current_nmcli_band"
				echo "candle: hotspot.sh: connection is already set to the correct band: $current_nmcli_band" >> /dev/kmsg
				# TODO: also ensure correct channel?
			else
				echo "candle: hotspot.sh: changing wifi channel to 44 (5Ghz)"
				echo "candle: hotspot.sh: changing wifi channel to 44 (5Ghz)" >> /dev/kmsg
				nmcli con modify Candle_hotspot 802-11-wireless.band a 802-11-wireless.channel 44
			fi
			
		else
			if [ "$current_nmcli_band" == "bg" ]; then
				echo "candle: hotspot.sh: connection is already set to the correct band: $current_nmcli_band"
				echo "candle: hotspot.sh: connection is already set to the correct band: $current_nmcli_band" >> /dev/kmsg
				# TODO: also ensure correct channel?
			else
				echo "candle: hotspot.sh: changing wifi channel to 1 (2.4Ghz)"
				echo "candle: hotspot.sh: changing wifi channel to 1 (2.4Ghz)" >> /dev/kmsg
				nmcli con modify Candle_hotspot 802-11-wireless.band bg 802-11-wireless.channel 1
			fi
		fi

		

		
		#if [[ $PASSWORD =~ ^........+ ]]; then
		#	echo "Setting hotspot password"
		
		#	nmcli con modify Candle_hotspot \
		#		802-11-wireless-security.key-mgmt wpa-psk \
		#		802-11-wireless-security.proto rsn \
		#		802-11-wireless-security.group ccmp \
		#		802-11-wireless-security.pairwise ccmp \
		#		802-11-wireless-security.psk "$PASSWORD"
				

				# wifi-sec.pairwise ccmp \
		
			#nmcli dev wifi hotspot ifname $IFNAME ssid "$SSID" password "$PASSWORD" 
			#sleep 1
			#echo "Basic hotspot command run, with basic security. Did it work?"
		#	echo
		#	echo "nmcli connection show --active:"
		#	nmcli connection show --active
		#	echo
		
		
		
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
	
		#else
		#	#nmcli con modify Candle_hotspot wifi-sec.key-mgmt sae wifi-sec.psk ""
		#	nmcli con modify Candle_hotspot \
		#		802-11-wireless-security.key-mgmt "" \
		#		802-11-wireless-security.proto "" \
		#		802-11-wireless-security.group "" \
		#		802-11-wireless-security.pairwise "" \
		#		802-11-wireless-security.psk ""
		#	echo "Warning, creating open hotspot without any security"
		#	echo "candle hotspot.sh: Warning, creating open hotspot without any security" >> /dev/kmng
		#	#nmcli dev wifi hotspot ifname $IFNAME ssid "$SSID"
		#fi

	
	

		# Protected Management Frames can lead to connectivity issues with some WiFi devices
		current_nmcli_pmf=$(nmcli c s Candle_hotspot | grep '802-11-wireless-security.pmf:' | sed 's/802-11-wireless-security.pmf://' | xargs)
		echo "candle: hotspot.sh: verify current_nmcli_pmf: -->$current_nmcli_pmf<--"
		
		if [ -f $BOOT_DIR/candle_hotspot_disable_wifi_pmf.txt ]; then
			if [[ $current_nmcli_pmf = "*disable*" ]]; then
				echo "candle: hotspot.sh: spotted candle_disable_wifi_pmf.txt -> protected management frames already set to disabled"
				echo "candle: hotspot.sh: spotted candle_disable_wifi_pmf.txt -> protected management frames already set to disabled" >> /dev/kmsg
			else
				echo "candle: hotspot.sh: spotted candle_disable_wifi_pmf.txt -> disabling wifi protected management frames"
				echo "candle: hotspot.sh: spotted candle_disable_wifi_pmf.txt -> disabling wifi protected management frames" >> /dev/kmsg
				nmcli con modify Candle_hotspot 802-11-wireless-security.pmf disable
			fi
		else
			if [[ $current_nmcli_pmf = "*disable*" ]]; then
				echo "candle: hotspot.sh: seting wifi protected management frames back to optional"
				echo "candle: hotspot.sh: seting wifi protected management frames back to optional" >> /dev/kmsg
				nmcli con modify Candle_hotspot 802-11-wireless-security.pmf optional
			fi
		fi
		
		
		
		


		

		echo
		echo
		echo "HERE WE GO, turning on the hotspot"
		echo "candle: hotspot.sh: using interface: $IFNAME" >> /dev/kmsg
		echo
		echo


		#if nmcli radio wifi | grep -q 'disabled'; then
		#	echo "hotspot.sh: WARNING, had to bring up wifi radio (1)"
		#	echo "candle: hotspot.sh: WARNING, had to bring up wifi radio (1)" >> /dev/kmsg
		#	nmcli radio wifi on
		#	sleep 1
		#fi

		rfkill unblock
		
		if ip link show | grep -q "$IFNAME:"; then
			
			
			if ip link show "$IFNAME" | grep -q 'state DOWN'; then
				echo "candle: hotspot.sh: interface $IFNAME was down, forcing to UP using ip"
				echo "candle: hotspot.sh: interface $IFNAME was down, forcing to UP using ip" >> /dev/kmsg
				ip link set "$IFNAME" up
				sleep 1
			else
				echo "candle: hotspot.sh: OK, interface $IFNAME was already brought up by NetworkManager"
				echo "candle: hotspot.sh: OK, interface $IFNAME was already brought up by NetworkManager" >> /dev/kmsg
			fi
			
			
			if nmcli device status | grep "$IFNAME" | grep -q 'unmanaged' ; then
				echo "candle: hotspot.sh: setting interface $IFNAME to managed"
				echo "candle: hotspot.sh: setting interface $IFNAME to managed" >> /dev/kmsg
				nmcli device set "$IFNAME" managed true
				sleep 1
			else
				echo "candle: hotspot.sh: unexpectedly, interface $IFNAME was already managed by NetworkManager"
				echo "candle: hotspot.sh: unexpectedly, interface $IFNAME was already managed by NetworkManager" >> /dev/kmsg
			fi
			
			
			if ip link show "$IFNAME" | grep -q DORMANT; then
				echo "candle: hotspot.sh: $IFNAME was in DORMANT mode, setting to DEFAULT instead"
				echo "candle: hotspot.sh: $IFNAME was in DORMANT mode, setting to DEFAULT instead" >> /dev/kmsg
				ip link set $IFNAME mode default
				sleep 1
			else
				echo "candle: hotspot.sh: OK, interface $IFNAME was not dormant"
				echo "candle: hotspot.sh: OK, interface $IFNAME was not dormant" >> /dev/kmsg
			fi
			
		else
			echo "candle: hotspot.sh: ERROR, interface $IFNAME was somehow missing from ip link show:"
			ip link show
			echo "candle: hotspot.sh: ERROR, interface $IFNAME was somehow missing from ip link show:" >> /dev/kmsg
			echo "candle: hotspot.sh: $(ip link show)" >> /dev/kmsg
		fi
		
		
		
		

		# Make sure no other connection is using the $IFNAME interface
		# nmcli dev dis $IFNAME
	
		if nmcli connection show --active | grep -q $IFNAME; then
			echo "candle: hotspot.sh: That was quick, the Candle_hotspot is already active"
			echo "candle: hotspot.sh: That was quick, the Candle_hotspot is already active" >> /dev/kmsg
			start_dnsmasq
			
		else
			if ip link show | grep -q "$IFNAME:"; then
				
				
				HOTSPOT_UP_OUTPUT=$(nmcli con up Candle_hotspot)
				echo " nmcli con up Candle_hotspot OUTPUT: $HOTSPOT_UP_OUTPUT"
				echo "candle: hotspot.sh: nmcli con up Candle_hotspot OUTPUT: $HOTSPOT_UP_OUTPUT" >> /dev/kmsg
		
				if echo "$HOTSPOT_UP_OUTPUT" | grep -q "successfully activated" ; then
					sleep 1
					if nmcli connection show --active | grep -q Candle_hotspot; then
						echo "candle: hotspot.sh: OK, Candle_hotspot activated succcesfully. Calling start_dnsmasq."
						echo "candle: hotspot.sh: OK, Candle_hotspot activated succcesfully. Calling start_dnsmasq." >> /dev/kmsg
						start_dnsmasq
					else
						echo "candle: hotspot.sh: ERROR, Candle_hotspot seemed to be succesfully actvated, but is not in active connections list"
						echo "candle: hotspot.sh: ERROR, Candle_hotspot seemed to be succesfully actvated, but is not in active connections list" >> /dev/kmsg
						sleep 10
					fi
				else
					sleep 1
					if nmcli connection show --active | grep -q Candle_hotspot; then
						echo "candle: hotspot.sh: OK, after a little pridding the Candle_hotspot is now up. Calling start_dnsmasq."
						echo "candle: hotspot.sh: OK, after a little pridding the Candle_hotspot is now up. Calling start_dnsmasq." >> /dev/kmsg
						start_dnsmasq
					else
						echo "candle: hotspot.sh: ERROR: bringing Candle_hotspot connection up really failed"
						echo "candle: hotspot.sh: ERROR: bringing Candle_hotspot connection up really failed" >> /dev/kmsg
						nmcli connection show
						sleep 10
					fi
				fi
			else
				echo "candle: hotspot.sh: ERROR, interface $IFNAME has vanished"
				echo "candle: hotspot.sh: ERROR, interface $IFNAME has vanished" >> /dev/kmsg
				sleep 10
				
			fi
			
		fi
		
	else
		echo "candle: hotspot.sh: ERROR, failed to create Candle_hotspot connection"
		echo "candle: hotspot.sh: ERROR, failed to create Candle_hotspot connection" >> /dev/kmsg

		sleep 10
	fi
	

else
	echo "candle: hotspot.sh: ERROR, missing interface $IFNAME after it was just created"
	echo "candle: hotspot.sh: ERROR, missing interface $IFNAME after it was just created" >> /dev/kmsg
	sleep 10
fi

echo "Sleeping 15 seconds..."
sleep 5
echo "zzz"
sleep 5
echo "zzz"
sleep 5
echo "Sleeping 15 seconds done"

echo "candle: hotspot.sh: $(date) - Stop"
echo "candle: hotspot.sh: $(date) - Stop" >> /dev/kmsg

exit 0
