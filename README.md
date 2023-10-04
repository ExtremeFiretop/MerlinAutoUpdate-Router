---WORK IN PROGRESS--- 
PREVIEW, NOT YET COMPLETE. PLEASE EXPECT ISSUES.

## SUPPORTED MODELS: (Multi-image models) - i.e. Any model that uses a .w file

 - GT-AXE11000 (Untested)
 - GT-AXE16000 (Untested)
 - GT-AX6000 (Untested)
 - GT-AX11000 (Untested)
 - GT-AX11000_PRO (Untested)
 - GT-AC2900 (Untested)
 - RT-AX88U_PRO (Untested)
 - RT-AX86U_PRO (Untested)
 - RT-AX68U (Untested)
 - RT-AX86U (Untested)
 - RT-AX56U (Untested)
 - RT-AX58U (Untested)
 - RT-AX3000 (Untested)
 - RT-AX88U (Untested)
 - RT-AC86U (Untested)
 - XT12 (Untested)
 
## UNSUPPORTED MODELS: (Single image models) - i.e. Any model that uses a .trx file

 - RT-AC86U (No)
 - RT-AC1900 (No)
 - RT-AC87U (No)
 - RT-AC5300 (No)
 - RT-AC3200 (No)
 - RT-AC3100 (No)
 - RT-AC88U (No)
 - RT-AC68U (No)
 - RT-AC66U (No)
 - RT-AC56U (No)
 - RT-AC66U_B1 (No)
 - RT-N66U (No)

## Remaining/Planned Features:
- ~~Log analysis to determine if a factory reset is recommended within a specified date range.~~ - Will need some kind of notification system for this
- ~~Add Install for AMTM.~~ - Will need some more research into AMTM
- ~~Add Un-Install for AMTM.~~ - Will need some more research into AMTM
  

## MerlinAutoUpdate-Router

MerlinAutoUpdate-Router is a versatile shell script designed to automate the firmware update process for ASUS routers running Asuswrt-Merlin firmware. 
It streamlines the firmware update procedure, automatically detects your router model, fetches the latest firmware, and offers options for installation. Moreover, it checks log files for reset recommendations before flashing the firmware.

## Features

- Automatic router model detection.
- Works with both ROG and non-ROG routers, if it's a ROG router simply select if you want to use the ROG or Pure Build.
- Download and install the latest firmware for your router model from the Asuswrt-Merlin repository.
- Option to reboot the router for enhanced system memory and finalize the update post flash.

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
curl --retry 3 "https://raw.githubusercontent.com/Firetop/MerlinAutoUpdate-Router/master/MerlinAutoUpdate.sh" -o "/jffs/scripts/MerlinAutoUpdate.sh" && chmod +x "/jffs/scripts/MerlinAutoUpdate.sh"
```
- The script is now ready for use!
  
## Usage

The script can be run using various options. Here are some common use cases:

- To update the firmware: (Run from Root of SSH location)
  ```bash
  /./jffs/scripts/MerlinAutoUpdate.sh

- Check desired cru (cron) schedule has been created:
  ```bash
  cru l

- Result should look something like: 
  ```bash
  0 0 * * 0 /bin/sh /jffs/scripts/MerlinAutoUpdate.sh #MerlinUpdate#

- (Cron calculator here: https://crontab.guru/)
## Contribution
Feel free to contribute to this script by submitting issues or pull requests on GitHub. Your feedback and contributions are greatly appreciated!

