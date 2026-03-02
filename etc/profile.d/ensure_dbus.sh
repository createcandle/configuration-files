#!/bin/bash

if [ -n "$DBUS_SESSION_BUS_ADDRESS"] ; then
  SESSION_FILE=$(ls -tp /home/pi/.dbus/session-bus | grep -v /$ | head -1)
  if ps aux | grep -q '/dbus-daemon' && [ -n "$SESSION_FILE" ] && [ -f "/home/pi/.dbus/session-bus/$SESSION_FILE" ]; then
    source "/home/pi/.dbus/session-bus/$SESSION_FILE"
  fi
fi

if [ -n "$DISPLAY"] ; then
	export DISPLAY=:0
fi
