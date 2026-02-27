#!/bin/bash

is_1a=$(i2cdetect -y  1 0x1a 0x1a | egrep "(1a|UU)" | awk '{print $2}')
is_35=$(i2cdetect -y  1 0x35 0x35 | egrep "(35|UU)" | awk '{print $2}')
is_3b=$(i2cdetect -y  1 0x3b 0x3b | egrep "(3b|UU)" | awk '{print $2}')

echo "respeaker card detections:"
echo "1 $is_1a"
echo "2 $is_35"
echo "3 $is_3b"
echo

if [ "x${is_1a}" != "x" ] && [ "x${is_35}" == "x" ] ; then
  echo "found 2mic"
  exit 0
elif [ "x${is_3b}" != "x" ] && [ "x${is_35}" == "x" ] ; then
  echo "found 4mic"
  exit 0
elif [ "x${is_3b}" != "x" ] && [ "x${is_35}" != "x" ] ; then
  echo "found 6mic"
  exit 0
else
  echo "no respeaker card detected"
  exit 1
fi
