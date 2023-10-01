---WORK IN PROGRESS--- NOT YET COMPLETE. PLEASE DO NOT USE AT THIS TIME....

## MerlinAutoUpdate-Router

MerlinAutoUpdate-Router is a versatile shell script designed to automate the firmware update process for ASUS routers running Asuswrt-Merlin firmware. 
It streamlines the firmware update procedure, automatically detects your router model, fetches the latest firmware, and offers options for installation. Moreover, it checks log files for reset recommendations before flashing the firmware.

## Features

- Automatic router model detection.
- Works with both ROG and non-ROG routers, if it's a ROG router simply select if you want to use the ROG or Pure Build.
- Download and install the latest firmware for your router model from the Asuswrt-Merlin repository.
- Log analysis to determine if a factory reset is recommended within a specified date range.
- Option to reboot the router for enhanced system memory and finalize the update post flash.

## Usage

The script can be run using various options. Here are some common use cases:

- To update the firmware:
  ```bash
  ./MerlinAutoUpdate-Router.sh

## Installation
Before using MerlinAutoUpdate-Router, ensure the following prerequisites are met:

An ASUS router running Asuswrt-Merlin firmware.
Access to the router's command line interface (SSH or Telnet).
A working internet connection on the router.

To install MerlinAutoUpdate-Router, follow these steps:

Enable SSH on your router if not already enabled.
Use your preferred SSH client to connect to the router.

Download the script to your router:
Copy and paste:
```bash
curl --retry 3 "https://raw.githubusercontent.com/Firetop/MerlinAutoUpdate-Router/master/MerlinAutoUpdate-Router.sh" -o "/jffs/scripts/MerlinAutoUpdate-Router.sh" && chmod +x "/jffs/scripts/MerlinAutoUpdate-Router.sh"
```
The script is now ready for use, however you would include the call to the script in using cru (cron) to schedule the script at a pre-determined scheduled time

e.g. Every week
```
cat > /jffs/scripts/MerlinUpdate << EOF;chmod +x /jffs/scripts/MerlinUpdate
#!/bin/sh

if [ "\$2" == "connected" ];then
   # Check for updates every week
   sh /jffs/MerlinAutoUpdate-Router.sh cron="0 0 * * 0" &
fi
EOF
```
Check desired cru (cron) schedule has been created
```
cru l
0 0 * * 0 /jffs/scripts/MerlinAutoUpdate-Router.sh #MerlinUpdate#
```
## Contribution
Feel free to contribute to this script by submitting issues or pull requests on GitHub. Your feedback and contributions are greatly appreciated!

