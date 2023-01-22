#!/bin/bash

# Fix avahi sometimes appending "-2" or "-3" to its hostname is a Bonjour server is repeating it on the network, causing it to think the name already exists
HOSTNAME=$(hostname)
AVAHI_HOSTNAME=$(systemctl status avahi-daemon.service | grep "avahi-daemon: running \[" | cut -d "[" -f2| cut -d "]" -f1 | cut -d. -f1) 
if [ "$AVAHI_HOSTNAME" != "$HOSTNAME" ]; then
     echo "Hostname mismatch (hostname:$HOSTNAME, avahi:$AVAHI_HOSTNAME). Restarting avahi."
     systemctl restart avahi-daemon.service
fi

# keep the syslog smaller than 2 megabytes
SYSLOG_FILESIZE=$(stat --printf="%s" /var/log/syslog)
if [ "$SYSLOG_FILESIZE" -gt 2000000 ]; then
    echo "$(tail -200 /var/log/syslog)" > /var/log/syslog
fi
