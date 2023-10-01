# MerlinAutoUpdate-Router

MerlinAutoUpdate-Router is a versatile shell script designed to automate the firmware update process for ASUS routers running Asuswrt-Merlin firmware. 
It streamlines the firmware update procedure, automatically detects your router model, fetches the latest firmware, and offers options for installation. Moreover, it checks log files for reset recommendations before flashing the firmware.

## Features

- Automatic router model detection.
- Download and install the latest firmware for your router model from the Asuswrt-Merlin repository.
- Log analysis to determine if a factory reset is recommended within a specified date range.
- Option to reboot the router for enhanced system memory.

## Usage

The script can be run using various options. Here are some common use cases:

- To update the firmware:
  ```bash
  ./MerlinAutoUpdate-Router.sh
To check log files for reset recommendations:

Before using MerlinAutoUpdate-Router, ensure the following prerequisites are met:

An ASUS router running Asuswrt-Merlin firmware.
Access to the router's command line interface (SSH or Telnet).
A working internet connection on the router.

Installation
To install MerlinAutoUpdate-Router, follow these steps:

Enable SSH on your router if not already enabled.
Use your preferred SSH client to connect to the router.
Download the script to your router:
bash
Copy code
curl --retry 3 "https://raw.githubusercontent.com/YourGitHubUsername/MerlinAutoUpdate-Router/master/MerlinAutoUpdate-Router.sh" -o "/jffs/scripts/MerlinAutoUpdate-Router.sh" && chmod +x "/jffs/scripts/MerlinAutoUpdate-Router.sh"
The script is now ready for use.

Contribution
Feel free to contribute to this script by submitting issues or pull requests on GitHub. Your feedback and contributions are greatly appreciated!
