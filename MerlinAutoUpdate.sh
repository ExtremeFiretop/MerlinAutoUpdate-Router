#!/bin/sh
################################################################
# MerlinAutoUpdate.sh
#
# Creation Date: 2023-Oct-01 by @ExtremeFiretop.
# Last Modified: 2023-Oct-10
################################################################
set -u

readonly SCRIPT_VERSION="0.2.7"
readonly URL_BASE="https://sourceforge.net/projects/asuswrt-merlin/files"
readonly URL_RELEASE_SUFFIX="Release"

##-------------------------------------##
## Added by Martinski W. [2023-Oct-09] ##
##-------------------------------------##
# Save initial LED state to put it back later #
readonly LED_InitState="$(nvram get led_disable)"
LED_ToggleState="$LED_InitState"

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-09] ##
##----------------------------------------##
# Function to toggle LED state
Toggle_Led() {
	LED_ToggleState="$((! LED_ToggleState))"
	nvram set led_disable="$LED_ToggleState"
	service restart_leds > /dev/null 2>&1
	sleep 2
	LED_ToggleState="$((! LED_ToggleState))"
	nvram set led_disable="$LED_ToggleState"
	service restart_leds > /dev/null 2>&1
	sleep 1
}

construct_url() {
    local urlproto urldomain urlport

    if [ "$(nvram get http_enable)" = "1" ]; then
        urlproto="https"
    else
        urlproto="http"
    fi

    if [ -n "$(nvram get lan_domain)" ]; then
        urldomain="$(nvram get lan_hostname).$(nvram get lan_domain)"
    else
        urldomain="$(nvram get lan_ipaddr)"
    fi

    if [ "$(nvram get ${urlproto}_lanport)" = "80" ] || [ "$(nvram get ${urlproto}_lanport)" = "443" ]; then
        urlport=""
    else
        urlport=":$(nvram get ${urlproto}_lanport)"
    fi

    echo "${urlproto}://${urldomain}${urlport}"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-05] ##
##----------------------------------------------##
_GetRouterModel_()
{
   local retCode=1  routerModelID=""
   local nvramModelKeys="productid build_name odmpid"
   for nvramKey in $nvramModelKeys
   do
       routerModelID="$(nvram get "$nvramKey")"
       [ -n "$routerModelID" ] && retCode=0 && break
   done
   echo "$routerModelID" ; return "$retCode"
}

readonly MODEL="$(_GetRouterModel_)"
readonly URL_RELEASE="${URL_BASE}/${MODEL}/${URL_RELEASE_SUFFIX}/"
readonly SETTINGS_DIR="/jffs/addons/MerlinAutoUpdate"
readonly SETTINGSFILE="$SETTINGS_DIR/custom_settings.txt"

##-------------------------------------##
## Added by Martinski W. [2023-Oct-07] ##
##-------------------------------------##
# The directory variable could be set via an argument or a custom setting
# depending on the available RAM & storage capacity of the target router.
# One possibility is to require USB-attached storage for the ZIP file.
#-------------------------------------------------------------------------
FW_SETP_DIR="/home/root"
readonly FW_FileName="${MODEL}_firmware"
readonly FW_TEMP_DIR="${FW_SETP_DIR}/$FW_FileName"
readonly FW_ZIP_FPATH="${FW_TEMP_DIR}/${FW_FileName}.zip"

# Define the cron schedule and job command to execute
readonly CRON_SCHEDULE="0 0 * * 0"
readonly CRON_JOB="sh /jffs/scripts/MerlinAutoUpdate.sh run_now"
readonly CRON_TAG="MerlinAutoUpdate"

##-------------------------------------##
## Added by Martinski W. [2023-Oct-06] ##
##-------------------------------------##
loggerFlags="-t"
isInteractive=false

if [ -n "$(tty)" ] && [ -n "$PS1" ]
then
   loggerFlags="-st"
   isInteractive=true
fi

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-07] ##
##----------------------------------------------##
_WaitForEnterKey_()
{
   ! "$isInteractive" && return 0
   local promptStr

   if [ $# -gt 0 ] && [ -n "$1" ]
   then promptStr="$1"
   else promptStr="Press Enter to continue..."
   fi
   printf "\n%s" "$promptStr" ; read EnterKEY
}

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-06] ##
##----------------------------------------##
Say(){
   echo -e "$@" | logger $loggerFlags "[$(basename "$0")] $$"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-05] ##
##----------------------------------------##
get_current_firmware() {
    local current_version="$(nvram get buildno).$(nvram get extendno)"
    echo "$current_version"
}

get_free_ram() {
    # Using awk to sum up the 'free', 'buffers', and 'cached' columns.
    free | awk '/^Mem:/{print $4 + $6 + $7}'  # This will return the available memory in kilobytes.
}

check_memory_and_reboot() {
    
    if [ ! -f "$FW_TEMP_DIR/$firmware_file" ]; then
        Say "**ERROR**: Firmware file [$FW_TEMP_DIR/$firmware_file] not found."
        exit 1
    fi
    firmware_size_kb=$(du -k "$FW_TEMP_DIR/$firmware_file" | cut -f1)  # Get firmware file size in kilobytes
    free_ram_kb=$(get_free_ram)

    if [ "$free_ram_kb" -lt "$firmware_size_kb" ]; then
        Say "Insufficient RAM available to proceed with the update. Rebooting router..."
        reboot
        exit 1  # Although the reboot command should end the script, it's good practice to exit after.
    fi
}

cleanup() {
    # Check if Toggle_Led_pid is set and if the process with that PID is still running
    if [ -n "$Toggle_Led_pid" ] && kill -0 "$Toggle_Led_pid" 2>/dev/null; then
        kill -15 "$Toggle_Led_pid"  # Terminate the background Toggle_Led process
			# Set LEDs to their "initial state" #
			nvram set led_disable="$LED_InitState"
			service restart_leds > /dev/null 2>&1
    fi
    
    # Additional cleanup operations can be added here if needed
	exit 1
}

print_center() {
    termwidth=$(stty size | cut -d ' ' -f 2)
    paddingwidth=$(( (termwidth - ${#1} - 4) / 2 ))  # Added 4 for color codes
    padding=$(printf "%0.s=" $(eval "echo {1..$paddingwidth}"))
    printf '%s %s %s\n' "$padding" "$1" "$padding"
}

##-------------------------------------##
## Added by Martinski W. [2023-Oct-06] ##
##-------------------------------------##
_VersionFormatToNumber_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo "" ; return 1 ; fi

   local versionNum  versionStr="$1"

   if [ "$(echo "$1" | awk -F '.' '{print NF}')" -lt "$2" ]
   then versionStr="$(nvram get firmver | sed 's/\.//g').$1" ; fi

   if [ "$2" -lt 4 ]
   then versionNum="$(echo "$versionStr" | awk -F '.' '{printf ("%d%03d%03d\n", $1,$2,$3);}')"
   else versionNum="$(echo "$versionStr" | awk -F '.' '{printf ("%d%d%03d%03d\n", $1,$2,$3,$4);}')"
   fi

   echo "$versionNum" ; return 0
}

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-07] ##
##----------------------------------------##
# Function to check if the current router model is supported
check_model_support() {
    # Minimum supported firmware version
    local minimum_supported_version="386.11.0"

    # Get the current firmware version
    local current_version="$(get_current_firmware)"

    local numFields="$(echo "$current_version" | awk -F '.' '{print NF}')"
    local numCurrentVers="$(_VersionFormatToNumber_ "$current_version" "$numFields")"
    local numMinimumVers="$(_VersionFormatToNumber_ "$minimum_supported_version" "$numFields")"

    # If the current firmware version is lower than the minimum supported firmware version, exit.
    if [ "$numCurrentVers" -lt "$numMinimumVers" ]
    then
        Say "\033[31mThe installed firmware version '$current_version' is below '$minimum_supported_version' which is the minimum supported version required.\033[0m" 
		Say "\033[31mExiting...\033[0m"
        exit 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-07] ##
##----------------------------------------##
# Function to get custom setting value from the settings file
Get_Custom_Setting()
{
    if [ $# -eq 0 ] || [ -z "$1" ]; then echo "**ERROR**" ; fi

    local setting_type="$1"  default_value="N/A"
    if [ $# -gt 1 ] ; then default_value="$2" ; fi

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

##----------------------------------------##
## Modified by ExtremeFiretop [2023-Oct-10] ##
##----------------------------------------##
credentials_menu() {
    echo "=== Credentials Menu ==="

    # Get the username from nvram
    local username=$(nvram get http_username)
    
    # Prompt the user only for a password
    read -s -p "Enter password for user ${username}: " password  # -s flag hides the password input
    echo  # Output a newline
	
	if [ -z "$password" ]
    then
        echo "The Username and Password cannot be empty. Credentials were not saved."
        _WaitForEnterKey_ "Press Enter to return to the main menu..."
        return 1
    fi
    
    # Encode the username and password in Base64
    credentials_base64="$(echo -n "${username}:${password}" | openssl base64)"
    
    # Use Update_Custom_Settings to save the credentials to the SETTINGSFILE
    Update_Custom_Settings "credentials_base64" "$credentials_base64"
    
    echo "Credentials saved."
    _WaitForEnterKey_ "Press Enter to return to the main menu..."
	return 0
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

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-05] ##
##----------------------------------------##
get_latest_firmware() {
    local url="$1"

    local links_and_versions="$(curl -s "$url" | grep -o 'href="[^"]*'"$MODEL"'[^"]*\.zip' | sed 's/amp;//g; s/href="//' | 
        awk -F'[_\.]' '{print $3"."$4"."$5" "$0}' | sort -t. -k1,1n -k2,2n -k3,3n)"

    if [ -z "$links_and_versions" ]
    then echo "**ERROR** **NO_URL**" ; return 1 ; fi

    local latest="$(echo "$links_and_versions" | tail -n 1)"
    local linkStr="$(echo "$latest" | cut -d' ' -f2-)"
    local fileStr="$(echo "$linkStr" | grep -oE "/${MODEL}_[0-9]+.*.zip$")"
    local versionStr

    if [ -z "$fileStr" ]
    then versionStr="$(echo "$latest" | cut -d ' ' -f1)"
    else versionStr="$(echo ${fileStr%.*} | sed "s/\/${MODEL}_//" | sed 's/_/./g')"
    fi

    # Extracting the correct link from the page
    local correct_link="$(echo "$linkStr" | sed 's|^/|https://sourceforge.net/|')"

    echo "$versionStr"
    echo "$correct_link"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-07] ##
##----------------------------------------##
change_build_type() {
    echo "Changing Build Type..."
    
    # Use Get_Custom_Setting to retrieve the previous choice
    previous_choice="$(Get_Custom_Setting "local" "n")"

    # Logging user's choice
    # Check for the presence of "rog" in filenames in the extracted directory
    cd "$FW_TEMP_DIR"
    rog_file="$(ls | grep -i '_rog_')"
    pure_file="$(ls | grep -i '_pureubi.w' | grep -iv 'rog')"

    if [ ! -z "$rog_file" ]; then
        echo -e "\033[31mFound ROG build: $rog_file. Would you like to use the ROG build? (y/n)\033[0m"

        while true; do
            # Use the previous_choice as the default value
            read -p "Enter your choice [$previous_choice]: " choice

            # Use the entered choice or the default value if the input is empty
            choice="${choice:-$previous_choice}"

            # Convert to lowercase to make comparison easier
            choice="$(echo "$choice" | tr '[:upper:]' '[:lower:]')"

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

    _WaitForEnterKey_
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

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-07] ##
##----------------------------------------##
# Function to add or change the cron schedule
change_schedule() {
  echo "Changing Schedule..."
  
  # Use crontab -l to retrieve all cron jobs and filter for the one containing the script's path
  current_schedule_line="$(crontab -l | grep "$CRON_JOB")"
  
  
  if [ -n "$current_schedule_line" ]; then
    # Extract the schedule part (the first five fields) from the current cron job line
    current_schedule="$(echo "$current_schedule_line" | awk '{print $1, $2, $3, $4, $5}')"
    
    # Translate the current schedule to English
    current_schedule_english="$(translate_schedule "$current_schedule")"
    
    echo -e "\033[32mCurrent Schedule: $current_schedule_english \033[0m"
  else
    echo "Cron job '${CRON_TAG}' does not exist. It will be added."
  fi

     while true; do  # Loop to keep asking for input
        read -p "Enter new cron schedule (e.g., 0 0 * * 0 for every Sunday at midnight, or 'e' to exit): " new_schedule
    
        # If the user enters 'e', break out of the loop and return to the main menu
        if [ "$new_schedule" = "e" ]; then
            echo "Returning to main menu..."
            return
        fi

        # Validate the input using grep
        if echo "$new_schedule" | grep -qE '^([0-9,*\/-]+[[:space:]]+){4}[0-9,*\/-]+$'
        then
            new_schedule="$(echo "$new_schedule" | awk '{print $1, $2, $3, $4, $5}')"
            break  # If valid input, break out of the loop
        else
            echo "Invalid schedule. Please try again or press 'e' to exit."
        fi
    done

    # Update the cron job in the crontab using the built-in utility.
    echo "Adding '${CRON_TAG}' cron job..."
    cru a "$CRON_TAG" "$new_schedule $CRON_JOB" ; sleep 1

    if crontab -l | grep -qF "$CRON_JOB"; then
        echo "Cron job '${CRON_TAG}' updated successfully."
    else
        echo "Failed to update the cron job."
    fi

    # Display the updated schedule
    current_schedule_english="$(translate_schedule "$new_schedule")"
    echo -e "\033[32mUpdated Schedule: $current_schedule_english \033[0m"

    # Return to the main menu
    _WaitForEnterKey_ "Press Enter to return to the main menu..."
}

# Check if the router model is supported OR if
# it has the minimum firmware version supported.
check_model_support

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-06] ##
##----------------------------------------##
# Check if the cron job command already exists
if ! crontab -l | grep -qF "$CRON_JOB"; then
   # Add the cron job if it doesn't exist
   echo "Adding '${CRON_TAG}' cron job..."
   cru a "$CRON_TAG" "$CRON_SCHEDULE $CRON_JOB" ; sleep 1

   # Verify that the cron job has been added
   if crontab -l | grep -qF "$CRON_JOB"; then
      echo "Cron job '${CRON_TAG}' added successfully."
   else
      echo "Failed to add the cron job."
   fi
   _WaitForEnterKey_
else
   echo "Cron job '${CRON_TAG}' already exists."
fi

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-09] ##
##----------------------------------------##
# Embed functions from second script, modified as necessary.
run_now() {

    Say "Running the task now...Checking for updates..."

    # Get current firmware version
    current_version="$(get_current_firmware)"	
    #current_version="388.3.0"

    # Use set to read the output of the function into variables
    set -- $(get_latest_firmware "$URL_RELEASE")
    release_version="$1"
    release_link="$2"

    if [ "$1" = "**ERROR**" ] && [ "$2" = "**NO_URL**" ] 
    then
        Say "**ERROR**: No firmware release URL was found for [$MODEL] router model."
        _WaitForEnterKey_
        return 1
    fi

    local numFields="$(echo "$release_version" | awk -F '.' '{print NF}')"
    local numCurrentVers="$(_VersionFormatToNumber_ "$current_version" "$numFields")"
    local numReleaseVers="$(_VersionFormatToNumber_ "$release_version" "$numFields")"

    # Create directory for downloading & extracting firmware #
    mkdir -p "$FW_TEMP_DIR"
    if [ -d "$FW_TEMP_DIR" ]
    then
        cd "$FW_TEMP_DIR"
    else
        Say "**ERROR**: Unable to create directory [$FW_TEMP_DIR] to download firmware."
        _WaitForEnterKey_
        return 1
    fi
    # Clear directory in case any previous files still exist #
    rm -f "${FW_TEMP_DIR}"/*

    # Compare versions before deciding to download
    if [ "$numReleaseVers" -gt "$numCurrentVers" ]; then
	
		# Start a loop to create a blinking LED effect while checking for updates
		while true; do
			Toggle_Led
		done &
		
		# Capture the background loop's PID
		Toggle_Led_pid=$!
		
		trap cleanup EXIT INT TERM
		
        Say "Latest release version is $release_version, downloading from $release_link"
        wget -O "$FW_ZIP_FPATH" "$release_link"
    else
        Say "Current firmware version $current_version is up to date."
        if [ "$1" != "run_now" ]; then  # Check if the first argument is not "cron"
            _WaitForEnterKey_ "Press Enter to return to the main menu..."
        fi
        return 0  # Exit the function early as there's no newer firmware
    fi

    if [ ! -f "$FW_ZIP_FPATH" ]
    then
        Say "**ERROR**: Firmware ZIP file [$FW_ZIP_FPATH] was not downloaded."
        _WaitForEnterKey_
        return 1
    fi

    # Extracting the firmware
    unzip -o "$FW_ZIP_FPATH" -d "$FW_TEMP_DIR" -x README*

    # If unzip was successful delete the zip file, else error out.
    if [ $? -eq 0 ]
    then
        rm -f "$FW_ZIP_FPATH"
    else
        Say "**ERROR**: Unable to decompress the firmware ZIP file [$FW_ZIP_FPATH]."
        _WaitForEnterKey_
        return 1
    fi

# Define the path to the log file
#log_file="${FW_TEMP_DIR}/Changelog-NG.txt"

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
    previous_choice="$(Get_Custom_Setting "local" "n")"

    # Logging user's choice
    # Check for the presence of "rog" in filenames in the extracted directory
    cd "$FW_TEMP_DIR"
    rog_file="$(ls | grep -i '_rog_')"
    pure_file="$(ls | grep -i '_pureubi.w' | grep -iv 'rog')"

    local_value="$(Get_Custom_Setting "local")"

if [ -z "$local_value" ]; then
    if [ ! -z "$rog_file" ]; then
        # Check if the first argument is "run_now"
        if [ "$1" = "run_now" ]; then
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
		Say "**ERROR**: Extracted firmware does not match the SHA256 signature!"
		_WaitForEnterKey_
		return 1
	fi
fi

    # Flashing the chosen firmware

    # Use Get_Custom_Setting to retrieve the previous choice
    previous_creds="$(Get_Custom_Setting "credentials_base64")"

    # Debug: Print the LAN IP to ensure it's being set correctly
    echo "Debug Web URL is: $(construct_url) "
	
	check_memory_and_reboot

    Say "\033[32mFlashing $firmware_file... Please Wait for reboot.\033[0m"

    curl_response="$(curl "$(construct_url)/login.cgi" \
    --referer $(construct_url)/Main_Login.asp \
    --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Origin: $(construct_url)/" \
    -H 'Connection: keep-alive' \
    --data-raw "group_id=&action_mode=&action_script=&action_wait=5&current_page=Main_Login.asp&next_page=index.asp&login_authorization=${previous_creds}" \
    --cookie-jar /tmp/cookie.txt)"

# IMPORTANT: Due to the nature of 'nohup' and the specific behavior of this 'curl' request,
# the following 'curl' command MUST always be the last step in this block.
# Do NOT insert any operations after it! (unless you understand the implications).

if echo "$curl_response" | grep -q 'url=index.asp'; then
    nohup curl "$(construct_url)/upgrade.cgi" \
    --referer $(construct_url)/Advanced_FirmwareUpgrade_Content.asp \
    --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H "Origin: $(construct_url)/" \
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
    Say "**ERROR**: Login failed. Please confirm credentials by selecting: 1. Configure Credentials"
fi
	# Stop the LED blinking after the update is completed
	kill -15 "$Toggle_Led_pid" # Terminate the background toggle_led loop	

	# Set LEDs to their "initial state" #
	nvram set led_disable="$LED_InitState"
	service restart_leds > /dev/null 2>&1
    _WaitForEnterKey_
}

if [ $# -gt 0 ] && [ "$1" = "run_now" ]; then
    # If the argument is "run_now", call the run_now function and exit
    run_now
    exit 0
fi

rog_file=""

# Function to display the menu
show_menu() {
  clear
  echo -e "\033[1;36m===== Merlin Auto Update Main Menu =====\033[0m"
  echo -e "\033[1;35m========== By ExtremeFiretop ===========\033[0m"
  echo -e "\033[1;33m============ Contributors: =============\033[0m"
  echo -e "\033[1;33m"
  print_center 'Martinski W.'
  print_center 'Dave14305'
  echo -e "\033[0m"  # Reset color
  echo "----------------------------------------"
  echo "1. Configure Credentials"
  echo "2. Run now"
  
  # Check if the directory exists before attempting to navigate to it
  if [ -d "$FW_TEMP_DIR" ]; then
    cd "$FW_TEMP_DIR"
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
  if [ -d "$FW_TEMP_DIR" ]; then
    cd "$FW_TEMP_DIR"
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
       _WaitForEnterKey_  # Pauses script until Enter is pressed
       ;;
  esac
done
