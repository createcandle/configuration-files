# CANDLE CONTROLLER
This is the disk of a Candle Controller. Learn more at www.candlesmarthome.com

If you are having trouble, visit: 
www.candlesmarthome.com/troubleshooting

To attempt to create an emergency backup, place a textfile called "candle_make_emergency_backup.txt" on the SD card. Then boot the Candle Controller again with the SD card, and after a minute or two, turn it off again. You should now hopefully find a backup file on the SD card.

- Output to HDMI is normally only enabled for systems with more than 1Gb of memory, but this can be forced. See below.



The information below is for advanced users.


# SSH ACCESS
If you would like to have more control over your device, go to the settings page and click on the settings gear icon 4 times. You will then see the developer options. You can then enable SSH and login with "pi" and "smarthome" using SSH (ssh pi@candle.local). Alternatively, add a file called SSH to this directory, and SSH should be enabled after a reboot. After another reboot SSH will be disabled again (because the sytem partition is read-only).


# DISABLING READ ONLY MODE
Candle has two big partitions, a read-only one for the system, and a writeable one for user data. The system partition uses an overlay. You can disable the read-only mode of the system partition in a number of ways:

1. Call "rw" or "ro" to set the /ro directory to RW or RW mode respectively. This allows for quick on-the-fly changes to the real underlying filesystem, which can be found under /ro. Making changes outside of /ro will still not stick.
2. Create a file called "candle_rw_once.txt" in the same folder as this readme file, and then reboot. This will completely remove the overlay. This file will automatically be deleted, so after another reboot the system will be back in read-only mode. When using this option the /ro directory will not exist, and you can change all parts of the filesystem. Candle uses this for more serious changes, such as a complete system update.
3. Create a file called "candle_rw_keep.txt" in the same folder as this readme file, and then reboot. This is like option 2, but will keep the system in RW mode as long as the file is there.


# DEBUGGING
If you would like to see information about the boot process on an attached display, you can replace the "cmdline.txt" file with the debug version of that file. Rename the current "cmdline.txt" file to something else first (e.g. "cmdline-original.txt"), so you can restore it later.

Alternatively, you can connect a monitor and keyboard. Then pressing CTRL-ALT-F3 should reveal the shell.


# RECOVERY
From Candle 2.0.2 onwards Candle has a built-in recovery partition. Booting into that will normally start a process which downloads and installs the latest version of Candle. It fully replaces the system partition with a downloaded disk image, and similarly copies files over the boot partition too. It does not change the recovery partition or user data partition. 

It is possible to boot into recovery without starting the update process; creating the file candle_recovery_type.txt with the string 'nothing' inside will cause the recovery to do nothing. It also won't copy the hostname, so (currently) you may login in to the recovery system with: ssh root@candleupdate.local and password 'smarthome'.


# EMERGENCY RECOVERY
Another last ditch attempt you could try if the recovery option doesn't work or is unavailable: using the recovery version of cmdline.txt. It will boot the system into a bash shell. Note that the filesystem will be in read-only mode, but you can remount it if you need to make changes:

mount -o remount,rw /dev/mmcblk0p2 /


# TOGGLES
The existence of these files can influence how the system operates:

candle_ssh.txt 			# Start SSH server at every boot. Login with username 'pi' and password 'smarthome'.
candle_ssh_once.txt             # Start SSH server after the next reboot.
candle_rw_once.txt             # On the next reboot the system partition will be writable. On the reboot after that it will be restored to read-only.
candle_rw_keep.txt             # After the next reboot the system partition will remain writeable until this file is removed (and another reboot)
emergency.txt 			# Booting is mostly halted, and SSH access is activated.
candle_emergency_backup.txt 	# If possible, creates an emergency backup which will be placed on the SD card as candle_emergency_backup.tar
candle_kiosk.txt 		# The URL inside this file will be shown in the browser. If it's empty the kiosk browser will not load.
candle_kiosk_forced.txt 	# Force the kiosk mode to start on low memory systems (Pi Zero).
candle_kiosk_require_login.txt 	# If this file exists it will force the user to log back into the kiosk browser after each reboot.
cloudless.txt 			# Experimental, to launch the controller even if there is no network at all. Use with the Hotspot addon.
candle_hotspot.txt 			# If present, Candle will start a guest WiFi network.
candle_hotspot.txt 			# Change the password of the guest wifi network by writing it into this file.
nohotspot.txt 			# Aborts hotspot addon launch. Useful if that feature somehow causes trouble.
show_mouse_pointer.txt 		# Forces showing the mouse pointer on the HDMI output.
hide_mouse_pointer.txt 		# Forces hiding the mouse pointer on the HDMI output.
rotate180.txt 			# Rotates the display 180 degrees.
exhibit_mode.txt		# Disables installing and uninstalling addons, as well as most mayor settings.
do_not_use_repeaker_hat.txt 	# Will stop ReSpeaker hat drivers from being loaded at boot.
candle_wifi_power_save 	        # If present, wifi power saving will be enabled. This may cause connection issues.
candle_cutting_edge.txt 	# If present, any system update will attempt to get the very latest version of everything. Risky, For developers only.
hostname.txt 			# The word inside this file will become the hostname. Must be one single word in lower case.

# RECOVERY OPTIONS
By default booting into the recovery partition starts the update process, but this can be overridden:

candle_update.txt		# If it exists, then this file will be renamed to candle_update.sh and run as a script. Also, the normal update process is not run.
candle_recovery_type.txt        # The contents of this file overrides the recovery type. Set its contents to the word "nothing" to boot into recovery and do nothing.
candle_stay_in_recovery.txt     #  The recovery system will normally automaticallty reboot after the update is done. It stays in recovery so you can inspect things.

# TOOLS
candle_make_emergency_backup.txt $ Make an emergency backup, which will be placed on the boot partition of the SD card.
generate_debug.txt 		# Will generate a file called debug.txt which contains details about the state of the system.
generate_raspinfo.txt 		# Will generate a file called raspinfo.txt which contains details about the operating system.
candle_forget_wifi.txt		# Will clear the currently stored wifi details (ssid, password) on the next boot.
candle_forget_users.txt		# Will delete all users on the next boot. Useful if you forgot your password.
candle_delete_these_addons.txt	# Will delete all addons listed in this file. These must be the names of the addon directories. E.g. Voco -> voco
candle_install_these_addons.txt	# Will install all addons listed in this file. These must be in the form of their GIT url's


# Factory reset related:
keep_z2m.txt 			# Keep Zigbee2MQTT settings on factory reset.
keep_bluetooth.txt 		# Keep paired bluetooth devices on factory reset.
developer.txt 			# Enables logging. Will also cause a factory reset to write zeros to empty space, so as to prepare for creating a disk image.


# INDICATORS 
candle_swap_enabled.txt 	# On lower memory systems (Pi Zero 2) this file indicates that on the first run the swap file was enabled. Normally swap is disabled.
candle_first_run_complete.txt 	# This file appears after the first boot, and blocks first_run.sh. It indicates that a new machine ID and new SSH keys were generated. 
candle_hardware_clock.txt 	# This file is present if the hardware clock module is detected and enabled.
candle_has_4th_partition.txt	# Indicates a Candle controller with an additional fourth (rescue) partition. Deprecated (use df or lsblk to check instead).


# FAILURE INDICATORS
candle_log.txt 			# Upgrade processes and commands you give may output status and errors into this file.
bootup_actions_failed.sh 	# If this file exists, it indicates that an upgrade process did not complete because it failed or was interupted. Deprecated.
candle_recovery_aborted.txt     # The recovery partition's system update script ran into a problem and aborted the update.
candle_recovery_interupted.txt  # If this file exists, the recovery partition's system update process was unexpectedly interupted during the critical part of the update.


# Source code
For source code please visit https://www.candlesmarthome.com
