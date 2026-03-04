#!/bin/bash

if [ -n "$XDG_RUNTIME_DIR" ] ; then
  export XDG_RUNTIME_DIR=/run/user/$(id -u)
fi

if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] ; then
  SESSION_FILE=$(ls -tp /home/pi/.dbus/session-bus | grep -v /$ | head -1)
  if ps aux | grep -q '/dbus-daemon'; then
    if [ -n "$SESSION_FILE" ] && [ -f "/home/pi/.dbus/session-bus/$SESSION_FILE" ]; then
      source "/home/pi/.dbus/session-bus/$SESSION_FILE"
    fi
  fi
fi

if [ -n "$DISPLAY"] ; then
  export DISPLAY=:0
fi

export CANDLE=COOL
