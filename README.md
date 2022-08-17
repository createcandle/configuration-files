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
- Next it's time for `/etc/rc.local`. This has some duplicate functionality with early.sh (in case one of these files becomes broken). It has the self-healing ability, where it can restore backups if it detects that an upgrade went badly, and can generate debug.txt. Finally, if there is at least 1.5gb of memory it calls `startx` to launch the Openbox desktop.

Now three things happen:
- Next, X calls `/etc/xdg/openbox/autostart` (it takes about 4 seconds before this happens after rc.local is done). This script shows the video of the Candle logo fullscreen and starts the browser behind that. After 15 seconds it stops the video and the browser is revealed.
- Simultaneously, as soon as rc.local is done, systemd will start the controller software (webthings-gateway.service).
- Another script called `/home/pi/candle/late.sh` also runs simultaneously, but this currently doesn't do anything.
