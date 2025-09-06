# Configuration files
Various configuration files for the Candle controller

https://www.candlesmarthome.com

For use with 

https://github.com/createcandle/install-scripts



Not provided here are the .png images in /boot. The Candle logo is not available under an MIT license, so wasn't added to this repository. The install script downloads the images and videos from the Candle webserver.




### Boot order

When Candle boots up it takes a number of steps.

- First /bin/ro-root.sh is run. This enables read-only mode unless it detects files that would prevent this, such as `candle_rw_once.txt` being in the boot partition. It also shows the first smaller Candle logo on the display.
- Next linux starts fully and eventually systemd calls `/home/pi/candle/early.sh`. This script can restore backups if it detects commands to do so.
- Next it's time for `webthings_gateway.service`.
- If there is at least 1.5gb of memory it calls `startx` to launch the Openbox desktop. X11 calls `/etc/xdg/openbox/autostart` . This script shows the video of the Candle logo fullscreen and starts the browser behind that.
- Finally, a script called `/home/pi/candle/late.sh` runs after the controller has started.
  


