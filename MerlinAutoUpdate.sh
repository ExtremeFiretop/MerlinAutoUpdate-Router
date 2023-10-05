#!/bin/sh

URL_BASE="https://sourceforge.net/projects/asuswrt-merlin/files"
URL_RELEASE_SUFFIX="Release"

MODEL=$(nvram get model)
URL_RELEASE="${URL_BASE}/${MODEL}/${URL_RELEASE_SUFFIX}/"
SETTINGS_DIR="/jffs/addons/MerlinAutoUpdate"
SETTINGSFILE="$SETTINGS_DIR/custom_settings.txt"

# Define the cron schedule and command to execute
CRON_SCHEDULE="0 0 * * 0"
COMMAND="sh /jffs/scripts/MerlinAutoUpdate.sh run_now"

# Function to get LAN IP
get_lan_ip() {
    local lan_ip
    lan_ip=$(nvram get lan_ipaddr)
    echo "$lan_ip"  # This will return just the IP address
}

Say(){
   echo -e $$ $@ | logger -st "($(basename $0))"
}

# Function to check if the current router model is supported
check_model_support() {
    # List of unsupported models as a space-separated string
    local unsupported_models="RT-AC1900 RT-AC87U RT-AC5300 RT-AC3200 RT-AC3100 RT-AC88U RT-AC68U RT-AC66U RT-AC56U RT-AC66U_B1 RT-N66U"
    
    # Get the current model
    local current_model=$(nvram get model)
    
    # Check if the current model is in the list of unsupported models
    if echo "$unsupported_models" | grep -wq "$current_model"; then
        # Output a message and exit the script if the model is unsupported
        Say "The $current_model is an unsupported model. Exiting..."
        exit 1
    fi
}

check_model_support

# Function to get custom setting value from the settings file
Get_Custom_Setting() {
    local setting_type="$1"
    local default_value="$2"

    if [ -f "$SETTINGSFILE" ]; then
        case "$setting_type" in
            credentials_base64)
                grep -q "credentials_base64" "$SETTINGSFILE" && grep "credentials_base64" "$SETTINGSFILE" | cut -f2 -d' ' || echo "$default_value"
                ;;
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

credentials_menu() {
    echo "=== Credentials Menu ==="
    
    # Prompt the user for a username and password
    read -p "Enter username: " username
    read -s -p "Enter password: " password  # -s flag hides the password input
    echo  # Output a newline
    
    # Encode the username and password in Base64
    credentials_base64=$(echo -n "$username:$password" | openssl base64)
    
    # Use Update_Custom_Settings to save the credentials to the SETTINGSFILE
    Update_Custom_Settings "credentials_base64" "$credentials_base64"
    
    echo "Credentials saved."
    read -p "Press Enter to return to the main menu..."
}

Update_Custom_Settings() {
    local setting_type="$1"
    local setting_value="$2"

    # Check if the directory exists, and if not, create it
    if [ ! -d "$SETTINGS_DIR" ]; then
        mkdir -p "$SETTINGS_DIR"
    fi

    case "$setting_type" in
        local|credentials_base64)
            if [ -f "$SETTINGSFILE" ]; then
                if [ "$(grep -c "$setting_type" "$SETTINGSFILE")" -gt 0 ]; then
                    if [ "$setting_value" != "$(grep "$setting_type" "$SETTINGSFILE" | cut -f2 -d' ')" ]; then
                        sed -i "s/$setting_type.*/$setting_type $setting_value/" "$SETTINGSFILE"
                    fi
                else
                    echo "$setting_type $setting_value" >> "$SETTINGSFILE"
                fi
            else
                echo "$setting_type $setting_value" >> "$SETTINGSFILE"
            fi
            ;;
        *)
            echo "Invalid setting type: $setting_type"
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
    
# Use Get_Custom_Setting to retrieve the previous choice
previous_choice=$(Get_Custom_Setting "local" "n")

# Logging user's choice
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
fi

# Embed functions from second script, modified as necessary.
run_now() {

Say "Running the task now...Checking for updates..."

# Get current firmware version
current_version=$(get_current_firmware)	
#current_version="388.3"

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
unzip -o "${MODEL}_firmware.zip" -d "/home/root/${MODEL}_firmware" -x README*

# If unzip was successful, delete the zip file
if [ $? -eq 0 ]; then
    rm -f "${MODEL}_firmware.zip"
fi

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
previous_choice=$(Get_Custom_Setting "local")

# Logging user's choice
# Check for the presence of "rog" in filenames in the extracted directory
cd "/home/root/${MODEL}_firmware"
rog_file=$(ls | grep -i '_rog_')
pure_file=$(ls | grep -i '_pureubi.w' | grep -iv 'rog')

local_value=$(Get_Custom_Setting "local")

if [[ -z "$local_value" ]]; then
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

if [ -f "sha256sum.sha256" ] && [ -f "$firmware_file" ]; then
	fw_sig="$(openssl sha256 $firmware_file | cut -d' ' -f2)"
	dl_sig="$(grep $firmware_file sha256sum.sha256 | cut -d' ' -f1)"
	if [ "$fw_sig" != "$dl_sig" ]; then
		Say "Extracted firmware does not match the SHA256 signature! Aborting"
		exit 1
	fi
fi

# Flashing the chosen firmware

# Use Get_Custom_Setting to retrieve the previous choice
previous_creds=$(Get_Custom_Setting "credentials_base64")

# Assuming get_lan_ip is the function that sets lan_ip
lan_ip=$(get_lan_ip)

# Debug: Print the LAN IP to ensure it's being set correctly
echo "Debug: LAN IP is $lan_ip"


Say "\033[32mFlashing $firmware_file...\033[0m"
curl_response=$(curl "http://${lan_ip}/login.cgi" \
--referer http://$lan_ip/Main_Login.asp \
--user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
-H 'Accept-Language: en-US,en;q=0.5' \
-H 'Content-Type: application/x-www-form-urlencoded' \
-H "Origin: http://${lan_ip}/" \
-H 'Connection: keep-alive' \
--data-raw "group_id=&action_mode=&action_script=&action_wait=5&current_page=Main_Login.asp&next_page=index.asp&login_authorization=${previous_creds}" \
--cookie-jar /tmp/cookie.txt)

if echo "$curl_response" | grep -q 'url=index.asp'; then
nohup curl "http://$lan_ip/upgrade.cgi" \
    --referer http://$lan_ip/Advanced_FirmwareUpgrade_Content.asp \
    --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H "Origin: http://${lan_ip}/" \
    -F 'current_page=Advanced_FirmwareUpgrade_Content.asp' \
    -F 'next_page=' \
    -F 'action_mode=' \
    -F 'action_script=' \
    -F 'action_wait=' \
    -F 'preferred_lang=EN' \
    -F 'firmver=3.0.0.4' \
    -F "file=@${firmware_file}" \
    --cookie /tmp/cookie.txt > /tmp/upload_response.txt 2>&1 &
	sleep 60
else
    Say "Login failed. Please confirm credentials by selecting: 1. Configure Credentials"
fi

read -p "Press Enter to continue..."
}

if [[ -n "$1" && "$1" == "run_now" ]]; then
    # If the argument is "run_now", call the run_now function and exit
    run_now
    exit 0
fi

# Function to display the menu
show_menu() {
  clear
  echo "===== Merlin Auto Update Main Menu ====="
  echo "1. Configure Credentials"
  echo "2. Run now"
  
  # Check if the directory exists before attempting to navigate to it
  if [ -d "/home/root/${MODEL}_firmware" ]; then
    cd "/home/root/${MODEL}_firmware"
    # Check for the presence of "rog" in filenames in the directory
    rog_file=$(ls | grep -i '_rog_')
    
    # If a file with "_rog_" in its name is found, display the "Change Build Type" option
    if [ ! -z "$rog_file" ]; then
      echo "3. Change Build Type"
      echo "4. Change Schedule"
      echo "e. Exit"
    else
      echo "3. Change Schedule"
      echo "e. Exit"
    fi
  else
    echo "3. Change Schedule"
    echo "e. Exit"
  fi
}

# Main loop
while true; do
  show_menu
  # Check if the directory exists again before attempting to navigate to it
  if [ -d "/home/root/${MODEL}_firmware" ]; then
    cd "/home/root/${MODEL}_firmware"
    # Check for the presence of "rog" in filenames in the directory again
    rog_file=$(ls | grep -i '_rog_')
    
    if [ ! -z "$rog_file" ]; then
      read -p "Enter your choice (1/2/3/4/e): " choice
    else
      read -p "Enter your choice (1/2/3/e): " choice
    fi
  else
    read -p "Enter your choice (1/2/3/e): " choice
  fi
  
  case $choice in
    1) credentials_menu ;;
    2) run_now ;;
    3) [ ! -z "$rog_file" ] && change_build_type || change_schedule ;;
    4) change_schedule ;;
    e) exit ;;
    *) echo "Invalid choice. Please try again."
       read -p "Press Enter to continue..."  # Pauses script until Enter is pressed
       ;;
  esac
done
