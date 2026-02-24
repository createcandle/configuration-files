# Candle

if [ -e "/var/run/dbus/sessionbus.pid" ];then
	DBUS_SESSION_BUS_PID=`cat /var/run/dbus/sessionbus.pid`
fi
if [ -e "/var/run/dbus/sessionbus.address" ];then
	DBUS_SESSION_BUS_ADDRESS=`cat /var/run/dbus/sessionbus.address`
fi
# start the dbus as session bus and save the enviroment vars
if [ -z ${DBUS_SESSION_BUS_PID+x} ];then
  echo ensure_dbus: starting session dbus
  #eval "export $(/usr/bin/dbus-launch)"
  /usr/bin/dbus-launch | while read line; do
    echo "ensure_dbus: exporting: $line"
    export "$line"
  done
  #echo "${DBUS_SESSION_BUS_PID}">/var/run/dbus/sessionbus.pid
  echo "${DBUS_SESSION_BUS_PID}" | sudo tee /var/run/dbus/sessionbus.pid
  #echo "${DBUS_SESSION_BUS_ADDRESS}">/var/run/dbus/sessionbus.address
  echo "${DBUS_SESSION_BUS_ADDRESS}" | sudo tee /var/run/dbus/sessionbus.address
  echo ensure_dbus: session dbus now runs at pid="${DBUS_SESSION_BUS_PID}"
else
  echo ensure_dbus: session dbus already runs at pid="${DBUS_SESSION_BUS_PID}"
fi

if [[ -z "$XDG_RUNTIME_DIR" ]]; then
  XDG_RUNTIME_DIR="/run/user/$(id -u)"
  echo ensure_dbus: had to create XDG_RUNTIME_DIR, it is now: "${XDG_RUNTIME_DIR}"
fi
#if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
#  DBUS_SESSION_BUS_ADDRESS=$(echo $DBUS_SESSION_BUS_ADDRESS)/bus
#fi

if [[ -z "$DISPLAY" ]]; then
  export DISPLAY=$HOSTNAME:0.0
  echo ensure_dbus: had to create DISPLAY, it is now: "${DISPLAY}"
fi
