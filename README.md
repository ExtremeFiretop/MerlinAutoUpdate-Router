![image](https://github.com/ExtremeFiretop/MerlinAutoUpdate-Router/assets/1971404/ffa9fed4-86fc-40b4-ac42-ba9ffe3dc264)

## TESTED MODELS (Multi-image models) - i.e. Any model that uses a .w or a .pkgtb file

 - GT-AXE11000 (Tested)
 - RT-AX88U_PRO (Tested)
 - RT-AX88U (Tested)
 - RT-AC86U (Tested)
 - RT-AX86U (Tested)
 - XT12 (Tested)

## UNSUPPORTED MODELS: (Single image models) - i.e. Any model that uses a .trx file
Blocked due to low RAM/ROM space and/or have not received updates in several years.
   
 - RT-AC87U (Blocked)
 - RT-AC56U (Blocked)
 - RT-AC66U (Blocked)
 - RT-AC3200 (Blocked)
 - RT-N66U (Blocked)
 - RT-AC88U (Blocked)
 - RT-AC5300 (Blocked)
 - RT-AC3100 (Blocked)
 - RT-AC68U (Blocked)
 - RT-AC66U_B1 (Blocked)
 - RT-AC1900 (Blocked)

## UNTESTED MODELS: (Multi-image models) - i.e. Any model that uses a .w or a .pkgtb file

 - GT-AXE16000 (Untested)
 - GT-AX6000 (Untested)
 - GT-AX11000 (Untested)
 - GT-AX11000_PRO (Untested)
 - GT-AC2900 (Untested)
 - RT-AX86U_PRO (Untested)
 - RT-AX68U (Untested)
 - RT-AX56U (Untested)
 - RT-AX58U (Untested)
 - RT-AX3000 (Untested)
 - XT12 (Untested)

 ## TESTERS NEEDED!
 - If you see your router listed as untested above, feel free to test and report any issues.
 - If the test was successful on your model, feel free to leave a comment on snb forums or open an issue with your successful test and router model.
 - https://www.snbforums.com/threads/introducing-merlinau-the-ultimate-firmware-auto-updater-addon.88577/

## Merlin(A)uto(U)pdate

MerlinAU.sh is a versatile shell script designed to automate the firmware update process for ASUS routers running Asuswrt-Merlin firmware. 
It streamlines the firmware update procedure, automatically detects your router model, fetches the latest firmware, and offers options for installation.

## NOTE: It is highly recommended to configure backups using BACKUPMON
- https://github.com/ViktorJp/BACKUPMON/tree/main

## Features

- Automatic router model detection and Automatic update detection.
- Automatically updates your router with the latest firmware from the Asuswrt-Merlin repository.
- Credential Management: Functions to handle router login credentials required for the update process.
- Cron Job Management: Logic to manage cron jobs for automated firmware update checks.
- Script Updates: Handling notifications for new script versions.
- User configurable Wait Period: Wait for a set duration after a new firmware release.
- Easy Enable/Disable: A menu switch for automatic update checking.
- Easy Uninstall: A routine to cleanly uninstall the script, removing all related files and settings.
- Logging and Cleanup: The script maintains logs for its operations and includes functions for cleanup tasks.
- Blinking LEDs: As a visual indicator before starting the firmware update.
- Checks RAM usage: Functions to check and manage available memory for firmware update operations.
- Compatible with ROG and non-ROG routers; select ROG or Pure Build for ROG routers.
- Backup the new firmware version to the USB drive. (If USB is selected for storage)

## Remaining/Planned Features:
      
1. AMTM Install:
- Only once it's been vetted through most routers.

- Notes:
  - New routers use UBIFS instead of JFFS2.

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
- Before any contributions, please review: [CONTRIBUTING.md](https://github.com/ExtremeFiretop/MerlinAutoUpdate-Router/blob/main/CONTRIBUTING.md) Guidelines. 
- Also please review the: [CODE_OF_CONDUCT.md](https://github.com/ExtremeFiretop/MerlinAutoUpdate-Router/blob/main/CODE_OF_CONDUCT.md).
- Feel free to contribute to this script by submitting issues or pull requests on GitHub. Your feedback and contributions are greatly appreciated!

## Use this Automatic F/W Update script at your own discretion. By using this script you assume all risks associated with updating a router to a new firmware version.
