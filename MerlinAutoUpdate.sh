#!/bin/bash

URL_BASE="https://sourceforge.net/projects/asuswrt-merlin/files"
URL_RELEASE_SUFFIX="Release"

MODEL=$(nvram get model)
URL_RELEASE="${URL_BASE}/${MODEL}/${URL_RELEASE_SUFFIX}/"
SETTINGS_DIR="/jffs/addons/MerlinAutoUpdate"
SETTINGSFILE="$SETTINGS_DIR/custom_settings.txt"

Say(){
   echo -e $$ $@ | logger -st "($(basename $0))"
}

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

get_current_firmware() {
    local current_version=$(nvram get buildno)
    echo "$current_version"
}

get_latest_firmware() {
    local url="$1"
    local page=$(curl -s "$url")

    local links_and_versions=$(echo "$page" | grep -o 'href="[^"]*'"$MODEL"'[^"]*\.zip' | sed 's/amp;//g; s/href="//' | 
        awk -F'[_\.]' '{print $3"."$4"."$5" "$0}' | sort -t. -k1,1n -k2,2n -k3,3n)

    local latest=$(echo "$links_and_versions" | tail -n 1)
    local version=$(echo "$latest" | cut -d' ' -f1 | awk -F. '{print $(NF-1)"."$NF}')
    local link=$(echo "$latest" | cut -d' ' -f2-)

    # Extracting the correct link from the page
    local correct_link=$(echo "$link" | sed 's|^/|https://sourceforge.net/|')

    echo "$version"
    echo "$correct_link"
}

change_build_type() {
    echo "Changing Build Type..."
    
# Logging user's choice
# Check for the presence of "rog" in filenames in the extracted directory
cd "/home/root/${MODEL}_firmware"
rog_file=$(ls | grep -i '_rog_')
pure_file=$(ls | grep -i '_pureubi.w' | grep -iv 'rog')

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

# Define the cron schedule and command to execute
CRON_SCHEDULE="0 0 * * 0"
COMMAND="sh /jffs/scripts/MerlinAutoUpdate.sh run_now"

# Check if the cron job command already exists
if ! crontab -l | grep -qF "$COMMAND"; then
  # Add the cron job if it doesn't exist
  (crontab -l; echo "$CRON_SCHEDULE $COMMAND") | crontab -
  
  # Verify that the cron job has been added
  if crontab -l | grep -qF "$COMMAND"; then
    echo "Cron job 'MerlinAutoUpdate' added successfully."
  else
    echo "Failed to add the cron job."
  fi
else
  echo "Cron job 'MerlinAutoUpdate' already exists."
  change_schedule
fi

# Function to translate cron schedule to English
translate_schedule() {
  case "$1" in
    "0 0 * * 0") schedule_english="Every Sunday at midnight" ;;
    "0 0 * * 1") schedule_english="Every Monday at midnight" ;;
    "0 0 * * 2") schedule_english="Every Tuesday at midnight" ;;
    "0 0 * * 3") schedule_english="Every Wednesday at midnight" ;;
    "0 0 * * 4") schedule_english="Every Thursday at midnight" ;;
    "0 0 * * 5") schedule_english="Every Friday at midnight" ;;
    "0 0 * * 6") schedule_english="Every Saturday at midnight" ;;
    "0 0 * * *") schedule_english="Every day at midnight" ;;
    *) schedule_english="Custom schedule: $1" ;; # for non-standard schedules
  esac
  echo "$schedule_english"
}

# Function to add or change the cron schedule
change_schedule() {
  echo "Changing Schedule..."
  
  # Use crontab -l to retrieve all cron jobs and filter for the one containing the script's path
  current_schedule_line=$(crontab -l | grep "$COMMAND")
  
  
  if [ -n "$current_schedule_line" ]; then
    # Extract the schedule part (the first five fields) from the current cron job line
    current_schedule=$(echo "$current_schedule_line" | awk '{print $1, $2, $3, $4, $5}')
    
    # Translate the current schedule to English
    current_schedule_english=$(translate_schedule "$current_schedule")
    
    echo -e "\033[32mCurrent Schedule: $current_schedule_english \033[0m"
  else
    echo "Cron job 'MerlinAutoUpdate' does not exist. It will be added."
  fi

     while true; do  # Loop to keep asking for input
        read -p "Enter new cron schedule (e.g., 0 0 * * 0 for every Sunday at midnight, or 'e' to exit): " new_schedule
    
        # If the user enters 'e', break out of the loop and return to the main menu
        if [[ "$new_schedule" == "e" ]]; then
            echo "Returning to main menu..."
            return
        fi
    
        # Validate the input using grep
        if echo "$new_schedule" | grep -E -q '^([0-9\*\-\,\/]+[[:space:]]){4}[0-9\*\-\,\/]+$'; then
            break  # If valid input, break out of the loop
        else
            echo "Invalid schedule. Please try again or press 'e' to exit."
        fi
    done

  # Update the cron job in the crontab
  (crontab -l | grep -vF "$COMMAND" && echo "$new_schedule $COMMAND") | crontab -

  if crontab -l | grep -qF "$COMMAND"; then
    echo "Cron job 'MerlinAutoUpdate' updated successfully."
  else
    echo "Failed to update the cron job."
  fi
  
  # Display the updated schedule
  current_schedule_english=$(translate_schedule "$new_schedule")
  echo -e "\033[32mUpdated Schedule: $current_schedule_english \033[0m"
  
  # Return to the main menu
  read -p "Press Enter to return to the main menu..."
}

# Embed functions from second script, modified as necessary.
run_now() {

Say "Running the task now...Checking for updates..."
# Get current firmware version
current_version=$(get_current_firmware)	


# Use set to read the output of the function into variables
set -- $(get_latest_firmware "$URL_RELEASE")
release_version=$1
release_link=$2

    # Compare versions before deciding to download
    if [ "$release_version" \> "$current_version" ]; then
        Say "Latest release version is $release_version, downloading from $release_link"
        wget -O "${MODEL}_firmware.zip" "$release_link"
    else
        Say "Current firmware version $current_version is up to date."
        if [[ $1 != "run_now" ]]; then  # Check if the first argument is not "cron"
            read -p "Press Enter to return to the main menu..."
        fi
        return  # Exit the function early as there's no newer firmware
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

# Use Get_Custom_Setting to retrieve the previous choice
previous_choice=$(Get_Custom_Setting "local" "n")

# Logging user's choice
# Check for the presence of "rog" in filenames in the extracted directory
cd "/home/root/${MODEL}_firmware"
rog_file=$(ls | grep -i '_rog_')
pure_file=$(ls | grep -i '_pureubi.w' | grep -iv 'rog')

if [ ! -f "$SETTINGSFILE" ]; then
    if [ ! -z "$rog_file" ]; then
        # Check if the first argument is "run_now"
        if [ "$1" == "run_now" ]; then
            # If the argument is "run_now", default to the "Pure Build"
            firmware_file="$pure_file"
            Update_Custom_Settings "local" "n"
        else
            # Otherwise, prompt the user for their choice
            echo -e "\033[31mFound ROG build: $rog_file. Would you like to use the ROG build? (y/n)\033[0m"
            read -p "Enter your choice [$previous_choice]: " choice
            choice="${choice:-$previous_choice}"
            if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
                firmware_file="$rog_file"
                Update_Custom_Settings "local" "y"
            else
                firmware_file="$pure_file"
                Update_Custom_Settings "local" "n"
            fi
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
Say "\033[32mFlashing $firmware_file...\033[0m"
hnd-write "$firmware_file"  # Execute the command to flash the firmware.

# Wait for 3 minutes
sleep 60

# Reboot the router
reboot
    
    read -p "Press Enter to continue..."
}

if [[ $1 == "run_now" ]]; then
    # If the argument is "run_now", call the run_now function and exit
    run_now
    exit 0
fi

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
    *) echo "Invalid choice. Please try again."
   read -p "Press Enter to continue..."  # Pauses script until Enter is pressed
   ;;
  esac
  else
  read -p "Enter your choice (1/2/e): " choice
  case $choice in
    1) run_now ;;
    2) change_schedule ;;
    e) exit ;;
    *) echo "Invalid choice. Please try again."
   read -p "Press Enter to continue..."  # Pauses script until Enter is pressed
   ;;
  esac
  fi
done
