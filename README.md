---WORK IN PROGRESS--- 
- PREVIEW, NOT YET COMPLETE. PLEASE EXPECT BUGS.

---TESTERS NEEDED!--- 
 - If you see your router listed as untested below, feel free to test and report any issues.
 - If the test was successful on your model, feel free to leave a comment on snb forums or open an issue with your successful test and router model.
 - https://www.snbforums.com/threads/seeking-feedback-contributions-merlin-auto-update-solutions.87044/

## TESTED MODELS (Multi-image models) - i.e. Any model that uses a .w file

 - GT-AXE11000 (Tested)
 - RT-AX88U (Tested)

## UNSUPPORTED MODELS: (Single image models) - i.e. Any model that uses a .trx file

 - RT-AC68U (Blocked)

## UNTESTED MODELS: (Multi-image models) - i.e. Any model that uses a .w file

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
 - RT-AC86U (Untested)
 - XT12 (Untested)
 
## UNTESTED MODELS: (Single image models) - i.e. Any model that uses a .trx file

 - RT-AC86U (Untested)
 - RT-AC1900 (Untested)
 - RT-AC87U (Untested)
 - RT-AC5300 (Untested)
 - RT-AC3200 (Untested)
 - RT-AC3100 (Untested)
 - RT-AC88U (Untested)
 - RT-AC66U (Untested)
 - RT-AC56U (Untested)
 - RT-AC66U_B1 (Untested)
 - RT-N66U (Untested)

## Remaining/Planned Features:

Backup and Storage:

 - If USB drive is connected to the router for storage.
 -  - Save the following to the USB drive:
 -  - Configuration files.
 -  - JFFS backup.
 -  - Newer firmware version.
 - Note:
 - Be aware that JFFS partitions may not work post-upgrades in some cases.
 - New routers use UBIFS instead of JFFS2.

System Notifications:

- Possibly modify the hardcoded notification in the GUI's upper right corner.
- Trigger a firmware update notification using a script.

AMTM Install and Uninstallation:
- Only once it's been vetted through most routers.

## MerlinAutoUpdate-Router

MerlinAutoUpdate-Router is a versatile shell script designed to automate the firmware update process for ASUS routers running Asuswrt-Merlin firmware. 
It streamlines the firmware update procedure, automatically detects your router model, fetches the latest firmware, and offers options for installation. Moreover, it checks log files for reset recommendations before flashing the firmware.

## Features

- Automatic router model detection.
- Works with both ROG and non-ROG routers, if it's a ROG router simply select if you want to use the ROG or Pure Build.
- Download and install the latest firmware for your router model from the Asuswrt-Merlin repository.
- Implemented a waiting period for firmware updates: Wait for a set duration after a new firmware release.
- Set up blinking LEDs as a visual indicator before starting the firmware update.
- Checks RAM usage. If free RAM is less than the firmware file size, reboots the router.

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

The script can be run using the below options:

- To update the firmware: (Run from Root of SSH location)
  ```bash
  /./jffs/scripts/MerlinAutoUpdate.sh

- Check desired cru (cron) schedule has been created:
  ```bash
  cru l

- Result should look something like: 
  ```bash
  0 0 * * 0 sh /jffs/scripts/MerlinAutoUpdate.sh run_now

- (Cron calculator here: https://crontab.guru/)
## Contribution
Feel free to contribute to this script by submitting issues or pull requests on GitHub. Your feedback and contributions are greatly appreciated!

