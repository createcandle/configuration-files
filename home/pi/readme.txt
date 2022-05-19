
This disk image has three partitions. 
- The first is /boot
- The second has the main OS and the Webthings Gateway.
- The third partition has user data, as well as some settings.

The second partition is set to read-only through an overlay + ramdisk. To make this partition writeable:
- run "sudo raspi-config"
- under 'performance' select overlay and disable it. Then reboot.

Important files:

/etc/rc.local
/etc/X11/openbox/autostart

There are also a number of services start start with 'candle'.

More details about files you can place in /boot to trigger certain things can be found in /boot/readme.txt
The existence of these files can also toggle certain things:
