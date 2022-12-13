
The Candle 2.0 disk image has multiple partitions. 
- The first is /boot
- The second has the main OS and the Candle Controller.
- The third partition is for a factory restore/upgrade system that downloads the latest disk image and partially writes it to disk.
- The fourth has user data, as well as some settings.

The second partition is set to read-only through an overlay + ramdisk. To make this partition writeable, type `rw`. Now any changes you make under /ro will be kept. Type `ro` to go back to read-only mode.

More details about files you can place in /boot to trigger certain things can be found in /boot/readme.txt


Learn more at:

https://www.candlesmarthome.com
