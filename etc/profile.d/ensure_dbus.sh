echo ""
echo "__CHECK BEFORE:__"
declare -p | grep DBUS

if [ -z "${DBUS_SESSION_BUS_PID}" ] && [ -e "/var/run/dbus/sessionbus.pid" ]; then
	DBUS_SESSION_BUS_PID=$(cat /var/run/dbus/sessionbus.pid)
fi
if [ -z "${DBUS_SESSION_BUS_ADDRESS}" ] && [ -e "/var/run/dbus/sessionbus.address" ]; then
	DBUS_SESSION_BUS_ADDRESS=$(cat /var/run/dbus/sessionbus.address)
fi




if [ -z "$XDG_RUNTIME_DIR" ]; then
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

# start the dbus as session bus and save the environment vars
#if [ -z ${DBUS_SESSION_BUS_PID+x} ]; then
if [ -z "${DBUS_SESSION_BUS_PID}" ]; then
  echo ensure_dbus: starting new session dbus

  eval $(dbus-launch --sh-syntax)

  echo "--eval done--"
  echo ""
  echo "DBUS_SESSION_BUS_PID: $DBUS_SESSION_BUS_PID"
  echo "DBUS_SESSION_BUS_ADDRESS: $DBUS_SESSION_BUS_ADDRESS"
  echo ""
  echo "--check done--"
  echo ""
  #echo "${DBUS_SESSION_BUS_PID}">/var/run/dbus/sessionbus.pid
  if [ -n "${DBUS_SESSION_BUS_PID}" ]; then
    echo "OK, DBUS_SESSION_BUS_PID was set: $DBUS_SESSION_BUS_PID"
  	echo "${DBUS_SESSION_BUS_PID}" | sudo tee /var/run/dbus/sessionbus.pid
  else
    echo "ERROR, DBUS_SESSION_BUS_PID was empty!: -->$DBUS_SESSION_BUS_PID<--"
  fi
	
  #echo "${DBUS_SESSION_BUS_ADDRESS}">/var/run/dbus/sessionbus.address
  if [ -n "${DBUS_SESSION_BUS_ADDRESS}" ]; then
    echo "OK, DBUS_SESSION_BUS_ADDRESS was set: $DBUS_SESSION_BUS_ADDRESS"
    echo "${DBUS_SESSION_BUS_ADDRESS}" | sudo tee /var/run/dbus/sessionbus.address
  else
    echo "ERROR, DBUS_SESSION_BUS_ADDRESS was empty!: -->$DBUS_SESSION_BUS_ADDRESS<--"
  fi
  #echo ensure_dbus: session dbus now runs at pid="${DBUS_SESSION_BUS_PID}"
  #echo "ensure_dbus: session dbus now runs at pid=-->$DBUS_SESSION_BUS_PID<--"
  
else
  echo "ensure_dbus: session dbus already runs at pid=-->$DBUS_SESSION_BUS_PID<--"
fi

# show all varibles:
echo ""
echo "__CHECK AFTER:__"
declare -p | grep DBUS
