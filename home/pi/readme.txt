Hey there! Nice to see you here.

To keep SSH enabled after reboots do:
sudo touch /boot/firmware/candle_ssh.txt


The readme in the boot/firmware folder has most details. But for now what you may like to know is this:

The Candle 2.0 disk image has multiple partitions. 
- The first is /boot
- The second has the main OS and the Candle Controller.
- The third partition is for a factory restore/upgrade system that downloads the latest disk image and partially writes it to disk.
- The fourth has user data, as well as various settings. It is mounted at ~/.webthings.

The second partition is set to read-only through an overlay + ramdisk. To make this partition briefly writeable, type `rw`. Now any changes you make under /ro will be kept. Type `ro` to go back to read-only mode. More practical is to do:
sudo touch /boot/firmware/candle_rw_keep.txt

The controller software itself can be found in ~/webthings (without the dot). It can be manually run through:
~/webthings/gateway/run-app.sh

You can restart the controller with:
sudo systemctl restart webthings-gateway.service

The internal log can be found here:
tail -f -n100 ~/.webthings/log/run-app.log

If you would like to make the entire home directory available through Samba, this might be useful:
curl -sSL www.candlesmarthome.com/tools/samba.txt | sudo bash

Lots and lots of details about the system can be found through:
~/candle/debug.sh

If you want to modify an addon, make sure to add a .git directory to its base folder. Then the integrity security checks will be disabled for that addon. E.g.
mkdir -p ~/.webthings/addons/candleappstore/.git

Learn more at:

https://www.candlesmarthome.com
