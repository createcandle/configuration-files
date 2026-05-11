#!/bin/bash

if [ -n "$XDG_RUNTIME_DIR" ] ; then
  export XDG_RUNTIME_DIR=/run/user/$(id -u)
fi

if [ -n "$DISPLAY" ] ; then
  export DISPLAY=:0
fi

export CANDLE=COOL
