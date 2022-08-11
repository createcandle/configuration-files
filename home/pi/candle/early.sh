#!/bin/bash
set +e

# This runs even before rc.local

echo "in Candle early"
echo "in Candle early. Fixing hostname." >> /dev/kmsg


# Fix hostname
/usr/bin/hostname -F /home/pi/.webthings/etc/hostname
systemctl restart avahi-daemon.service


# Add firewall rules
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


# Handle forced restore of rc.local
if [ -f /boot/restore_boot_backup.txt ];
then
  rm /boot/restore_boot_backup.txt
  if [ -f /etc/rc.local.bak ];
  then
    cp /etc/rc.local.bak /etc/rc.local
    echo "$(date) - forced restored boot backup" >> /boot/candle.log
    echo "$(date) - forced restored boot backup" >> /dev/kmsg

  else
    echo "$(date) - forced restoring boot backup: no backup found" >> /boot/candle.log
    echo "$(date) - forced restoring boot backup: no backup found" >> /dev/kmsg
  fi
fi


# Handle forced restore of Candle Controller backup
if [ -f /boot/restore_controller_backup.txt ];
then
  rm /boot/restore_controller_backup.txt
  if [ -f /home/pi/controller_backup.tar ];
  then
    cd /home/pi || exit
    echo "$(date) - forced restoring controller backup..." >> /boot/candle.log
    echo "$(date) - forced restoring controller backup..." >> /dev/kmsg
    rm -rf /home/pi/webthings
    tar -xvf controller_backup.tar
    echo "$(date) - forced restoring controller backup done" >> /boot/candle.log
    echo "$(date) - forced restoring controller backup done" >> /dev/kmsg
  else
    echo "$(date) - forced restoring controller backup: no backup found" >> /boot/candle.log
    echo "$(date) - forced restoring controller backup: no backup found" >> /dev/kmsg
  fi
fi


# If the user wants a forced rebuild, do that.
elif [ -f /boot/force_controller_rebuild.txt ];
then
  rm /boot/force_controller_rebuild.txt
  cd /home/pi || exit
  echo "$(date) - starting forced controller regeneration..." >> /boot/candle.log
  echo "$(date) - starting forced controller regeneration..." >> /dev/kmsg
  wget https://raw.githubusercontent.com/createcandle/install-scripts/main/install_candle_controller.sh
  chmod +x ./install_candle_controller.sh
  sudo -u pi ./install_candle_controller.sh
  rm ./install_candle_controller.sh
  echo "$(date) - forced controller regeneration done" >> /boot/candle.log
  echo "$(date) - forced controller regeneration done" >> /dev/kmsg
fi






