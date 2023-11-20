#!/bin/sh
################################################################
# MerlinAutoUpdate.sh
#
# Creation Date: 2023-Oct-01 by @ExtremeFiretop.
# Last Modified: 2023-Nov-19
################################################################
set -u

readonly SCRIPT_VERSION="0.2.15"
readonly URL_BASE="https://sourceforge.net/projects/asuswrt-merlin/files"
readonly URL_RELEASE_SUFFIX="Release"

##-------------------------------------##
## Added by Martinski W. [2023-Oct-16] ##
##-------------------------------------##
readonly ADDONS_PATH="/jffs/addons"
readonly SCRIPTS_PATH="/jffs/scripts"

readonly ScriptFileName="${0##*/}"
readonly ScriptFNameTag="${ScriptFileName%.*}"

ScriptsDirPath="$(/usr/bin/dirname "$0")"
if [ "$ScriptsDirPath" != "." ]
then
   ScriptFilePath="$0"
else
   ScriptsDirPath="$(pwd)"
   ScriptFilePath="$(pwd)/$ScriptFileName"
fi

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-18] ##
##----------------------------------------------##
# Save initial LEDs state to put it back later #
readonly LED_InitState="$(nvram get led_disable)"
LED_ToggleState="$LED_InitState"
Toggle_LEDs_PID=""

# To enable/disable the built-in "F/W Update Check" #
FW_UpdateCheckState="TBD"
FW_UpdateCheckScript="/usr/sbin/webs_update.sh"

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-09] ##
##----------------------------------------##
# Function to toggle LEDs state
Toggle_LEDs()
{
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

##-------------------------------------##
## Added by Martinski W. [2023-Nov-18] ##
##-------------------------------------##
readonly FW_Update_ZIP_DefaultSetupDIR="/home/root"
readonly FW_Update_CRON_DefaultSchedule="0 0 * * 0"

# To postpone a firmware update for a few days #
readonly FW_UpdateMinimumPostponementDays=0
readonly FW_UpdateDefaultPostponementDays=7
readonly FW_UpdateMaximumPostponementDays=30
readonly FW_UpdateNotificationDateFormat="%Y-%m-%d_12:00:00"

readonly MODEL="$(_GetRouterModel_)"
readonly URL_RELEASE="${URL_BASE}/${MODEL}/${URL_RELEASE_SUFFIX}/"
readonly SETTINGS_DIR="${ADDONS_PATH}/$ScriptFNameTag"
readonly SETTINGSFILE="${SETTINGS_DIR}/custom_settings.txt"

##-------------------------------------##
## Added by Martinski W. [2023-Nov-18] ##
##-------------------------------------##
_Init_Custom_Settings_Config_()
{
   [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

   if [ ! -f "$SETTINGSFILE" ]
   then
      {
         echo "FW_New_Update_Notification_Date TBD"
         echo "FW_New_Update_Notification_Vers TBD"
         echo "FW_New_Update_Postponement_Days=$FW_UpdateDefaultPostponementDays"
         echo "FW_New_Update_Cron_Job_Schedule=\"${FW_Update_CRON_DefaultSchedule}\""
         echo "FW_New_Update_ZIP_Directory_Path=\"${FW_Update_ZIP_DefaultSetupDIR}\""
      } > "$SETTINGSFILE"
      return 1
   fi
   local retCode=0

   if ! grep -q "^FW_New_Update_Postponement_Days=" "$SETTINGSFILE"
   then
       sed -i "1 i FW_New_Update_Postponement_Days=$FW_UpdateDefaultPostponementDays" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_Cron_Job_Schedule=" "$SETTINGSFILE"
   then
       sed -i "2 i FW_New_Update_Cron_Job_Schedule=\"${FW_Update_CRON_DefaultSchedule}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_ZIP_Directory_Path=" "$SETTINGSFILE"
   then
       sed -i "3 i FW_New_Update_ZIP_Directory_Path=\"${FW_Update_ZIP_DefaultSetupDIR}\"" "$SETTINGSFILE"
       retCode=1
   fi
   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-18] ##
##----------------------------------------##
# Function to get custom setting value from the settings file
Get_Custom_Setting()
{
    if [ $# -eq 0 ] || [ -z "$1" ] ; then echo "**ERROR**" ; return 1 ; fi

    local setting_type="$1"  default_value="TBD"

    [ $# -gt 1 ] && default_value="$2"
    [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

    if [ -f "$SETTINGSFILE" ]; then
        case "$setting_type" in
            "credentials_base64" | \
            "FW_New_Update_Notification_Date" | \
            "FW_New_Update_Notification_Vers")
                grep -q "^$setting_type" "$SETTINGSFILE" && grep "^$setting_type" "$SETTINGSFILE" | cut -f2 -d' ' || echo "$default_value"
                ;;
            local)
                grep -q "^FirmwareVersion_setting" "$SETTINGSFILE" && grep "^FirmwareVersion_setting" "$SETTINGSFILE" | cut -f2 -d' ' || echo "$default_value"
                ;;
            "FW_New_Update_Postponement_Days" | \
            "FW_New_Update_Cron_Job_Schedule" | \
            "FW_New_Update_ZIP_Directory_Path")
                if ! grep -q "^${setting_type}=" "$SETTINGSFILE"
                then echo "$default_value"
                else echo "$(grep "^${setting_type}=" "$SETTINGSFILE" | awk -F '=' '{print $2}' | sed "s/['\"]//g")"
                fi
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
## Modified by Martinski W. [2023-Nov-18] ##
##----------------------------------------##
Update_Custom_Settings()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] ; then return 1 ; fi

    local fixedVal  oldVal=""
    local setting_type="$1"  setting_value="$2"

    # Check if the directory exists, and if not, create it
    [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

    case "$setting_type" in
        "local" | "credentials_base64" | \
        "FW_New_Update_Notification_Date" | \
        "FW_New_Update_Notification_Vers")
            if [ -f "$SETTINGSFILE" ]; then
                if [ "$(grep -c "$setting_type" "$SETTINGSFILE")" -gt 0 ]; then
                    if [ "$setting_value" != "$(grep "^$setting_type" "$SETTINGSFILE" | cut -f2 -d' ')" ]; then
                        sed -i "s/$setting_type.*/$setting_type $setting_value/" "$SETTINGSFILE"
                    fi
                else
                    echo "$setting_type $setting_value" >> "$SETTINGSFILE"
                fi
            else
                echo "$setting_type $setting_value" > "$SETTINGSFILE"
            fi
            ;;
        "FW_New_Update_Postponement_Days" | \
        "FW_New_Update_Cron_Job_Schedule" | \
        "FW_New_Update_ZIP_Directory_Path")
            if [ -f "$SETTINGSFILE" ]
            then
                if grep -q "^${setting_type}=" "$SETTINGSFILE"
                then
                    oldVal="$(grep "^${setting_type}=" "$SETTINGSFILE" | awk -F '=' '{print $2}' | sed "s/['\"]//g")"
                    if [ -z "$oldVal" ] || [ "$oldVal" != "$setting_value" ]
                    then
                        fixedVal="$(echo "$setting_value" | sed 's/[\/.,*-]/\\&/g')"
                        sed -i "s/${setting_type}=.*/${setting_type}=\"${fixedVal}\"/" "$SETTINGSFILE"
                    fi
                else
                    echo "$setting_type=\"${setting_value}\"" >> "$SETTINGSFILE"
                fi
            else
                echo "$setting_type=\"${setting_value}\"" > "$SETTINGSFILE"
            fi
            if [ "$setting_type" = "FW_New_Update_ZIP_Directory_Path" ]
            then
                FW_ZIP_SETUP_DIR="$setting_value"
                FW_ZIP_DIR="${setting_value}/$FW_FileName"
                FW_ZIP_FPATH="${FW_ZIP_DIR}/${FW_FileName}.zip"
            #
            elif [ "$setting_type" = "FW_New_Update_Postponement_Days" ]
            then
                FW_UpdatePostponementDays="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_Cron_Job_Schedule" ]
            then
                FW_UpdateCronJobSchedule="$setting_value"
            fi
            ;;
        *)
            echo "Invalid setting type: $setting_type"
            ;;
    esac
}

##-------------------------------------##
## Added by Martinski W. [2023-Nov-19] ##
##-------------------------------------##
_Set_FW_UpdateZIP_DirectoryPath_()
{
   local newZIP_SetupDirPath="$FW_ZIP_SETUP_DIR"  newZIP_FileDirPath="" 

   while true
   do
      printf "\nEnter the directory path where the Firmware ZIP file will be stored.\n"
      printf "[${theExitStr}] [DEFAULT: ${GRNct}${FW_ZIP_SETUP_DIR}${NOct}]:  "
      read -r userInput

      if [ -z "$userInput" ] || echo "$userInput" | grep -qE "^(e|exit|Exit)$"
      then break ; fi

      if echo "$userInput" | grep -q '/$'
      then userInput="${userInput%/*}" ; fi

      if echo "$userInput" | grep -q '//'   || \
         echo "$userInput" | grep -q '/$'   || \
         ! echo "$userInput" | grep -q '^/' || \
         [ "${#userInput}" -lt 4 ]          || \
         [ "$(echo "$userInput" | awk -F '/' '{print NF-1}')" -lt 2 ]
      then
          printf "${REDct}INVALID input.${NOct}\n"
          continue
      fi

      if [ -d "$userInput" ]
      then newZIP_SetupDirPath="$userInput" ; break ; fi

      rootDir="${userInput%/*}"
      if [ ! -d "$rootDir" ]
      then
          printf "\n${REDct}**ERROR**${NOct}: Root directory path [${REDct}${rootDir}${NOct}] does NOT exist.\n\n"
          printf "${REDct}INVALID input.${NOct}\n"
          continue
      fi

      printf "The directory path '${REDct}${userInput}${NOct}' does NOT exist.\n\n"
      if ! _WaitForYESorNO_ "Do you want to create it now"
      then
          printf "Directory was ${REDct}NOT${NOct} created.\n\n"
      else
          mkdir -m 755 "$userInput" 2>/dev/null
          if [ -d "$userInput" ]
          then newZIP_SetupDirPath="$userInput" ; break
          else printf "\n${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${userInput}${NOct}].\n\n"
          fi
      fi
   done

   if [ "$newZIP_SetupDirPath" != "$FW_ZIP_SETUP_DIR" ] && [ -d "$newZIP_SetupDirPath" ]
   then
       if  [ "${newZIP_SetupDirPath##*/}" != "$FW_FileName" ]
       then newZIP_FileDirPath="${newZIP_SetupDirPath}/$FW_FileName" ; fi
       mkdir -m 755 "$newZIP_FileDirPath" 2>/dev/null
       if [ ! -d "$newZIP_FileDirPath" ]
       then
           printf "\n${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${newZIP_FileDirPath}${NOct}].\n"
           _WaitForEnterKey_
           return 1
       fi
       rm -fr "$FW_ZIP_DIR"
       rm -f "${newZIP_FileDirPath}"/*.zip  "${newZIP_FileDirPath}"/*.sha256
       Update_Custom_Settings FW_New_Update_ZIP_Directory_Path "$newZIP_SetupDirPath"
       echo "The directory path for the F/W ZIP file was updated successfully."
       _WaitForEnterKey_ "$menuReturnPromptStr"
   fi
   return 0
}

_Init_Custom_Settings_Config_

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-18] ##
##----------------------------------------------##
# NOTE:
# Depending on available RAM & storage capacity of the 
# target router, it may be required to have USB-attached 
# storage for the ZIP file so that it can be downloaded
# in a separate directory from the firmware bin file.
#-----------------------------------------------------------
FW_BIN_SETUP_DIR="$FW_Update_ZIP_DefaultSetupDIR"
FW_ZIP_SETUP_DIR="$(Get_Custom_Setting FW_New_Update_ZIP_Directory_Path)"

readonly FW_FileName="${MODEL}_firmware"
readonly FW_BIN_DIR="${FW_BIN_SETUP_DIR}/$FW_FileName"

FW_ZIP_DIR="${FW_ZIP_SETUP_DIR}/$FW_FileName"
FW_ZIP_FPATH="${FW_ZIP_DIR}/${FW_FileName}.zip"

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-18] ##
##----------------------------------------------##
# The built-in F/W hook script file to be used for
# setting up persistent jobs to run after a reboot.
readonly hookScriptFName="services-start"
readonly hookScriptFPath="${SCRIPTS_PATH}/$hookScriptFName"
readonly hookScriptTagStr="#Added by $ScriptFNameTag#"

# Postponement Days for F/W Update Check #
FW_UpdatePostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days)"

# Define the CRON job command to execute #
FW_UpdateCronJobSchedule="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
readonly CRON_JOB_RUN="sh $ScriptFilePath run_now"
readonly CRON_JOB_TAG="$ScriptFNameTag"
readonly CRON_SCRIPT_JOB="sh $ScriptFilePath addCronJob &  $hookScriptTagStr"
readonly CRON_SCRIPT_HOOK="[ -f $ScriptFilePath ] && $CRON_SCRIPT_JOB"

# Define post-reboot run job command to execute #
readonly POST_REBOOT_SCRIPT_JOB="sh $ScriptFilePath postRebootRun &  $hookScriptTagStr"
readonly POST_REBOOT_SCRIPT_HOOK="[ -f $ScriptFilePath ] && $POST_REBOOT_SCRIPT_JOB"

##-------------------------------------##
## Added by Martinski W. [2023-Nov-18] ##
##-------------------------------------##
readonly NOct="\033[0m"  
readonly REDct="\033[0;31m\033[1m"  
readonly GRNct="\033[1;32m\033[1m"

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-12] ##
##----------------------------------------------##
loggerFlags="-t"
inMenuMode=true
isInteractive=false
menuReturnPromptStr="Press Enter to return to the main menu..."

if [ -n "$(tty)" ] && [ -n "$PS1" ]
then isInteractive=true ; fi

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-12] ##
##----------------------------------------------##
_WaitForEnterKey_()
{
   ! "$isInteractive" && return 0
   local promptStr

   if [ $# -gt 0 ] && [ -n "$1" ]
   then promptStr="$1"
   else promptStr="Press Enter to continue..."
   fi

   printf "\n%s" "$promptStr"
   read -s EnterKEY ; echo
}

##----------------------------------##
## Added Martinski W. [2023-Oct-12] ##
##----------------------------------##
_WaitForYESorNO_()
{
   ! "$isInteractive" && return 0
   printf "$1 [yY|nN] N? "
   read YESorNO
   if echo "$YESorNO" | grep -qE "^([Yy](es)?)$"
   then echo "OK" ; return 0
   else echo "NO" ; return 1
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-12] ##
##----------------------------------------##
Say(){
   echo -e "$@" | logger $loggerFlags "[$(basename "$0")] $$"
   "$isInteractive" && printf "${@}\n"
}

##-------------------------------------##
## Added by Martinski W. [2023-Oct-12] ##
##-------------------------------------##
# Directory for downloading & extracting firmware #
_CreateDirectory_()
{
    if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

    mkdir -p "$1"
    if [ ! -d "$1" ]
    then
        Say "${REDct}**ERROR**${NOct}: Unable to create directory [$1] to download firmware."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi
    # Clear directory in case any previous files still exist #
    rm -f "${1}"/*
    return 0
}

##-------------------------------------##
## Added by Martinski W. [2023-Oct-16] ##
##-------------------------------------##
_DelPostRebootRunScriptHook_()
{
   local hookScriptFile

   if [ $# -gt 0 ] && [ -n "$1" ]
   then hookScriptFile="$1"
   else hookScriptFile="$hookScriptFPath"
   fi
   if [ ! -f "$hookScriptFile" ] ; then return 1 ; fi

   if grep -qE "$POST_REBOOT_SCRIPT_JOB" "$hookScriptFile"
   then
       sed -i -e '/\/'"$ScriptFileName"' postRebootRun &  '"$hookScriptTagStr"'/d' "$hookScriptFile"
       if [ $? -eq 0 ]
       then
           Say "Post-reboot run hook was deleted successfully from '$hookScriptFile' script."
       fi
   else
       echo "Post-reboot run hook does not exist in '$hookScriptFile' script."
   fi
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-17] ##
##----------------------------------------------##
_AddPostRebootRunScriptHook_()
{
   local hookScriptFile  jobHookAdded=false

   if [ $# -gt 0 ] && [ -n "$1" ]
   then hookScriptFile="$1"
   else hookScriptFile="$hookScriptFPath"
   fi

   if [ ! -f "$hookScriptFile" ]
   then
      jobHookAdded=true
      {
        echo "#!/bin/sh"
        echo "# $hookScriptFName"
        echo "#"
        echo "$POST_REBOOT_SCRIPT_HOOK"
      } > "$hookScriptFile"
   #
   elif ! grep -qE "$POST_REBOOT_SCRIPT_JOB" "$hookScriptFile"
   then
      jobHookAdded=true
      echo "$POST_REBOOT_SCRIPT_HOOK" >> "$hookScriptFile"
   fi
   chmod 0755 "$hookScriptFile"

   if "$jobHookAdded"
   then Say "Post-reboot run hook was added successfully to '$hookScriptFile' script."
   else Say "Post-reboot run hook already exists in '$hookScriptFile' script."
   fi
   _WaitForEnterKey_
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

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-16] ##
##----------------------------------------##
check_memory_and_reboot() {
    
    if [ ! -f "${FW_BIN_DIR}/$firmware_file" ]; then
        Say "${REDct}**ERROR**${NOct}: Firmware file [${FW_BIN_DIR}/$firmware_file] not found."
        exit 1
    fi
    firmware_size_kb="$(du -k "${FW_BIN_DIR}/$firmware_file" | cut -f1)"  # Get firmware file size in kilobytes
    free_ram_kb="$(get_free_ram)"

    if [ "$free_ram_kb" -lt "$firmware_size_kb" ]; then
        Say "Insufficient RAM available to proceed with the firmware update."

        # During an interactive shell session, ask user to confirm reboot #
        if _WaitForYESorNO_ "Reboot router now"
        then
            _AddPostRebootRunScriptHook_
            Say "Rebooting router..."
            /sbin/service reboot
        fi
        exit 1  # Although the reboot command should end the script, it's good practice to exit after.
    fi
}

cleanup() {
    # Check if Toggle_LEDs_PID is set and if the process with that PID is still running
    if [ -n "$Toggle_LEDs_PID" ] && kill -0 "$Toggle_LEDs_PID" 2>/dev/null; then
        kill -15 "$Toggle_LEDs_PID"  # Terminate the background Toggle_LEDs process
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
check_version_support() {
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

check_model_support() {
    # List of unsupported models as a space-separated string
    local unsupported_models="RT-AC68U"

    # Get the current model
    local current_model="$(_GetRouterModel_)"

    # Check if the current model is in the list of unsupported models
    if echo "$unsupported_models" | grep -wq "$current_model"; then
        # Output a message and exit the script if the model is unsupported
        Say "The $current_model is an unsupported model. Exiting..."
        exit 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------##
_GetLoginCredentials_()
{
    echo "=== Login Credentials ==="

    # Get the username from nvram
    local username="$(nvram get http_username)"

    # Prompt the user only for a password [-s flag hides the password input]
    printf "Enter password for user ${GRNct}${username}${NOct}: "
    read -s password
    echo
    if [ -z "$password" ]
    then
        echo "The Username and Password cannot be empty. Credentials were not saved."
        _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Encode the username and password in Base64
    credentials_base64="$(echo -n "${username}:${password}" | openssl base64)"
    
    # Use Update_Custom_Settings to save the credentials to the SETTINGSFILE
    Update_Custom_Settings "credentials_base64" "$credentials_base64"
    
    echo "Credentials saved."
    _WaitForEnterKey_ "$menuReturnPromptStr"
    return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-13] ##
##----------------------------------------------##
_GetLatestFWversionFromRouter_()
{
   local retCode=0  newVersionStr
   if [ "$(nvram get webs_state_flag)" -eq 0 ]
   then retCode=1 ; fi

   newVersionStr="$(echo "$(nvram get webs_state_info)" | sed 's/_/./g')"
   if [ -z "$newVersionStr" ]
   then echo "" ; retCode=1
   else echo "$newVersionStr"
   fi
   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-05] ##
##----------------------------------------##
_GetLatestFWversionFromWebsite_() {
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
## Modified by Martinski W. [2023-Oct-12] ##
##----------------------------------------##
change_build_type() {
    echo "Changing Build Type..."
    
    # Use Get_Custom_Setting to retrieve the previous choice
    previous_choice="$(Get_Custom_Setting "local" "n")"

    # Logging user's choice
    # Check for the presence of "rog" in filenames in the extracted directory
    cd "$FW_BIN_DIR"
    rog_file="$(ls | grep -i '_rog_')"
    pure_file="$(ls | grep -iE '_pureubi.w|_ubi.w' | grep -iv 'rog')"

    if [ -n "$rog_file" ]; then
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

    _WaitForEnterKey_ "$menuReturnPromptStr"
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
    *) schedule_english="Custom [$1]" ;; # for non-standard schedules
  esac
  echo "$schedule_english"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------------##
_AddCronJobEntry_()
{
   local newSchedule  newSetting  retCode=1
   if [ $# -gt 0 ] && [ -n "$1" ]
   then
       newSetting=true
       newSchedule="$1"
   else
       newSetting=false
       newSchedule="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
   fi
   if [ -z "$newSchedule" ] || [ "$newSchedule" = "TBD"  ]
   then
       newSchedule="$FW_Update_CRON_DefaultSchedule"
   fi

   cru a "$CRON_JOB_TAG" "$newSchedule $CRON_JOB_RUN"
   sleep 1
   if crontab -l | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
   then
       retCode=0
       "$newSetting" && \
       Update_Custom_Settings FW_New_Update_Cron_Job_Schedule "$newSchedule"
   fi
   return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2023-Nov-19] ##
##-------------------------------------##
_DelCronJobEntry_()
{
   local retCode
   if crontab -l | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
   then
       cru d "$CRON_JOB_TAG" ; sleep 1
       if crontab -l | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
       then
           retCode=1
           printf "${REDct}**ERROR**${NOct}: Failed to remove cron job [${GRNct}${CRON_JOB_TAG}${NOct}].\n"
       else
           retCode=0
           printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was removed successfully.\n"
       fi
   else
       retCode=0
       printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' does not exist.\n"
   fi
   return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2023-Oct-12] ##
##-------------------------------------##
_CheckPostponementDays_()
{
   local retCode  newPostponementDays
   newPostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days TBD)"
   if [ -z "$newPostponementDays" ] || [ "$newPostponementDays" = "TBD" ]
   then retCode=1 ; else retCode=0 ; fi
   return "$retCode"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------------##
_Set_FW_UpdatePostponementDays_()
{
   local validNumRegExp="([0-9]|[1-9][0-9])"
   local oldPostponementDays  newPostponementDays  postponeDaysStr  userInput

   oldPostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days TBD)"
   if [ -z "$oldPostponementDays" ] || [ "$oldPostponementDays" = "TBD" ]
   then
       newPostponementDays="$FW_UpdateDefaultPostponementDays"
       postponeDaysStr="Default Value: ${GRNct}${newPostponementDays}${NOct}"
   else
       newPostponementDays="$oldPostponementDays"
       postponeDaysStr="Current Value: ${GRNct}${newPostponementDays}${NOct}"
   fi

   while true
   do
       printf "\nEnter the number of days to postpone the update once a new firmware notification is made.\n"
       printf "[${theExitStr}] "
       printf "[Min=${GRNct}${FW_UpdateMinimumPostponementDays}${NOct}, Max=${GRNct}${FW_UpdateMaximumPostponementDays}${NOct}] "
       printf "[${postponeDaysStr}]:  "
       read -r userInput

       if [ -z "$userInput" ] || echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then break ; fi

       if echo "$userInput" | grep -qE "^${validNumRegExp}$" && \
          [ "$userInput" -ge "$FW_UpdateMinimumPostponementDays" ] && \
          [ "$userInput" -le "$FW_UpdateMaximumPostponementDays" ]
       then newPostponementDays="$userInput" ; break ; fi

       printf "${REDct}INVALID input.${NOct}\n" 
   done

   if [ "$newPostponementDays" != "$oldPostponementDays" ]
   then
       Update_Custom_Settings FW_New_Update_Postponement_Days "$newPostponementDays"
       echo "The number of days to postpone F/W Update was updated successfully."
       _WaitForEnterKey_ "$menuReturnPromptStr"
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------##
_Set_FW_UpdateCronSchedule_()
{
    printf "Changing Firmware Update Schedule...\n"

    local retCode=1  current_schedule=""  new_schedule=""  userInput

    FW_UpdateCronJobSchedule="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
    if [ "$FW_UpdateCronJobSchedule" = "TBD" ] ; then FW_UpdateCronJobSchedule="" ; fi

    if [ -n "$FW_UpdateCronJobSchedule" ]
    then
        # Extract the schedule part (the first five fields) from the current cron job line
        current_schedule="$(echo "$FW_UpdateCronJobSchedule" | awk '{print $1, $2, $3, $4, $5}')"
        new_schedule="$current_schedule"

        # Translate the current schedule to English
        current_schedule_english="$(translate_schedule "$current_schedule")"
        printf "Current Schedule: ${GRNct}${current_schedule_english}${NOct}\n"
    else
        new_schedule="$FW_Update_CRON_DefaultSchedule"
    fi

    while true; do  # Loop to keep asking for input
        printf "\nEnter new cron job schedule (e.g. '${GRNct}0 0 * * 0${NOct}' for every Sunday at midnight)"
        if [ -z "$current_schedule" ]
        then printf "\n[${theExitStr}] [Default Schedule: ${GRNct}${new_schedule}${NOct}]:  "
        else printf "\n[${theExitStr}] [Current Schedule: ${GRNct}${current_schedule}${NOct}]:  "
        fi
        read -r userInput

        # If the user enters 'e', break out of the loop and return to the main menu
        if [ -z "$userInput" ] || echo "$userInput" | grep -qE "^(e|exit|Exit)$"
        then break ; fi

        # Validate the input using grep
        if echo "$userInput" | grep -qE '^([0-9,*\/-]+[[:space:]]+){4}[0-9,*\/-]+$'
        then
            new_schedule="$(echo "$userInput" | awk '{print $1, $2, $3, $4, $5}')"
            break  # If valid input, break out of the loop
        else
            printf "${REDct}INVALID schedule.${NOct}\n"
        fi
    done

    [ "$new_schedule" = "$current_schedule" ] && return 0

    FW_UpdateCheckState="$(nvram get firmware_check_enable)"
    if [ "$FW_UpdateCheckState" -eq 1 ]
    then
        # Add/Update cron job ONLY if "F/W Update Check" is enabled #
        printf "Updating '${GRNct}${CRON_JOB_TAG}${NOct}' cron job...\n"
        if _AddCronJobEntry_ "$new_schedule"
        then
            retCode=0
            printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was updated successfully.\n"
            current_schedule_english="$(translate_schedule "$new_schedule")"
            printf "Job Schedule: ${GRNct}${current_schedule_english}${NOct}\n"
        else
            retCode=1
            printf "${REDct}**ERROR**${NOct}: Failed to add/update the cron job [${CRON_JOB_TAG}].\n"
        fi
    else
        Update_Custom_Settings FW_New_Update_Cron_Job_Schedule "$new_schedule"
        printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was configured but not added.\n"
        printf "Firmware Update Check is currently ${REDct}DISABLED${NOct}.\n"
    fi

    _WaitForEnterKey_ "$menuReturnPromptStr"
    return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2023-Oct-12] ##
##-------------------------------------##
_CheckNewUpdateFirmwareNotification_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

   local numVersionFields  fwNewUpdateVersNum

   numVersionFields="$(echo "$2" | awk -F '.' '{print NF}')"
   currentVersionNum="$(_VersionFormatToNumber_ "$1" "$numVersionFields")"
   releaseVersionNum="$(_VersionFormatToNumber_ "$2" "$numVersionFields")"

   if [ "$currentVersionNum" -ge "$releaseVersionNum" ]
   then
       Say "Current firmware version '$1' is up to date."
       Update_Custom_Settings FW_New_Update_Notification_Date TBD
       Update_Custom_Settings FW_New_Update_Notification_Vers TBD
       return 1
   fi

   fwNewUpdateNotificationVers="$(Get_Custom_Setting FW_New_Update_Notification_Vers TBD)"
   if [ -z "$fwNewUpdateNotificationVers" ] || [ "$fwNewUpdateNotificationVers" = "TBD" ]
   then
       fwNewUpdateNotificationVers="$2"
       Update_Custom_Settings FW_New_Update_Notification_Vers "$fwNewUpdateNotificationVers"
   else
       numVersionFields="$(echo "$fwNewUpdateNotificationVers" | awk -F '.' '{print NF}')"
       fwNewUpdateVersNum="$(_VersionFormatToNumber_ "$fwNewUpdateNotificationVers" "$numVersionFields")"
       if [ "$releaseVersionNum" -gt "$fwNewUpdateVersNum" ]
       then
           fwNewUpdateNotificationVers="$2"
           fwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
           Update_Custom_Settings FW_New_Update_Notification_Vers "$fwNewUpdateNotificationVers"
           Update_Custom_Settings FW_New_Update_Notification_Date "$fwNewUpdateNotificationDate"
       fi
   fi

   fwNewUpdateNotificationDate="$(Get_Custom_Setting FW_New_Update_Notification_Date TBD)"
   if [ -z "$fwNewUpdateNotificationDate" ] || [ "$fwNewUpdateNotificationDate" = "TBD" ]
   then
       fwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
       Update_Custom_Settings FW_New_Update_Notification_Date "$fwNewUpdateNotificationDate"
   fi
   return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-12] ##
##----------------------------------------------##
_CheckTimeToUpdateFirmware_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

   local notifyTimeSecs  postponeTimeSecs  currentTimeSecs
   local fwNewUpdateNotificationDate  fwNewUpdateNotificationVers  fwNewUpdatePostponementDays

   _CheckNewUpdateFirmwareNotification_ "$1" "$2"

   if [ "$currentVersionNum" -ge "$releaseVersionNum" ]
   then return 1 ; fi

   fwNewUpdatePostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days TBD)"
   if [ -z "$fwNewUpdatePostponementDays" ] || [ "$fwNewUpdatePostponementDays" = "TBD" ]
   then
       fwNewUpdatePostponementDays="$FW_UpdateDefaultPostponementDays"
       Update_Custom_Settings FW_New_Update_Postponement_Days "$fwNewUpdatePostponementDays"
   fi

   if [ "$fwNewUpdatePostponementDays" -eq 0 ]
   then return 0 ; fi

   postponeTimeSecs="$((fwNewUpdatePostponementDays * 86400))"
   currentTimeSecs="$(date +%s)"
   notifyTimeStrn="$(echo "$fwNewUpdateNotificationDate" | sed 's/_/ /g')"
   notifyTimeSecs="$(date +%s -d "$notifyTimeStrn")"

   if [ "$(($currentTimeSecs - $notifyTimeSecs))" -gt "$postponeTimeSecs" ]
   then return 0 ; fi

   upfwDateTimeSecs="$((notifyTimeSecs + postponeTimeSecs))"
   upfwDateTimeStrn="$(echo "$upfwDateTimeSecs" | awk '{print strftime("%Y-%b-%d",$1)}')"

   Say "The firmware update to '${2}' version is postponed for '${fwNewUpdatePostponementDays}' day(s)."
   Say "The firmware update is expected to occur on or after '${upfwDateTimeStrn}' depending on when your cron job is scheduled to check again."
   return 1
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------------##
_Toggle_FW_UpdateCheckSetting_()
{
   local fwUpdateCheckEnabled  fwUpdateCheckNewStateStr
   local runfwUpdateCheck=false

   if [ "$FW_UpdateCheckState" -eq 0 ]
   then
       fwUpdateCheckEnabled=false
       fwUpdateCheckNewStateStr="${GRNct}ENABLE${NOct}"
   else
       fwUpdateCheckEnabled=true
       fwUpdateCheckNewStateStr="${GRNct}DISABLE${NOct}"
   fi

   if ! _WaitForYESorNO_ "Do you want to ${fwUpdateCheckNewStateStr} Router's F/W Update Check"
   then return 1 ; fi

   if "$fwUpdateCheckEnabled"
   then
       runfwUpdateCheck=false
       FW_UpdateCheckState=0
       fwUpdateCheckNewStateStr="DISABLED"
       _DelCronJobEntry_
       _DelCronJobRunScriptHook_
   else
       if [ -x "$FW_UpdateCheckScript" ]
       then runfwUpdateCheck=true ; fi
       FW_UpdateCheckState=1
       fwUpdateCheckNewStateStr="ENABLED"
       if _AddCronJobEntry_
       then
           printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was added successfully.\n"
           _AddCronJobRunScriptHook_
       else
           printf "${REDct}**ERROR**${NOct}: Failed to add the cron job [${CRON_JOB_TAG}].\n"
       fi
   fi

   nvram set firmware_check_enable="$FW_UpdateCheckState"
   printf "Router's built-in Firmware Update Check is now ${GRNct}${fwUpdateCheckNewStateStr}${NOct}.\n"
   nvram commit
   "$runfwUpdateCheck" && sh $FW_UpdateCheckScript &
   _WaitForEnterKey_ "$menuReturnPromptStr"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-18] ##
##----------------------------------------##
# Embed functions from second script, modified as necessary.
_RunFirmwareUpdateNow_()
{
    Say "Running the task now... Checking for updates..."

    local currentVersionNum=""  releaseVersionNum=""
    local current_version=""  release_version=""

    # Create directory for downloading & extracting firmware #
    if ! _CreateDirectory_ "$FW_ZIP_DIR" ; then return 1 ; fi

    # In case ZIP directory is different from BIN directory #
    if [ "$FW_ZIP_DIR" != "$FW_BIN_DIR" ] && \
       ! _CreateDirectory_ "$FW_BIN_DIR" ; then return 1 ; fi

    # Get current firmware version #
    current_version="$(get_current_firmware)"	
    ###current_version="388.3.0"

    #---------------------------------------------------------#
    # If the "F/W Update Check" in the WebGUI is disabled 
    # exit without further actions. This allows users to 
    # control the "F/W Auto-Update" feature from one place.
    # However, when running in "Menu Mode" the assumption
    # is that the user wants to do a MANUAL Update Check
    # regardless of the state of the "F/W Update Check."
    #---------------------------------------------------------#  
    FW_UpdateCheckState="$(nvram get firmware_check_enable)"
    if [ "$FW_UpdateCheckState" -eq 0 ]
    then
        Say "Firmware update check is currently disabled."
        "$inMenuMode" && _WaitForEnterKey_ || return 1
    fi

    #------------------------------------------------------
    # If the "New F/W Update" flag has been set get the
    # "New F/W Release Version" from the router itself.
    # If no new F/W version update is available exit.
    #------------------------------------------------------
    if ! release_version="$(_GetLatestFWversionFromRouter_)" || \
       ! _CheckNewUpdateFirmwareNotification_ "$current_version" "$release_version"
    then
        Say "No new firmware version update is found for [$MODEL] router model."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Use set to read the output of the function into variables
    set -- $(_GetLatestFWversionFromWebsite_ "$URL_RELEASE")
    release_version="$1"
    release_link="$2"

    # Extracting the first octet to use in the curl
    firstOctet="$(echo "$release_version" | cut -d'.' -f1)"
    # Inserting dots between each number
    dottedVersion="$(echo "$firstOctet" | sed 's/./&./g' | sed 's/.$//')"

    if [ "$1" = "**ERROR**" ] && [ "$2" = "**NO_URL**" ] 
    then
        Say "${REDct}**ERROR**${NOct}: No firmware release URL was found for [$MODEL] router model."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    if ! _CheckTimeToUpdateFirmware_ "$current_version" "$release_version"
    then
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 0
    fi

    # Compare versions before deciding to download
    if [ "$releaseVersionNum" -gt "$currentVersionNum" ]; then

		# Start a loop to create a blinking LED effect while checking for updates
		while true ; do Toggle_LEDs ; done &

		# Capture the background loop's PID
		Toggle_LEDs_PID=$!

		trap cleanup EXIT INT TERM

        Say "Latest release version is ${GRNct}${release_version}${NOct}."
        Say "Downloading ${GRNct}${release_link}${NOct}"
        echo
        wget -O "$FW_ZIP_FPATH" "$release_link"
    fi

    if [ ! -f "$FW_ZIP_FPATH" ]
    then
        Say "${REDct}**ERROR**${NOct}: Firmware ZIP file [$FW_ZIP_FPATH] was not downloaded."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Extracting the firmware
    unzip -o "$FW_ZIP_FPATH" -d "$FW_BIN_DIR" -x README*

    # If unzip was successful delete the zip file, else error out.
    if [ $? -eq 0 ]
    then
        rm -f "$FW_ZIP_FPATH"
    else
        Say "${REDct}**ERROR**${NOct}: Unable to decompress the firmware ZIP file [$FW_ZIP_FPATH]."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Use Get_Custom_Setting to retrieve the previous choice
    previous_choice="$(Get_Custom_Setting "local" "n")"

    # Logging user's choice
    # Check for the presence of "rog" in filenames in the extracted directory
    cd "$FW_BIN_DIR"
    rog_file="$(ls | grep -i '_rog_')"
    pure_file="$(ls | grep -iE '_pureubi.w|_ubi.w' | grep -iv 'rog')"

    local_value="$(Get_Custom_Setting "local")"

if [ -z "$local_value" ]; then
    if [ -n "$rog_file" ]; then
        # Check if the first argument is 'run_now'
        if ! "$inMenuMode" ; then
            # If the argument is 'run_now' default to the "Pure Build"
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
        fw_sig="$(openssl sha256 "$firmware_file" | cut -d' ' -f2)"
        dl_sig="$(grep "$firmware_file" sha256sum.sha256 | cut -d' ' -f1)"
        if [ "$fw_sig" != "$dl_sig" ]; then
            Say "${REDct}**ERROR**${NOct}: Extracted firmware does not match the SHA256 signature!"
            "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
            return 1
        fi
    fi

    # Flashing the chosen firmware

    # Use Get_Custom_Setting to retrieve the previous choice
    previous_creds="$(Get_Custom_Setting "credentials_base64")"

    # Debug: Print the LAN IP to ensure it's being set correctly
    echo "Debug Web URL is: $(construct_url) "

    check_memory_and_reboot

    Say "Flashing ${GRNct}${firmware_file}${NOct}... ${REDct}Please Wait for Reboot.${NOct}"
    echo

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
        -F "firmver=${dottedVersion}" \
        -F "file=@${firmware_file}" \
        --cookie /tmp/cookie.txt > /tmp/upload_response.txt 2>&1 &
        sleep 60
    else
        Say "${REDct}**ERROR**${NOct}: Login failed. Please confirm credentials by selecting: 1. Configure Login Credentials"
    fi
    # Stop the LED blinking after the update is completed
    kill -15 "$Toggle_LEDs_PID" # Terminate the background toggle_led loop	

    # Set LEDs to their "initial state" #
    nvram set led_disable="$LED_InitState"
    service restart_leds > /dev/null 2>&1
    "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
}

##-------------------------------------##
## Added by Martinski W. [2023-Nov-19] ##
##-------------------------------------##
_PostRebootRunNow_()
{
   _DelPostRebootRunScriptHook_

   local theWaitDelaySecs=10
   local maxWaitDelaySecs=360  #6 minutes#
   local curWaitDelaySecs=0
   #---------------------------------------------------------
   # Wait until all services are started, including NTP
   # so the system clock is updated with correct time.
   # By this time the USB drive should be mounted as well.
   #---------------------------------------------------------
   while [ "$curWaitDelaySecs" -lt "$maxWaitDelaySecs" ]
   do
      if [ "$(nvram get ntp_ready)" -eq 1 ] && \
         [ "$(nvram get start_service_ready)" -eq 1 ] && \
         [ "$(nvram get success_start_service)" -eq 1 ]
      then sleep 30 ; break; fi

      echo "Waiting for all services to be started [$theWaitDelaySecs secs.]..."
      sleep $theWaitDelaySecs
      curWaitDelaySecs="$((curWaitDelaySecs + theWaitDelaySecs))"
   done

   _RunFirmwareUpdateNow_
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------------##
_DelCronJobRunScriptHook_()
{
   local hookScriptFile

   if [ $# -gt 0 ] && [ -n "$1" ]
   then hookScriptFile="$1"
   else hookScriptFile="$hookScriptFPath"
   fi
   if [ ! -f "$hookScriptFile" ] ; then return 1 ; fi

   if grep -qE "$CRON_SCRIPT_JOB" "$hookScriptFile"
   then
       sed -i -e '/\/'"$ScriptFileName"' addCronJob &  '"$hookScriptTagStr"'/d' "$hookScriptFile"
       if [ $? -eq 0 ]
       then
           Say "Cron job hook was deleted successfully from '$hookScriptFile' script."
       fi
   else
       printf "Cron job hook does not exist in '$hookScriptFile' script.\n"
   fi
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-17] ##
##----------------------------------------------##
_AddCronJobRunScriptHook_()
{
   local hookScriptFile  jobHookAdded=false

   if [ $# -gt 0 ] && [ -n "$1" ]
   then hookScriptFile="$1"
   else hookScriptFile="$hookScriptFPath"
   fi

   if [ ! -f "$hookScriptFile" ]
   then
      jobHookAdded=true
      {
        echo "#!/bin/sh"
        echo "# $hookScriptFName"
        echo "#"
        echo "$CRON_SCRIPT_HOOK"
      } > "$hookScriptFile"
   #
   elif ! grep -qE "$CRON_SCRIPT_JOB" "$hookScriptFile"
   then
      jobHookAdded=true
      echo "$CRON_SCRIPT_HOOK" >> "$hookScriptFile"
   fi
   chmod 0755 "$hookScriptFile"

   if "$jobHookAdded"
   then Say "Cron job hook was added successfully to '$hookScriptFile' script."
   else Say "Cron job hook already exists in '$hookScriptFile' script."
   fi
}

##-------------------------------------##
## Added by Martinski W. [2023-Nov-18] ##
##-------------------------------------##
_DoUninstall_()
{
   _DelCronJobEntry_
   _DelCronJobRunScriptHook_
   _DelPostRebootRunScriptHook_
   rm -rf "$SETTINGS_DIR"
   rm -f "$ScriptFilePath"
   echo "Uninstall completed."
   exit 0
}

# Check if the router model is supported OR if
# it has the minimum firmware version supported.
check_model_support
check_version_support

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-18] ##
##----------------------------------------##
if [ $# -gt 0 ]
then
   inMenuMode=false
   case $1 in
       run_now) _RunFirmwareUpdateNow_ ; exit 0
           ;;
       addCronJob) _AddCronJobEntry_ ; exit 0
           ;;
       postRebootRun) _PostRebootRunNow_ ; exit 0
           ;;
       uninstall)
           if _WaitForYESorNO_ "Are you sure you want to uninstall $ScriptFileName"
           then _DoUninstall_
           else exit 0
           fi
           ;;

##FOR TEST/DEBUG ONLY##
       addPostRebootHook) _AddPostRebootRunScriptHook_ ; exit 0
           ;;
##FOR TEST/DEBUG ONLY##
       delPostRebootHook) _DelPostRebootRunScriptHook_ ; exit 0
           ;;

       *) printf "${REDct}INVALID Parameter.${NOct}\n" ; exit 1
           ;;
   esac
fi

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------##
FW_UpdateCheckState="$(nvram get firmware_check_enable)"
if [ "$FW_UpdateCheckState" -eq 1 ]
then
    # Add cron job ONLY if "F/W Update Check" is enabled #
    if ! crontab -l | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
    then
        # Add the cron job if it doesn't exist
        printf "Adding '${GRNct}${CRON_JOB_TAG}${NOct}' cron job...\n"
        if _AddCronJobEntry_
        then
            printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was added successfully.\n"
            current_schedule_english="$(translate_schedule "$FW_UpdateCronJobSchedule")"
            printf "Job Schedule: ${GRNct}${current_schedule_english}${NOct}\n"
        else
            printf "${REDct}**ERROR**${NOct}: Failed to add the cron job [${CRON_JOB_TAG}].\n"
        fi
    else
        printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' already exists.\n"
    fi
    _AddCronJobRunScriptHook_
    _WaitForEnterKey_
fi

rog_file=""

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------##
show_menu()
{
   clear
   SEPstr="---------------------------------------------------"
   echo -e "\033[1;36m===== Merlin Auto Update Main Menu =====\033[0m"
   echo -e "\033[1;35m========== By ExtremeFiretop ===========\033[0m"
   echo -e "\033[1;33m============ Contributors: =============\033[0m"
   echo -e "\033[1;33m"
   print_center 'Martinski W.'
   print_center 'Dave14305'
   echo -e "\033[0m"  # Reset color

   printf "${SEPstr}"
   printf "\n  ${GRNct}1${NOct}.  Configure Router Login Credentials\n"
   printf "\n  ${GRNct}2${NOct}.  Run Update F/W Check Now\n"

   printf "\n  ${GRNct}3${NOct}.  Set F/W Update Check Schedule"
   printf "\n      [Current Schedule: ${GRNct}${FW_UpdateCronJobSchedule}${NOct}]\n"

   printf "\n  ${GRNct}4${NOct}.  Set F/W Update Postponement Days"
   printf "\n      [Current Days: ${GRNct}${FW_UpdatePostponementDays}${NOct}]\n"

   # Enable/Disable the ASUS Router's built-in "F/W Update Check" #
   FW_UpdateCheckState="$(nvram get firmware_check_enable)"
   if [ "$FW_UpdateCheckState" -eq 0 ]
   then
       printf "\n  ${GRNct}5${NOct}.  Enable Router's F/W Update Check"
       printf "\n      [Currently ${GRNct}DISABLED${NOct}]\n"
   else
       printf "\n  ${GRNct}5${NOct}.  Disable Router's F/W Update Check"
       printf "\n      [Currently ${GRNct}ENABLED${NOct}]\n"
   fi

   printf "\n  ${GRNct}6${NOct}.  Set Directory Path for F/W Update ZIP File"
   printf "\n      [Current Path: ${GRNct}${FW_ZIP_SETUP_DIR}${NOct}]\n"

   # Check if the directory exists before attempting to navigate to it
   if [ -d "$FW_BIN_DIR" ]
   then
      cd "$FW_BIN_DIR"
      # Check for the presence of "rog" in filenames in the directory
      rog_file="$(ls | grep -i '_rog_')"

      # If a file with "_rog_" in its name is found, display the "Change Build Type" option
      if [ -n "$rog_file" ]; then
          printf "\n  ${GRNct}7${NOct}.  Change Update Build Type\n"
      fi
   fi

   printf "\n ${GRNct}un${NOct}.  Uninstall\n"
   printf "\n  ${GRNct}e${NOct}.  Exit\n"
   printf "${SEPstr}\n"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------##
# Main Menu loop
inMenuMode=true
theExitStr="${GRNct}e${NOct}=Exit to main menu"

while true
do
   show_menu

   # Check if the directory exists again before attempting to navigate to it
   if [ -d "$FW_BIN_DIR" ]; then
       cd "$FW_BIN_DIR"
       # Check for the presence of "rog" in filenames in the directory again
       rog_file="$(ls | grep -i '_rog_')"
   fi

   printf "Enter selection:  " ; read -r userChoice
   echo
   case $userChoice in
       1) _GetLoginCredentials_
          ;;
       2) _RunFirmwareUpdateNow_
          ;;
       3) _Set_FW_UpdateCronSchedule_
          ;;
       4) _Set_FW_UpdatePostponementDays_
          ;;
       5) _Toggle_FW_UpdateCheckSetting_
          ;;
       6) _Set_FW_UpdateZIP_DirectoryPath_
          ;;
       7) if [ -n "$rog_file" ]
          then change_build_type ; break ; fi
          printf "${REDct}INVALID selection.${NOct} Please try again."
          _WaitForEnterKey_
          ;;
       un) if _WaitForYESorNO_ "Are you sure you want to uninstall ${GRNct}${ScriptFileName}${NOct}"
           then _DoUninstall_
           else _WaitForEnterKey_
           fi
           ;;
       e) exit 0
          ;;
       *) printf "${REDct}INVALID selection.${NOct} Please try again."
          _WaitForEnterKey_
          ;;
   esac
done

#EOF#
