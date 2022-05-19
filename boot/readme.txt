# CANDLE CONTROLLER
This is the disk of a Candle Controller. Learn more at www.candlesmarthome.com

# DEBUGGING
If you would like to see information about the boot process on an attached display, you can replace the "cmdline.txt" file with the debug  version of that file. Rename the current "cmdline.txt" file to something else first (e.g. "cmdline-original"), so you can restore it later.

# RECOVERY
If you are having a lot of trouble, you can try using the recovery version of cmdline.txt. It will boot the system into a bash shell. Note that the filesystem will be in read-only mode, but you can remount it if you need to make changes:

sudo mount -o remount,rw /dev/mmcblk0p2 /

# SSH ACCESS
If you would like to have more control over your device, go to the settings page and click on the settings gear icon 4 times. You will then see the developer options. You can then enable SSH and login with "pi" and "candlesmarthome" using SSH (ssh pi@candle.local). You can disable the read-only mode of the file system using raspi-config -> performance -> overlay. Alternatively, add a file called SSH to this directory, and SSH should be enabled after a reboot.

# TOGGLES

The existence of these files can also toggle certain things:

disable_uninstall.txt # useful for public exhibitions, disables uninstalling addons in the Candle app store
candle_kiosk.txt # the URL inside this file will be shown in the browser. If it's empty the kiosk browser will not load
keep_browser_session.txt # Don't delete browser sessions on boot. This will allow login password to be saved accross reboots.
cloudless.txt # experimental, to launch the gateway even if there is no network at all
nohotspot.txt # aborts hotspot launch. Useful if that feature somehow causes trouble.
hide_mouse_pointer.txt # hides the mouse pointer on the HDMI output. Enabled by default.
rotate180.txt # Rotates the display 180 degrees. The Display Toggle addon manages the existence of this file.
exhibit_mode.txt # Disables installing and uninstalling addons.
do_not_use_repeaker_hat.txt # will stop ReSpeaker hat drivers from being loaded at boot
disable_wifi_power_save.txt # if present, wifi power saving feature will be disabled. This might improve some connections. Handled in /etc/rc.local

# Factory reset related:
keep_z2m.txt # keep Zigbee2MQTT settings on factory reset
keep_bluetooth.txt # Keep paired bluetooth devices on factory reset
developer.txt # Enables logging. Will also cause a factory reset to write zeros to empty space, so as to prepare for creating a disk image

# Indicators
candle_swap_enabled.txt # on lower memory systems (Pi zero) this file indicates that on the first run the swap file was enabled. Normally it's disabled, but on low memory systems candle_first_run.sh will enable it.
candle_first_run_complete.txt # this file appears after the first even boot of the disk image. It indicates that new SSH keys were generated
