#!/bin/bash

# Check if script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root (use sudo)"
  exit
fi


echo "--installing samba"
apt-get update
echo "samba-common samba-common/workgroup string  WORKGROUP" | debconf-set-selections
echo "samba-common samba-common/dhcp boolean true" | debconf-set-selections
echo "samba-common samba-common/do_debconf boolean true" | debconf-set-selections
apt-get install samba samba-common-bin -y



isInFile2=$(cat /etc/samba/smb.conf | grep -c "Candle")
if [ $isInFile2 -eq 0 ]
then
	echo '' >> /etc/samba/smb.conf
	echo '#Candle' >> /etc/samba/smb.conf
	echo '[pi]' >> /etc/samba/smb.conf
	echo 'Comment = Pi shared folder' >> /etc/samba/smb.conf
	echo 'Path = /home/pi' >> /etc/samba/smb.conf
	echo 'Browseable = yes' >> /etc/samba/smb.conf
	echo 'Writeable = Yes' >> /etc/samba/smb.conf
	echo 'only guest = no' >> /etc/samba/smb.conf
	echo 'create mask = 0777' >> /etc/samba/smb.conf
	echo 'directory mask = 0777' >> /etc/samba/smb.conf
	echo 'Public = yes' >> /etc/samba/smb.conf
	echo 'Guest ok = yes' >> /etc/samba/smb.conf

else
    echo "- /etc/samba/smb.conf was already modified"
fi

printf "smarthome\nsmarthome\n" | smbpasswd -a -s pi

#chmod -R 777 /home/pi/.webthings/addons
systemctl restart smbd

echo "samba has been installed."
echo " "
echo "user: pi"
echo "pass: smarthome"
echo " "
