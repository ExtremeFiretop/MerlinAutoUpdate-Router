---WORK IN PROGRESS--- 
- PREVIEW, NOT YET COMPLETE. PLEASE EXPECT BUGS.

![image](https://github.com/ExtremeFiretop/MerlinAutoUpdate-Router/assets/1971404/e948e3c3-9068-41ab-b8dc-3678a6eb4a68)

---TESTERS NEEDED!--- 
 - If you see your router listed as untested below, feel free to test and report any issues.
 - If the test was successful on your model, feel free to leave a comment on snb forums or open an issue with your successful test and router model.
 - https://www.snbforums.com/threads/seeking-feedback-contributions-merlin-auto-update-solutions.87044/

## TESTED MODELS (Multi-image models) - i.e. Any model that uses a .w file

 - GT-AXE11000 (Tested)
 - RT-AX88U (Tested)
 - RT-AC86U (Tested)
 - RT-AX86U (Tested)

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
 - RT-AX56U (Untested)
 - RT-AX58U (Untested)
 - RT-AX3000 (Untested)
 - XT12 (Untested)
 
## UNTESTED MODELS: (Single image models) - i.e. Any model that uses a .trx file

 - RT-AC88U (Untested)
 - RT-AC5300 (Untested)
 - RT-AC3100 (Untested)
 - 
 - RT-AC1900 (Untested)
 - RT-AC87U (Untested)
 - RT-AC3200 (Untested)
 - RT-AC3100 (Untested)
 - RT-AC66U (Untested)
 - RT-AC56U (Untested)
 - RT-AC66U_B1 (Untested)
 - RT-N66U (Untested)

## Remaining/Planned Features:
      
1. System Notifications:

- Possibly trigger the hardcoded notification in the GUI's upper right corner.

2. AMTM Install:
- Only once it's been vetted through most routers.

- Notes:
  - Might need to add some "overhead" to the file size comparison to account for the "ZIP + F/W" files being on the "$HOME" directory at the same time, even if just temporarily.
  - New routers use UBIFS instead of JFFS2.

## Merlin(A)uto(U)pdate

MerlinAU.sh is a versatile shell script designed to automate the firmware update process for ASUS routers running Asuswrt-Merlin firmware. 
It streamlines the firmware update procedure, automatically detects your router model, fetches the latest firmware, and offers options for installation.

## NOTE: It is highly recommended to configure backups using BACKUPMON
- https://github.com/ViktorJp/BACKUPMON/tree/main

## Features

- Automatic router model detection.
- Automatic update detection.
- Automatically updates your router with the latest firmware from the Asuswrt-Merlin repository.
- User configurable waiting period for firmware updates. (Wait for a set duration after a new firmware release.)
- Easy Enable/Disable switch for automatic update checking
- Easy uninstall.
- Logs update process in desired path.
- Set up blinking LEDs as a visual indicator before starting the firmware update.
- Checks RAM usage. If free RAM is less than the firmware file size, reboots the router.
- Compatible with ROG and non-ROG routers; select ROG or Pure Build for ROG routers.
- Backup the new firmware version to the USB drive. (If USB is selected for storage)

## Installation
Before using MerlinAU, ensure the following prerequisites are met:

An ASUS router running Asuswrt-Merlin firmware.
Access to the router's command line interface (SSH or Telnet).
A working internet connection on the router.

To install MerlinAutoUpdate, follow these steps:

Enable SSH on your router if not already enabled.
Use your preferred SSH client to connect to the router.

Download the script to your router:
Copy and paste:
```bash
curl --retry 3 "https://raw.githubusercontent.com/ExtremeFiretop/MerlinAutoUpdate-Router/master/MerlinAU.sh" -o "/jffs/scripts/MerlinAU.sh" && chmod +x "/jffs/scripts/MerlinAU.sh"
```
- The script is now ready for use!
  
## Usage

The script can be run using the below options:

- To update the firmware: (Run from Root of SSH location)
  ```bash
  /./jffs/scripts/MerlinAU.sh

- Check desired cru (cron) schedule has been created:
  ```bash
  cru l

- Result should look something like: 
  ```bash
  0 0 * * 0 sh /jffs/scripts/MerlinAU.sh run_now

- (Cron calculator here: https://crontab.guru/)
## Contribution
Feel free to contribute to this script by submitting issues or pull requests on GitHub. Your feedback and contributions are greatly appreciated!

