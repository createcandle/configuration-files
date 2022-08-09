
The Candle 2.0 disk image has three partitions. 
- The first is /boot
- The second has the main OS and the Candle Controller.
- The third partition has user data, as well as some settings.

The second partition is set to read-only through an overlay + ramdisk. To make this partition writeable, type `rw`. Type `ro` to set it back to read-only mode.

More details about files you can place in /boot to trigger certain things can be found in /boot/readme.txt


Learn more at:

https://www.candlesmarthome.com
