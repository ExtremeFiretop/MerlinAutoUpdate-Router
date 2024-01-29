#!/bin/sh
###################################################################
# MerlinAU.sh (MerlinAutoUpdate)
#
# Original Creation Date: 2023-Oct-01 by @ExtremeFiretop.
# Official Co-Author: @Martinski W. - Date: 2023-Nov-01
# Last Modified: 2024-Jan-28
###################################################################
set -u

#For AMTM versioning:
readonly SCRIPT_VERSION=1.0
readonly SCRIPT_NAME="MerlinAU"

##-------------------------------------##
## Added by Martinski W. [2023-Dec-01] ##
##-------------------------------------##
# Script URL Info #
readonly SCRIPT_BRANCH="master"
readonly SCRIPT_URL_BASE="https://raw.githubusercontent.com/ExtremeFiretop/MerlinAutoUpdate-Router/$SCRIPT_BRANCH"

# Firmware URL Info #
readonly FW_URL_BASE="https://sourceforge.net/projects/asuswrt-merlin/files"
readonly FW_URL_RELEASE_SUFFIX="Release"

# For new script version updates from source repository #
UpdateNotify=0
DLRepoVersion=""

# For supported version and model checks #
MinFirmwareCheckFailed=0
ModelCheckFailed=0

readonly ScriptFileName="${0##*/}"
readonly ScriptFNameTag="${ScriptFileName%%.*}"
readonly ScriptDirNameD="${ScriptFNameTag}.d"

ScriptsDirPath="$(/usr/bin/dirname "$0")"
if [ "$ScriptsDirPath" != "." ]
then
   ScriptFilePath="$0"
else
   ScriptsDirPath="$(pwd)"
   ScriptFilePath="$(pwd)/$ScriptFileName"
fi

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-21] ##
##------------------------------------------##
readonly ADDONS_PATH="/jffs/addons"
readonly SCRIPTS_PATH="/jffs/scripts"
readonly SETTINGS_DIR="${ADDONS_PATH}/$ScriptDirNameD"
readonly SETTINGSFILE="${SETTINGS_DIR}/custom_settings.txt"
readonly SCRIPTVERPATH="${SETTINGS_DIR}/version.txt"

##-------------------------------------##
## Added by Martinski W. [2024-Jan-24] ##
##-------------------------------------##
#-------------------------------------------------------#
# We'll use the built-in AMTM email configuration file
# to send email notifications *IF* enabled by the user.
#-------------------------------------------------------#
readonly FW_UpdateEMailNotificationDefault=false
readonly amtmMailDirPath="/jffs/addons/amtm/mail"
readonly amtmMailConfFile="${amtmMailDirPath}/email.conf"
readonly amtmMailPswdFile="${amtmMailDirPath}/emailpw.enc"
readonly tempEMailContent="/tmp/var/tmp/tempEMailContent.$$.TXT"
readonly tempEMailBodyMsg="/tmp/var/tmp/tempEMailBodyMsg.$$.TXT"
readonly saveEMailInfoMsg="${SETTINGS_DIR}/savedEMailInfoMsg.SAVE.TXT"

cronCmd="$(which crontab) -l"
[ "$cronCmd" = " -l" ] && cronCmd="$(which cru) l"

##----------------------------------------------##
## Added/Modified by Martinski W. [2024-Jan-06] ##
##----------------------------------------------##
inMenuMode=true
isInteractive=false
menuReturnPromptStr="Press Enter to return to the main menu..."

[ -t 0 ] && ! echo "$(tty)" | grep -qwi "NOT" && isInteractive=true

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-23] ##
##----------------------------------------##
userLOGFile=""
userTraceFile="${SETTINGS_DIR}/${ScriptFNameTag}_Trace.LOG"
LOGdateFormat="%Y-%m-%d %H:%M:%S"
_LogMsgNoTime_() { _UserLogMsg_ "_NOTIME_" "$@" ; }

_UserLogMsg_()
{
   if [ -z "$userLOGFile" ] || [ ! -f "$userLOGFile" ]
   then return 1 ; fi

   local logTime="$(date +"$LOGdateFormat")"
   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       echo >> "$userLOGFile"
   elif [ $# -eq 1 ]
   then
       echo "$logTime" "$1" >> "$userLOGFile"
   elif [ "$1" = "_NOTIME_" ]
   then
       echo "$2" >> $userLOGFile
   else
       echo "$logTime" "${1}: $2" >> "$userLOGFile"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-21] ##
##----------------------------------------##
Say()
{
   "$isInteractive" && printf "${1}\n"
   # Clean out the "color escape sequences" from the log file #
   local logMsg="$(echo "$1" | sed 's/\\\e\[0m//g ; s/\\\e\[[0-1];3[0-9]m//g')"
   _UserLogMsg_ "$logMsg"
   printf "$logMsg" | logger -t "[$(basename "$0")] $$"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-20] ##
##----------------------------------------------##
_WaitForEnterKey_()
{
   ! "$isInteractive" && return 0
   local promptStr

   if [ $# -gt 0 ] && [ -n "$1" ]
   then promptStr="$1"
   else promptStr="Press Enter to continue..."
   fi

   printf "\n$promptStr"
   read -rs EnterKEY ; echo
}

##----------------------------------##
## Added Martinski W. [2023-Nov-28] ##
##----------------------------------##
_WaitForYESorNO_()
{
   ! "$isInteractive" && return 0
   local promptStr

   if [ $# -eq 0 ] || [ -z "$1" ]
   then promptStr=" [yY|nN] N? "
   else promptStr="$1 [yY|nN] N? "
   fi

   printf "$promptStr" ; read -r YESorNO
   if echo "$YESorNO" | grep -qE "^([Yy](es)?)$"
   then echo "OK" ; return 0
   else echo "NO" ; return 1
   fi
}

##-------------------------------------##
## Added by Martinski W. [2023-Dec-26] ##
##-------------------------------------##
LockFilePath="/tmp/var/${ScriptFNameTag}.LOCK"
LockFileMaxSecs=600  #10-min "hold"#
_ReleaseLock_() { rm -f "$LockFilePath" ; }

_AcquireLock_()
{
   if [ ! -f "$LockFilePath" ]
   then
       echo "$$" > "$LockFilePath"
       return 0
   fi

   ageOfLockSecs="$(($(date +%s) - $(date +%s -r "$LockFilePath")))"
   if [ "$ageOfLockSecs" -gt "$LockFileMaxSecs" ]
   then
       Say "Stale lock found (older than $LockFileMaxSecs secs.) Reset lock file."
       oldPID="$(cat "$LockFilePath")"
       if [ -n "$oldPID" ] && kill -EXIT $oldPID 2>/dev/null && \
          echo "$(pidof "$ScriptFileName")" | grep -qow "$oldPID"
       then
           kill -TERM $oldPID ; wait $oldPID
       fi
       rm -f "$LockFilePath"
       echo "$$" > "$LockFilePath"
       return 0
   else
       Say "${REDct}**ERROR**${NOct}: The shell script '${ScriptFileName}' is already running [Lock file: $ageOfLockSecs secs.]"
       return 1
   fi
}

##-------------------------------------##
## Added by Martinski W. [2023-Dec-26] ##
##-------------------------------------##
_DoExit_()
{
   local exitCode=0
   [ $# -gt 0 ] && [ -n "$1" ] && exitCode="$1"
   _ReleaseLock_ ; exit "$exitCode"
}

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

##--------------------------------------##
## Added by Martinski W. [22023-Nov-24] ##
##--------------------------------------##
#---------------------------------------------------------#
# The USB-attached drives can have multiple partitions
# with different file systems (NTFS, ext3, ext4, etc.),
# which means that multiple mount points can be found.
# So for the purpose of choosing a default value here
# we will simply select the first mount point found.
# Users can later on change it by typing a different
# mount point path or directory using the Main Menu.
#---------------------------------------------------------#
_GetDefaultUSBMountPoint_()
{
   local mounPointPath  retCode=0
   local mountPointRegExp="/dev/sd.* /tmp/mnt/.*"

   mounPointPath="$(grep -m1 "$mountPointRegExp" /proc/mounts | awk -F ' ' '{print $2}')"
   [ -z "$mounPointPath" ] && retCode=1
   echo "$mounPointPath" ; return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-22] ##
##----------------------------------------##
# Background function to create a blinking LED effect #
Toggle_LEDs()
{
   if [ -z "$LED_ToggleState" ]
   then
       sleep 1
       Toggle_LEDs_PID=""
       return 1
   fi

   if [ $# -eq 0 ] || [ -z "$1" ] || \
      ! echo "$1" | grep -qE "^[2-5]$"
   then blinkRateSecs=2
   else blinkRateSecs="$1"
   fi

   while true
   do
      LED_ToggleState="$((! LED_ToggleState))"
      nvram set led_disable="$LED_ToggleState"
      service restart_leds > /dev/null 2>&1
      sleep "$blinkRateSecs"
   done
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-23] ##
##----------------------------------------##
_Reset_LEDs_()
{
   local doTrace=false
   [ $# -gt 0 ] && [ "$1" -eq 1 ] && doTrace=false
   if "$doTrace"
   then
       Say "START _Reset_LEDs_"
       echo "$(date +"$LOGdateFormat") START _Reset_LEDs_" >> "$userTraceFile"
   fi

   # Check if the process with that PID is still running #
   if [ -n "$Toggle_LEDs_PID" ] && \
      kill -EXIT "$Toggle_LEDs_PID" 2>/dev/null
   then
       kill -TERM $Toggle_LEDs_PID
       wait $Toggle_LEDs_PID
       # Set LEDs to their "initial state" #
       nvram set led_disable="$LED_InitState"
       service restart_leds >/dev/null 2>&1
       sleep 2
   fi
   Toggle_LEDs_PID=""

   if "$doTrace"
   then
       Say "EXIT _Reset_LEDs_"
       echo "$(date +"$LOGdateFormat") EXIT _Reset_LEDs_" >> "$userTraceFile"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-21] ##
##----------------------------------------##
_GetRouterURL_()
{
    local urlProto  urlDomain  urlPort

    if [ "$(nvram get http_enable)" = "1" ]
    then urlProto="https"
    else urlProto="http"
    fi

    urlDomain="$(nvram get lan_domain)"
    if [ -z "$urlDomain" ]
    then urlDomain="$(nvram get lan_ipaddr)"
    else urlDomain="$(nvram get lan_hostname).$urlDomain"
    fi

    urlPort="$(nvram get "${urlProto}_lanport")"
    if [ "$urlPort" -eq 80 ] || [ "$urlPort" -eq 443 ]
    then urlPort=""
    else urlPort=":$urlPort"
    fi

    echo "${urlProto}://${urlDomain}${urlPort}"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-20] ##
##----------------------------------------------##
_GetRouterModelID_()
{
   local retCode=1  routerModelID=""
   local nvramModelKeys="odmpid wps_modelnum model build_name"
   for nvramKey in $nvramModelKeys
   do
       routerModelID="$(nvram get "$nvramKey")"
       [ -n "$routerModelID" ] && retCode=0 && break
   done
   echo "$routerModelID" ; return "$retCode"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-20] ##
##----------------------------------------------##
_GetRouterProductID_()
{
   local retCode=1  routerProductID=""
   local nvramProductKeys="productid build_name odmpid"
   for nvramKey in $nvramProductKeys
   do
       routerProductID="$(nvram get "$nvramKey")"
       [ -n "$routerProductID" ] && retCode=0 && break
   done
   echo "$routerProductID" ; return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2023-Nov-28] ##
##-------------------------------------##
_ScriptVersionStrToNum_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then echo ; return 1 ; fi
   local verNum  verStr

   verStr="$(echo "$1" | awk -F '_' '{print $1}')"
   verNum="$(echo "$verStr" | awk -F '.' '{printf ("%d%03d%03d\n", $1,$2,$3);}')"
   verNum="$(echo "$verNum" | sed 's/^0*//')"
   echo "$verNum" ; return 0
}

##------------------------------------------------##
## Added/Modified by ExtremeFiretop [2024-Jan-28] ##
##------------------------------------------------##
_FWVersionStrToNum_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo ; return 1 ; fi

   USE_BETA_WEIGHT="$(Get_Custom_Setting FW_Allow_Beta_Production_Up)"

   local verNum
   local verStr="$1"
   local betaWeight=0

   if [ "$USE_BETA_WEIGHT" = "ENABLED" ] && echo "$verStr" | grep -q 'beta'; then
      betaWeight=-1000
      verStr=$(echo "$verStr" | sed 's/beta[0-9]*//') # Remove 'beta' and any following numbers

   if [ "$(echo "$verStr" | awk -F '.' '{print NF}')" -lt "$2" ]
   then verStr="$(nvram get firmver | sed 's/\.//g').$verStr" ; fi

   if [ "$2" -lt 4 ]; then
    verNum=$(echo "$verStr" | awk -F '.' '{printf "%d%03d%01d\n", $1,$2,$3}')
   else
    verNum=$(echo "$verStr" | awk -F '.' '{printf "%d%d%d%01d\n", $1,$2,$3,$4}')
   fi

    verNum=$((verNum + betaWeight)) 

   else
      if [ "$(echo "$1" | awk -F '.' '{print NF}')" -lt "$2" ]
      then verStr="$(nvram get firmver | sed 's/\.//g').$1" ; fi

   if [ "$2" -lt 4 ]; then
    verNum=$(echo "$verStr" | awk -F '.' '{printf "%d%03d%01d\n", $1,$2,$3}')
   else
    verNum=$(echo "$verStr" | awk -F '.' '{printf "%d%d%d%01d\n", $1,$2,$3,$4}')
   fi

   fi

   echo "$verNum" ; return 0
}

##--------------------------------------------##
## Modified by ExtremeFiretop [2023-Nov-26]   ##
##--------------------------------------------##
readonly NOct="\e[0m"
readonly REDct="\e[1;31m"
readonly GRNct="\e[1;32m"
readonly BLKct="\e[1;30m"
readonly YLWct="\e[1;33m"
readonly BLUEct="\e[1;34m"
readonly MAGENTAct="\e[1;35m"
readonly CYANct="\e[1;36m"
readonly WHITEct="\e[1;37m"

readonly FW_Update_CRON_DefaultSchedule="0 0 * * 0"

##------------------------------------------##
## Modified by Martinski W. [2024-Jan-22]   ##
##------------------------------------------##
# To postpone a firmware update for a few days #
readonly FW_UpdateMinimumPostponementDays=0
readonly FW_UpdateDefaultPostponementDays=15
readonly FW_UpdateMaximumPostponementDays=60
readonly FW_UpdateNotificationDateFormat="%Y-%m-%d_12:00:00"

readonly MODEL_ID="$(_GetRouterModelID_)"
readonly PRODUCT_ID="$(_GetRouterProductID_)"
readonly FW_FileName="${PRODUCT_ID}_firmware"
readonly FW_URL_RELEASE="${FW_URL_BASE}/${PRODUCT_ID}/${FW_URL_RELEASE_SUFFIX}/"

##-----------------------------------------------##
## Modified by: ExtremeFiretop [2023-Dec-16]     ##
##-----------------------------------------------##
_CheckForNewScriptUpdates_()
{
   local DLRepoVersionNum  ScriptVersionNum

   # Download the latest version file from the source repository
   curl --silent --retry 3 "${SCRIPT_URL_BASE}/version.txt" -o "$SCRIPTVERPATH"

   if [ ! -f "$SCRIPTVERPATH" ] ; then UpdateNotify=0 ; return 1 ; fi

   # Read in its contents for the current version file
   DLRepoVersion="$(cat "$SCRIPTVERPATH")"

   DLRepoVersionNum="$(_ScriptVersionStrToNum_ "$DLRepoVersion")"
   ScriptVersionNum="$(_ScriptVersionStrToNum_ "$SCRIPT_VERSION")"

   # Version comparison
   if [ "$DLRepoVersionNum" -gt "$ScriptVersionNum" ]
   then
      UpdateNotify="New script update available.
${REDct}v$SCRIPT_VERSION${NOct} --> ${GRNct}v$DLRepoVersion${NOct}"
      Say "$(date +'%b %d %Y %X') $(nvram get lan_hostname) ${ScriptFNameTag}_[$$] - INFO: A new script update (v$DLRepoVersion) is available to download."
   else
      UpdateNotify=0
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-17] ##
##----------------------------------------##
#a function that provides a UI to check for script updates and allows you to install the latest version...
_SCRIPTUPDATE_()
{
   # Check for the latest version from source repository
   _CheckForNewScriptUpdates_
   clear
   logo
   echo
   echo -e "${YLWct}Update Utility${NOct}"
   echo
   echo -e "${CYANct}Current Version: ${YLWct}${SCRIPT_VERSION}${NOct}"
   echo -e "${CYANct}Updated Version: ${YLWct}${DLRepoVersion}${NOct}"
   echo
   if [ "$SCRIPT_VERSION" = "$DLRepoVersion" ]
   then
      echo -e "${CYANct}You are on the latest version! Would you like to download anyways?${NOct}"
      echo -e "${CYANct}This will overwrite your currently installed version.${NOct}"
      if _WaitForYESorNO_ ; then
          echo ; echo
          echo -e "${CYANct}Downloading $SCRIPT_NAME ${CYANct}v$DLRepoVersion${NOct}"
          curl --silent --retry 3 "${SCRIPT_URL_BASE}/version.txt" -o "$SCRIPTVERPATH"
          curl --silent --retry 3 "${SCRIPT_URL_BASE}/${SCRIPT_NAME}.sh" -o "${ScriptsDirPath}/${SCRIPT_NAME}.sh" && chmod +x "${ScriptsDirPath}/${SCRIPT_NAME}.sh"
          echo
          echo -e "${CYANct}Download successful!${NOct}"
          echo -e "$(date) - $SCRIPT_NAME - Successfully downloaded $SCRIPT_NAME v$DLRepoVersion"
          echo
          _WaitForEnterKey_
          return
      else
          echo ; echo
          echo -e "${GRNct}Exiting Update Utility...${NOct}"
          sleep 1
          return
      fi
   elif [ "$UpdateNotify" != "0" ]
   then
      echo -e "${CYANct}Bingo! New version available! Would you like to update now?${NOct}"
      if _WaitForYESorNO_ ; then
          echo ; echo
          echo -e "${CYANct}Downloading $SCRIPT_NAME ${CYANct}v$DLRepoVersion${NOct}"
          curl --silent --retry 3 "${SCRIPT_URL_BASE}/version.txt" -o "$SCRIPTVERPATH"
          curl --silent --retry 3 "${SCRIPT_URL_BASE}/${SCRIPT_NAME}.sh" -o "${ScriptsDirPath}/${SCRIPT_NAME}.sh"
          if [ $? -eq 0 ]; then
              chmod a+x "${ScriptsDirPath}/${SCRIPT_NAME}.sh"
              echo
              echo -e "$(date) - $SCRIPT_NAME - Successfully downloaded $SCRIPT_NAME v$DLRepoVersion"
              echo -e "${CYANct}Update successful! Restarting script...${NOct}"
              _ReleaseLock_
              exec "${ScriptsDirPath}/${SCRIPT_NAME}.sh"  # Re-execute the updated script
              exit 0  # This line will not be executed as exec replaces the current process
          else
              echo
              echo -e "${REDct}Download failed.${NOct}"
              # Handle download failure
              _WaitForEnterKey_
              return
          fi
      else
          echo ; echo
          echo -e "${GRNct}Exiting Update Utility...${NOct}"
          sleep 1
          return
      fi
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jan-27] ##
##----------------------------------------##
#-------------------------------------------------------------#
# Since a list of current mount points can have a different
# order after each reboot, or when USB drives are unmounted
# (unplugged) & then mounted (plugged in) manually by users,
# to validate a given mount point path selection we have to
# go through the current list & check for the specific path.
# We also make a special case for Entware "/opt/" paths.
#-------------------------------------------------------------#
_ValidateUSBMountPoint_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   local mounPointPaths  expectedPath
   local symblPath  realPath1  realPath2  foundPathOK
   local mountPointRegExp="/dev/sd.* /tmp/mnt/.*"

   mounPointPaths="$(grep "$mountPointRegExp" /proc/mounts | awk -F ' ' '{print $2}')"
   [ -z "$mounPointPaths" ] && return 1

   expectedPath="$1"
   if echo "$1" | grep -qE "^(/opt/|/tmp/opt/)"
   then
       realPath1="$(readlink -f /tmp/opt)"
       realPath2="$(ls -l /tmp/opt | awk -F ' ' '{print $11}')"
       symblPath="$(ls -l /tmp/opt | awk -F ' ' '{print $9}')"
       [ -L "$symblPath" ] && [ -n "$realPath1" ] && \
       [ -n "$realPath2" ] && [ "$realPath1" = "$realPath2" ] && \
       expectedPath="$(/usr/bin/dirname "$realPath1")"
   fi

   foundPathOK=false
   for thePATH in $mounPointPaths
   do
      if echo "${expectedPath}/" | grep -qE "^${thePATH}/"
      then foundPathOK=true ; break ; fi
   done
   "$foundPathOK" && return 0 || return 1
}

##----------------------------------------##
## Added by ExtremeFiretop [2023-Nov-26] ##
##----------------------------------------##
logo() {
  echo -e "${YLWct}"
  echo -e "    __  __           _ _               _    _ "
  echo -e "   |  \/  |         | (_)         /\  | |  | |"
  echo -e "   | \  / | ___ _ __| |_ _ __    /  \ | |  | |"
  echo -e "   | |\/| |/ _ | '__| | | '_ \  / /\ \| |  | |"
  echo -e "   | |  | |  __| |  | | | | | |/ ____ | |__| |"
  echo -e "   |_|  |_|\___|_|  |_|_|_| |_/_/    \_\____/ ${GRNct}v${SCRIPT_VERSION}"
  echo -e "                                              ${NOct}"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-24] ##
##----------------------------------------##
if USBMountPoint="$(_GetDefaultUSBMountPoint_)"
then
    USBConnected="${GRNct}True${NOct}"
    readonly FW_Update_ZIP_DefaultSetupDIR="$USBMountPoint"
    readonly FW_Update_LOG_BASE_DefaultDIR="$USBMountPoint"
else
    USBConnected="${REDct}False${NOct}"
    readonly FW_Update_ZIP_DefaultSetupDIR="/home/root"
    readonly FW_Update_LOG_BASE_DefaultDIR="$ADDONS_PATH"
fi

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-27] ##
##------------------------------------------##
_Init_Custom_Settings_Config_()
{
   [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

   if [ ! -f "$SETTINGSFILE" ]
   then
      {
         echo "FW_New_Update_Notification_Date TBD"
         echo "FW_New_Update_Notification_Vers TBD"
         echo "FW_New_Update_Postponement_Days=$FW_UpdateDefaultPostponementDays"
         echo "FW_New_Update_EMail_Notification=$FW_UpdateEMailNotificationDefault"
         echo "FW_New_Update_Cron_Job_Schedule=\"${FW_Update_CRON_DefaultSchedule}\""
         echo "FW_New_Update_ZIP_Directory_Path=\"${FW_Update_ZIP_DefaultSetupDIR}\""
         echo "FW_New_Update_LOG_Directory_Path=\"${FW_Update_LOG_BASE_DefaultDIR}\""
         echo "FW_New_Update_LOG_Preferred_Path=\"${FW_Update_LOG_BASE_DefaultDIR}\""
         echo "CheckChangeLog ENABLED"
         echo "FW_Allow_Beta_Production_Up ENABLED"
      } > "$SETTINGSFILE"
      return 1
   fi
   local retCode=0  prefPath

   if ! grep -q "^FW_New_Update_Notification_Date " "$SETTINGSFILE"
   then
       sed -i "1 i FW_New_Update_Notification_Date TBD" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_Notification_Vers " "$SETTINGSFILE"
   then
       sed -i "2 i FW_New_Update_Notification_Vers TBD" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_Postponement_Days=" "$SETTINGSFILE"
   then
       sed -i "3 i FW_New_Update_Postponement_Days=$FW_UpdateDefaultPostponementDays" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_EMail_Notification=" "$SETTINGSFILE"
   then
       sed -i "4 i FW_New_Update_EMail_Notification=$FW_UpdateEMailNotificationDefault" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_Cron_Job_Schedule=" "$SETTINGSFILE"
   then
       sed -i "5 i FW_New_Update_Cron_Job_Schedule=\"${FW_Update_CRON_DefaultSchedule}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_ZIP_Directory_Path=" "$SETTINGSFILE"
   then
       sed -i "6 i FW_New_Update_ZIP_Directory_Path=\"${FW_Update_ZIP_DefaultSetupDIR}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_LOG_Directory_Path=" "$SETTINGSFILE"
   then
       sed -i "7 i FW_New_Update_LOG_Directory_Path=\"${FW_Update_LOG_BASE_DefaultDIR}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_LOG_Preferred_Path=" "$SETTINGSFILE"
   then
       preferredPath="$(Get_Custom_Setting FW_New_Update_LOG_Directory_Path)"
       sed -i "8 i FW_New_Update_LOG_Preferred_Path=\"${preferredPath}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^CheckChangeLog" "$SETTINGSFILE"
   then
       sed -i "9 i CheckChangeLog ENABLED" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_Allow_Beta_Production_Up" "$SETTINGSFILE"
   then
       sed -i "5 i FW_Allow_Beta_Production_Up ENABLED" "$SETTINGSFILE"
       retCode=1
   fi
   return "$retCode"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-28] ##
##------------------------------------------##
# Function to get custom setting value from the settings file
Get_Custom_Setting()
{
    if [ $# -eq 0 ] || [ -z "$1" ]; then echo "**ERROR**"; return 1; fi
    [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

    local setting_value="" setting_type="$1" default_value="TBD"
    [ $# -gt 1 ] && default_value="$2"

    if [ -f "$SETTINGSFILE" ]; then
        case "$setting_type" in
            "ROGBuild" | "credentials_base64" | "CheckChangeLog" | \
            "FW_Allow_Beta_Production_Up" | \
            "FW_New_Update_Notification_Date" | \
            "FW_New_Update_Notification_Vers")
                setting_value="$(grep "^${setting_type} " "$SETTINGSFILE" | awk -F ' ' '{print $2}')"
                ;;
            "FW_New_Update_Postponement_Days"  | \
            "FW_New_Update_Cron_Job_Schedule"  | \
            "FW_New_Update_ZIP_Directory_Path" | \
            "FW_New_Update_LOG_Directory_Path" | \
            "FW_New_Update_LOG_Preferred_Path" | \
            "FW_New_Update_EMail_Notification")
                grep -q "^${setting_type}=" "$SETTINGSFILE" && \
                setting_value="$(grep "^${setting_type}=" "$SETTINGSFILE" | awk -F '=' '{print $2}' | sed "s/['\"]//g")"
                ;;
            *)
                setting_value="**ERROR**"
                ;;
        esac
        [ -z "$setting_value" ] && echo "$default_value" || echo "$setting_value"
    else
        echo "$default_value"
    fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-28] ##
##------------------------------------------##
Update_Custom_Settings()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] ; then return 1 ; fi

    local fixedVal  oldVal=""
    local setting_type="$1"  setting_value="$2"

    # Check if the directory exists, and if not, create it
    [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

    case "$setting_type" in
        "ROGBuild" | "credentials_base64" | "CheckChangeLog" | \
        "FW_Allow_Beta_Production_Up" | \
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
        "FW_New_Update_Postponement_Days"  | \
        "FW_New_Update_Cron_Job_Schedule"  | \
        "FW_New_Update_ZIP_Directory_Path" | \
        "FW_New_Update_LOG_Directory_Path" | \
        "FW_New_Update_LOG_Preferred_Path" | \
        "FW_New_Update_EMail_Notification")
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
            if [ "$setting_type" = "FW_New_Update_Postponement_Days" ]
            then
                FW_UpdatePostponementDays="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_EMail_Notification" ]
            then
                sendEMailNotificationsFlag="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_Cron_Job_Schedule" ]
            then
                FW_UpdateCronJobSchedule="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_ZIP_Directory_Path" ]
            then
                FW_ZIP_BASE_DIR="$setting_value"
                FW_ZIP_DIR="${setting_value}/$FW_ZIP_SUBDIR"
                FW_ZIP_FPATH="${FW_ZIP_DIR}/${FW_FileName}.zip"
            #
            elif [ "$setting_type" = "FW_New_Update_LOG_Directory_Path" ]
            then  # Addition for handling log directory path
                FW_LOG_BASE_DIR="$setting_value"
                FW_LOG_DIR="${setting_value}/$FW_LOG_SUBDIR"
            fi
            ;;
        *)
            echo "Invalid setting type: $setting_type"
            ;;
    esac
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-26] ##
##------------------------------------------##
_migrate_settings_() {
    local USBMountPoint="$(Get_Custom_Setting FW_New_Update_LOG_Directory_Path)"
    local old_settings_dir="${ADDONS_PATH}/$ScriptFNameTag"
    local new_settings_dir="${ADDONS_PATH}/$ScriptDirNameD"
    local old_bin_dir="/home/root/$ScriptFNameTag"
    local new_bin_dir="/home/root/$ScriptDirNameD"
    local old_log_dir="${USBMountPoint}/$ScriptFNameTag"
    local new_log_dir="${USBMountPoint}/$ScriptDirNameD"

    # Check if the old SETTINGS directory exists #
    if [ -d "$old_settings_dir" ]; then
        # Check if the new SETTINGS directory already exists
        if [ -d "$new_settings_dir" ]; then
            echo "The new SETTINGS directory already exists. Migration is not required."
        else
            # Move the old SETTINGS directory to the new location
            mv "$old_settings_dir" "$new_settings_dir"
            if [ $? -eq 0 ]; then
                echo "SETTINGS directory successfully migrated to the new location."
            else
                echo "Error occurred during migration of the SETTINGS directory."
            fi
        fi
    fi

    # Check if the old BIN directory exists #
    if [ -d "$old_bin_dir" ]; then
        # Check if the new BIN directory already exists
        if [ -d "$new_bin_dir" ]; then
            echo "The new BIN directory already exists. Migration is not required."
        else
            # Move the old BIN directory to the new location
            mv "$old_bin_dir" "$new_bin_dir"
            if [ $? -eq 0 ]; then
                echo "BIN directory successfully migrated to the new location."
            else
                echo "Error occurred during migration of the BIN directory."
            fi
        fi
    fi

    # Check if the old LOG directory exists #
    if [ -d "$old_log_dir" ]; then
        # Check if the new LOG directory already exists
        if [ -d "$new_log_dir" ]; then
            echo "The new LOG directory already exists. Migration is not required."
        else
            # Move the old LOG directory to the new location
            mv "$old_log_dir" "$new_log_dir"
            if [ $? -eq 0 ]; then
                echo "LOG directory successfully migrated to the new location."
            else
                echo "Error occurred during migration of the LOG directory."
            fi
        fi
    fi
}

_migrate_settings_

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-24] ##
##------------------------------------------##
_Set_FW_UpdateLOG_DirectoryPath_()
{
   local newLogBaseDirPath="$FW_LOG_BASE_DIR"  newLogFileDirPath=""

   while true
   do
      printf "\nEnter the directory path where the LOG subdirectory [${GRNct}${FW_LOG_SUBDIR}${NOct}] will be stored.\n"
      printf "[${theADExitStr}] [CURRENT: ${GRNct}${FW_LOG_BASE_DIR}${NOct}]:  "
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
      then newLogBaseDirPath="$userInput" ; break ; fi

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
          then newLogBaseDirPath="$userInput" ; break
          else printf "\n${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${userInput}${NOct}].\n\n"
          fi
      fi
   done

   # Double-check current directory indeed exists after menu selection #
   if [ "$newLogBaseDirPath" = "$FW_LOG_BASE_DIR" ] && [ ! -d "$FW_LOG_DIR" ]
   then mkdir -p -m 755 "$FW_LOG_DIR" ; fi

   if [ "$newLogBaseDirPath" != "$FW_LOG_BASE_DIR" ] && [ -d "$newLogBaseDirPath" ]
   then
       if ! echo "$newLogBaseDirPath" | grep -qE "${FW_LOG_SUBDIR}$"
       then newLogFileDirPath="${newLogBaseDirPath}/$FW_LOG_SUBDIR" ; fi
       mkdir -p -m 755 "$newLogFileDirPath" 2>/dev/null
       if [ ! -d "$newLogFileDirPath" ]
       then
           printf "\n${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${newLogFileDirPath}${NOct}].\n"
           _WaitForEnterKey_
           return 1
       fi
       # Move any existing log files to new directory #
       mv -f "${FW_LOG_DIR}"/*.log "$newLogFileDirPath" 2>/dev/null
       # Remove now the obsolete directory path #
       rm -fr "$FW_LOG_DIR"
       # Update the log directory path after validation #
       Update_Custom_Settings FW_New_Update_LOG_Directory_Path "$newLogBaseDirPath"
       Update_Custom_Settings FW_New_Update_LOG_Preferred_Path "$newLogBaseDirPath"
       echo "The directory path for the log files was updated successfully."
       _WaitForEnterKey_ "$menuReturnPromptStr"
   fi
   return 0
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-24] ##
##------------------------------------------##
_Set_FW_UpdateZIP_DirectoryPath_()
{
   local newZIP_BaseDirPath="$FW_ZIP_BASE_DIR"  newZIP_FileDirPath="" 

   while true
   do
      printf "\nEnter the directory path where the ZIP subdirectory [${GRNct}${FW_ZIP_SUBDIR}${NOct}] will be stored.\n"
      printf "[${theADExitStr}] [CURRENT: ${GRNct}${FW_ZIP_BASE_DIR}${NOct}]:  "
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
      then newZIP_BaseDirPath="$userInput" ; break ; fi

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
          then newZIP_BaseDirPath="$userInput" ; break
          else printf "\n${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${userInput}${NOct}].\n\n"
          fi
      fi
   done

   if [ "$newZIP_BaseDirPath" != "$FW_ZIP_BASE_DIR" ] && [ -d "$newZIP_BaseDirPath" ]
   then
       if ! echo "$newZIP_BaseDirPath" | grep -qE "${FW_ZIP_SUBDIR}$"
       then newZIP_FileDirPath="${newZIP_BaseDirPath}/$FW_ZIP_SUBDIR" ; fi
       mkdir -p -m 755 "$newZIP_FileDirPath" 2>/dev/null
       if [ ! -d "$newZIP_FileDirPath" ]
       then
           printf "\n${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${newZIP_FileDirPath}${NOct}].\n"
           _WaitForEnterKey_
           return 1
       fi
       # Remove now the obsolete directory path #
       rm -fr "$FW_ZIP_DIR"
       rm -f "${newZIP_FileDirPath}"/*.zip  "${newZIP_FileDirPath}"/*.sha256
       Update_Custom_Settings FW_New_Update_ZIP_Directory_Path "$newZIP_BaseDirPath"
       echo "The directory path for the F/W ZIP file was updated successfully."
       _WaitForEnterKey_ "$menuReturnPromptStr"
   fi
   return 0
}

_Init_Custom_Settings_Config_

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-27] ##
##------------------------------------------##
# NOTE:
# Depending on available RAM & storage capacity of the 
# target router, it may be required to have USB-attached 
# storage for the ZIP file so that it can be downloaded
# in a separate directory from the firmware bin file.
#-----------------------------------------------------------
FW_BIN_BASE_DIR="/home/root"
FW_ZIP_BASE_DIR="$(Get_Custom_Setting FW_New_Update_ZIP_Directory_Path)"
FW_LOG_BASE_DIR="$(Get_Custom_Setting FW_New_Update_LOG_Directory_Path)"

readonly FW_LOG_SUBDIR="${ScriptDirNameD}/logs"
readonly FW_BIN_SUBDIR="${ScriptDirNameD}/$FW_FileName"
readonly FW_ZIP_SUBDIR="${ScriptDirNameD}/$FW_FileName"

FW_BIN_DIR="${FW_BIN_BASE_DIR}/$FW_BIN_SUBDIR"
FW_LOG_DIR="${FW_LOG_BASE_DIR}/$FW_LOG_SUBDIR"
FW_ZIP_DIR="${FW_ZIP_BASE_DIR}/$FW_ZIP_SUBDIR"
FW_ZIP_FPATH="${FW_ZIP_DIR}/${FW_FileName}.zip"

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-24] ##
##----------------------------------------------##
# The built-in F/W hook script file to be used for
# setting up persistent jobs to run after a reboot.
readonly hookScriptFName="services-start"
readonly hookScriptFPath="${SCRIPTS_PATH}/$hookScriptFName"
readonly hookScriptTagStr="#Added by $ScriptFNameTag#"

# Postponement Days for F/W Update Check #
FW_UpdatePostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days)"

# F/W Update Email Notifications #
isEMailConfigEnabledInAMTM=false
sendEMailNotificationsFlag="$(Get_Custom_Setting FW_New_Update_EMail_Notification)"

# Define the CRON job command to execute #
FW_UpdateCronJobSchedule="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
readonly CRON_JOB_RUN="sh $ScriptFilePath run_now"
readonly CRON_JOB_TAG="$ScriptFNameTag"
readonly CRON_SCRIPT_JOB="sh $ScriptFilePath addCronJob &  $hookScriptTagStr"
readonly CRON_SCRIPT_HOOK="[ -f $ScriptFilePath ] && $CRON_SCRIPT_JOB"

# Define post-reboot run job command to execute #
readonly POST_REBOOT_SCRIPT_JOB="sh $ScriptFilePath postRebootRun &  $hookScriptTagStr"
readonly POST_REBOOT_SCRIPT_HOOK="[ -f $ScriptFilePath ] && $POST_REBOOT_SCRIPT_JOB"

# Define post-update email notification job command to execute #
readonly POST_UPDATE_EMAIL_SCRIPT_JOB="sh $ScriptFilePath postUpdateEmail &  $hookScriptTagStr"
readonly POST_UPDATE_EMAIL_SCRIPT_HOOK="[ -f $ScriptFilePath ] && $POST_UPDATE_EMAIL_SCRIPT_JOB"

if [ -d "$FW_LOG_DIR" ]
then
    # Log rotation - delete logs older than 30 days #
    find "$FW_LOG_DIR" -name '*.log' -mtime +30 -exec rm {} \;
fi

##----------------------------------------##
## Modified by Martinski W. [2024-Jan-27] ##
##----------------------------------------##
#-------------------------------------------------------------------------------------------
# This code is in case the user-selected USB mount point isn't available anymore.
# If the USB drive is selected as the log location but it goes offline for some reason, 
# any call to the "Say" function creates a new '/tmp/mnt/XXXX' directory.
# In such a case where the USB drive is unmounted, we need to change the log directory 
# back to a local directory. First if-statement executes first and updates to local 'jffs' 
# directory if no USB drives are found. If ANY DefaultUSBMountPoint found, then move the 
# log files from their local jffs location to the default mount location. 
# We don't know the user selected yet because it's local at this time and was changed 
# by the else statement. Remove the old log directory location from jffs, and update the 
# settings file again to the new default again. This creates a semi-permanent switch which 
# can reset back to default if the user-selected mount points aren't valid anymore.
#-------------------------------------------------------------------------------------------
UserSelectedLogPath="$(Get_Custom_Setting FW_New_Update_LOG_Directory_Path)"
if [ ! -d "$UserSelectedLogPath" ] || [ ! -r "$UserSelectedLogPath" ]; then
    Update_Custom_Settings FW_New_Update_LOG_Directory_Path "$ADDONS_PATH"
fi

UserPreferredLogPath="$(Get_Custom_Setting FW_New_Update_LOG_Preferred_Path)"
if echo "$UserPreferredLogPath" | grep -qE "^(/tmp/mnt/|/tmp/opt/|/opt/)" && \
   _ValidateUSBMountPoint_ "$UserPreferredLogPath" &&
   [ "$UserPreferredLogPath" != "$FW_LOG_BASE_DIR" ]
then
   mv -f "${FW_LOG_DIR}"/*.log "${UserPreferredLogPath}/$FW_LOG_SUBDIR" 2>/dev/null
   rm -fr "$FW_LOG_DIR"
   Update_Custom_Settings FW_New_Update_LOG_Directory_Path "$UserPreferredLogPath"
fi

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-22] ##
##----------------------------------------------##
_GetLatestFWUpdateVersionFromRouter_()
{
   local retCode=0  webState  newVersionStr

   webState="$(nvram get webs_state_flag)"
   if [ -z "$webState" ] || [ "$webState" -eq 0 ]
   then retCode=1 ; fi

   newVersionStr="$(nvram get webs_state_info | sed 's/_/./g')"
   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       newVersionStr="$(echo "$newVersionStr" | awk -F '-' '{print $1}')"
   fi

   [ -z "$newVersionStr" ] && retCode=1
   echo "$newVersionStr" ; return "$retCode"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-26] ##
##------------------------------------------##
_CreateEMailContent_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   local fwInstalledVersion  fwNewUpdateVersion  subjectStr
   local savedInstalledVersion  savedNewUpdateVersion

   rm -f "$tempEMailContent" "$tempEMailBodyMsg"

   fwInstalledVersion="$(_GetCurrentFWInstalledLongVersion_)"
   fwNewUpdateVersion="$(_GetLatestFWUpdateVersionFromRouter_ 1)"
   subjectStr="F/W Update Status for $MODEL_ID"

   case "$1" in
       FW_UPDATE_TEST_EMAIL)
           {
             echo
             echo "TESTING:"
             echo "This is a test of the F/W Update email notification from the <b>${MODEL_ID}</b> router."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n\n"
           } > "$tempEMailBodyMsg"
           ;;
       NEW_FW_UPDATE_STATUS)
           {
             echo
             echo "A new F/W Update version <b>${fwNewUpdateVersion}</b> is available for the <b>${MODEL_ID}</b> router."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n"
             printf "\nNumber of days to postpone flashing the new F/W Update version: <b>${FW_UpdatePostponementDays}</b>\n\n"
           } > "$tempEMailBodyMsg"
           ;;
       START_FW_UPDATE_STATUS)
           {
             echo
             echo "Started flashing the new F/W Update version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n\n"
           } > "$tempEMailBodyMsg"
           ;;
       STOP_FW_UPDATE_APPROVAL)
           {
             echo
             echo "<b>WARNING</b>:"
             echo "Found high-risk phrases in the change-logs while Auto-Updating to version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             printf "\nPlease run script interactively to approve this F/W Update from current version:\n<b>${fwInstalledVersion}</b>\n\n"
           } > "$tempEMailBodyMsg"
           ;;
       NEW_BM_BACKUP_FAILED)
           {
             echo
             echo "<b>WARNING</b>:"
             echo "Backup failed during the F/W Update process to version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             echo "Flashing the F/W Update on the <b>${MODEL_ID}</b> router is now cancelled."
             printf "\nPlease check backupmon.sh configuration and retry F/W Update from current version:\n<b>${fwInstalledVersion}</b>\n\n"
           } > "$tempEMailBodyMsg"
           ;;
       FAILED_FW_UPDATE_STATUS)
           {
             echo
             echo "<b>**ERROR**</b>:"
             echo "Flashing of new F/W Update version <b>${fwNewUpdateVersion}</b> for the <b>${MODEL_ID}</b> router failed."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n\n"
           } > "$tempEMailBodyMsg"
           ;;
       POST_REBOOT_FW_UPDATE_SETUP)
           {
              echo "FW_InstalledVersion=$fwInstalledVersion"
              echo "FW_NewUpdateVersion=$fwNewUpdateVersion"
           } > "$saveEMailInfoMsg"
           _AddPostUpdateEmailNotifyScriptHook_
           return 0
           ;;
       POST_REBOOT_FW_UPDATE_STATUS)
           if [ ! -f "$saveEMailInfoMsg" ]
           then
               Say "${REDct}**ERROR**${NOct}: Unable to send post-update email notification [No saved info file]."
               return 1
           fi
           savedInstalledVersion="$(cat "$saveEMailInfoMsg" | grep "FW_InstalledVersion=" | awk -F '=' '{print $2}')"
           savedNewUpdateVersion="$(cat "$saveEMailInfoMsg" | grep "FW_NewUpdateVersion=" | awk -F '=' '{print $2}')"
           if [ -z "$savedInstalledVersion" ] || [ -z "$savedNewUpdateVersion" ]
           then
               Say "${REDct}**ERROR**${NOct}: Unable to send post-update email notification [Saved info is empty]."
               return 1
           fi
           if [ "$savedNewUpdateVersion" = "$fwInstalledVersion" ] && \
              [ "$savedInstalledVersion" != "$fwInstalledVersion" ]
           then
              {
                echo
                echo "Flashing of new F/W Update version <b>${fwInstalledVersion}</b> for the <b>${MODEL_ID}</b> router was successful."
                printf "\nThe F/W version that was previously installed:\n<b>${savedInstalledVersion}</b>\n\n"
              } > "$tempEMailBodyMsg"
           else
              {
                echo
                echo "<b>**ERROR**</b>:"
                echo "Flashing of new F/W Update version <b>${savedNewUpdateVersion}</b> for the <b>${MODEL_ID}</b> router failed."
                printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n\n"
              } > "$tempEMailBodyMsg"
           fi
           rm -f "$saveEMailInfoMsg"
           ;;
       *) return 1
           ;;
   esac

   ## Header ##
   cat <<EOF > "$tempEMailContent"
From: "$FROM_NAME" <$FROM_ADDRESS>
To: "$TO_NAME" <$TO_ADDRESS>
Subject: $subjectStr
Date: $(date -R)
MIME-Version: 1.0
Content-Type: text/html; charset="UTF-8"
<!DOCTYPE html><html><body><pre>
<p style="color:black; font-family:sans-serif; font-size:100%;">
EOF
   cat "$tempEMailBodyMsg" >> "$tempEMailContent"

   ## Footer ##
   cat <<EOF >> "$tempEMailContent"
Sent by the "<b>${ScriptFNameTag}</b>" Utility.
From the "<b>${FRIENDLY_ROUTER_NAME}</b>" router.

$(date +"%Y-%b-%d, %I:%M:%S %p %Z (%a)")
</p></pre></body></html>
EOF
    rm -f "$tempEMailBodyMsg"
    return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Jan-24] ##
##-------------------------------------##
_CheckEMailConfigFileFromAMTM_()
{
   local doLogMsgs

   if [ $# -gt 0 ] && [ "$1" -eq 1 ]
   then doLogMsgs=true
   else doLogMsgs=false
   fi

   isEMailConfigEnabledInAMTM=false

   if [ ! -f "$amtmMailConfFile" ] || [ ! -f "$amtmMailPswdFile" ]
   then
       "$doLogMsgs" && \
       Say "${REDct}**ERROR**${NOct}: Unable to send email notification [No config file]."
       return 1
   fi

   FROM_NAME=""  TO_NAME=""  FROM_ADDRESS=""  TO_ADDRESS=""
   USERNAME=""  SMTP=""  PORT=""  PROTOCOL=""  emailPwEnc=""

   . "$amtmMailConfFile"

   if [ -z "$TO_NAME" ] || [ -z "$USERNAME" ] || \
      [ -z "$FROM_ADDRESS" ] || [ -z "$TO_ADDRESS" ] || \
      [ -z "$SMTP" ] || [ -z "$PORT" ] || [ -z "$PROTOCOL" ] || [ -z "$emailPwEnc" ]
   then
       "$doLogMsgs" && \
       Say "${REDct}**ERROR**${NOct}: Unable to send email notification [Empty variables]."
       return 1
   fi

   isEMailConfigEnabledInAMTM=true
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Jan-24] ##
##-------------------------------------##
_SendEMailNotification_()
{
   if [ $# -eq 0 ] || [ -z "$1" ]  || \
   ! "$sendEMailNotificationsFlag" || \
   ! _CheckEMailConfigFileFromAMTM_ 1
   then return 1 ; fi

   [ -z "$FROM_NAME" ] && FROM_NAME="$ScriptFNameTag"
   [ -z "$FRIENDLY_ROUTER_NAME" ] && FRIENDLY_ROUTER_NAME="$MODEL_ID"

   ! _CreateEMailContent_ "$1" && return 1

   [ "$1" = "POST_REBOOT_FW_UPDATE_SETUP" ] && return 0

   printf "\nSending email notification [$1]. Please wait...\n"

   echo "$(date +"$LOGdateFormat")" > "$userTraceFile"

   /usr/sbin/curl --url ${PROTOCOL}://${SMTP}:${PORT} \
   --mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" \
   --user "${USERNAME}:$(/usr/sbin/openssl aes-256-cbc $emailPwEnc -d -in "$amtmMailPswdFile" -pass pass:ditbabot,isoi)" \
   --upload-file "$tempEMailContent" \
   $SSL_FLAG --ssl-reqd --crlf >> "$userTraceFile" 2>&1

   if [ $? -eq 0 ]
   then
       sleep 2
       Say "The email notification was sent successfully [$1]."
   else
       Say "${REDct}**ERROR**${NOct}: Failure to send email notification [$1]."
   fi
   rm -f "$tempEMailContent"

   return 0
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
## Added by Martinski W. [2024-Jan-24] ##
##-------------------------------------##
_DelPostUpdateEmailNotifyScriptHook_()
{
   local hookScriptFile

   if [ $# -gt 0 ] && [ -n "$1" ]
   then hookScriptFile="$1"
   else hookScriptFile="$hookScriptFPath"
   fi
   if [ ! -f "$hookScriptFile" ] ; then return 1 ; fi

   if grep -qE "$POST_UPDATE_EMAIL_SCRIPT_JOB" "$hookScriptFile"
   then
       sed -i -e '/\/'"$ScriptFileName"' postUpdateEmail &  '"$hookScriptTagStr"'/d' "$hookScriptFile"
       if [ $? -eq 0 ]
       then
           Say "Post-update email notification hook was deleted successfully from '$hookScriptFile' script."
       fi
   else
       Say "${GRNct}Post-update email notification hook is not found in '$hookScriptFile' script.${NOct}"
   fi
}

##-------------------------------------##
## Added by Martinski W. [2024-Jan-24] ##
##-------------------------------------##
_AddPostUpdateEmailNotifyScriptHook_()
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
        echo "$POST_UPDATE_EMAIL_SCRIPT_HOOK"
      } > "$hookScriptFile"
   #
   elif ! grep -qE "$POST_UPDATE_EMAIL_SCRIPT_JOB" "$hookScriptFile"
   then
      jobHookAdded=true
      echo "$POST_UPDATE_EMAIL_SCRIPT_HOOK" >> "$hookScriptFile"
   fi
   chmod 0755 "$hookScriptFile"

   if "$jobHookAdded"
   then Say "Post-update email notification hook was added successfully to '$hookScriptFile' script."
   else Say "Post-update email notification hook already exists in '$hookScriptFile' script."
   fi
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-28] ##
##----------------------------------------------##
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
       Say "${GRNct}Post-reboot run hook is not found in '$hookScriptFile' script.${NOct}"
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

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-22] ##
##----------------------------------------------##
_GetCurrentFWInstalledLongVersion_()
{
   local theBranchVers  theVersionStr  extVersNum

   theBranchVers="$(nvram get firmver | sed 's/\.//g')"

   extVersNum="$(nvram get extendno)"
   [ -z "$extVersNum" ] && extVersNum=0

   theVersionStr="$(nvram get buildno).$extVersNum"
   [ -n "$theBranchVers" ] && theVersionStr="${theBranchVers}.${theVersionStr}"

   echo "$theVersionStr"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-22] ##
##----------------------------------------##
_GetCurrentFWInstalledShortVersion_()
{
    local theVersionStr  extVersNum

    extVersNum="$(nvram get extendno | awk -F '-' '{print $1}')"
    [ -z "$extVersNum" ] && extVersNum=0

    theVersionStr="$(nvram get buildno).$extVersNum"
    echo "$theVersionStr"
}

##-------------------------------------##
## Added by Martinski W. [2023-Dec-15] ##
##-------------------------------------##
_HasRouterMoreThan256MBtotalRAM_()
{
   local totalRAM_KB
   totalRAM_KB="$(cat /proc/meminfo | awk -F ' ' '/^MemTotal: /{print $2}')"
   [ -n "$totalRAM_KB" ] && [ "$totalRAM_KB" -gt 262144 ] && return 0
   return 1
}

##-------------------------------------##
## Added by Martinski W. [2023-Dec-15] ##
##-------------------------------------##
#---------------------------------------------------------------------#
# The actual amount of RAM that is available for any new process
# (*without* using the swap file) can be roughly estimated from
# "MemFree" & "Page Cache" (i.e. Active files + Inactive files),
# This estimate must take into account that the overall system 
# (kernel + native services + tmpfs) needs a minimum amount of RAM
# to continue to work, and that not all reclaimable Page Cache can
# be reclaimed because some may actually be in used at the time.
#---------------------------------------------------------------------#
_GetAvailableRAM_KB_()
{
   local theMemAvailable_KB  theMemFree_KB
   local activeFiles_KB  inactiveFiles_KB  thePageCache_KB

   theMemAvailable_KB="$(cat /proc/meminfo | awk -F ' ' '/^MemAvailable: /{print $2}')"
   [ -n "$theMemAvailable_KB" ] && echo "$theMemAvailable_KB" && return 0

   theMemFree_KB="$(cat /proc/meminfo | awk -F ' ' '/^MemFree: /{print $2}')"
   activeFiles_KB="$(cat /proc/meminfo | awk -F ' ' '/^Active\(file\): /{print $2}')"
   inactiveFiles_KB="$(cat /proc/meminfo | awk -F ' ' '/^Inactive\(file\): /{print $2}')"
   thePageCache_KB="$((activeFiles_KB + inactiveFiles_KB))"

   #----------------------------------------------------------------#
   # Since not all Page Cache is guaranteed to be reclaimed at any
   # moment, we simply estimate that only half will be reclaimable.
   #----------------------------------------------------------------#
   theMemAvailable_KB="$((theMemFree_KB + ((thePageCache_KB / 2))))"
   echo "$theMemAvailable_KB" ; return 0
}

get_free_ram() {
    # Using awk to sum up the 'free', 'buffers', and 'cached' columns.
    free | awk '/^Mem:/{print $4}'  # This will return the available memory in kilobytes.
    ##FOR DEBUG ONLY##echo 1000
}

##---------------------------------------##
## Added by ExtremeFiretop [2023-Dec-09] ##
##---------------------------------------##
get_required_space() {
    local url="$1"
    local zip_file_size_kb extracted_file_size_buffer_kb 
    local overhead_percentage=50  # Overhead percentage (e.g., 50%)
    
    # Size of the ZIP file in bytes
    local zip_file_size_bytes=$(curl -sIL "$url" | grep -i Content-Length | tail -1 | awk '{print $2}')
    # Convert bytes to kilobytes
    zip_file_size_kb=$((zip_file_size_bytes / 1024))
    
    # Calculate overhead based on the percentage
    local overhead_kb=$((zip_file_size_kb * overhead_percentage / 100))
    
    # Calculate total required space
    local total_required_kb=$((zip_file_size_kb + overhead_kb))
    echo "$total_required_kb"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jan-06] ##
##----------------------------------------##
check_memory_and_prompt_reboot() {
    local required_space_kb="$1"
    local availableRAM_kb="$2"

    if [ "$availableRAM_kb" -lt "$required_space_kb" ]; then
        Say "Insufficient RAM available."

        # Attempt to clear PageCache #
        Say "Attempting to free up memory..."
        sync; echo 1 > /proc/sys/vm/drop_caches

        # Check available memory again #
        availableRAM_kb=$(_GetAvailableRAM_KB_)
        if [ "$availableRAM_kb" -lt "$required_space_kb" ]; then
            # In an interactive shell session, ask user to confirm reboot #
            if "$isInteractive" && _WaitForYESorNO_ "Reboot router now"
            then
                _AddPostRebootRunScriptHook_
                Say "Rebooting router..."
                _ReleaseLock_
                /sbin/service reboot
                exit 1  # Although the reboot command should end the script, it's good practice to exit after.
            else
                # Exit script if non-interactive or if user answers NO #
                Say "Insufficient memory to continue. Exiting script."
                _DoCleanUp_ 1 "$keepZIPfile"
                _DoExit_ 1
            fi
        else
            Say "Successfully freed up memory. Available: ${availableRAM_kb}KB."
        fi
    fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-26] ##
##------------------------------------------##
_DoCleanUp_()
{
   local delBINfiles=false  keepZIPfile=false  moveZIPback=false

   local doTrace=false
   [ $# -gt 0 ] && [ "$1" -eq 0 ] && doTrace=false
   if "$doTrace"
   then
       Say "\nSTART _DoCleanUp_"
       echo "$(date +"$LOGdateFormat") START _DoCleanUp_" >> "$userTraceFile"
   fi

   [ $# -gt 0 ] && [ "$1" -eq 1 ] && delBINfiles=true
   [ $# -gt 1 ] && [ "$2" -eq 1 ] && keepZIPfile=true

   # Stop the LEDs blinking #
   _Reset_LEDs_ 1

   # Move file temporarily to save it from deletion #
   "$keepZIPfile" && [ -f "$FW_ZIP_FPATH" ] && \
   mv -f "$FW_ZIP_FPATH" "${FW_ZIP_BASE_DIR}/$ScriptDirNameD" && moveZIPback=true

   rm -f "${FW_ZIP_DIR}"/*
   "$delBINfiles" && rm -f "${FW_BIN_DIR}"/*

   # Move file back to original location #
   "$keepZIPfile" && "$moveZIPback" && \
   mv -f "${FW_ZIP_BASE_DIR}/${ScriptDirNameD}/${FW_FileName}.zip" "$FW_ZIP_FPATH"

   if "$doTrace"
   then
       Say "EXIT _DoCleanUp_"
       echo "$(date +"$LOGdateFormat") EXIT _DoCleanUp_" >> "$userTraceFile"
   fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-06] ##
##------------------------------------------##
# Function to check if the current router model is supported
check_version_support() {
    # Minimum supported firmware version
    minimum_supported_version="386.12.0"

    # Get the current firmware version
    local current_version="$(_GetCurrentFWInstalledShortVersion_)"

    local numFields="$(echo "$current_version" | awk -F '.' '{print NF}')"
    local numCurrentVers="$(_FWVersionStrToNum_ "$current_version" "$numFields")"
    local numMinimumVers="$(_FWVersionStrToNum_ "$minimum_supported_version" "$numFields")"

    # If the current firmware version is lower than the minimum supported firmware version, exit.
    if [ "$numCurrentVers" -lt "$numMinimumVers" ]
    then
       MinFirmwareCheckFailed="1"
    fi
}

check_model_support() {
    # List of unsupported models as a space-separated string
    local unsupported_models="RT-AC87U RT-AC56U RT-AC66U RT-AC3200 RT-N66U RT-AC88U RT-AC5300 RT-AC3100 RT-AC68U RT-AC66U_B1 RT-AC1900"

    # Get the current model
    local current_model="$(_GetRouterProductID_)"

    # Check if the current model is in the list of unsupported models
    if echo "$unsupported_models" | grep -wq "$current_model"; then
       ModelCheckFailed="1"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-16] ##
##----------------------------------------##
_GetLoginCredentials_()
{
    echo "=== Login Credentials ==="
    local username  password  credsBase64

    # Get the username from nvram
    username="$(nvram get http_username)"

    # Prompt the user only for a password [-s flag hides the password input]
    printf "Enter password for user ${GRNct}${username}${NOct}: "
    read -rs password
    echo
    if [ -z "$password" ]
    then
        echo "Password cannot be empty. Credentials were not saved."
        _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Encode the username and password in Base64 #
    credsBase64="$(echo -n "${username}:${password}" | openssl base64 -A)"

    # Save the credentials to the SETTINGSFILE #
    Update_Custom_Settings credentials_base64 "$credsBase64"

    echo "Credentials saved."
    _WaitForEnterKey_ "$menuReturnPromptStr"
    return 0
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-20] ##
##----------------------------------------##
_GetLatestFWUpdateVersionFromWebsite_()
{
    local url="$1"

    local links_and_versions="$(curl -s "$url" | grep -o 'href="[^"]*'"$PRODUCT_ID"'[^"]*\.zip' | sed 's/amp;//g; s/href="//' | 
        awk -F'[_\.]' '{print $3"."$4"."$5" "$0}' | sort -t. -k1,1n -k2,2n -k3,3n)"

    if [ -z "$links_and_versions" ]
    then echo "**ERROR** **NO_URL**" ; return 1 ; fi

    local latest="$(echo "$links_and_versions" | tail -n 1)"
    local linkStr="$(echo "$latest" | cut -d' ' -f2-)"
    local fileStr="$(echo "$linkStr" | grep -oE "/${PRODUCT_ID}_[0-9]+.*.zip$")"
    local versionStr

    if [ -z "$fileStr" ]
    then versionStr="$(echo "$latest" | cut -d ' ' -f1)"
    else versionStr="$(echo "${fileStr%.*}" | sed "s/\/${PRODUCT_ID}_//" | sed 's/_/./g')"
    fi

    # Extracting the correct link from the page
    local correct_link="$(echo "$linkStr" | sed 's|^/|https://sourceforge.net/|')"

    echo "$versionStr"
    echo "$correct_link"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Jan-23] ##
##---------------------------------------##
_toggle_change_log_check_() {
    local currentSetting="$(Get_Custom_Setting "CheckChangeLog")"

    if [ "$currentSetting" = "ENABLED" ]; then
        printf "${REDct}*WARNING*:${NOct} Disabling change-log verification may risk unanticipated changes.\n"
        printf "The advice is to proceed only if you review the change-logs manually.\n"
        printf "\nProceed to disable? [y/N]: "
        read -r response
        case $response in
            [Yy]* )
                Update_Custom_Settings "CheckChangeLog" "DISABLED"
                printf "Change-log verification check is now ${REDct}DISABLED.${NOct}\n"
                ;;
            *)
                printf "Change-log verification check remains ${GRNct}ENABLED.${NOct}\n"
                ;;
        esac
    else
        printf "Are you sure you want to enable the change-log verification check? [y/N]: "
        read -r response
        case $response in
            [Yy]* )
                Update_Custom_Settings "CheckChangeLog" "ENABLED"
                printf "Change-log verification check is now ${GRNct}ENABLED.${NOct}\n"
                ;;
            *)
                printf "Change-log verification check remains ${REDct}DISABLED.${NOct}\n"
                ;;
        esac
    fi
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Jan-27] ##
##---------------------------------------##
_toggle_beta_updates_() {
    local currentSetting="$(Get_Custom_Setting "FW_Allow_Beta_Production_Up")"

    if [ "$currentSetting" = "ENABLED" ]; then
        printf "${REDct}*WARNING*:${NOct}\n"
		printf "Disabling updates from beta F/Ws to release F/Ws may prevent access to the latest features and fixes.\n"
        printf "Keep this enabled if you prefer to stay up-to-date with the latest releases.\n"
        printf "\nProceed to disable? [y/N]: "
        read -r response
        case $response in
            [Yy]* )
                Update_Custom_Settings "FW_Allow_Beta_Production_Up" "DISABLED"
                printf "Updates from beta firmwares to production firmwares are now ${REDct}DISABLED.${NOct}\n"
                ;;
            *)
                printf "Updates from beta firmwares to production firmwares remain ${GRNct}ENABLED.${NOct}\n"
                ;;
        esac
    else
        printf "Are you sure you want to enable updates from beta F/Ws to production F/Ws?"
        printf "\nProceed to enable? [y/N]: "
        read -r response
        case $response in
            [Yy]* )
                Update_Custom_Settings "FW_Allow_Beta_Production_Up" "ENABLED"
                printf "Updates from beta firmwares to production firmwares are now ${GRNct}ENABLED.${NOct}\n"
                ;;
            *)
                printf "Updates from beta firmwares to production firmwares remain ${REDct}DISABLED.${NOct}\n"
                ;;
        esac
    fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-07] ##
##------------------------------------------##
change_build_type() {
    echo "Changing Build Type..."

    # Use Get_Custom_Setting to retrieve the previous choice
    previous_choice="$(Get_Custom_Setting "ROGBuild")"

    # If the previous choice is not set, default to 'n'
    if [ "$previous_choice" = "TBD" ]; then
        previous_choice="n"
    fi

    # Convert previous choice to a descriptive text
    if [ "$previous_choice" = "y" ]; then
        display_choice="ROG Build"
    else
        display_choice="Pure Build"
    fi

    printf "Current Build Type: ${GRNct}$display_choice${NOct}.\n"
    printf "Would you like to use the original ${REDct}ROG${NOct} themed user interface?${NOct}\n"

    while true; do
        printf "\n[${theADExitStr}] Enter your choice (y/n): "
        read -r choice
        choice="${choice:-$previous_choice}"
        choice="$(echo "$choice" | tr '[:upper:]' '[:lower:]')"

        if [ "$choice" = "y" ] || [ "$choice" = "yes" ]; then
			Update_Custom_Settings "ROGBuild" "y"
			break
        elif [ "$choice" = "n" ] || [ "$choice" = "no" ]; then
			Update_Custom_Settings "ROGBuild" "n"
			break
        elif [ "$choice" = "exit" ] || [ "$choice" = "e" ]; then
			echo "Exiting without changing the build type."
			break
        else
			echo "Invalid input! Please enter 'y', 'yes', 'n', 'no', or 'exit'."
        fi
    done
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
   if [ -z "$newSchedule" ] || [ "$newSchedule" = "TBD" ]
   then
       newSchedule="$FW_Update_CRON_DefaultSchedule"
   fi

   cru a "$CRON_JOB_TAG" "$newSchedule $CRON_JOB_RUN"
   sleep 1
   if $cronCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
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
   if $cronCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
   then
       cru d "$CRON_JOB_TAG" ; sleep 1
       if $cronCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
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
        then printf "\n[${theADExitStr}] [Default Schedule: ${GRNct}${new_schedule}${NOct}]:  "
        else printf "\n[${theADExitStr}] [Current Schedule: ${GRNct}${current_schedule}${NOct}]:  "
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
    [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
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

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-26] ##
##------------------------------------------##
_CheckNewUpdateFirmwareNotification_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

   local numVersionFields  fwNewUpdateVersNum

   numVersionFields="$(echo "$2" | awk -F '.' '{print NF}')"
   currentVersionNum="$(_FWVersionStrToNum_ "$1" "$numVersionFields")"
   releaseVersionNum="$(_FWVersionStrToNum_ "$2" "$numVersionFields")"

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
       fwNewUpdateVersNum="$(_FWVersionStrToNum_ "$fwNewUpdateNotificationVers" "$numVersionFields")"
       if [ "$releaseVersionNum" -gt "$fwNewUpdateVersNum" ]
       then
           fwNewUpdateNotificationVers="$2"
           fwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
           Update_Custom_Settings FW_New_Update_Notification_Vers "$fwNewUpdateNotificationVers"
           Update_Custom_Settings FW_New_Update_Notification_Date "$fwNewUpdateNotificationDate"
           _SendEMailNotification_ NEW_FW_UPDATE_STATUS
       fi
   fi

   fwNewUpdateNotificationDate="$(Get_Custom_Setting FW_New_Update_Notification_Date)"
   if [ -z "$fwNewUpdateNotificationDate" ] || [ "$fwNewUpdateNotificationDate" = "TBD" ]
   then
       fwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
       Update_Custom_Settings FW_New_Update_Notification_Date "$fwNewUpdateNotificationDate"
       _SendEMailNotification_ NEW_FW_UPDATE_STATUS
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

   if [ "$((currentTimeSecs - notifyTimeSecs))" -gt "$postponeTimeSecs" ]
   then return 0 ; fi

   upfwDateTimeSecs="$((notifyTimeSecs + postponeTimeSecs))"
   upfwDateTimeStrn="$(echo "$upfwDateTimeSecs" | awk '{print strftime("%Y-%b-%d",$1)}')"

   Say "The firmware update to ${GRNct}${2}${NOct} version is currently postponed for ${GRNct}${fwNewUpdatePostponementDays}${NOct} day(s)."
   Say "The firmware update is expected to occur on or after ${GRNct}${upfwDateTimeStrn}${NOct} depending on when your cron job is scheduled to check again."
   return 1
}

##-------------------------------------##
## Added by Martinski W. [2024-Jan-24] ##
##-------------------------------------##
_Toggle_FW_UpdateEmailNotifications_()
{
   local emailNotificationEnabled  emailNotificationNewStateStr
   local runEmailNotifyTestOK=false

   if "$sendEMailNotificationsFlag"
   then
       emailNotificationEnabled=true
       emailNotificationNewStateStr="${REDct}DISABLE${NOct}"
   else
       emailNotificationEnabled=false
       emailNotificationNewStateStr="${GRNct}ENABLE${NOct}"
   fi

   if ! _WaitForYESorNO_ "Do you want to ${emailNotificationNewStateStr} F/W Update email notifications?"
   then return 1 ; fi

   if "$emailNotificationEnabled"
   then
       runEmailNotifyTestOK=false
       sendEMailNotificationsFlag=false
       emailNotificationNewStateStr="${REDct}DISABLED${NOct}"
   else
       runEmailNotifyTestOK=true
       sendEMailNotificationsFlag=true
       emailNotificationNewStateStr="${GRNct}ENABLED${NOct}"
   fi

   Update_Custom_Settings FW_New_Update_EMail_Notification "$sendEMailNotificationsFlag"
   printf "F/W Update email notifications are now ${emailNotificationNewStateStr}.\n"

   if "$runEmailNotifyTestOK" && \
      _WaitForYESorNO_ "\nWould you like to run a test of the email notification?"
   then
       _SendEMailNotification_ FW_UPDATE_TEST_EMAIL
   fi
   _WaitForEnterKey_ "$menuReturnPromptStr"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2023-Nov-26] ##
##------------------------------------------##
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
       fwUpdateCheckNewStateStr="${REDct}DISABLE${NOct}"
   fi

   if ! _WaitForYESorNO_ "Do you want to ${fwUpdateCheckNewStateStr} the built-in F/W Update Check?"
   then return 1 ; fi

   if "$fwUpdateCheckEnabled"
   then
       runfwUpdateCheck=false
       FW_UpdateCheckState=0
       fwUpdateCheckNewStateStr="${REDct}DISABLED${NOct}"
       _DelCronJobEntry_
       _DelCronJobRunScriptHook_
   else
       [ -x "$FW_UpdateCheckScript" ] && runfwUpdateCheck=true
       FW_UpdateCheckState=1
       fwUpdateCheckNewStateStr="${GRNct}ENABLED${NOct}"
       if _AddCronJobEntry_
       then
           printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was added successfully.\n"
           _AddCronJobRunScriptHook_
       else
           printf "${REDct}**ERROR**${NOct}: Failed to add the cron job [${CRON_JOB_TAG}].\n"
       fi
   fi

   nvram set firmware_check_enable="$FW_UpdateCheckState"
   printf "Router's built-in Firmware Update Check is now ${fwUpdateCheckNewStateStr}.\n"
   nvram commit

   "$runfwUpdateCheck" && sh $FW_UpdateCheckScript 2>&1 &
   _WaitForEnterKey_ "$menuReturnPromptStr"
}

##-------------------------------------##
## Added by Martinski W. [2024-Jan-25] ##
##-------------------------------------##
_EntwareServicesHandler_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   local fileCount  entwOPT_init  entwOPT_unslung  actionStr=""

   entwOPT_init="/opt/etc/init.d"
   entwOPT_unslung="${entwOPT_init}/rc.unslung"

   if [ ! -x /opt/bin/opkg ] || [ ! -x "$entwOPT_unslung" ]
   then return 0 ; fi  ## Entware is not found ##

   fileCount="$(/usr/bin/find "$entwOPT_init" -name "S*" -exec ls -1 {} \; 2>/dev/null | /bin/grep -cE "${entwOPT_init}/S[0-9]+")"
   [ "$fileCount" -eq 0 ] && return 0

   case "$1" in
       stop) actionStr="Stopping" ;;
      start) actionStr="Restarting" ;;
          *) return 1 ;;
   esac

   if [ -n "$actionStr" ]
   then
      printf "\n${actionStr} Entware services... Please wait.\n"
      $entwOPT_unslung $1 ; sleep 5
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jan-25] ##
##----------------------------------------##
# Embed functions from second script, modified as necessary.
_RunFirmwareUpdateNow_()
{
    # Check if the router model is supported OR if
    # it has the minimum firmware version supported.
    if [ "$ModelCheckFailed" != "0" ]; then
        Say "${REDct}WARNING:${NOct} The current router model is not supported by this script."
        if "$inMenuMode"; then
            printf "\nWould you like to uninstall the script now?"
            if _WaitForYESorNO_; then
                _DoUninstall_
                return 0
            else
                Say "Uninstallation cancelled. Exiting script."
                _WaitForEnterKey_ "$menuReturnPromptStr"
                return 0
            fi
        else
            Say "Exiting script due to unsupported router model."
            _DoExit_ 1
        fi
    fi
    if [ "$MinFirmwareCheckFailed" != "0" ]; then
        Say "${REDct}WARNING:${NOct} The current firmware version is below the minimum supported.
Please manually update to version $minimum_supported_version or higher to use this script.\n"
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    Say "Running the task now... Checking for F/W updates..."

    #---------------------------------------------------------------#
    # Check if an expected USB-attached drive is still mounted.
    # Make a special case when USB drive has Entware installed. 
    #---------------------------------------------------------------#
    if echo "$FW_ZIP_BASE_DIR" | grep -qE "^(/tmp/mnt/|/tmp/opt/|/opt/)" && \
       ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR"
    then
        Say "Expected directory path $FW_ZIP_BASE_DIR is NOT found."
        Say "${REDct}**ERROR**${NOct}: Required USB storage device is not connected or not mounted correctly."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Double-check the directory exists before using it #
    [ ! -d "$FW_LOG_DIR" ] && mkdir -p -m 755 "$FW_LOG_DIR"

    # Set up the custom log file #
    userLOGFile="${FW_LOG_DIR}/${MODEL_ID}_FW_Update_$(date '+%Y-%m-%d_%H_%M_%S').log"
    touch "$userLOGFile"  ## Must do this to indicate custom log file is enabled ##

    #---------------------------------------------------------#
    # If the expected directory path for the ZIP file is not
    # found, we select the $HOME path instead as a temporary 
    # fallback. This should work if free RAM is >= ~150MB.
    #---------------------------------------------------------#
    if [ ! -d "$FW_ZIP_BASE_DIR" ]
    then
        Say "Expected directory path $FW_ZIP_BASE_DIR is NOT found."
        Say "Using temporary fallback directory: /home/root"
        "$inMenuMode" && { _WaitForYESorNO_ "Continue?" || return 1 ; }
        # Continue #
        FW_ZIP_BASE_DIR="/home/root"
        FW_ZIP_DIR="${FW_ZIP_BASE_DIR}/$FW_ZIP_SUBDIR"
        FW_ZIP_FPATH="${FW_ZIP_DIR}/${FW_FileName}.zip"
    fi

    local credsBase64=""
    local currentVersionNum=""  releaseVersionNum=""
    local current_version=""  release_version=""

    # Create directory for downloading & extracting firmware #
    if ! _CreateDirectory_ "$FW_ZIP_DIR" ; then return 1 ; fi

    # In case ZIP directory is different from BIN directory #
    if [ "$FW_ZIP_DIR" != "$FW_BIN_DIR" ] && \
       ! _CreateDirectory_ "$FW_BIN_DIR" ; then return 1 ; fi

    # Get current firmware version #
    current_version="$(_GetCurrentFWInstalledShortVersion_)"
    ##FOR DEBUG ONLY##current_version="388.5.0"

    #---------------------------------------------------------#
    # If the "F/W Update Check" in the WebGUI is disabled 
    # return without further actions. This allows users to 
    # control the "F/W Auto-Update" feature from one place.
    # However, when running in "Menu Mode" the assumption
    # is that the user wants to do a MANUAL Update Check
    # regardless of the state of the "F/W Update Check."
    #---------------------------------------------------------#  
    FW_UpdateCheckState="$(nvram get firmware_check_enable)"
    [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
    if [ "$FW_UpdateCheckState" -eq 0 ]
    then
        Say "Firmware update check is currently disabled."
        "$inMenuMode" && _WaitForEnterKey_ || return 1
    fi

    #------------------------------------------------------
    # If the "New F/W Update" flag has been set get the
    # "New F/W Release Version" from the router itself.
    # If no new F/W version update is available return.
    #------------------------------------------------------
    if ! release_version="$(_GetLatestFWUpdateVersionFromRouter_)" || \
       ! _CheckNewUpdateFirmwareNotification_ "$current_version" "$release_version"
    then
        Say "No new firmware version update is found for [$PRODUCT_ID] router model."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Use set to read the output of the function into variables
    set -- $(_GetLatestFWUpdateVersionFromWebsite_ "$FW_URL_RELEASE")
    release_version="$1"
    release_link="$2"

    # Extracting the first octet to use in the curl
    firstOctet="$(echo "$release_version" | cut -d'.' -f1)"
    # Inserting dots between each number
    dottedVersion="$(echo "$firstOctet" | sed 's/./&./g' | sed 's/.$//')"

    if ! _CheckTimeToUpdateFirmware_ "$current_version" "$release_version"
    then
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 0
    fi

    ## Check for Login Credentials ##
    credsBase64="$(Get_Custom_Setting credentials_base64)"
    if [ -z "$credsBase64" ] || [ "$credsBase64" = "TBD" ]
    then
        Say "${REDct}**ERROR**${NOct}: No login credentials have been saved. Use the Main Menu to save login credentials."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    if [ "$1" = "**ERROR**" ] && [ "$2" = "**NO_URL**" ] 
    then
        Say "${REDct}**ERROR**${NOct}: No firmware release URL was found for [$PRODUCT_ID] router model."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    ##---------------------------------------##
    ## Added by ExtremeFiretop [2023-Dec-09] ##
    ##---------------------------------------##
    # Get the required space for the firmware download and extraction
    required_space_kb=$(get_required_space "$release_link")
    if ! _HasRouterMoreThan256MBtotalRAM_ && [ "$required_space_kb" -gt 51200 ]; then
        if ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR"; then
            Say "${REDct}**ERROR**${NOct}: A USB drive is required for the F/W update due to limited RAM."
            "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
            return 1
        fi
    fi

    freeRAM_kb="$(get_free_ram)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${required_space_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$required_space_kb" "$availableRAM_kb"

    # Compare versions before deciding to download
    if [ "$releaseVersionNum" -gt "$currentVersionNum" ]
    then
        # Background function to create a blinking LED effect #
        Toggle_LEDs 2 & Toggle_LEDs_PID=$!

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

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Jan-22] ##
    ##------------------------------------------##
    freeRAM_kb="$(get_free_ram)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${required_space_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$required_space_kb" "$availableRAM_kb"

    # Extracting the firmware binary image #
    if unzip -o "$FW_ZIP_FPATH" -d "$FW_BIN_DIR" -x README*
    then
        #---------------------------------------------------------------#
        # Check if ZIP file was downloaded to a USB-attached drive.
        # Take into account special case for Entware "/opt/" paths. 
        #---------------------------------------------------------------#
        if ! echo "$FW_ZIP_FPATH" | grep -qE "^(/tmp/mnt/|/tmp/opt/|/opt/)"
        then
            # It's not on a USB drive, so it's safe to delete it #
            rm -f "$FW_ZIP_FPATH"
        #
        elif ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR"
        then
            #-------------------------------------------------------------#
            # This should not happen because we already checked for it
            # at the very beginning of this function, but just in case
            # it does (drive going bad suddenly?) we'll report it here.
            #-------------------------------------------------------------#
            Say "Expected directory path $FW_ZIP_BASE_DIR is NOT found."
            Say "${REDct}**ERROR**${NOct}: Required USB storage device is not connected or not mounted correctly."
            "$inMenuMode" && _WaitForEnterKey_
            # Consider how to handle this error. For now, we'll not delete the ZIP file.
        else
            keepZIPfile=1
        fi
    else
        #------------------------------------------------------------#
        # Remove ZIP file here because it may have been corrupted.
        # Better to download it again and start all over, instead
        # of trying to figure out why uncompressing it failed.
        #------------------------------------------------------------#
        rm -f "$FW_ZIP_FPATH"
        Say "${REDct}**ERROR**${NOct}: Unable to decompress the firmware ZIP file [$FW_ZIP_FPATH]."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Navigate to the firmware directory
    cd "$FW_BIN_DIR"

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Jan-25] ##
    ##------------------------------------------##
    local checkChangeLogSetting="$(Get_Custom_Setting "CheckChangeLog")"

    if [ "$checkChangeLogSetting" = "ENABLED" ]; then
        # Define the path to the log file
        changelog_file="${FW_BIN_DIR}/Changelog-NG.txt"

        # Check if the log file exists
        if [ ! -f "$changelog_file" ]; then
            Say "Change-log file does not exist at $changelog_file"
            _DoCleanUp_
            "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
            return 1
        else
            # Format current_version by removing the last '.0'
            formatted_current_version=$(echo $current_version | awk -F. '{print $1"."$2}')

            # Format release_version by removing the prefix '3004.' and the last '.0'
            formatted_release_version=$(echo $release_version | awk -F. '{print $2"."$3}')

            # Extract log contents between two firmware versions
            changelog_contents=$(awk "/$formatted_release_version/,/$formatted_current_version/" "$changelog_file")

            # Define high-risk terms as a single string separated by '|'
            high_risk_terms="factory default reset|features are disabled|break backward compatibility|must be manually|strongly recommended"

            # Search for high-risk terms in the extracted log contents
            if echo "$changelog_contents" | grep -Eiq "$high_risk_terms"; then
                if [ "$inMenuMode" = true ]; then
                    printf "\n ${REDct}Warning: Found high-risk phrases in the change-logs.${NOct}"
                    printf "\n ${REDct}Would you like to continue anyways?${NOct}"
                    if ! _WaitForYESorNO_ ; then
                        Say "Exiting for change-log review."
                        _DoCleanUp_ 1 ; return 1
                    fi
                else
                    Say "Warning: Found high-risk phrases in the change-logs."
                    Say "Please run script interactively to approve the upgrade."
                    _SendEMailNotification_ STOP_FW_UPDATE_APPROVAL
                    _DoCleanUp 1
                    _DoExit_ 1
                fi
            else
                Say "No high-risk phrases found in the change-logs."
            fi
        fi
    else
        Say "Change-logs check disabled."
    fi

    # Detect ROG and pure firmware files
    rog_file="$(ls | grep -i '_rog_')"
    pure_file="$(ls -1 | grep -iE '.*[.](w|pkgtb)$' | grep -iv 'rog')"

    # Fetch the previous choice from the settings file
    previous_choice="$(Get_Custom_Setting "ROGBuild")"

    # Check if a ROG build is present
    if [ -n "$rog_file" ]; then
        # Use the previous choice if it exists and valid, else prompt the user for their choice in interactive mode
        if [ "$previous_choice" = "y" ]; then
            Say "ROG Build selected for flashing"
            firmware_file="$rog_file"
        elif [ "$previous_choice" = "n" ]; then
            Say "Pure Build selected for flashing"
            firmware_file="$pure_file"
        elif [ "$inMenuMode" = true ]; then
            printf "${REDct}Found ROG build: $rog_file.${NOct}\n"
            printf "${REDct}Would you like to use the ROG build?${NOct}\n"
            printf "Enter your choice (y/n): "
            read -r choice
            if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
                Say "ROG Build selected for flashing"
                firmware_file="$rog_file"
                Update_Custom_Settings "ROGBuild" "y"
            else
                Say "Pure Build selected for flashing"
                firmware_file="$pure_file"
                Update_Custom_Settings "ROGBuild" "n"
            fi
        else
            # Default to pure_file in non-interactive mode if no previous choice
            Say "Pure Build selected for flashing"
            Update_Custom_Settings "ROGBuild" "n"
            firmware_file="$pure_file"
        fi
    else
        # No ROG build found, use the pure build
        Say "No ROG Build detected. Skipping."
        firmware_file="$pure_file"
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

    ##---------------------------------------##
    ## Added by ExtremeFiretop [2024-Jan-26] ##
    ##---------------------------------------##
    freeRAM_kb=$(get_free_ram)
    availableRAM_kb=$(_GetAvailableRAM_KB_)
    Say "Required RAM: ${required_space_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$required_space_kb" "$availableRAM_kb"

    # Check for the presence of backupmon.sh script (Commented out until issues resolved)
    if [ -f "/jffs/scripts/backupmon.sh" ] && [ -f "/jffs/addons/backupmon.d/version.txt" ]; then

        # Read version number from version.txt
        BM_VERSION=$(cat /jffs/addons/backupmon.d/version.txt)

        # Convert both current and required versions to numeric format
        current_version=$(_ScriptVersionStrToNum_ "$BM_VERSION")
        required_version=$(_ScriptVersionStrToNum_ "1.44")

        # Check if BACKUPMON version is greater than or equal to 1.44
        if [ "$current_version" -ge "$required_version" ]; then
            # Execute the backup script if it exists #
            Say "\nBackup Started (by BACKUPMON)"
            sh /jffs/scripts/backupmon.sh -backup >/dev/null
            BE=$?
            Say "Backup Finished\n"
            if [ $BE -eq 0 ]; then
                Say "Backup Completed Successfully\n"
            else
                Say "Backup Failed\n"
                _SendEMailNotification_ NEW_BM_BACKUP_FAILED
                _DoCleanUp_ 1
                if "$isInteractive"
                then
                    printf "\n${REDct}**IMPORTANT NOTICE**:${NOct}\n"
                    printf "The firmware flash has been ${REDct}CANCELLED${NOct} due to a failed backup from BACKUPMON.\n"
                    printf "Please fix the BACKUPMON configuration, or consider uninstalling it to proceed flash.\n"
                    printf "Resolving the BACKUPMON configuration is HIGHLY recommended for safety of the upgrade.\n"
                    _WaitForEnterKey_ "$menuReturnPromptStr"
                    return 1
                else
                    _DoExit_ 1
                fi
            fi
        else
            # BACKUPMON version is not sufficient
            Say "\n${REDct}**IMPORTANT NOTICE**:${NOct}\n"
            Say "Backup script (BACKUPMON) is installed; but version $BM_VERSION does not meet the minimum required version of 1.44.\n"
            Say "Skipping backup. Please update your version of BACKUPMON.\n"
        fi
    else
        # Print a message if the backup script is not installed
        Say "Backup script (BACKUPMON) is not installed. Skipping backup.\n"
    fi

    ##----------------------------------------##
    ## Modified by Martinski W. [2024-Jan-06] ##
    ##----------------------------------------##
    freeRAM_kb="$(get_free_ram)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${required_space_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$required_space_kb" "$availableRAM_kb"

    routerURLstr="$(_GetRouterURL_)"
    Say "Router Web URL is: ${routerURLstr}"

    if "$isInteractive"
    then
        printf "${GRNct}**IMPORTANT**:${NOct}\nThe firmware flash is about to start.\n"
        printf "Press Enter to stop now, or type ${GRNct}Y${NOct} to continue.\n"
        printf "Once started, the flashing process CANNOT be interrupted.\n"
        if ! _WaitForYESorNO_ "Continue?"
        then _DoCleanUp_ 1 "$keepZIPfile" ; return 1 ; fi
    fi

    #------------------------------------------------------------#
    # Restart the WebGUI to make sure nobody else is logged in
    # so that the F/W Update can start without interruptions.
    #------------------------------------------------------------#
    "$isInteractive" && printf "\nRestarting web server... Please wait.\n"
    /sbin/service restart_httpd &
    sleep 5

    # Send last email notification before flash #
    _SendEMailNotification_ START_FW_UPDATE_STATUS

    # Check if '/opt/bin/diversion' exists #
    if [ -f /opt/bin/diversion ]; then
        # Stop Diversion services before flash #
        Say "Stopping Diversion service..."
        /opt/bin/diversion unmount
    fi

    # Stop entware services before flash #
    _EntwareServicesHandler_ stop

    curl_response="$(curl "${routerURLstr}/login.cgi" \
    --referer ${routerURLstr}/Main_Login.asp \
    --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Origin: ${routerURLstr}/" \
    -H 'Connection: keep-alive' \
    --data-raw "group_id=&action_mode=&action_script=&action_wait=5&current_page=Main_Login.asp&next_page=index.asp&login_authorization=${credsBase64}" \
    --cookie-jar /tmp/cookie.txt)"

    # IMPORTANT: Due to the nature of 'nohup' and the specific behavior of this 'curl' request,
    # the following 'curl' command MUST always be the last step in this block.
    # Do NOT insert any operations after it! (unless you understand the implications).

    if echo "$curl_response" | grep -q 'url=index.asp'
    then
        _SendEMailNotification_ POST_REBOOT_FW_UPDATE_SETUP

        Say "Flashing ${GRNct}${firmware_file}${NOct}... ${REDct}Please wait for reboot in about 4 minutes or less.${NOct}"
        echo

        nohup curl "${routerURLstr}/upgrade.cgi" \
        --referer ${routerURLstr}/Advanced_FirmwareUpgrade_Content.asp \
        --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
        -H 'Accept-Language: en-US,en;q=0.5' \
        -H "Origin: ${routerURLstr}/" \
        -F 'current_page=Advanced_FirmwareUpgrade_Content.asp' \
        -F 'next_page=' \
        -F 'action_mode=' \
        -F 'action_script=' \
        -F 'action_wait=' \
        -F 'preferred_lang=EN' \
        -F "firmver=${dottedVersion}" \
        -F "file=@${firmware_file}" \
        --cookie /tmp/cookie.txt > /tmp/upload_response.txt 2>&1 &
        curlPID=$!
        #----------------------------------------------------------#
        # In the rare case that the F/W Update gets "stuck" for
        # some reason & the "curl" cmd never returns, we create 
        # a background child process that sleeps for 3 minutes
        # and then kills the "curl" process if it still exists.
        # Otherwise, this child process does nothing & returns.
        # NORMALLY the "Curl" command returns almost instantly
        # once the upload is complete.
        #----------------------------------------------------------#
        (
           sleep 180
           if [ "$curlPID" -gt 0 ]
           then
               kill -EXIT $curlPID 2>/dev/null || return
               kill -TERM $curlPID 2>/dev/null
           fi
        ) &
        wait $curlPID ; curlPID=0
        #----------------------------------------------------------#
        # Let's wait for 3 minutes here. If the router does not 
        # reboot by itself after the process returns, do it now.
        # Restart the LEDs with a "slower" blinking rate.
        #----------------------------------------------------------#
        _Reset_LEDs_ ; Toggle_LEDs 3 & Toggle_LEDs_PID=$!
        sleep 180 ; _Reset_LEDs_ 1
        /sbin/service reboot
    else
        Say "${REDct}**ERROR**${NOct}: Login failed. Please try the following:
1. Confirm you are not already logged into the router using a web browser.
2. Update credentials by selecting \"Configure Router Login Credentials\" from the Main Menu."

        _SendEMailNotification_ FAILED_FW_UPDATE_STATUS
        _DoCleanUp_ 1 "$keepZIPfile"
        _EntwareServicesHandler_ start
    fi

    "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
}

##-------------------------------------##
## Added by Martinski W. [2024-Jan-24] ##
##-------------------------------------##
_PostUpdateEmailNotification_()
{
   _DelPostUpdateEmailNotifyScriptHook_

   local theWaitDelaySecs=10
   local maxWaitDelaySecs=360  #6 minutes#
   local curWaitDelaySecs=0
   #---------------------------------------------------------
   # Wait until all services are started, including NTP
   # so the system clock is updated with correct time.
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

   _SendEMailNotification_ POST_REBOOT_FW_UPDATE_STATUS
}

##-------------------------------------##
## Added by Martinski W. [2023-Nov-20] ##
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
      if [ -d "$FW_ZIP_BASE_DIR" ] && \
         [ "$(nvram get ntp_ready)" -eq 1 ] && \
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

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-26] ##
##------------------------------------------##
_DoUninstall_()
{
   printf "Are you sure you want to uninstall $ScriptFileName script now"
   ! _WaitForYESorNO_ && return 0

   _DelCronJobEntry_
   _DelCronJobRunScriptHook_
   _DelPostRebootRunScriptHook_
   _DelPostUpdateEmailNotifyScriptHook_

   if rm -fr "$SETTINGS_DIR" && \
      rm -fr "${FW_BIN_BASE_DIR}/$ScriptDirNameD" && \
      rm -fr "${FW_LOG_BASE_DIR}/$ScriptDirNameD" && \
      rm -fr "${FW_ZIP_BASE_DIR}/$ScriptDirNameD" && \
      rm -f "$ScriptFilePath"
   then
       Say "${GRNct}Successfully Uninstalled.${NOct}"
   else
       Say "${REDct}Error: Uninstallation failed.${NOct}"
   fi
   _DoExit_ 0
}

keepZIPfile=0
trap "_DoCleanUp_ 0 "$keepZIPfile" ; _DoExit_ 0" HUP INT QUIT ABRT TERM

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-26] ##
##----------------------------------------##
# Prevent running this script multiple times simultaneously #
if ! _AcquireLock_
then Say "Exiting..." ; exit 1 ; fi

# Check if the router model is supported OR if
# it has the minimum firmware version supported.
check_model_support
check_version_support

##-------------------------------------##
## Added by Martinski W. [2024-Jan-24] ##
##-------------------------------------##
_CheckEMailConfigFileFromAMTM_ 0

##----------------------------------------##
## Modified by Martinski W. [2024-Jan-24] ##
##----------------------------------------##
if [ $# -gt 0 ]
then
   inMenuMode=false
   case $1 in
       run_now) _RunFirmwareUpdateNow_
           ;;
       addCronJob) _AddCronJobEntry_
           ;;
       postRebootRun) _PostRebootRunNow_
           ;;
       postUpdateEmail) _PostUpdateEmailNotification_
           ;;
       uninstall) _DoUninstall_
           ;;
       *) printf "${REDct}INVALID Parameter.${NOct}\n"
           ;;
   esac
   _DoExit_ 0
fi

# Download the latest version file from the source repository #
# to check if there's a new version update to notify the user #
_CheckForNewScriptUpdates_

##----------------------------------------##
## Modified by Martinski W. [2024-Jan-21] ##
##----------------------------------------##
FW_UpdateCheckState="$(nvram get firmware_check_enable)"
[ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
if [ "$FW_UpdateCheckState" -eq 1 ]
then
    runfwUpdateCheck=true
    # Check if the CRON job already exists #
    if ! $cronCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
    then
        logo
        # If CRON job does not exist, ask user for permission to add #
        printf "Do you want to enable automatic firmware update checks?\n"
        printf "This will create a CRON job to check for updates regularly.\n"
        printf "The CRON can be disabled at anytime through the menu.\n"
        if _WaitForYESorNO_
        then
            # Add the cron job since it doesn't exist and user consented
            printf "Adding '${GRNct}${CRON_JOB_TAG}${NOct}' cron job...\n"
            if _AddCronJobEntry_
            then
                printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was added successfully.\n"
                current_schedule_english="$(translate_schedule "$FW_UpdateCronJobSchedule")"
                printf "Job Schedule: ${GRNct}${current_schedule_english}${NOct}\n"
            else
                printf "${REDct}**ERROR**${NOct}: Failed to add the cron job [${CRON_JOB_TAG}].\n"
            fi
            _AddCronJobRunScriptHook_
        else
            printf "Automatic firmware update checks will be DISABLED.\n"
            printf "You can enable this feature later through the menu.\n"
            FW_UpdateCheckState=0
            nvram set firmware_check_enable="$FW_UpdateCheckState"
            nvram commit
            runfwUpdateCheck=false
        fi
    else
        printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' already exists.\n"
        _AddCronJobRunScriptHook_
    fi

    # Check if there's a new F/W update available #
    "$runfwUpdateCheck" && [ -x "$FW_UpdateCheckScript" ] && sh $FW_UpdateCheckScript 2>&1 &
    _WaitForEnterKey_
fi

rog_file=""

FW_RouterProductID="${GRNct}${PRODUCT_ID}${NOct}"
if [ "$PRODUCT_ID" = "$MODEL_ID" ]
then FW_RouterModelID="${FW_RouterProductID}"
else FW_RouterModelID="${FW_RouterProductID}/${GRNct}${MODEL_ID}${NOct}"
fi

FW_InstalledVers="$(_GetCurrentFWInstalledShortVersion_)"
FW_NewUpdateVersion="$(_GetLatestFWUpdateVersionFromRouter_ 1)"
FW_InstalledVersion="${GRNct}$(_GetCurrentFWInstalledLongVersion_)${NOct}"

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-23] ##
##------------------------------------------##
show_menu()
{
   #-----------------------------------------------------------#
   # Check if router reports a new F/W update is available.
   # If yes, modify the notification settings accordingly.
   #-----------------------------------------------------------#
   FW_NewUpdateVers="$(_GetLatestFWUpdateVersionFromRouter_)" && \
   [ -n "$FW_InstalledVers" ] && [ -n "$FW_NewUpdateVers" ] && \
   _CheckNewUpdateFirmwareNotification_ "$FW_InstalledVers" "$FW_NewUpdateVers"

   clear
   SEPstr="-----------------------------------------------------"
   logo
   printf "${YLWct}========= By ExtremeFiretop & Martinski W. ==========${NOct}\n\n"

   # New Script Update Notification #
   if [ "$UpdateNotify" != "0" ]; then
      Say "${REDct}WARNING:${NOct} ${UpdateNotify}${NOct}\n"
   fi

   # Unsupported Model Checks #
   if [ "$ModelCheckFailed" != "0" ]; then
      Say "${REDct}WARNING:${NOct} The current router model is not supported by this script. 
Please uninstall.\n"
   fi
   if [ "$MinFirmwareCheckFailed" != "0" ]; then
      Say "${REDct}WARNING:${NOct} The current firmware version is below the minimum supported.
Please manually update to version $minimum_supported_version or higher to use this script.\n"
   fi

   if ! _HasRouterMoreThan256MBtotalRAM_ && ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR"; then
      Say "${REDct}WARNING:${NOct} Limited RAM detected (256MB). 
A USB drive is required for F/W updates.\n"
   fi

   padStr="      "  arrowStr=" ${REDct}<<---${NOct}"

   notifyDate="$(Get_Custom_Setting FW_New_Update_Notification_Date)"
   if [ "$notifyDate" = "TBD" ]
   then notificationStr="${REDct}NOT SET${NOct}"
   else notificationStr="${GRNct}${notifyDate%%_*}${NOct}"
   fi

   printf "${SEPstr}"
   if ! FW_NewUpdateVersion="$(_GetLatestFWUpdateVersionFromRouter_ 1)"
   then FW_NewUpdateVersion="${REDct}NONE FOUND${NOct}"
   else FW_NewUpdateVersion="${GRNct}${FW_NewUpdateVersion}${NOct}$arrowStr"
   fi
   printf "\n${padStr}F/W Product/Model ID:  $FW_RouterModelID"
   printf "\n${padStr}F/W Update Available:  $FW_NewUpdateVersion"
   printf "\n${padStr}F/W Version Installed: $FW_InstalledVersion"
   printf "\n${padStr}USB Storage Connected: $USBConnected"

   printf "\n${SEPstr}"
   printf "\n  ${GRNct}1${NOct}.  Run F/W Update Check Now\n"
   printf "\n  ${GRNct}2${NOct}.  Configure Router Login Credentials\n"

   # Enable/Disable the ASUS Router's built-in "F/W Update Check" #
   FW_UpdateCheckState="$(nvram get firmware_check_enable)"
   [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
   if [ "$FW_UpdateCheckState" -eq 0 ]
   then
       printf "\n  ${GRNct}3${NOct}.  Enable F/W Update Check"
       printf "\n${padStr}[Currently ${REDct}DISABLED${NOct}]"
   else
       printf "\n  ${GRNct}3${NOct}.  Disable F/W Update Check"
       printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}]"
   fi
   printf "\n${padStr}[Last Notification Date: $notificationStr]\n"

   printf "\n  ${GRNct}4${NOct}.  Set F/W Update Postponement Days"
   printf "\n${padStr}[Current Days: ${GRNct}${FW_UpdatePostponementDays}${NOct}]\n"

   # F/W Update EMail Notifications #
   if _CheckEMailConfigFileFromAMTM_ 0
   then
      if "$sendEMailNotificationsFlag"
      then
          printf "\n ${GRNct}em${NOct}.  Disable F/W Update EMail Notifications"
          printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}]\n"
      else
          printf "\n ${GRNct}em${NOct}.  Enable F/W Update EMail Notifications"
          printf "\n${padStr}[Currently ${REDct}DISABLED${NOct}]\n"
      fi
   fi

   # In the show_menu function, add an option for Advanced Options
   printf "\n ${GRNct}ad${NOct}.  Advanced Options\n"

   # Check for new script updates #
   if [ "$UpdateNotify" != "0" ]; then
      printf "\n ${GRNct}up${NOct}.  Update $SCRIPT_NAME Script Now"
      printf "\n${padStr}[Version: ${GRNct}${DLRepoVersion}${NOct} Available for Download]\n"
   fi

   printf "\n ${GRNct}un${NOct}.  Uninstall\n"
   printf "\n  ${GRNct}e${NOct}.  Exit\n"
   printf "${SEPstr}\n"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Jan-27] ##
##---------------------------------------##
_advanced_options_menu_() {
    theADExitStr="${GRNct}e${NOct}=Exit to advanced menu"
    while true; do
        clear
        logo
        printf "=============== Advanced Options Menu ===============\n"
        printf "${SEPstr}\n"
        printf "\n  ${GRNct}1${NOct}.  Set F/W Update Check Schedule"
        printf "\n${padStr}[Current Schedule: ${GRNct}${FW_UpdateCronJobSchedule}${NOct}]\n"

        printf "\n  ${GRNct}2${NOct}.  Set Directory for F/W Update ZIP File"
        printf "\n${padStr}[Current Path: ${GRNct}${FW_ZIP_DIR}${NOct}]\n"

        printf "\n  ${GRNct}3${NOct}.  Set Directory for F/W Update Log Files"
        printf "\n${padStr}[Current Path: ${GRNct}${FW_LOG_DIR}${NOct}]\n"

        local checkChangeLogSetting="$(Get_Custom_Setting "CheckChangeLog")"
        if [ "$checkChangeLogSetting" = "DISABLED" ]
        then
            printf "\n  ${GRNct}4${NOct}.  Enable Change-log Check"
            printf "\n${padStr}[Currently ${REDct}DISABLED${NOct}]\n"
        else
            printf "\n  ${GRNct}4${NOct}.  Disable Change-log Check"
            printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}]\n"
        fi

        local BetaProductionSetting="$(Get_Custom_Setting "FW_Allow_Beta_Production_Up")"
        if [ "$BetaProductionSetting" = "DISABLED" ]
        then
            printf "\n  ${GRNct}5${NOct}.  Enable Beta-to-Release Upgrades"
            printf "\n${padStr}[Currently ${REDct}DISABLED${NOct}]\n"
        else
            printf "\n  ${GRNct}5${NOct}.  Disable Beta-to-Release Upgrades"
            printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}]\n"
        fi

        # Retrieve the current build type setting
        local current_build_type=$(Get_Custom_Setting "ROGBuild")

        # Convert the setting to a descriptive text
        if [ "$current_build_type" = "y" ]; then
            current_build_type_menu="ROG Build"
        elif [ "$current_build_type" = "n" ]; then
            current_build_type_menu="Pure Build"
        else
            current_build_type_menu="NOT SET"
        fi

        if echo "$PRODUCT_ID" | grep -q "^GT-"; then
            printf "\n  ${GRNct}6${NOct}.  Change ROG F/W Build Type"
            if [ "$current_build_type_menu" = "NOT SET" ]
            then printf "\n${padStr}[Current Build Type: ${REDct}${current_build_type_menu}${NOct}]\n"
            else printf "\n${padStr}[Current Build Type: ${GRNct}${current_build_type_menu}${NOct}]\n"
            fi
        fi

        printf "\n  ${GRNct}e${NOct}.  Return to Main Menu\n"
        printf "${SEPstr}"

        printf "\nEnter selection:  "
        read -r advancedChoice
        echo
        case $advancedChoice in
            1) _Set_FW_UpdateCronSchedule_
               ;;
            2) _Set_FW_UpdateZIP_DirectoryPath_
               ;;
            3) _Set_FW_UpdateLOG_DirectoryPath_
               ;;
            4) _toggle_change_log_check_ && _WaitForEnterKey_
               ;;
            5) _toggle_beta_updates_ && _WaitForEnterKey_
               ;;
            6) if echo "$PRODUCT_ID" | grep -q "^GT-"; then
                   change_build_type && _WaitForEnterKey_
               fi
               ;;
            e|exit) break
               ;;
            *) printf "${REDct}INVALID selection.${NOct} Please try again."
               _WaitForEnterKey_
               ;;
        esac
    done
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-23] ##
##------------------------------------------##
# Main Menu loop
inMenuMode=true
theExitStr="${GRNct}e${NOct}=Exit to main menu"

while true
do
   local_choice_set="$(Get_Custom_Setting "ROGBuild")"
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
       1) _RunFirmwareUpdateNow_
          ;;
       2) _GetLoginCredentials_
          ;;
       3) _Toggle_FW_UpdateCheckSetting_
          ;;
       4) _Set_FW_UpdatePostponementDays_
          ;;
      em) "$isEMailConfigEnabledInAMTM" && \
          _Toggle_FW_UpdateEmailNotifications_
          ;;
      ad) _advanced_options_menu_
          ;;
      up) _SCRIPTUPDATE_
          ;;
      un) _DoUninstall_ && _WaitForEnterKey_
          ;;
  e|exit) _DoExit_ 0
          ;;
       *) printf "${REDct}INVALID selection.${NOct} Please try again."
          _WaitForEnterKey_
          ;;
   esac
done

#EOF#
