# MerlinAU - AsusWRT-Merlin Firmware Auto Updater
## v1.4.8
## 2025-Jun-08

## WebUI:
![image](https://github.com/user-attachments/assets/9c1dff99-9c13-491b-a7fa-aff924d5f02e)

## CLI Shell Script:
![image](https://github.com/user-attachments/assets/3af75fda-ecda-419c-86b9-628e255abba0)
![image](https://github.com/user-attachments/assets/caff3af3-5404-4b4c-92dd-f225df1431b8)
![image](https://github.com/user-attachments/assets/62767ed5-f9a3-4343-890f-b151b9c2f318)
![image](https://github.com/user-attachments/assets/35607f78-bd02-49ca-af10-b1ea77412d2d)

## Update Process (Triggered Manually):
![image](https://github.com/user-attachments/assets/62d60c39-9bb0-40db-bb80-dda3de08c508)
![image](https://github.com/user-attachments/assets/5661b0eb-0305-46c3-a474-0674719f41c0)

## SUPPORTED MERLIN MODELS (Multi-image models) - i.e. Any model that uses a .w or a .pkgtb file

 - GT-BE98_PRO
 - GT-AX6000
 - GT-AXE16000
 - GT-AXE11000
 - GT-AX11000_PRO
 - GT-AX11000
 - GT-AC2900
 - RT-BE92U
 - RT-BE96U
 - RT-BE88U
 - RT-BE86U
 - RT-AX88U_PRO 
 - RT-AX88U 
 - RT-AC86U
 - RT-AC2900
 - RT-AX86U
 - RT-AX86U_PRO
 - RT-AX86S
 - RT-AX68U
 - RT-AX58U V1
 - RT-AX56U
 - RT-AX3000 V1
 - XT12

## SUPPORTED GNUTON MODELS (Multi-image models) - i.e. Any model that uses a .w or a .pkgtb file
 - GT-BE98
 - DSL-AX82U
 - TUF-AX3000 V1
 - TUF-AX3000 V2
 - TUF-AX5400
 - RT-AX5400
 - RT-AX82U V1
 - RT-AX82U V2
 - RT-AX58U V2
 - RT-AX92U
 - RT-AX95Q
 - RT-AXE95Q

## UNSUPPORTED MERLIN MODELS: (Single image models) - i.e. Any model that uses a .trx file
Blocked due to being single image models.
   
 - RT-AC87U (Blocked)
 - RT-AC56U (Blocked)
 - RT-AC66U (Blocked)
 - RT-AC3200 (Blocked)
 - RT-AC88U (Blocked)
 - RT-AC5300 (Blocked)
 - RT-AC3100 (Blocked)
 - RT-AC68U (Blocked)
 - RT-AC66U_B1 (Blocked)
 - RT-AC68UF (Blocked)
 - RT-AC68P (Blocked)
 - RT-AC1900 (Blocked)
 - RT-AC1900P (Blocked)
 - RT-N66U (Blocked)
 - RT-N16 (Blocked)

## UNSUPPORTED GNUTON MODELS: (Single image models) - i.e. Any model that uses a .trx file
Blocked due to being single image models.
   
 - DSL-AC68U (Blocked)

## Merlin(A)uto(U)pdate

MerlinAU.sh is a versatile shell script designed to automate the firmware update process for ASUS routers running Asuswrt-Merlin firmware. 
It streamlines the firmware update procedure, automatically detects your router model, fetches the latest firmware, and offers options for installation.

## NOTE: It is highly recommended to configure backups using BACKUPMON
- https://github.com/ViktorJp/BACKUPMON/tree/main

## Features

- Automatic router model detection and Automatic update detection.
- Automatically install updates to your router with the latest firmware from the Asuswrt-Merlin repository.
- Logic to customize scheduled cron jobs for automated firmware update checks.
- Notifications for new script updates and download the latest version of MerlinAU
- User configurable wait periods. Wait for a set duration after a new firmware release.
- Menu switch to enable or disable automatic update checking within MerlinAU.
- A routine to cleanly uninstall the script, removing all related files and settings.
- Maintains logs for its update checks and flash operations which can be viewed from the logs menu
- Includes functions for cleanup tasks pre-flash and post-flash.
- A visual indicator before starting the firmware update.
- Checks the changelogs for very obvious red flags and prompts for approval.
- Menu option and notifications to pre-approve the changelog verification if enabled with risks before the flash.
- Ability to download the latest changelog notes for manual review from the logs menu.
- Functions to check and manage available memory for firmware update operations.
- Compatible with ROG and non-ROG routers; select ROG or Pure Build for ROG routers.
- Backup the new firmware version to the USB drive. (If USB is selected for storage)
- Email notifications if you configured email options in AMTM. (With format selection in the advanced options)
- Automatic backup with BACKUPMON if installed.
- Allow or Block Alpha/Beta upgrades to Production versions of the same cycle.
  (388.6.alpha1 or 388.6.beta1 --> 388.6.0)
- Automatically stops all Entware services, if installed, before the flash.
- Automatically stops diversion, if installed, before the flash.
- Unmounts any physically attached storage via USB as the last step before the flash.
- AiMesh Node Update Check from Primary Router. (No Flashing from Primary, MerlinAU needs to be on each node for flashing)
- Automatically remove any loaded cron jobs from third party scripts before flashing.
- Menu switch to keep Tailscale or ZeroTier VPN access active while flashing over SSH in the advanced menu.

## Installation
Before using MerlinAU, ensure the following prerequisites are met:

An ASUS router running Asuswrt-Merlin firmware.
Access to the router's command line interface (SSH or Telnet).
A working internet connection on the router.

To install MerlinAutoUpdate, follow these steps:

Enable SSH on your router if not already enabled.
Use your preferred SSH client to connect to the router.

*MerlinAU is now available through AMTM!*
1. Simply connect to the router via SSH and type: "amtm" to load AMTM
2. Select option (i) to view the list of available applications.
3. MerlinAU is option (8) from AMTM.

*Manual Installation*
1. To Download the script to your router, Copy and paste:
```bash
curl --retry 3 "https://raw.githubusercontent.com/ExtremeFiretop/MerlinAutoUpdate-Router/master/MerlinAU.sh" -o "/jffs/scripts/MerlinAU.sh" && chmod +x "/jffs/scripts/MerlinAU.sh" && sh /jffs/scripts/MerlinAU.sh install
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

## Star History
<a href="https://www.star-history.com/#ExtremeFiretop/MerlinAutoUpdate-Router&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=ExtremeFiretop/MerlinAutoUpdate-Router&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=ExtremeFiretop/MerlinAutoUpdate-Router&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=ExtremeFiretop/MerlinAutoUpdate-Router&type=Date" />
 </picture>
</a>
