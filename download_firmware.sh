#!/bin/sh

URL_BASE="https://sourceforge.net/projects/asuswrt-merlin/files"
URL_BETA_SUFFIX="Beta"
URL_RELEASE_SUFFIX="Release"

MODEL=$(nvram get model)

URL_BETA="${URL_BASE}/${MODEL}/${URL_BETA_SUFFIX}/"
URL_RELEASE="${URL_BASE}/${MODEL}/${URL_RELEASE_SUFFIX}/"

Update_Custom_Settings() {
    SETTINGS_DIR="/jffs/addons/MerlinUpdate"
    SETTINGSFILE="$SETTINGS_DIR/custom_settings.txt"

    # Check if the directory exists, and if not, create it
    if [ ! -d "$SETTINGS_DIR" ]; then
        mkdir -p "$SETTINGS_DIR"
    fi

    case "$1" in
        local)
            if [ -f "$SETTINGSFILE" ]; then
                if [ "$(grep -c "local_setting" "$SETTINGSFILE")" -gt 0 ]; then
                    if [ "$2" != "$(grep "local_setting" "$SETTINGSFILE" | cut -f2 -d' ')" ]; then
                        sed -i "s/local_setting.*/local_setting $2/" "$SETTINGSFILE"
                    fi
                else
                    echo "local_setting $2" >> "$SETTINGSFILE"
                fi
            else
                echo "local_setting $2" >> "$SETTINGSFILE"
            fi
            ;;
        server)
            if [ -f "$SETTINGSFILE" ]; then
                if [ "$(grep -c "server_setting" "$SETTINGSFILE")" -gt 0 ]; then
                    if [ "$2" != "$(grep "server_setting" "$SETTINGSFILE" | cut -f2 -d' ')" ]; then
                        sed -i "s/server_setting.*/server_setting $2/" "$SETTINGSFILE"
                    fi
                else
                    echo "server_setting $2" >> "$SETTINGSFILE"
                fi
            else
                echo "server_setting $2" >> "$SETTINGSFILE"
            fi
            ;;
    esac
}

get_latest_firmware() {
    local url="$1"
    local page=$(curl -s "$url")
  
    local links_and_versions=$(echo "$page" | grep -o 'href="[^"]*'"$MODEL"'[^"]*\.zip' | sed 's/amp;//g; s/href="//' | 
        awk -F'[_\.]' '{print $2"."$3"."$4" "$0}' | sort -t. -k1,1n -k2,2n -k3,3n)
    
    local latest=$(echo "$links_and_versions" | tail -n 1)
    local version=$(echo "$latest" | cut -d' ' -f1)
    local link=$(echo "$latest" | cut -d' ' -f2-)
    
    # Extracting the correct link from the page
    local correct_link=$(echo "$link" | sed 's|^/|https://sourceforge.net/|')
    
    echo "$version"
    echo "$correct_link"
}

# Use set to read the output of the function into variables
set -- $(get_latest_firmware "$URL_BETA")
beta_version=$1
beta_link=$2

set -- $(get_latest_firmware "$URL_RELEASE")
release_version=$1
release_link=$2

if [ "$beta_version" \> "$release_version" ]; then
    echo "Latest beta version is $beta_version, downloading from $beta_link"
    wget -O "${MODEL}_firmware.zip" "$beta_link"
else
    echo "Latest release version is $release_version, downloading from $release_link"
    wget -O "${MODEL}_firmware.zip" "$release_link"
fi

# Create directory for extracting firmware
mkdir -p "/home/root/${MODEL}_firmware"

# Extracting the firmware
unzip -o "${MODEL}_firmware.zip" -d "/home/root/${MODEL}_firmware"

# Define the path to the log file
log_file="/home/root/${MODEL}_firmware/Changelog-NG.txt"

# Check if the log file exists
if [ ! -f "$log_file" ]; then
    echo "Log file does not exist at $log_file"
    exit 1
fi

# Checking the log file for reset recommendation between two dates
#log_contents=$(awk '/2023-09-30 00:00:00/,/2023-10-01 23:59:59/' "$log_file")

#if echo "$log_contents" | grep -q "reset recommended"; then
#    echo -e "Factory Default Reset is recommended according to the logs. Would you like to continue anyways?"
#	read choice
#	if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
#       continue
#    else
#        exit
#    fi
#else
#    echo "No reset is recommended according to the logs."
#fi

# Logging user's choice
# Check for the presence of "rog" in filenames in the extracted directory
cd "/home/root/${MODEL}_firmware"
rog_file=$(ls | grep -i '_rog_')
pure_file=$(ls | grep -i '_pureubi.w' | grep -iv 'rog')

if [ ! -z "$rog_file" ]; then
    echo -e "\033[31mFound ROG build: $rog_file. Would you like to use the ROG build? (y/n)\033[0m"
    read choice
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    firmware_file="$rog_file"
    Update_Custom_Settings "local" "$rog_file"
    else
        firmware_file="$pure_file"
        Update_Custom_Settings "local" "$pure_file"
    fi
else
    firmware_file="$pure_file"
    Update_Custom_Settings "local" "$pure_file"
fi

# Flashing the chosen firmware
echo -e "\033[32mFlashing $firmware_file...\033[0m"
hnd-write "$firmware_file"  # Execute the command to flash the firmware.

# Wait for 3 minutes
sleep 180

# Reboot the router
reboot
