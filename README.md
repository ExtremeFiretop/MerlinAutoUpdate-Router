# MerlinAU - AsusWRT-Merlin Firmware Auto Updater
## v1.3.0
## 2024-08-08

![image](https://github.com/user-attachments/assets/2b2b886c-0719-4d0a-861a-7fec94087e1e)
![image](https://github.com/user-attachments/assets/fffdb79c-6fbb-44ee-ac79-366c7fedc5b7)
![image](https://github.com/user-attachments/assets/a79e3044-ae49-483a-b9ff-2f081fa81964)
![image](https://github.com/user-attachments/assets/6d0aad68-5c02-4355-abd3-cd441cdfe108)

## SUPPORTED MERLIN MODELS (Multi-image models) - i.e. Any model that uses a .w or a .pkgtb file

 - GT-BE98_PRO (Tested)
 - GT-AX6000 (Tested)
 - GT-AXE16000 (Tested)
 - GT-AXE11000 (Tested)
 - GT-AX11000_PRO (Tested)
 - GT-AX11000 (Tested)
 - GT-AC2900 **(Untested)**
 - RT-BE96U **(Untested)**
 - RT-AX88U_PRO (Tested)
 - RT-AX88U (Tested)
 - RT-AC86U (Tested)
 - RT-AX86U (Tested)
 - RT-AX86U_PRO (Tested)
 - RT-AX86S (Tested)
 - RT-AX68U (Tested)
 - RT-AX58U V1 (Tested)
 - RT-AX56U **(Untested)**
 - RT-AX3000 V1 (Tested)
 - XT12 (Tested)

## SUPPORTED GNUTON MODELS (Multi-image models) - i.e. Any model that uses a .w or a .pkgtb file
 - GT-BE98 - **Known issues due to missing from manifest2.txt file in Gnuton**
 - DSL-AX82U **(Untested)**
 - TUF-AX3000 V1 **(Untested)**
 - TUF-AX3000 V2 (Tested)
 - TUF-AX5400 (Tested)
 - RT-AX5400 **(Untested)**
 - RT-AX82U V1 (Tested)
 - RT-AX82U V2 **(Untested)**
 - RT-AX58U V2 **(Untested)**
 - RT-AX92U - **Known issues due to PR: https://github.com/gnuton/asuswrt-merlin.ng/pull/654**
 - RT-AX95Q **(Untested)**
 - RT-AXE95Q **(Untested)**

## UNSUPPORTED MERLIN MODELS: (Single image models) - i.e. Any model that uses a .trx file
Blocked due to low RAM/ROM space and/or have reached end-of-life support from ASUS and Merlin.
   
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

## UNSUPPORTED GNUTON MODELS: (Single image models) - i.e. Any model that uses a .trx file
Blocked due to low RAM/ROM space and/or have reached end-of-life support from ASUS and Gnuton.
   
 - DSL-AC68U (Blocked)

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
- AiMesh Node Update Check from Primary Router. (No Flashing from Primary, MerlinAU needs to be on each node for flashing)

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
