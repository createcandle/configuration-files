# CANDLE CONTROLLER
This is the disk of a Candle Controller. Learn more at www.candlesmarthome.com


# SSH ACCESS
If you would like to have more control over your device, go to the settings page and click on the settings gear icon 4 times. You will then see the developer options. You can then enable SSH and login with "pi" and "smarthome" using SSH (ssh pi@candle.local). Alternatively, add a file called SSH to this directory, and SSH should be enabled after a reboot. Alternatively, add a file called SSH to this directory, and SSH should be enabled after a reboot. After you reboot again, SSH will be disabled again because the sytem partition is read-only.


# DISABLING READ ONLY MODE
Candle has two big partitions, a read-only one for the system, and a writeable one for user data. The system partition uses an overlay. You can disable the read-only mode of the system partition in a number of ways:

1. Call "rw" or "ro" to set the /ro directory to RW or RW mode respectively. This allows for quick changes to the real underlying filesystem, which can be found under /ro. Making changes outside of /ro will still not stick.
2. Create a file called "candle_rw_once.txt" in the same folder as this readme file, and then reboot. This will completely remove the overlay. This file will automatically be deleted, so after another reboot the system will be back in read-only mode. When using this option the /ro directory will not exist, and you can change all parts of the filesystem. Candle uses this for more serious changes, such as a complete system update.
3. Create a file called "candle_rw_keep.txt" in the same folder as this readme file, and then reboot. This is like option 2, but will keep the system in RW mode as long as the file is there.


# DEBUGGING
If you would like to see information about the boot process on an attached display, you can replace the "cmdline.txt" file with the debug version of that file. Rename the current "cmdline.txt" file to something else first (e.g. "cmdline-original"), so you can restore it later.


# RECOVERY
If you are having a lot of trouble, you can try using the recovery version of cmdline.txt. It will boot the system into a bash shell. Note that the filesystem will be in read-only mode, but you can remount it if you need to make changes:

sudo mount -o remount,rw /dev/mmcblk0p2 /


# TOGGLES
The existence of these files can also toggle certain things:

candle_kiosk.txt 		# the URL inside this file will be shown in the browser. If it's empty the kiosk browser will not load
keep_browser_session.txt 	# Don't delete browser sessions on boot
cloudless.txt 			# experimental, to launch the gateway even if there is no network at all
nohotspot.txt 			# aborts hotspot launch. Useful if that feature somehow causes trouble.
hide_mouse_pointer.txt 		# hides the mouse pointer on the HDMI output
rotate180.txt 			# Rotates the display 180 degrees
exhibit_mode.txt		# Disables installing and uninstalling addons.
do_not_use_repeaker_hat.txt 	# will stop ReSpeaker hat drivers from being loaded at boot
disable_wifi_power_save.txt 	# if present, wifi power saving feature will be disabled. This might improve some connections.

# Factory reset related:
keep_z2m.txt 			# keep Zigbee2MQTT settings on factorry reset
keep_bluetooth.txt 		# Keep paired bluetooth devices on factory reset
developer.txt 			# Enables logging. Will also cause a factory reset to write zeros to empty space, so as to prepare for creating a disk image

# Indicators
candle_swap_enabled.txt 	# on lower memory systems (Pi Zero 2) this file indicates that on the first run the swap file was enabled. Normally it's disabled, a>
candle_first_run_complete.txt 	# this file appears after the first boot. It indicates that and new SSH keys were generated
candle_hardware_clock.txt 	# this file is present if the hardware clock module is detected and enabled
