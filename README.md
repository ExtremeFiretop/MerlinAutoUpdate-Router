# MerlinAU - AsusWRT-Merlin Firmware Auto Updater
## v1.0.6
## 2024-02-22


![image](https://github.com/ExtremeFiretop/MerlinAutoUpdate-Router/assets/1971404/c2523224-2269-46be-b5bc-bd6545f40507)
![image](https://github.com/ExtremeFiretop/MerlinAutoUpdate-Router/assets/1971404/ad9a5675-1460-4d2e-9baa-f18b0e4c7622)


## TESTED MODELS (Multi-image models) - i.e. Any model that uses a .w or a .pkgtb file

 - GT-AX6000 (Tested)
 - GT-AXE11000 (Tested)
 - GT-AX11000_PRO (Tested)
 - RT-AX88U_PRO (Tested)
 - RT-AX88U (Tested)
 - RT-AC86U (Tested)
 - RT-AX86U (Tested)
 - RT-AX86U_PRO (Tested)
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
 - GT-AX11000 (Untested)
 - GT-AC2900 (Untested)
 - RT-AX86U_PRO (Untested)
 - RT-AX68U (Untested)
 - RT-AX56U (Untested)
 - RT-AX58U (Untested)
 - RT-AX3000 (Untested)

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
- Automatically install updates to your router with the latest firmware from the Asuswrt-Merlin repository.
- Logic to manage cron jobs for automated firmware update checks.
- Notifications for new script updates and download the latest version of MerlinAU
- User configurable wait periods. Wait for a set duration after a new firmware release.
- Easy Enable/Disable: A menu switch for automatic update checking.
- Easy Uninstall: A routine to cleanly uninstall the script, removing all related files and settings.
- Logging and Cleanup: The script maintains logs for its operations and includes functions for cleanup tasks.
- Blinking LEDs: A visual indicator before starting the firmware update.
- Changelog verification check: Checks the changelogs for very obvious red flags and prompts for approval.
- Checks RAM usage: Functions to check and manage available memory for firmware update operations.
- Compatible with ROG and non-ROG routers; select ROG or Pure Build for ROG routers.
- Backup the new firmware version to the USB drive. (If USB is selected for storage)
- Email notifications if you configured email options in AMTM.
- Automatic backup with BACKUPMON if installed.
- Allow or Block Alpha/Beta upgrades to Production versions of the same cycle.
  (388.6.alpha1 or 388.6.beta1 --> 388.6.0)
- Automatically stops all Entware services, if installed, before the flash.
- Automatically stops diversion, if installed, before the flash.
- Unmounts any physically attached storage via USB as the last step before the flash.

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
