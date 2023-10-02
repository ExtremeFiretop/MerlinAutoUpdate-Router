#!/bin/bash

URL_BASE="https://sourceforge.net/projects/asuswrt-merlin/files"
URL_BETA_SUFFIX="Beta"
URL_RELEASE_SUFFIX="Release"

MODEL=$(nvram get model)
URL_BETA="${URL_BASE}/${MODEL}/${URL_BETA_SUFFIX}/"
URL_RELEASE="${URL_BASE}/${MODEL}/${URL_RELEASE_SUFFIX}/"
SETTINGS_DIR="/jffs/addons/MerlinAutoUpdate"
SETTINGSFILE="$SETTINGS_DIR/custom_settings.txt"

Update_Custom_Settings() {
    local setting_type="$1"
    local setting_value="$2"

    # Check if the directory exists, and if not, create it
    if [ ! -d "$SETTINGS_DIR" ]; then
        mkdir -p "$SETTINGS_DIR"
    fi

    case "$setting_type" in
        local)
            if [ -f "$SETTINGSFILE" ]; then
                if [ "$(grep -c "FirmwareVersion_setting" "$SETTINGSFILE")" -gt 0 ]; then
                    if [ "$setting_value" != "$(grep "FirmwareVersion_setting" "$SETTINGSFILE" | cut -f2 -d' ')" ]; then
                        sed -i "s/FirmwareVersion_setting.*/FirmwareVersion_setting $setting_value/" "$SETTINGSFILE"
                    fi
                else
                    echo "FirmwareVersion_setting $setting_value" >> "$SETTINGSFILE"
                fi
            else
                echo "FirmwareVersion_setting $setting_value" >> "$SETTINGSFILE"
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

# Embed functions from second script, modified as necessary.
run_now() {
    echo "Running the task now..."
	
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
#log_file="/home/root/${MODEL}_firmware/Changelog-NG.txt"

# Check if the log file exists
#if [ ! -f "$log_file" ]; then
#    echo "Log file does not exist at $log_file"
#    exit 1
#fi

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

# Function to get custom setting value from the settings file
Get_Custom_Setting() {
    local setting_type="$1"
    local default_value="$2"

    if [ -f "$SETTINGSFILE" ]; then
        case "$setting_type" in
            local)
                grep -q "FirmwareVersion_setting" "$SETTINGSFILE" && grep "FirmwareVersion_setting" "$SETTINGSFILE" | cut -f2 -d' ' || echo "$default_value"
                ;;
            *)
                echo "$default_value"
                ;;
        esac
    else
        echo "$default_value"
    fi
}

# Use Get_Custom_Setting to retrieve the previous choice
previous_choice=$(Get_Custom_Setting "local" "n")

# Check for the presence of "rog" in filenames in the extracted directory
cd "/home/root/${MODEL}_firmware"
rog_file=$(ls | grep -i '_rog_')
pure_file=$(ls | grep -i '_pureubi.w' | grep -iv 'rog')

if [ ! -f "$SETTINGSFILE" ]; then
    # On the first run, when the settings file doesn't exist, prompt the user
    if [ ! -z "$rog_file" ]; then
        echo -e "\033[31mFound ROG build: $rog_file. Would you like to use the ROG build? (y/n)\033[0m"
        
        # Use the previous_choice as the default value
        read -p "Enter your choice [$previous_choice]: " choice

        # Use the entered choice or the default value if the input is empty
        choice="${choice:-$previous_choice}"

        if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
            firmware_file="$rog_file"
            Update_Custom_Settings "local" "y"
        else
            firmware_file="$pure_file"
            Update_Custom_Settings "local" "n"
        fi
    else
        firmware_file="$pure_file"
        Update_Custom_Settings "local" "n"
    fi
else
    # On subsequent runs, use the stored choice without prompting
    if [ "$previous_choice" = "y" ]; then
        firmware_file="$rog_file"
    else
        firmware_file="$pure_file"
    fi
fi

# Flashing the chosen firmware
echo -e "\033[32mFlashing $firmware_file...\033[0m"
#hnd-write "$firmware_file"  # Execute the command to flash the firmware.

# Wait for 3 minutes
#sleep 180

# Reboot the router
#reboot
    
    read -p "Press Enter to continue..."
}

change_build_type() {
    echo "Changing Build Type..."
    
# Logging user's choice
# Check for the presence of "rog" in filenames in the extracted directory
cd "/home/root/${MODEL}_firmware"
rog_file=$(ls | grep -i '_rog_')
pure_file=$(ls | grep -i '_pureubi.w' | grep -iv 'rog')

# Function to get custom setting value from the settings file
Get_Custom_Setting() {
    local setting_type="$1"
    local default_value="$2"

    if [ -f "$SETTINGSFILE" ]; then
        case "$setting_type" in
            local)
                grep -q "FirmwareVersion_setting" "$SETTINGSFILE" && grep "FirmwareVersion_setting" "$SETTINGSFILE" | cut -f2 -d' ' || echo "$default_value"
                ;;
            *)
                echo "$default_value"
                ;;
        esac
    else
        echo "$default_value"
    fi
}

# Use Get_Custom_Setting to retrieve the previous choice
previous_choice=$(Get_Custom_Setting "local" "n")

# Check for the presence of "rog" in filenames in the extracted directory
cd "/home/root/${MODEL}_firmware"
rog_file=$(ls | grep -i '_rog_')
pure_file=$(ls | grep -i '_pureubi.w' | grep -iv 'rog')

    if [ ! -z "$rog_file" ]; then
        echo -e "\033[31mFound ROG build: $rog_file. Would you like to use the ROG build? (y/n)\033[0m"

        while true; do
            # Use the previous_choice as the default value
            read -p "Enter your choice [$previous_choice]: " choice

            # Use the entered choice or the default value if the input is empty
            choice="${choice:-$previous_choice}"

            # Convert to lowercase to make comparison easier
            choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

            # Check if the input is valid
            if [ "$choice" = "y" ] || [ "$choice" = "yes" ] || [ "$choice" = "n" ] || [ "$choice" = "no" ]; then
                break
            else
                echo "Invalid input! Please enter 'y', 'yes', 'n', or 'no'."
            fi
        done

        if [ "$choice" = "y" ] || [ "$choice" = "yes" ]; then
            firmware_file="$rog_file"
            Update_Custom_Settings "local" "y"
        else
            firmware_file="$pure_file"
            Update_Custom_Settings "local" "n"
        fi
    else
        firmware_file="$pure_file"
        Update_Custom_Settings "local" "n"
    fi

    read -p "Press Enter to continue..."
}

change_schedule() {
  echo "Changing Schedule..."
  # Extract the current cron schedule from the script
  current_schedule=$(awk -F'"' '/sh \/jffs\/MerlinAutoUpdate.sh cron/ {print $2}' /jffs/scripts/MerlinAutoUpdateCron)
  
  # Translate cron schedule to English
  case "$current_schedule" in
    "0 0 * * 0") current_schedule_english="Every Sunday at midnight" ;;
    "0 0 * * 1") current_schedule_english="Every Monday at midnight" ;;
    "0 0 * * 2") current_schedule_english="Every Tuesday at midnight" ;;
    "0 0 * * 3") current_schedule_english="Every Wednesday at midnight" ;;
    "0 0 * * 4") current_schedule_english="Every Thursday at midnight" ;;
    "0 0 * * 5") current_schedule_english="Every Friday at midnight" ;;
    "0 0 * * 6") current_schedule_english="Every Saturday at midnight" ;;
    "0 0 * * *") current_schedule_english="Every day at midnight" ;;
    *) current_schedule_english="Custom schedule: $current_schedule" ;; # for non-standard schedules
  esac
  
  echo "Current Schedule: $current_schedule_english"
  
  read -p "Enter new cron schedule (e.g. 0 0 * * 0 for every Sunday at midnight): " new_schedule
  
  # Update the cron job in the script
  sed -i "/sh \/jffs\/MerlinAutoUpdate.sh cron/c\   sh \/jffs\/MerlinAutoUpdate.sh cron=\"$new_schedule\" &" /jffs/scripts/MerlinAutoUpdateCron
  
  # You may also need to update the cron job itself in the crontab if it's there
  crontab -l | grep -v '/jffs/scripts/MerlinAutoUpdateCron' | crontab -
  (crontab -l; echo "$new_schedule sh /jffs/scripts/MerlinAutoUpdateCron") | crontab -
  
  read -p "Press Enter to continue..."
}

show_menu() {
  clear
  echo "===== Merlin Auto Update Main Menu ====="
  echo "1. Run now"
  
  # Only display the "Change Build Type" option if a custom_settings.txt file exists
  if [ -f "$SETTINGSFILE" ]; then
    echo "2. Change Build Type"
	echo "3. Change Schedule"
	echo "e. Exit"
  else
	echo "2. Change Schedule"
	echo "e. Exit"
  fi

}

# Main loop
while true; do
  show_menu
  if [ -f "$SETTINGSFILE" ]; then
  read -p "Enter your choice (1/2/3/e): " choice
    case $choice in
    1) run_now ;;
    2) change_build_type ;;
    3) change_schedule ;;
    e) exit ;;
    *) echo "Invalid choice. Please try again." ;;
  esac
  else
  read -p "Enter your choice (1/2/e): " choice
  case $choice in
    1) run_now ;;
    2) change_schedule ;;
    e) exit ;;
    *) echo "Invalid choice. Please try again." ;;
  esac
  fi
done
