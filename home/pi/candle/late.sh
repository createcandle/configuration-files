#!/bin/bash
set +e

#/bin/echo "in late" | sudo tee -a /dev/kmsg
echo "In late" >> /dev/kmsg

# Do aditional checks for missing files, and restore them if possible.
if [ -d /home/pi/candle/configuration-files-backup ]; then
    if rsync --ignore-existing --dry-run -vri /home/pi/candle/configuration-files-backup/* / | grep -q  +++++; then
        if [ -d /ro ]; then
            sudo mount -o remount,ro /rw
        fi
        echo "Candle: late: fixing missing"
        rsync --ignore-existing -vr /home/pi/candle/configuration-files-backup/* / >> /dev/kmsg
        if [ -d /ro ]; then
            sudo mount -o remount,ro /ro
        fi
    fi
else
    echo "configuration files backup dir does not exist"
fi
