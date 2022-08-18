#!/bin/bash
set +e

#/bin/echo "in late" | sudo tee -a /dev/kmsg
echo "In late" >> /dev/kmsg

# Do aditional checks for missing files, and restore them if possible.
if [ -d /home/pi/candle/configuration-files-backup ]; then
    rsync --ignore-existing -vr /home/pi/candle/configuration-files-backup/* /
fi
