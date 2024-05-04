#!/bin/sh
###################################################################
# MerlinAU.sh (MerlinAutoUpdate)
#
# Original Creation Date: 2023-Oct-01 by @ExtremeFiretop.
# Official Co-Author: @Martinski W. - Date: 2023-Nov-01
# Last Modified: 2024-May-03
###################################################################
set -u

readonly SCRIPT_VERSION=1.1.3
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

##---------------------------------------##
## Added by ExtremeFiretop [2024-May-03] ##
##---------------------------------------##
# Changelog URL Info #
readonly CL_URL_NG="https://sourceforge.net/projects/asuswrt-merlin/files/Documentation/Changelog-NG.txt/download"
readonly CL_URL_386="https://sourceforge.net/projects/asuswrt-merlin/files/Documentation/Changelog-386.txt/download"

# For new script version updates from source repository #
UpdateNotify=0
DLRepoVersion=""

# For supported version and model checks #
MinFirmwareCheckFailed=0
ModelCheckFailed=0

readonly ScriptFileName="${0##*/}"
readonly ScriptFNameTag="${ScriptFileName%%.*}"
readonly ScriptDirNameD="${ScriptFNameTag}.d"

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-21] ##
##------------------------------------------##
readonly ADDONS_PATH="/jffs/addons"
readonly SCRIPTS_PATH="/jffs/scripts"
readonly SETTINGS_DIR="${ADDONS_PATH}/$ScriptDirNameD"
readonly SETTINGSFILE="${SETTINGS_DIR}/custom_settings.txt"
readonly SCRIPTVERPATH="${SETTINGS_DIR}/version.txt"

##----------------------------------------##
## Modified by Martinski W. [2024-May-01] ##
##----------------------------------------##
ScriptsDirPath="$SCRIPTS_PATH"
ScriptFilePath="${SCRIPTS_PATH}/$ScriptFileName"

if [ ! -f "$ScriptFilePath" ]
then
    ScriptsDirPath="$(pwd)"
    ScriptFilePath="$(pwd)/$ScriptFileName"
fi

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Apr-02] ##
##------------------------------------------##
#-------------------------------------------------------#
# We'll use the built-in AMTM email configuration file
# to send email notifications *IF* enabled by the user.
#-------------------------------------------------------#
readonly FW_UpdateEMailFormatTypeDefault=HTML
readonly FW_UpdateEMailNotificationDefault=false
readonly amtmMailDirPath="/jffs/addons/amtm/mail"
readonly amtmMailConfFile="${amtmMailDirPath}/email.conf"
readonly amtmMailPswdFile="${amtmMailDirPath}/emailpw.enc"
readonly tempEMailContent="/tmp/var/tmp/tempEMailContent.$$.TXT"
readonly tempNodeEMailList="/tmp/var/tmp/tempNodeEMailList.$$.TXT"
readonly tempEMailBodyMsg="/tmp/var/tmp/tempEMailBodyMsg.$$.TXT"
readonly saveEMailInfoMsg="${SETTINGS_DIR}/savedEMailInfoMsg.SAVE.TXT"
readonly theEMailDateTimeFormat="%Y-%b-%d %a %I:%M:%S %p %Z"

if [ -z "$(which crontab)" ]
then cronListCmd="cru l"
else cronListCmd="crontab -l"
fi

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-06] ##
##----------------------------------------##
inMenuMode=true
isInteractive=false

mainLAN_IPaddr="$(nvram get lan_ipaddr)"

if [ "$(nvram get sw_mode)" -eq 1 ]
then inRouterSWmode=true
else inRouterSWmode=false
fi

mainMenuReturnPromptStr="Press <Enter> to return to the Main Menu..."
advnMenuReturnPromptStr="Press <Enter> to return to the Advanced Menu..."

[ -t 0 ] && ! tty | grep -qwi "NOT" && isInteractive=true

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-23] ##
##----------------------------------------##
userLOGFile=""
userTraceFile="${SETTINGS_DIR}/${ScriptFNameTag}_Trace.LOG"
userDebugFile="${SETTINGS_DIR}/${ScriptFNameTag}_Debug.LOG"
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
       echo "$2" >> "$userLOGFile"
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
   else promptStr="Press <Enter> to continue..."
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
   local mountPointRegExp="^/dev/sd.* /tmp/mnt/.*"

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
      /sbin/service restart_leds > /dev/null 2>&1
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
       /sbin/service restart_leds >/dev/null 2>&1
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
## Modified by Martinski W. [2024-Apr-06] ##
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
    then urlDomain="$mainLAN_IPaddr"
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

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-28] ##
##----------------------------------------##
_FWVersionStrToNum_()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
    then echo ; return 1 ; fi

    USE_BETA_WEIGHT="$(Get_Custom_Setting FW_Allow_Beta_Production_Up)"

    local verNum  verStr="$1"  nonProductionVersionWeight=0
    local fwBranchVers=""  numFields

    #--------------------------------------------------------------
    # Handle any 'alpha/beta' in the version string to be sure
    # that we always get good numerical values for comparison.
    #--------------------------------------------------------------
    if echo "$verStr" | grep -qiE '(alpha|beta)'
    then
        # Adjust weight value if "Beta-to-Production" update is enabled #
        [ "$USE_BETA_WEIGHT" = "ENABLED" ] && nonProductionVersionWeight=-100

        # Replace '.alpha|.beta' and anything following it with ".0" #
        verStr="$(echo "$verStr" | sed 's/[.][Aa]lpha.*/.0/ ; s/[.][Bb]eta.*/.0/')"
        # Remove 'alpha|beta' and anything following it #
        verStr="$(echo "$verStr" | sed 's/[_-]\?[Aa]lpha.*// ; s/[_-]\?[Bb]eta.*//')"
    fi

    numFields="$(echo "$verStr" | awk -F '.' '{print NF}')"

    if [ "$numFields" -lt "$2" ]
    then fwBranchVers="$(nvram get firmver | sed 's/\.//g')" ; fi

    #-----------------------------------------------------------
    # Temporarily remove Branch version to avoid issues with
    # integers greater than the maximum 32-bit signed integer
    # when doing arithmetic computations with shell cmds.
    #-----------------------------------------------------------
    if [ "$numFields" -gt 3 ]
    then
        fwBranchVers="$(echo "$verStr" | cut -d'.' -f1)"
        verStr="$(echo "$verStr" | cut -d'.' -f2-)"
    fi
    verNum="$(echo "$verStr" | awk -F '.' '{printf ("%d%02d%02d\n", $1,$2,$3);}')"

    # Subtract non-production weight from the version number #
    verNum="$((verNum + nonProductionVersionWeight))"

    # Now prepend the F/W Branch version #
    [ -n "$fwBranchVers" ] && verNum="${fwBranchVers}$verNum"

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

##------------------------------------------##
## Modified by ExtremeFiretop [2024-May-03] ##
##------------------------------------------##
if "$inRouterSWmode" 
then
    readonly FW_Update_CRON_DefaultSchedule="0 0 * * *"
else
    readonly FW_Update_CRON_DefaultSchedule="15 0 * * *"
fi

readonly CRON_MINS_RegEx="([*0-9]|[1-5][0-9])([\/,-]([0-9]|[1-5][0-9]))*"
readonly CRON_HOUR_RegEx="([*0-9]|1[0-9]|2[0-3])([\/,-]([0-9]|1[0-9]|2[0-3]))*"
readonly CRON_DAYofMONTH_RegEx="([*1-9]|[1-2][0-9]|3[0-1])([\/,-]([1-9]|[1-2][0-9]|3[0-1]))*"

readonly CRON_DAYofWEEK_NAMES="(Sun|Mon|Tue|Wed|Thu|Fri|Sat)"
readonly CRON_DAYofWEEK_RegEx="$CRON_DAYofWEEK_NAMES([\/,-]$CRON_DAYofWEEK_NAMES)*|[*0-6]([\/,-][0-6])*"

readonly CRON_MONTH_NAMES="(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"
readonly CRON_MONTH_RegEx="$CRON_MONTH_NAMES([\/,-]$CRON_MONTH_NAMES)*|([*1-9]|1[0-2])([\/,-]([1-9]|1[0-2]))*"

##------------------------------------------##
## Modified by Martinski W. [2024-Jan-22]   ##
##------------------------------------------##
# To postpone a firmware update for a few days #
readonly FW_UpdateMinimumPostponementDays=0
readonly FW_UpdateDefaultPostponementDays=15
readonly FW_UpdateMaximumPostponementDays=60
readonly FW_UpdateNotificationDateFormat="%Y-%m-%d_%H:%M:00"

readonly MODEL_ID="$(_GetRouterModelID_)"
readonly PRODUCT_ID="$(_GetRouterProductID_)"
readonly FW_FileName="${PRODUCT_ID}_firmware"
readonly FW_URL_RELEASE="${FW_URL_BASE}/${PRODUCT_ID}/${FW_URL_RELEASE_SUFFIX}/"

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Feb-01] ##
##------------------------------------------##
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

##-----------------------------------------------##
## Modified by: ExtremeFiretop [2023-Dec-16]     ##
##-----------------------------------------------##
_CheckForNewScriptUpdates_()
{
   local DLRepoVersionNum  ScriptVersionNum

   echo ""
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
## Modified by Martinski W. [2024-Mar-14] ##
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

   local mounPointPaths  expectedPath  mountPointList
   local symblPath  realPath1  realPath2  foundPathOK
   local mountPointRegExp="^/dev/sd.* /tmp/mnt/.*"

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

   mountPointList=""
   foundPathOK=false

   for thePATH in $mounPointPaths
   do
      if echo "${expectedPath}/" | grep -qE "^${thePATH}/"
      then foundPathOK=true ; break ; fi
      mountPointList="$mountPointList $thePATH"
   done
   "$foundPathOK" && return 0

   ## Report found Mount Points on failure ##
   if [ $# -gt 1 ] && [ "$2" -eq 1 ] && [ -n "$mountPointList" ]
   then Say "Mount points found:\n$mountPointList" ; fi
   return 1
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
## Modified by ExtremeFiretop [2024-Mar-20] ##
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
         echo "FW_New_Update_EMail_FormatType=\"${FW_UpdateEMailFormatTypeDefault}\""
         echo "FW_New_Update_Cron_Job_Schedule=\"${FW_Update_CRON_DefaultSchedule}\""
         echo "FW_New_Update_ZIP_Directory_Path=\"${FW_Update_ZIP_DefaultSetupDIR}\""
         echo "FW_New_Update_LOG_Directory_Path=\"${FW_Update_LOG_BASE_DefaultDIR}\""
         echo "FW_New_Update_LOG_Preferred_Path=\"${FW_Update_LOG_BASE_DefaultDIR}\""
         echo "FW_New_Update_EMail_CC_Name=TBD"
         echo "FW_New_Update_EMail_CC_Address=TBD"
         echo "CheckChangeLog ENABLED"
         echo "FW_Allow_Beta_Production_Up ENABLED"
         echo "FW_Auto_Backupmon ENABLED"
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
   if ! grep -q "^FW_New_Update_EMail_FormatType=" "$SETTINGSFILE"
   then
       sed -i "5 i FW_New_Update_EMail_FormatType=\"${FW_UpdateEMailFormatTypeDefault}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_Cron_Job_Schedule=" "$SETTINGSFILE"
   then
       sed -i "6 i FW_New_Update_Cron_Job_Schedule=\"${FW_Update_CRON_DefaultSchedule}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_ZIP_Directory_Path=" "$SETTINGSFILE"
   then
       sed -i "7 i FW_New_Update_ZIP_Directory_Path=\"${FW_Update_ZIP_DefaultSetupDIR}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_LOG_Directory_Path=" "$SETTINGSFILE"
   then
       sed -i "8 i FW_New_Update_LOG_Directory_Path=\"${FW_Update_LOG_BASE_DefaultDIR}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_LOG_Preferred_Path=" "$SETTINGSFILE"
   then
       preferredPath="$(Get_Custom_Setting FW_New_Update_LOG_Directory_Path)"
       sed -i "9 i FW_New_Update_LOG_Preferred_Path=\"${preferredPath}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^CheckChangeLog" "$SETTINGSFILE"
   then
       sed -i "10 i CheckChangeLog ENABLED" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_Allow_Beta_Production_Up" "$SETTINGSFILE"
   then
       sed -i "11 i FW_Allow_Beta_Production_Up ENABLED" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_Auto_Backupmon" "$SETTINGSFILE"
   then
       sed -i "12 i FW_Auto_Backupmon ENABLED" "$SETTINGSFILE"
       retCode=1
   fi
   return "$retCode"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Mar-20] ##
##------------------------------------------##
Get_Custom_Setting()
{
    if [ $# -eq 0 ] || [ -z "$1" ]; then echo "**ERROR**"; return 1; fi
    [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

    local setting_value=""  setting_type="$1"  default_value="TBD"
    [ $# -gt 1 ] && default_value="$2"

    if [ -f "$SETTINGSFILE" ]; then
        case "$setting_type" in
            "ROGBuild" | "credentials_base64" | "CheckChangeLog" | \
            "FW_Allow_Beta_Production_Up" | \
            "FW_Auto_Backupmon" | \
            "FW_New_Update_Notification_Date" | \
            "FW_New_Update_Notification_Vers")
                setting_value="$(grep "^${setting_type} " "$SETTINGSFILE" | awk -F ' ' '{print $2}')"
                ;;
            "FW_New_Update_Postponement_Days"  | \
            "FW_New_Update_Cron_Job_Schedule"  | \
            "FW_New_Update_ZIP_Directory_Path" | \
            "FW_New_Update_LOG_Directory_Path" | \
            "FW_New_Update_LOG_Preferred_Path" | \
            "FW_New_Update_EMail_Notification" | \
            "FW_New_Update_EMail_FormatType" | \
            "FW_New_Update_EMail_CC_Name" | \
            "FW_New_Update_EMail_CC_Address")
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

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-30] ##
##----------------------------------------##
_GetAllNodeSettings_()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
    then echo "**ERROR**" ; return 1; fi

    ## Node Setting KEY="Node_{MACaddress}_{keySuffix}" ##
    local fullKeyName="Node_${1}_${2}"
    local setting_value="TBD"  matched_lines

    # Ensure the settings directory exists #
    [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

    if [ -f "$SETTINGSFILE" ]
    then
        matched_lines="$(grep -E "^${fullKeyName}=.*" "$SETTINGSFILE")"
        if [ -n "$matched_lines" ]
        then
            # Extract the value from the first matched line #
            setting_value="$(echo "$matched_lines" | head -n 1 | awk -F '=' '{print $2}' | tr -d '"')"
        fi
    fi
    echo "$setting_value"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-06] ##
##----------------------------------------##
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
        "FW_Auto_Backupmon" | \
        "FW_New_Update_Notification_Date" | \
        "FW_New_Update_Notification_Vers")
            if [ -f "$SETTINGSFILE" ]
            then
                if [ "$(grep -c "$setting_type" "$SETTINGSFILE")" -gt 0 ]
                then
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
        "FW_New_Update_EMail_Notification" | \
        "FW_New_Update_EMail_FormatType" | \
        "FW_New_Update_EMail_CC_Name" | \
        "FW_New_Update_EMail_CC_Address")
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
            elif [ "$setting_type" = "FW_New_Update_EMail_FormatType" ]
            then
                sendEMailFormaType="$setting_value"
                [ "$sendEMailFormaType" = "HTML" ] && \
                isEMailFormatHTML=true || isEMailFormatHTML=false
            #
            elif [ "$setting_type" = "FW_New_Update_EMail_CC_Name" ]
            then
                sendEMail_CC_Name="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_EMail_CC_Address" ]
            then
                sendEMail_CC_Address="$setting_value"
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
            # Generic handling for arbitrary settings #
            if grep -q "^${setting_type}=" "$SETTINGSFILE"
            then
                oldVal="$(grep "^${setting_type}=" "$SETTINGSFILE" | awk -F '=' '{print $2}' | sed "s/['\"]//g")"
                if [ -z "$oldVal" ] || [ "$oldVal" != "$setting_value" ]
                then
                    fixedVal="$(echo "$setting_value" | sed 's/[\/&]/\\&/g')"
                    sed -i "s/^${setting_type}=.*/${setting_type}=\"${fixedVal}\"/" "$SETTINGSFILE"
                fi
            else
                echo "${setting_type}=\"${setting_value}\"" >> "$SETTINGSFILE"
            fi
            ;;
    esac
}

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
       _WaitForEnterKey_ "$advnMenuReturnPromptStr"
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
       _WaitForEnterKey_ "$advnMenuReturnPromptStr"
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

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-18] ##
##----------------------------------------##
# F/W Update Email Notifications #
isEMailFormatHTML=true
isEMailConfigEnabledInAMTM=false
sendEMailFormaType="$(Get_Custom_Setting FW_New_Update_EMail_FormatType)"
sendEMailNotificationsFlag="$(Get_Custom_Setting FW_New_Update_EMail_Notification)"
sendEMail_CC_Name="$(Get_Custom_Setting FW_New_Update_EMail_CC_Name)"
sendEMail_CC_Address="$(Get_Custom_Setting FW_New_Update_EMail_CC_Address)"
[ "$sendEMailFormaType" = "HTML" ] && \
isEMailFormatHTML=true || isEMailFormatHTML=false

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
    /usr/bin/find -L "$FW_LOG_DIR" -name '*.log' -mtime +30 -exec rm {} \;
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
## Modified by ExtremeFiretop [2024-May-03] ##
##------------------------------------------##
_CreateEMailContent_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   local fwInstalledVersion  fwNewUpdateVersion
   local savedInstalledVersion  savedNewUpdateVersion
   local subjectStr  emailBodyTitle=""

   rm -f "$tempEMailContent" "$tempEMailBodyMsg"

   subjectStr="F/W Update Status for $MODEL_ID"
   fwInstalledVersion="$(_GetCurrentFWInstalledLongVersion_)"
   fwNewUpdateVersion="$(_GetLatestFWUpdateVersionFromRouter_ 1)"

   # Remove "_rog" suffix to avoid version comparison failures #
   fwInstalledVersion="$(echo "$fwInstalledVersion" | sed 's/_rog$//')"

   case "$1" in
       FW_UPDATE_TEST_EMAIL)
           emailBodyTitle="Testing Email Notification"
           {
             echo "This is a TEST of the F/W Update email notification from the <b>${MODEL_ID}</b> router."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       NEW_FW_UPDATE_STATUS)
           emailBodyTitle="New Firmware Update for ASUS Router"
           {
             echo "A new F/W Update version <b>${fwNewUpdateVersion}</b> is available for the <b>${MODEL_ID}</b> router."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n"
             printf "\nNumber of days to postpone flashing the new F/W Update version: <b>${FW_UpdatePostponementDays}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       AGGREGATED_UPDATE_NOTIFICATION)
           if "$inRouterSWmode" && [ -n "$node_list" ]; then
              nodefwNewUpdateVersion="$(_GetLatestFWUpdateVersionFromNode_ 1)"
           fi
           if [ ! -n "$nodefwNewUpdateVersion" ]
           then
               Say "${REDct}**ERROR**${NOct}: Unable to send node email notification [No saved info]."
               return 1
           fi
           emailBodyTitle="New Firmware Update(s) for AiMesh Node(s)"
           NODE_UPDATE_CONTENT="$(cat "$tempNodeEMailList")"
           {
             echo "The following AiMesh Node(s) have a new F/W Update version available:"
             echo "$NODE_UPDATE_CONTENT"
           } > "$tempEMailBodyMsg"
           ;;
       START_FW_UPDATE_STATUS)
           emailBodyTitle="New Firmware Flash Started"
           {
             echo "Started flashing the new F/W Update version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       STOP_FW_UPDATE_APPROVAL)
           emailBodyTitle="WARNING"
           {
             echo "Found high-risk phrases in the change-logs while Auto-Updating to version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             echo "Changelog contents include the following changes:"
             echo "$changelog_contents"
             printf "\nPlease run script interactively to approve this F/W Update from current version:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       NEW_BM_BACKUP_FAILED)
           emailBodyTitle="WARNING"
           {
             echo "Backup failed during the F/W Update process to version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             echo "Flashing the F/W Update on the <b>${MODEL_ID}</b> router is now cancelled."
             printf "\nPlease check <b>backupmon.sh</b> configuration and retry F/W Update from current version:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       FAILED_FW_UNZIP_STATUS)
           emailBodyTitle="**ERROR**"
           {
             echo "Unable to decompress the F/W Update ZIP file for version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             echo "Flashing the F/W Update on the <b>${MODEL_ID}</b> router is now cancelled due to decompress error."
             printf "\nPlease retry F/W Update from current version:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       FAILED_FW_CHECKSUM_STATUS)
           emailBodyTitle="**ERROR**"
           {
             echo "Checksum verification failed during the F/W Update process to version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             echo "Flashing the F/W Update on the <b>${MODEL_ID}</b> router is now cancelled due to checksum mismatch."
             printf "\nPlease retry F/W Update from current version:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       FAILED_FW_UPDATE_STATUS)
           emailBodyTitle="**ERROR**"
           {
             echo "Flashing of new F/W Update version <b>${fwNewUpdateVersion}</b> for the <b>${MODEL_ID}</b> router failed."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n"
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
           savedInstalledVersion="$(grep "^FW_InstalledVersion=" "$saveEMailInfoMsg" | awk -F '=' '{print $2}')"
           savedNewUpdateVersion="$(grep "^FW_NewUpdateVersion=" "$saveEMailInfoMsg" | awk -F '=' '{print $2}')"
           if [ -z "$savedInstalledVersion" ] || [ -z "$savedNewUpdateVersion" ]
           then
               Say "${REDct}**ERROR**${NOct}: Unable to send post-update email notification [Saved info is empty]."
               return 1
           fi
           if [ "$savedNewUpdateVersion" = "$fwInstalledVersion" ] && \
              [ "$savedInstalledVersion" != "$fwInstalledVersion" ]
           then
              emailBodyTitle="Successful Firmware Update"
              {
                echo "Flashing of new F/W Update version <b>${fwInstalledVersion}</b> for the <b>${MODEL_ID}</b> router was successful."
                printf "\nThe F/W version that was previously installed:\n<b>${savedInstalledVersion}</b>\n"
              } > "$tempEMailBodyMsg"
           else
              emailBodyTitle="**ERROR**"
              {
                echo "Flashing of new F/W Update version <b>${savedNewUpdateVersion}</b> for the <b>${MODEL_ID}</b> router failed."
                printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n"
              } > "$tempEMailBodyMsg"
           fi
           rm -f "$saveEMailInfoMsg"
           ;;
       *) return 1
           ;;
   esac

   ! "$isEMailFormatHTML" && sed -i 's/[<]b[>]//g ; s/[<]\/b[>]//g' "$tempEMailBodyMsg"

   if [ -n "$CC_NAME" ] && [ -n "$CC_ADDRESS" ]
   then
       CC_ADDRESS_ARG="--mail-rcpt $CC_ADDRESS"
       CC_ADDRESS_STR="\"${CC_NAME}\" <$CC_ADDRESS>"
   fi

   ## Header-1 ##
   cat <<EOF > "$tempEMailContent"
From: "$FROM_NAME" <$FROM_ADDRESS>
To: "$TO_NAME" <$TO_ADDRESS>
EOF

   [ -n "$CC_ADDRESS_STR" ] && \
   printf "Cc: %s\n" "$CC_ADDRESS_STR" >> "$tempEMailContent"

   ## Header-2 ##
   cat <<EOF >> "$tempEMailContent"
Subject: $subjectStr
Date: $(date -R)
EOF

   if "$isEMailFormatHTML"
   then
       cat <<EOF >> "$tempEMailContent"
MIME-Version: 1.0
Content-Type: text/html; charset="UTF-8"
Content-Disposition: inline

<!DOCTYPE html><html>
<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></head>
<body><h2>${emailBodyTitle}</h2>
<div style="color:black; font-family: sans-serif; font-size:130%;"><pre>
EOF
    else
        cat <<EOF >> "$tempEMailContent"
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: quoted-printable
Content-Disposition: inline

EOF
       [ -n "$emailBodyTitle" ] && \
       printf "%s\n\n" "$emailBodyTitle" >> "$tempEMailContent"
   fi

   ## Body ##
   cat "$tempEMailBodyMsg" >> "$tempEMailContent"

   ## Footer ##
   if "$isEMailFormatHTML"
   then
       cat <<EOF >> "$tempEMailContent"

Sent by the "<b>${ScriptFNameTag}</b>" utility.
From the "<b>${FRIENDLY_ROUTER_NAME}</b>" router.

$(date +"$theEMailDateTimeFormat")
</pre></div></body></html>
EOF
   else
       cat <<EOF >> "$tempEMailContent"

Sent by the "${ScriptFNameTag}" utility.
From the "${FRIENDLY_ROUTER_NAME}" router.

$(date +"$theEMailDateTimeFormat")
EOF
   fi

   rm -f "$tempEMailBodyMsg"
   rm -f "$tempNodeEMailList"
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-16] ##
##----------------------------------------##
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
   USERNAME=""  SMTP=""  PORT=""  PROTOCOL=""
   PASSWORD=""  emailPwEnc=""

   # Custom Options ##
   CC_NAME=""  CC_ADDRESS=""

   . "$amtmMailConfFile"

   if [ -z "$TO_NAME" ] || [ -z "$USERNAME" ] || \
      [ -z "$FROM_ADDRESS" ] || [ -z "$TO_ADDRESS" ] || \
      [ -z "$SMTP" ] || [ -z "$PORT" ] || [ -z "$PROTOCOL" ] || \
      [ -z "$emailPwEnc" ] || [ "$PASSWORD" = "PUT YOUR PASSWORD HERE" ]
   then
       "$doLogMsgs" && \
       Say "${REDct}**ERROR**${NOct}: Unable to send email notification [Empty variables]."
       return 1
   fi

   if [ -n "$sendEMail_CC_Name" ] && [ "$sendEMail_CC_Name" != "TBD" ] && \
      [ -n "$sendEMail_CC_Address" ] && [ "$sendEMail_CC_Address" != "TBD" ]
   then
       [ -z "$CC_NAME" ] && CC_NAME="$sendEMail_CC_Name"
       [ -z "$CC_ADDRESS" ] && CC_ADDRESS="$sendEMail_CC_Address"
   fi

   isEMailConfigEnabledInAMTM=true
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-16] ##
##----------------------------------------##
_SendEMailNotification_()
{
   if [ $# -eq 0 ] || [ -z "$1" ]  || \
   ! "$sendEMailNotificationsFlag" || \
   ! _CheckEMailConfigFileFromAMTM_ 1
   then return 1 ; fi

   local CC_ADDRESS_STR=""  CC_ADDRESS_ARG=""

   [ -z "$FROM_NAME" ] && FROM_NAME="$ScriptFNameTag"
   [ -z "$FRIENDLY_ROUTER_NAME" ] && FRIENDLY_ROUTER_NAME="$MODEL_ID"

   ! _CreateEMailContent_ "$1" && return 1

   [ "$1" = "POST_REBOOT_FW_UPDATE_SETUP" ] && return 0

   if "$isInteractive"
   then
       printf "\nSending email notification [$1]."
       printf "\nPlease wait...\n"
   fi

   date +"$LOGdateFormat" > "$userTraceFile"

   /usr/sbin/curl -v --url "${PROTOCOL}://${SMTP}:${PORT}" \
   --mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" $CC_ADDRESS_ARG \
   --user "${USERNAME}:$(/usr/sbin/openssl aes-256-cbc "$emailPwEnc" -d -in "$amtmMailPswdFile" -pass pass:ditbabot,isoi)" \
   --upload-file "$tempEMailContent" \
   $SSL_FLAG --ssl-reqd --crlf >> "$userTraceFile" 2>&1
   curlCode="$?"

   if [ "$curlCode" -eq 0 ]
   then
       sleep 2
       rm -f "$userTraceFile"
       Say "The email notification was sent successfully [$1]."
   else
       Say "${REDct}**ERROR**${NOct}: Failure to send email notification [Code: $curlCode][$1]."
   fi
   rm -f "$tempEMailContent"

   return "$curlCode"
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
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
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

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-28] ##
##----------------------------------------##
_GetCurrentFWInstalledLongVersion_()
{
   local theBranchVers  theVersionStr  extVersNum

   theBranchVers="$(nvram get firmver | sed 's/\.//g')"

   extVersNum="$(nvram get extendno)"
   echo "$extVersNum" | grep -qiE "^(alpha|beta)" && extVersNum="0_$extVersNum"
   [ -z "$extVersNum" ] && extVersNum=0

   theVersionStr="$(nvram get buildno).$extVersNum"
   [ -n "$theBranchVers" ] && theVersionStr="${theBranchVers}.${theVersionStr}"

   echo "$theVersionStr"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-28] ##
##----------------------------------------##
_GetCurrentFWInstalledShortVersion_()
{
##FOR TESTING/DEBUG ONLY##
if false ; then echo "388.6.2" ; return 0 ; fi
##FOR TESTING/DEBUG ONLY##

    local theVersionStr  extVersNum

    extVersNum="$(nvram get extendno | awk -F '-' '{print $1}')"
    echo "$extVersNum" | grep -qiE "^(alpha|beta)" && extVersNum="0_$extVersNum"
    [ -z "$extVersNum" ] && extVersNum=0

    theVersionStr="$(nvram get buildno).$extVersNum"
    echo "$theVersionStr"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Mar-31] ##
##----------------------------------------##
_HasRouterMoreThan256MBtotalRAM_()
{
   local totalRAM_KB
   totalRAM_KB="$(awk -F ' ' '/^MemTotal:/{print $2}' /proc/meminfo)"
   [ -n "$totalRAM_KB" ] && [ "$totalRAM_KB" -gt 262144 ] && return 0
   return 1
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-01] ##
##----------------------------------------##
#---------------------------------------------------------------------#
# The actual amount of RAM that is available for any new process
# (*without* using the swap file) can be roughly estimated from
# "Free Memory" & "Page Cache" (e.g. Inactive memory pages).
# This estimate must take into account that the overall system
# (kernel + native services + tmpfs) needs a minimum amount of RAM
# to continue to work, and that not all reclaimable Page Cache can
# be reclaimed because some may actually be in used at the time.
# NOTE: [Martinski]
# Since reported "Available RAM" estimates tend to be extremely
# conservative in many cases, we decided to take another approach
# and calculate it based on the reported "Free RAM" plus ~66% of
# reported "Memory Cached" and then take the largest of the two
# values: Reported "Available RAM" vs Calculated "Available RAM"
# While still somewhat conservative, this would provide a better
# estimate, especially at the time when the router is about to
# shut down and terminate all non-critical services/processes
# before the actual F/W flash is performed.
#---------------------------------------------------------------------#
_GetAvailableRAM_KB_()
{
   local theMemAvailable_KB  theMemAvail_KB  theMemCache_KB
   local theMemFree1_KB  theMemFree2_KB  inactivePgs_KB

   _MaxNumber_() { echo "$(($1 < $2 ? $2 : $1))" ; }

   theMemCache_KB="$(awk -F ' ' '/^Cached:/{print $2}' /proc/meminfo)"
   theMemFree1_KB="$(awk -F ' ' '/^MemFree:/{print $2}' /proc/meminfo)"
   theMemAvail_KB="$(awk -F ' ' '/^MemAvailable:/{print $2}' /proc/meminfo)"
   # Assumes that only ~66% of Page Cache can be reclaimed #
   theMemFree2_KB="$((theMemFree1_KB + ((theMemCache_KB * 2) / 3)))"

   if [ -z "$theMemAvail_KB" ]
   then
       inactivePgs_KB="$(awk -F ' ' '/^Inactive:/{print $2}' /proc/meminfo)"
       theMemAvail_KB="$((theMemFree1_KB + inactivePgs_KB))"
   fi
   theMemAvailable_KB="$(_MaxNumber_ "$theMemAvail_KB" "$theMemFree2_KB")"
   echo "$theMemAvailable_KB" ; return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Mar-31] ##
##----------------------------------------##
_GetFreeRAM_KB_()
{
   awk -F ' ' '/^MemFree:/{print $2}' /proc/meminfo
   ##FOR DEBUG ONLY## echo 1000
}

##----------------------------------------##
## Modified by Martinski W. [2024-Mar-31] ##
##----------------------------------------##
_GetRequiredRAM_KB_()
{
    local url="$1"
    local zip_file_size_bytes  zip_file_size_kb  overhead_kb
    local total_required_kb  overhead_percentage=50

    # Size of the ZIP file in bytes
    zip_file_size_bytes="$(curl -sIL "$url" | grep -i Content-Length | tail -1 | awk '{print $2}')"
    # Convert bytes to kilobytes
    zip_file_size_kb="$((zip_file_size_bytes / 1024))"

    # Calculate overhead based on the percentage
    overhead_kb="$((zip_file_size_kb * overhead_percentage / 100))"

    # Calculate total required space
    total_required_kb="$((zip_file_size_kb + overhead_kb))"
    echo "$total_required_kb"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Mar-24] ##
##----------------------------------------##
_ShutDownNonCriticalServices_()
{
    for procName in nt_center nt_monitor nt_actMail
    do
         procNum="$(ps w | grep -w "$procName" | grep -cv "grep -w")"
         if [ "$procNum" -gt 0 ]
         then
             printf "$procName: [$procNum]\n"
             killall -9 "$procName" && sleep 1
         fi
    done

    for service_name in conn_diag samba nasapps
    do
        procNum="$(ps w | grep -w "$service_name" | grep -cv "grep -w")"
        if [ "$procNum" -gt 0 ]
        then
            printf "$service_name: [$procNum]\n"
            service "stop_$service_name" && sleep 1
        fi
    done
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
       Say "START _DoCleanUp_"
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

##-------------------------------------##
## Added by Martinski W. [2023-Mar-26] ##
##-------------------------------------##
_LogMemoryDebugInfo_()
{
   {
     printf "Uptime\n------\n" ; uptime ; echo
     df -hT | grep -E '(^Filesystem|/jffs$|/tmp$|/var$)' | sort -d -t ' ' -k 1
     echo
     printf "/proc/meminfo\n-------------\n"
     grep -E '^Mem[TFA].*:[[:blank:]]+.*' /proc/meminfo
     grep -E '^(Buffers|Cached):[[:blank:]]+.*' /proc/meminfo
     grep -E '^Swap[TFC].*:[[:blank:]]+.*' /proc/meminfo
     grep -E '^(Active|Inactive)(\([af].*\))?:[[:blank:]]+.*' /proc/meminfo
     grep -E '^(Dirty|Writeback|AnonPages|Unevictable):[[:blank:]]+.*' /proc/meminfo
     echo "------------------------------"
   } > "$userDebugFile"
   "$isInteractive" && cat "$userDebugFile"
   _LogMsgNoTime_ "$(cat "$userDebugFile")"
   rm -f "$userDebugFile"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Mar-26] ##
##----------------------------------------##
check_memory_and_prompt_reboot()
{
    local requiredRAM_kb="$1"
    local availableRAM_kb="$2"

    if [ "$availableRAM_kb" -lt "$requiredRAM_kb" ]
    then
        Say "Insufficient RAM available."

        # Attempt to clear PageCache #
        Say "Attempting to free up memory..."
        sync; echo 1 > /proc/sys/vm/drop_caches
        sleep 2

        # Check available memory again #
        availableRAM_kb="$(_GetAvailableRAM_KB_)"
        if [ "$availableRAM_kb" -lt "$requiredRAM_kb" ]
        then
            freeRAM_kb="$(_GetFreeRAM_KB_)"
            Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
            _LogMemoryDebugInfo_

            # Attempt to clear dentries and inodes. #
            Say "Attempting to free up memory again more aggressively..."
            sync; echo 2 > /proc/sys/vm/drop_caches
            sleep 2

            # Check available memory again #
            availableRAM_kb="$(_GetAvailableRAM_KB_)"
            if [ "$availableRAM_kb" -lt "$requiredRAM_kb" ]
            then
                freeRAM_kb="$(_GetFreeRAM_KB_)"
                Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
                _LogMemoryDebugInfo_

                # Attempt to clear clears pagecache, dentries, and inodes after shutting down services
                Say "Attempting to free up memory once more even more aggressively..."

                # Stop Entware services before F/W flash #
                _EntwareServicesHandler_ stop

                _ShutDownNonCriticalServices_

                sync; echo 3 > /proc/sys/vm/drop_caches
                sleep 2

                # Check available memory again #
                availableRAM_kb="$(_GetAvailableRAM_KB_)"
                if [ "$availableRAM_kb" -lt "$requiredRAM_kb" ]
                then
                    _LogMemoryDebugInfo_

                    # In an interactive shell session, ask user to confirm reboot #
                    if "$isInteractive" && _WaitForYESorNO_ "Reboot router now"
                    then
                        freeRAM_kb="$(_GetFreeRAM_KB_)"
                        Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
                        _AddPostRebootRunScriptHook_
                        Say "Rebooting router..."
                        _ReleaseLock_
                        /sbin/service reboot
                        exit 1  # Although the reboot command should end the script, it's good practice to exit after.
                    else
                        # Exit script if non-interactive or if user answers NO #
                        freeRAM_kb="$(_GetFreeRAM_KB_)"
                        Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
                        Say "Insufficient memory to continue. Exiting script."
                        # Restart Entware services #
                        _EntwareServicesHandler_ start

                        _DoCleanUp_ 1 "$keepZIPfile"
                        _DoExit_ 1
                    fi
                else
                    Say "Successfully freed up memory. Available: ${availableRAM_kb}KB."
                fi
            else
                Say "Successfully freed up memory. Available: ${availableRAM_kb}KB."
            fi
        else
            Say "Successfully freed up memory. Available: ${availableRAM_kb}KB."
        fi
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

##---------------------------------------##
## Added by ExtremeFiretop [2024-Feb-29] ##
##---------------------------------------##
_TestLoginCredentials_()
{
    local credsBase64="$1"
    local curl_response routerURLstr

    # Define routerURLstr
    routerURLstr="$(_GetRouterURL_)"

    "$isInteractive" && printf "\nRestarting web server... Please wait.\n"
    /sbin/service restart_httpd >/dev/null 2>&1 &
    sleep 5

    curl_response="$(curl -k "${routerURLstr}/login.cgi" \
    --referer "${routerURLstr}/Main_Login.asp" \
    --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Origin: ${routerURLstr}/" \
    -H 'Connection: keep-alive' \
    --data-raw "group_id=&action_mode=&action_script=&action_wait=5&current_page=Main_Login.asp&next_page=index.asp&login_authorization=${credsBase64}" \
    --cookie-jar /tmp/cookie.txt)"

    # Interpret the curl_response to determine login success or failure
    # This is a basic check
    if echo "$curl_response" | grep -Eq 'url=index\.asp|url=GameDashboard\.asp'; then
        printf "\n${GRNct}Login test passed.${NOct}"
        "$isInteractive" && printf "\nRestarting web server... Please wait.\n"
        /sbin/service restart_httpd >/dev/null 2>&1 &
        sleep 1
        return 0
    else
        printf "\n${REDct}Login test failed.${NOct}\n"
        if _WaitForYESorNO_ "Would you like to try again?"; then
            return 1 # Indicates failure but with intent to retry
        else
            return 0 # User opted not to retry; treated as a graceful exit
        fi
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-15] ##
##----------------------------------------##
_GetPasswordInput_()
{
   local PSWDstrLenMIN=1  PSWDstrLenMAX=64
   local PSWDstring  PSWDtmpStr  PSWDprompt
   local retCode  charNum  pswdLength  showPSWD
   # Added for TAB keypress debounce #
   local lastTabTime=0  currentTime

   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       printf "${REDct}**ERROR**${NOct}: NO prompt string was provided.\n"
       return 1
   fi
   PSWDprompt="$1"

   _GetKeypress_()
   {
      local savedSettings
      savedSettings="$(stty -g)"
      stty -echo raw
      echo "$(dd count=1 2>/dev/null)"
      stty "$savedSettings"
   }

   _ShowAsterisks_()
   {
      if [ $# -eq 0 ] || [ "$1" -eq 0 ]
      then echo ""
      else printf "%*s" "$1" ' ' | tr ' ' '*'
      fi
   }

   _ShowPSWDPrompt_()
   {
      local pswdTemp  LENct  LENwd
      [ "$showPSWD" = "1" ] && pswdTemp="$PSWDstring" || pswdTemp="$PSWDtmpStr"
      if [ "$pswdLength" -lt "$PSWDstrLenMIN" ] || [ "$pswdLength" -gt "$PSWDstrLenMAX" ]
      then LENct="$REDct" ; LENwd=""
      else LENct="$GRNct" ; LENwd="02"
      fi
      printf "\r\033[0K$PSWDprompt [Length=${LENct}%${LENwd}d${NOct}]: %s" "$pswdLength" "$pswdTemp"
   }

   showPSWD=0
   charNum=""
   PSWDstring="$pswdString"
   pswdLength="${#PSWDstring}"
   PSWDtmpStr="$(_ShowAsterisks_ "$pswdLength")"
   echo ; _ShowPSWDPrompt_

   local savedIFS="$IFS"
   while IFS='' theChar="$(_GetKeypress_)"
   do
      charNum="$(printf "%d" "'$theChar")"

      if [ "$theChar" = "" ] || [ "$charNum" -eq 13 ]
      then
          if [ "$pswdLength" -ge "$PSWDstrLenMIN" ] && [ "$pswdLength" -le "$PSWDstrLenMAX" ]
          then
              echo
              retCode=0
          elif [ "$pswdLength" -lt "$PSWDstrLenMIN" ]
          then
              PSWDstring=""
              printf "\n${REDct}**ERROR**${NOct}: Password length is less than allowed minimum length "
              printf "[MIN=${GRNct}${PSWDstrLenMIN}${NOct}].\n"
              retCode=1
          elif [ "$pswdLength" -gt "$PSWDstrLenMAX" ]
          then
              PSWDstring=""
              printf "\n${REDct}**ERROR**${NOct}: Password length is greater than allowed maximum length "
              printf "[MAX=${GRNct}${PSWDstrLenMAX}${NOct}].\n"
              retCode=1
          fi
          break
      fi

      ## Ignore Escape Sequences ##
      [ "$charNum" -eq 27 ] && continue

      ## TAB keypress as toggle with debounce ##
      if [ "$charNum" -eq 9 ]
      then
          currentTime="$(date +%s)"
          if [ "$((currentTime - lastTabTime))" -gt 0 ]
          then
              showPSWD="$((! showPSWD))"
              lastTabTime="$currentTime"  # Update TAB keypress time #
              _ShowPSWDPrompt_
          fi
          continue
      fi

      ## BACKSPACE keypress ##
      if [ "$charNum" -eq 8 ] || [ "$charNum" -eq 127 ]
      then
          if [ "$pswdLength" -gt 0 ]
          then
              PSWDstring="${PSWDstring%?}"
              pswdLength="${#PSWDstring}"
              PSWDtmpStr="$(_ShowAsterisks_ "$pswdLength")"
              _ShowPSWDPrompt_
              continue
          fi
      fi

      ## ONLY 7-bit ASCII printable characters are VALID ##
      if [ "$charNum" -gt 31 ] && [ "$charNum" -lt 127 ]
      then
          if [ "$pswdLength" -le "$PSWDstrLenMAX" ]
          then
              PSWDstring="${PSWDstring}${theChar}"
              pswdLength="${#PSWDstring}"
              PSWDtmpStr="$(_ShowAsterisks_ "$pswdLength")"
              _ShowPSWDPrompt_
              continue
          fi
      fi
   done
   IFS="$savedIFS"

   pswdString="$PSWDstring"
   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-29] ##
##----------------------------------------##
_GetLoginCredentials_()
{
    local retry="yes"  userName  pswdString
    local loginCredsENC  loginCredsDEC

    # Get the Username from NVRAM #
    userName="$(nvram get http_username)"

    loginCredsENC="$(Get_Custom_Setting credentials_base64)"
    if [ -z "$loginCredsENC" ] || [ "$loginCredsENC" = "TBD" ]
    then
        pswdString=""
    else
        loginCredsDEC="$(echo "$loginCredsENC" | openssl base64 -d)"
        pswdString="$(echo "$loginCredsDEC" | sed "s/${userName}://")"
    fi

    while [ "$retry" = "yes" ]
    do
        echo "=== Login Credentials ==="
        _GetPasswordInput_ "Enter password for user ${GRNct}${userName}${NOct}"
        if [ -z "$pswdString" ]
        then
            printf "\nPassword string is ${REDct}NOT${NOct} valid. Credentials were not saved.\n"
            _WaitForEnterKey_
            continue
        fi

        # Encode the Username and Password in Base64 #
        loginCredsENC="$(echo -n "${userName}:${pswdString}" | openssl base64 -A)"

        # Save the credentials to the SETTINGSFILE #
        Update_Custom_Settings credentials_base64 "$loginCredsENC"

        printf "\n${GRNct}Credentials saved.${NOct}\n"
        printf "Encoded Credentials:\n"
        printf "${GRNct}$loginCredsENC${NOct}\n"

        # Prompt to test the credentials
        if _WaitForYESorNO_ "\nWould you like to test the current login credentials?"; then
            _TestLoginCredentials_ "$loginCredsENC" || continue
        fi

        retry="no"  # Stop the loop if the test passes or if the user chooses not to test
    done

    _WaitForEnterKey_ "$mainMenuReturnPromptStr"
    return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-06] ##
##----------------------------------------##
_GetNodeIPv4List_()
{
    # Get the value of asus_device_list #
    local ip_addresses
    local device_list="$(nvram get asus_device_list)"

    # Check if asus_device_list is not empty #
    if [ -n "$device_list" ]
    then
        # Split the device list into records and extract the IP addresses, excluding Main Router LAN IP address #
        ip_addresses="$(echo "$device_list" | tr '<' '\n' | awk -v exclude="$mainLAN_IPaddr" -F'>' '{if (NF>=4 && $3 != exclude) print $3}')"

        # Check if IP addresses are not empty #
        if [ -n "$ip_addresses" ]; then
            # Print each IP address on a separate line
            printf "%s\n" "$ip_addresses"
        else
            return 1
        fi
    else
        Say "NVRAM asus_device_list is NOT populated. No Mesh Nodes were found."
        return 1
    fi
    return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-06] ##
##----------------------------------------##
_NodeActiveStatus_()
{
    # Get the value of cfg_device_list #
    local ip_addresses
    local node_online_status="$(nvram get cfg_device_list)"

    # Check if cfg_device_list is not empty #
    if [ -n "$node_online_status" ]
    then
        # Split the device list into records and extract the IP addresses, excluding Main Router LAN IP address #
        ip_addresses="$(echo "$node_online_status" | tr '<' '\n' | awk -v exclude="$mainLAN_IPaddr" -F'>' '{if (NF>=3 && $2 != exclude) print $2}')"

        # Check if IP addresses are not empty #
        if [ -n "$ip_addresses" ]; then
            # Print each IP address on a separate line
            printf "%s\n" "$ip_addresses"
        else
            return 1
        fi
    else
        Say "NVRAM cfg_device_list is NOT populated. No Mesh Nodes were found."
        return 1
    fi
    return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-30] ##
##----------------------------------------##
_Populate_Node_Settings_()
{
    local MAC_address="$1"
    local model_id="$2"
    local update_date="$3"
    local update_vers="$4"
    local nodeKeyPrefix="Node_${MAC_address}_"

    # Update or add each piece of information
    Update_Custom_Settings "${nodeKeyPrefix}Model_NameID" "$model_id"
    Update_Custom_Settings "${nodeKeyPrefix}New_Notification_Date" "$update_date"
    Update_Custom_Settings "${nodeKeyPrefix}New_Notification_Vers" "$update_vers"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Mar-26] ##
##---------------------------------------##
_GetNodeURL_()
{
    local NodeIP_Address="$1"
    local urlProto urlDomain urlPort

    if [ "$(nvram get http_enable)" = "1" ]; then
        urlProto="https"
    else
        urlProto="http"
    fi

    urlPort="$(nvram get "${urlProto}_lanport")"
    if [ "$urlPort" -eq 80 ] || [ "$urlPort" -eq 443 ]; then
        urlPort=""
    else
        urlPort=":$urlPort"
    fi

    echo "${urlProto}://${NodeIP_Address}${urlPort}"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Mar-26] ##
##---------------------------------------##
_GetNodeInfo_()
{
    local NodeIP_Address="$1"
    local NodeURLstr="$(_GetNodeURL_ "$NodeIP_Address")"

    ## Default values for specific variables
    node_productid="Unreachable"
    Node_combinedVer="Unreachable"
    node_asus_device_list=""
    node_cfg_device_list=""
    node_firmver="Unreachable"
    node_buildno="Unreachable"
    node_extendno="Unreachable"
    node_webs_state_flag=""
    node_webs_state_info=""
    node_odmpid="Unreachable"
    node_wps_modelnum="Unreachable"
    node_model="Unreachable"
    node_build_name="Unreachable"
    node_lan_hostname="Unreachable"
    node_label_mac="Unreachable"

    ## Check for Login Credentials ##
    credsBase64="$(Get_Custom_Setting credentials_base64)"
    if [ -z "$credsBase64" ] || [ "$credsBase64" = "TBD" ]
    then
        Say "${REDct}**ERROR**${NOct}: No login credentials have been saved. Use the Main Menu to save login credentials."
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        return 1
    fi

    # Perform login request
    curl -s -k "${NodeURLstr}/login.cgi" \
    --referer "${NodeURLstr}/Main_Login.asp" \
    --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Origin: ${NodeURLstr}" \
    -H 'Connection: keep-alive' \
    --data-raw "group_id=&action_mode=&action_script=&action_wait=5&current_page=Main_Login.asp&next_page=index.asp&login_authorization=$credsBase64" \
    --cookie-jar '/tmp/nodecookies.txt' \
    --max-time 2 > /tmp/login_response.txt 2>&1

    if [ $? -ne 0 ]; then
        return 1
    fi

    # Run the curl command to retrieve the HTML content
    htmlContent="$(curl -s -k "${NodeURLstr}/appGet.cgi?hook=nvram_get(productid)%3bnvram_get(asus_device_list)%3bnvram_get(cfg_device_list)%3bnvram_get(firmver)%3bnvram_get(buildno)%3bnvram_get(extendno)%3bnvram_get(webs_state_flag)%3bnvram_get(odmpid)%3bnvram_get(wps_modelnum)%3bnvram_get(model)%3bnvram_get(build_name)%3bnvram_get(lan_hostname)%3bnvram_get(webs_state_info)%3bnvram_get(label_mac)" \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Accept-Encoding: gzip, deflate' \
    -H 'Connection: keep-alive' \
    -H "Referer: ${NodeURLstr}/index.asp" \
    -H 'Upgrade-Insecure-Requests: 0' \
    --cookie '/tmp/nodecookies.txt' \
    --max-time 2 2>&1)"

    if [ $? -ne 0 ]; then
        return 1
    fi

    # Extract values using regular expressions #
    node_productid="$(echo "$htmlContent" | grep -o '"productid":"[^"]*' | sed 's/"productid":"//')"
    node_asus_device_list="$(echo "$htmlContent" | grep -o '"asus_device_list":"[^"]*' | sed 's/"asus_device_list":"//')"
    node_cfg_device_list="$(echo "$htmlContent" | grep -o '"cfg_device_list":"[^"]*' | sed 's/"cfg_device_list":"//')"
    node_firmver="$(echo "$htmlContent" | grep -o '"firmver":"[^"]*' | sed 's/"firmver":"//' | tr -d '.')"
    node_buildno="$(echo "$htmlContent" | grep -o '"buildno":"[^"]*' | sed 's/"buildno":"//')"
    node_extendno="$(echo "$htmlContent" | grep -o '"extendno":"[^"]*' | sed 's/"extendno":"//')"
    node_webs_state_flag="$(echo "$htmlContent" | grep -o '"webs_state_flag":"[^"]*' | sed 's/"webs_state_flag":"//')"
    node_webs_state_info="$(echo "$htmlContent" | grep -o '"webs_state_info":"[^"]*' | sed 's/"webs_state_info":"//')"
    node_odmpid="$(echo "$htmlContent" | grep -o '"odmpid":"[^"]*' | sed 's/"odmpid":"//')"
    node_wps_modelnum="$(echo "$htmlContent" | grep -o '"wps_modelnum":"[^"]*' | sed 's/"wps_modelnum":"//')"
    node_model="$(echo "$htmlContent" | grep -o '"model":"[^"]*' | sed 's/"model":"//')"
    node_build_name="$(echo "$htmlContent" | grep -o '"build_name":"[^"]*' | sed 's/"build_name":"//')"
    node_lan_hostname="$(echo "$htmlContent" | grep -o '"lan_hostname":"[^"]*' | sed 's/"lan_hostname":"//')"
    node_label_mac="$(echo "$htmlContent" | grep -o '"label_mac":"[^"]*' | sed 's/"label_mac":"//')"

    # Combine extracted information into one string
    Node_combinedVer="$node_firmver.$node_buildno.$node_extendno"

    # Perform logout request
    curl -s -k "${NodeURLstr}/Logout.asp" \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Accept-Encoding: gzip, deflate' \
    -H 'Connection: keep-alive' \
    -H "Referer: ${NodeURLstr}/Main_Login.asp" \
    -H 'Upgrade-Insecure-Requests: 0' \
    --cookie '/tmp/nodecookies.txt' \
    --max-time 2 > /tmp/logout_response.txt 2>&1

    if [ $? -ne 0 ]; then
        return 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-06] ##
##----------------------------------------##
_GetLatestFWUpdateVersionFromNode_()
{
   local retCode=0  webState  newVersionStr

   if [ -z "${node_webs_state_flag:+xSETx}" ]
   then webState=""
   else webState="$node_webs_state_flag"
   fi
   if [ -z "$webState" ] || [ "$webState" -eq 0 ]
   then retCode=1 ; fi

   if [ -z "${node_webs_state_info:+xSETx}" ]
   then
       newVersionStr=""
   else
       newVersionStr="$(echo "$node_webs_state_info" | sed 's/_/./g')"
       if [ $# -eq 0 ] || [ -z "$1" ]
       then
           newVersionStr="$(echo "$newVersionStr" | awk -F '-' '{print $1}')"
       fi
   fi

   [ -z "$newVersionStr" ] && retCode=1
   echo "$newVersionStr" ; return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Mar-25] ##
##----------------------------------------##
_GetLatestFWUpdateVersionFromWebsite_()
{
    local url="$1"

    local links_and_versions="$(curl -s "$url" | grep -o 'href="[^"]*'"$PRODUCT_ID"'[^"]*\.zip' | sed 's/amp;//g; s/href="//' | \
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

    if [ -z "$versionStr" ] || [ -z "$correct_link" ]
    then echo "**ERROR** **NO_URL**" ; return 1 ; fi

    echo "$versionStr"
    echo "$correct_link"
    return 0
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
    _WaitForEnterKey_
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Jan-27] ##
##---------------------------------------##
_toggle_beta_updates_() {
    local currentSetting="$(Get_Custom_Setting "FW_Allow_Beta_Production_Up")"

    if [ "$currentSetting" = "ENABLED" ]; then
        printf "${REDct}*WARNING*:${NOct}\n"
        printf "Disabling updates from beta to release firmware may limit access to new features and fixes.\n"
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
    _WaitForEnterKey_
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Mar-20] ##
##---------------------------------------##
_Toggle_Auto_Backups_() {
    local currentSetting="$(Get_Custom_Setting "FW_Auto_Backupmon")"

    if [ "$currentSetting" = "ENABLED" ]; then
        printf "${REDct}*WARNING*:${NOct} Disabling auto backups may risk data loss or inconsistency.\n"
        printf "The advice is to proceed only if you're sure you want to disable auto backups.\n"
        printf "\nProceed to disable? [y/N]: "
        read -r response
        case $response in
            [Yy]* )
                Update_Custom_Settings "FW_Auto_Backupmon" "DISABLED"
                printf "Auto backups are now ${REDct}DISABLED.${NOct}\n"
                ;;
            *)
                printf "Auto backups remain ${GRNct}ENABLED.${NOct}\n"
                ;;
        esac
    else
        printf "Are you sure you want to enable auto backups? [y/N]: "
        read -r response
        case $response in
            [Yy]* )
                Update_Custom_Settings "FW_Auto_Backupmon" "ENABLED"
                printf "Auto backups are now ${GRNct}ENABLED.${NOct}\n"
                ;;
            *)
                printf "Auto backups remain ${REDct}DISABLED.${NOct}\n"
                ;;
        esac
    fi
    _WaitForEnterKey_
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Feb-18] ##
##------------------------------------------##
change_build_type()
{
   local doReturnToMenu  buildtypechoice
   printf "Changing Flash Build Type...\n"

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

   printf "\nCurrent Build Type: ${GRNct}$display_choice${NOct}.\n"

   doReturnToMenu=false
   while true
   do
       printf "\n${SEPstr}"
       printf "\nChoose your preferred option for the build type to flash:\n"
       printf "\n  ${GRNct}1${NOct}. Original ${REDct}ROG${NOct} themed user interface${NOct}\n"
       printf "\n  ${GRNct}2${NOct}. Pure ${GRNct}non-ROG${NOct} themed user interface ${GRNct}(Recommended)${NOct}\n"
       printf "\n  ${GRNct}e${NOct}. Exit to Advanced Menu\n"
       printf "${SEPstr}\n"
       printf "[$display_choice] Enter selection:  "
       read -r choice

       [ -z "$choice" ] && break

       if echo "$choice" | grep -qE "^(e|exit|Exit)$"
       then doReturnToMenu=true ; break ; fi

       case $choice in
           1) buildtypechoice="y" ; break
              ;;
           2) buildtypechoice="n" ; break
              ;;
           *) echo ; _InvalidMenuSelection_
              ;;
       esac
   done

   "$doReturnToMenu" && return 0

   Update_Custom_Settings "ROGBuild" "$buildtypechoice"
   printf "\nThe build type to flash was updated successfully.\n"

   _WaitForEnterKey_ "$advnMenuReturnPromptStr"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-22] ##
##----------------------------------------##
translate_schedule()
{
   minute="$(echo "$1" | cut -d' ' -f1)"
   hour="$(echo "$1" | cut -d' ' -f2)"
   day_of_month="$(echo "$1" | cut -d' ' -f3)"
   month="$(echo "$1" | cut -d' ' -f4)"
   day_of_week="$(echo "$1" | cut -d' ' -f5)"

   # Function to add ordinal suffix to day
   get_ordinal()
   {
      case $1 in
          1? | *[04-9]) echo "$1"th ;;
          *1) echo "$1"st ;;
          *2) echo "$1"nd ;;
          *3) echo "$1"rd ;;
      esac
   }

   # Helper function to translate each field
   translate_field()
   {
      local field="$1"
      local type="$2"
      case "$field" in
          '*') echo "every $type" ;;
          */*) echo "every $(echo "$field" | cut -d'/' -f2) $type(s)" ;;
          *-*) echo "from $(echo "$field" | cut -d'-' -f1) to $(echo "$field" | cut -d'-' -f2) $type(s)" ;;
          *,*) echo "$(echo "$field" | sed 's/,/, /g') $type(s)" ;;
            *) if [ "$type" = "day of the month" ]; then
                   echo "$(get_ordinal "$field") $type"
               else
                   echo "$type $field"
               fi ;;
      esac
   }

   minute_text="$(translate_field "$minute" "Minute")"
   hour_text="$(translate_field "$hour" "Hour")"
   day_of_month_text="$(translate_field "$day_of_month" "day of the month")"
   month_text="$(translate_field "$month" "month")"
   # Check specifically for "day_of_week" being "*" #
   if [ "$day_of_week" = "*" ]; then
       day_of_week_text="Any day of the week"
   else
       day_of_week_text="$(translate_field "$day_of_week" "week day")"
   fi

   # Special handling for "month" to map short abbreviations to long full names #
   month_text="$(echo "$month_text" | tr 'A-Z' 'a-z')"
   month_map1="jan:January feb:February mar:March apr:April may:May jun:June jul:July aug:August sep:September oct:October nov:November dec:December"
   for month_pair in $month_map1
   do
       month_stName="$(echo "$month_pair" | cut -d':' -f1)"
       month_lnName="$(echo "$month_pair" | cut -d':' -f2)"
       month_text="$(echo "$month_text" | sed "s/\b${month_stName}\b/$month_lnName/g")"
   done

   # Special handling for "month" to map month numbers to long full names #
   month_map2="1:January 2:February 3:March 4:April 5:May 6:June 7:July 8:August 9:September 10:October 11:November 12:December"
   for month_pair in $month_map2
   do
       month_number="$(echo "$month_pair" | cut -d':' -f1)"
       month_lnName="$(echo "$month_pair" | cut -d':' -f2)"
       month_text="$(echo "$month_text" | sed "s/\b${month_number}\b/$month_lnName/g")"
   done

   if [ "$day_of_week_text" != "Any day of the week" ]
   then
       # Special handling for "day of the week" to map short abbreviations to long full names #
       day_of_week_text="$(echo "$day_of_week_text" | tr 'A-Z' 'a-z')"
       dow_map1="sun:Sunday mon:Monday tue:Tuesday wed:Wednesday thu:Thursday fri:Friday sat:Saturday"
       for dow_pair in $dow_map1
       do
           dow_stName="$(echo "$dow_pair" | cut -d':' -f1)"
           dow_lnName="$(echo "$dow_pair" | cut -d':' -f2)"
           day_of_week_text="$(echo "$day_of_week_text" | sed "s/\b${dow_stName}\b/$dow_lnName/g")"
       done

       # Special handling for "day of the week" to map day numbers to long full names #
       dow_map2="0:Sunday 1:Monday 2:Tuesday 3:Wednesday 4:Thursday 5:Friday 6:Saturday"
       for dow_pair in $dow_map2
       do
           dow_number="$(echo "$dow_pair" | cut -d':' -f1)"
           dow_lnName="$(echo "$dow_pair" | cut -d':' -f2)"
           day_of_week_text="$(echo "$day_of_week_text" | sed "s/\b${dow_number}\b/$dow_lnName/g")"
       done
   fi

   echo "At $hour_text, and $minute_text."
   echo "$day_of_week_text, $day_of_month_text, in $month_text."
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
   if eval $cronListCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
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
   if eval $cronListCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
   then
       cru d "$CRON_JOB_TAG" ; sleep 1
       if eval $cronListCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
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
       _WaitForEnterKey_ "$mainMenuReturnPromptStr"
   fi
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Feb-22] ##
##-------------------------------------##
_CapitalizeFirstChar_()
{
   if [ $# -eq 0 ] && [ -z "$1" ]
   then echo "$1" ; return 1; fi

   local upperChar  capWord  origStr="$1"
   local prevIFS="$IFS"

   IFS="/,-$IFS"
   for origWord in $1
   do
       upperChar="$(echo "${origWord:0:1}" | tr 'a-z' 'A-Z')"
       if [ -n "$upperChar" ]
       then
           capWord="${upperChar}${origWord:1}"
           origStr="$(echo "$origStr" | sed "s/\b${origWord}\b/$capWord/g")"
       fi
   done
   IFS="$prevIFS"
   echo "$origStr"
}

##-------------------------------------##
## Added by Martinski W. [2024-Feb-22] ##
##-------------------------------------##
_ValidateCronJobSchedule_()
{
   local cronSchedsStr
   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       printf "${REDct}INVALID cron schedule string: [EMPTY].${NOct}\n"
       return 1
   fi
   cronSchedsStr="$(echo "$1" | awk -F ' ' '{print NF}')"
   if [ "$cronSchedsStr" -ne 5 ]
   then
       printf "${REDct}INVALID cron schedule string [$1]. Incorrect number of parameters.${NOct}\n"
       return 1
   fi
   cronSchedsStr="$(echo "$1" | awk -F ' ' '{print $1}')"
   if ! echo "$cronSchedsStr" | grep -qE "^(${CRON_MINS_RegEx})$"
   then
       printf "${REDct}INVALID 'minute' cron value: [$cronSchedsStr].${NOct}\n"
       return 1
   fi
   cronSchedsStr="$(echo "$1" | awk -F ' ' '{print $2}')"
   if ! echo "$cronSchedsStr" | grep -qE "^(${CRON_HOUR_RegEx})$"
   then
       printf "${REDct}INVALID 'hour' cron value: [$cronSchedsStr].${NOct}\n"
       return 1
   fi
   cronSchedsStr="$(echo "$1" | awk -F ' ' '{print $3}')"
   if ! echo "$cronSchedsStr" | grep -qE "^(${CRON_DAYofMONTH_RegEx})$"
   then
       printf "${REDct}INVALID 'day of month' cron value: [$cronSchedsStr].${NOct}\n"
       return 1
   fi
   cronSchedsStr="$(echo "$1" | awk -F ' ' '{print $4}')"
   if ! echo "$cronSchedsStr" | grep -qiE "^(${CRON_MONTH_RegEx})$"
   then
       printf "${REDct}INVALID 'month' cron value: [$cronSchedsStr].${NOct}\n"
       return 1
   fi
   cronSchedsStr="$(echo "$1" | awk -F ' ' '{print $5}')"
   if ! echo "$cronSchedsStr" | grep -qiE "^(${CRON_DAYofWEEK_RegEx})$"
   then
       printf "${REDct}INVALID 'day of week' cron value: [$cronSchedsStr].${NOct}\n"
       return 1
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-22] ##
##----------------------------------------##
_Set_FW_UpdateCronSchedule_()
{
    printf "Changing Firmware Update Schedule...\n"

    local retCode=1  currCronSchedule  nextCronSchedule  userInput

    currCronSchedule="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
    if [ -z "$currCronSchedule" ] || [ "$currCronSchedule" = "TBD" ]
    then
        nextCronSchedule=""
        currCronSchedule="$FW_UpdateCronJobSchedule"
    else
        nextCronSchedule="$currCronSchedule"
        # Translate the current schedule to English (human readable form) #
        current_schedule_english="$(translate_schedule "$currCronSchedule")"
        printf "Current Schedule: ${GRNct}${current_schedule_english}${NOct}\n"
    fi

    while true
    do
        printf "\nEnter new cron job schedule (e.g. '${GRNct}0 0 * * Sun${NOct}' for every Sunday at midnight)"
        if [ -z "$currCronSchedule" ]
        then printf "\n[${theADExitStr}] [Default Schedule: ${GRNct}${nextCronSchedule}${NOct}]:  "
        else printf "\n[${theADExitStr}] [Current Schedule: ${GRNct}${currCronSchedule}${NOct}]:  "
        fi
        read -r userInput

        # If the user enters 'e', break out of the loop and return to the main menu
        if [ -z "$userInput" ] || echo "$userInput" | grep -qE "^(e|exit|Exit)$"
        then
            ! _ValidateCronJobSchedule_ "$currCronSchedule" && continue

            # Capitalize 1st char of any abbreviated short names #
            currCronSchedule="$(_CapitalizeFirstChar_ "$currCronSchedule")"
            currCronSchedule="$(echo "$currCronSchedule" | awk -F ' ' '{print $1, $2, $3, $4, $5}')"
            break
        fi

        if _ValidateCronJobSchedule_ "$userInput"
        then
            # Capitalize 1st char of any abbreviated short names #
            nextCronSchedule="$(_CapitalizeFirstChar_ "$userInput")"
            nextCronSchedule="$(echo "$nextCronSchedule" | awk -F ' ' '{print $1, $2, $3, $4, $5}')"
            break
        fi
    done

    [ "$nextCronSchedule" = "$currCronSchedule" ] && return 0

    FW_UpdateCheckState="$(nvram get firmware_check_enable)"
    [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
    if [ "$FW_UpdateCheckState" -eq 1 ]
    then
        # Add/Update cron job ONLY if "F/W Update Check" is enabled #
        printf "Updating '${GRNct}${CRON_JOB_TAG}${NOct}' cron job...\n"
        if _AddCronJobEntry_ "$nextCronSchedule"
        then
            retCode=0
            printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was updated successfully.\n"
            current_schedule_english="$(translate_schedule "$nextCronSchedule")"
            printf "Job Schedule: ${GRNct}${current_schedule_english}${NOct}\n"
        else
            retCode=1
            printf "${REDct}**ERROR**${NOct}: Failed to add/update the cron job [${CRON_JOB_TAG}].\n"
        fi
    else
        Update_Custom_Settings FW_New_Update_Cron_Job_Schedule "$nextCronSchedule"
        printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was configured but not added.\n"
        printf "Firmware Update Check is currently ${REDct}DISABLED${NOct}.\n"
    fi

    _WaitForEnterKey_ "$advnMenuReturnPromptStr"
    return "$retCode"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Apr-13] ##
##------------------------------------------##
_CheckNewUpdateFirmwareNotification_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
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
           if "$inRouterSWmode" 
           then
              _SendEMailNotification_ NEW_FW_UPDATE_STATUS
           fi
       fi
   fi

   fwNewUpdateNotificationDate="$(Get_Custom_Setting FW_New_Update_Notification_Date)"
   if [ -z "$fwNewUpdateNotificationDate" ] || [ "$fwNewUpdateNotificationDate" = "TBD" ]
   then
       fwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
       Update_Custom_Settings FW_New_Update_Notification_Date "$fwNewUpdateNotificationDate"
       if "$inRouterSWmode" 
       then
          _SendEMailNotification_ NEW_FW_UPDATE_STATUS
       fi
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-30] ##
##----------------------------------------##
_CheckNodeFWUpdateNotification_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

   local nodenumVersionFields  nodefwNewUpdateVersNum

   nodenumVersionFields="$(echo "$2" | awk -F '.' '{print NF}')"
   nodecurrentVersionNum="$(_FWVersionStrToNum_ "$1" "$nodenumVersionFields")"
   nodereleaseVersionNum="$(_FWVersionStrToNum_ "$2" "$nodenumVersionFields")"

   if [ "$nodecurrentVersionNum" -ge "$nodereleaseVersionNum" ]
   then
       _Populate_Node_Settings_ "$node_label_mac" "$node_lan_hostname" "TBD" "TBD" "$uid"
       return 1
   fi

   nodefwNewUpdateNotificationVers="$(_GetAllNodeSettings_ "$node_label_mac" "New_Notification_Vers")"
   if [ -z "$nodefwNewUpdateNotificationVers" ] || [ "$nodefwNewUpdateNotificationVers" = "TBD" ]
   then
       nodefwNewUpdateNotificationVers="$2"
       _Populate_Node_Settings_ "$node_label_mac" "$node_lan_hostname" "TBD" "$nodefwNewUpdateNotificationVers" "$uid"
   else
       nodenumVersionFields="$(echo "$nodefwNewUpdateNotificationVers" | awk -F '.' '{print NF}')"
       nodefwNewUpdateVersNum="$(_FWVersionStrToNum_ "$nodefwNewUpdateNotificationVers" "$nodenumVersionFields")"
       if [ "$nodereleaseVersionNum" -gt "$nodefwNewUpdateVersNum" ]
       then
           nodefwNewUpdateNotificationVers="$2"
           nodefwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
           _Populate_Node_Settings_ "$node_label_mac" "$node_lan_hostname" "$nodefwNewUpdateNotificationDate" "$nodefwNewUpdateNotificationVers" "$uid"
           nodefriendlyname="$(_GetAllNodeSettings_ "$node_label_mac" "Model_NameID")"
           echo "" > "$tempNodeEMailList"
           echo "AiMesh Node $nodefriendlyname with MAC Address: $node_label_mac requires update from $1 to $2 ($1 --> $2)" >> "$tempNodeEMailList"
       fi
   fi

   nodefwNewUpdateNotificationDate="$(_GetAllNodeSettings_ "$node_label_mac" "New_Notification_Date")"
   if [ -z "$nodefwNewUpdateNotificationDate" ] || [ "$nodefwNewUpdateNotificationDate" = "TBD" ]
   then
       nodefwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
       _Populate_Node_Settings_ "$node_label_mac" "$node_lan_hostname" "$nodefwNewUpdateNotificationDate" "$nodefwNewUpdateNotificationVers" "$uid"
       nodefriendlyname="$(_GetAllNodeSettings_ "$node_label_mac" "Model_NameID")"
       echo "" > "$tempNodeEMailList"
       echo "AiMesh Node $nodefriendlyname with MAC Address: $node_label_mac requires update from $1 to $2 ($1 --> $2)" >> "$tempNodeEMailList"
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Mar-21] ##
##----------------------------------------##
_CheckTimeToUpdateFirmware_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

   local notifyTimeSecs  postponeTimeSecs  currentTimeSecs  dstAdjustSecs  dstAdjustDays
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

   currentTimeSecs="$(date +%s)"
   notifyTimeStrn="$(echo "$fwNewUpdateNotificationDate" | sed 's/_/ /g')"
   notifyTimeSecs="$(date +%s -d "$notifyTimeStrn")"

   #----------------------------------------------------------------------
   # Adjust calculation of postponed days as elapsed time in seconds to
   # account for the hour discrepancy when Daylight Saving Time happens.
   # This way we can avoid a scenario where the F/W Update "date+time"
   # threshold is set one hour *after* the scheduled cron job is set
   # to run again and check if it's time to update the router.
   #----------------------------------------------------------------------
   if [ "$(date -d @$currentTimeSecs +'%Z')" = "$(date -d @$notifyTimeSecs +'%Z')" ]
   then dstAdjustSecs=86400  #24-hour day is same as always#
   else dstAdjustSecs=82800  #23-hour day only when DST happens#
   fi
   dstAdjustDays="$((fwNewUpdatePostponementDays - 1))"
   if [ "$dstAdjustDays" -eq 0 ]
   then postponeTimeSecs="$dstAdjustSecs"
   else postponeTimeSecs="$(((dstAdjustDays * 86400) + dstAdjustSecs))"
   fi

   if [ "$((currentTimeSecs - notifyTimeSecs))" -ge "$postponeTimeSecs" ]
   then return 0 ; fi

   upfwDateTimeSecs="$((notifyTimeSecs + postponeTimeSecs))"
   upfwDateTimeStrn="$(date -d @$upfwDateTimeSecs +"%A, %Y-%b-%d %I:%M %p")"

   Say "The firmware update to ${GRNct}${2}${NOct} version is currently postponed for ${GRNct}${fwNewUpdatePostponementDays}${NOct} day(s)."
   Say "The firmware update is expected to occur on or after ${GRNct}${upfwDateTimeStrn}${NOct}, depending on when your cron job is scheduled to check again."
   return 1
}

##-------------------------------------##
## Added by Martinski W. [2024-Feb-16] ##
##-------------------------------------##
_RunEMailNotificationTest_()
{
   ! "$sendEMailNotificationsFlag" && return 1
   local retCode=1

   if _WaitForYESorNO_ "\nWould you like to run a test of the email notification?"
   then
       retCode=0
       _SendEMailNotification_ FW_UPDATE_TEST_EMAIL
   fi
   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-16] ##
##----------------------------------------##
_Toggle_FW_UpdateEmailNotifications_()
{
   local emailNotificationEnabled  emailNotificationNewStateStr

   if "$sendEMailNotificationsFlag"
   then
       emailNotificationEnabled=true
       emailNotificationNewStateStr="${REDct}DISABLE${NOct}"
   else
       emailNotificationEnabled=false
       emailNotificationNewStateStr="${GRNct}ENABLE${NOct}"
   fi

   if ! _WaitForYESorNO_ "Do you want to ${emailNotificationNewStateStr} F/W Update email notifications?"
   then
       _RunEMailNotificationTest_ && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
       return 1
   fi

   if "$emailNotificationEnabled"
   then
       sendEMailNotificationsFlag=false
       emailNotificationNewStateStr="${REDct}DISABLED${NOct}"
   else
       sendEMailNotificationsFlag=true
       emailNotificationNewStateStr="${GRNct}ENABLED${NOct}"
   fi

   Update_Custom_Settings FW_New_Update_EMail_Notification "$sendEMailNotificationsFlag"
   printf "F/W Update email notifications are now ${emailNotificationNewStateStr}.\n"

   _RunEMailNotificationTest_
   _WaitForEnterKey_ "$mainMenuReturnPromptStr"
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

   if "$runfwUpdateCheck"
   then
       printf "\nChecking for new F/W Updates... Please wait.\n"
       sh $FW_UpdateCheckScript 2>&1
   fi
   _WaitForEnterKey_ "$mainMenuReturnPromptStr"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Mar-16] ##
##----------------------------------------##
_EntwareServicesHandler_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   local serviceCnt  entwOPT_init  entwOPT_unslung  actionStr=""  divAction=""

   case "$1" in
       stop) actionStr="Stopping" ; divAction="unmount" ;;
      start) actionStr="Restarting" ; divAction="mount" ;;
          *) return 1 ;;
   esac

   if [ -f /opt/bin/diversion ]
   then
       Say "${actionStr} Diversion service..."
       /opt/bin/diversion "$divAction"
       sleep 1
   fi

   entwOPT_init="/opt/etc/init.d"
   entwOPT_unslung="${entwOPT_init}/rc.unslung"

   if [ ! -x /opt/bin/opkg ] || [ ! -x "$entwOPT_unslung" ]
   then return 0 ; fi  ## Entware is NOT found ##

   serviceCnt="$(/usr/bin/find -L "$entwOPT_init" -name "S*" -exec ls -1 {} \; 2>/dev/null | /bin/grep -cE "${entwOPT_init}/S[0-9]+")"
   [ "$serviceCnt" -eq 0 ] && return 0

   Say "${actionStr} Entware services..."
   "$isInteractive" && printf "\nPlease wait.\n"
   $entwOPT_unslung "$1" ; sleep 5
   "$isInteractive" && printf "\nDone.\n"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jan-25] ##
##----------------------------------------##
# Embed functions from second script, modified as necessary.
_RunFirmwareUpdateNow_()
{
    # Double-check the directory exists before using it #
    [ ! -d "$FW_LOG_DIR" ] && mkdir -p -m 755 "$FW_LOG_DIR"

    # Set up the custom log file #
    userLOGFile="${FW_LOG_DIR}/${MODEL_ID}_FW_Update_$(date '+%Y-%m-%d_%H_%M_%S').log"
    touch "$userLOGFile"  ## Must do this to indicate custom log file is enabled ##

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
                _WaitForEnterKey_ "$mainMenuReturnPromptStr"
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
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        return 1
    fi

    Say "${GRNct}MerlinAU${NOct} v$SCRIPT_VERSION"
    Say "Running the update task now... Checking for F/W updates..."

    #---------------------------------------------------------------#
    # Check if an expected USB-attached drive is still mounted.
    # Make a special case when USB drive has Entware installed.
    #---------------------------------------------------------------#
    if echo "$FW_ZIP_BASE_DIR" | grep -qE "^(/tmp/mnt/|/tmp/opt/|/opt/)" && \
       ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR" 1
    then
        Say "Expected directory path $FW_ZIP_BASE_DIR is NOT found."
        Say "${REDct}**ERROR**${NOct}: Required USB storage device is not connected or not mounted correctly."
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        return 1
    fi

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

    _ProcessMeshNodes_ 0

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
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        return 1
    fi

    # Use set to read the output of the function into variables
    set -- $(_GetLatestFWUpdateVersionFromWebsite_ "$FW_URL_RELEASE")
    if [ $? -eq 0 ] && [ $# -eq 2 ] && \
       [ "$1" != "**ERROR**" ] && [ "$2" != "**NO_URL**" ]
    then
        release_version="$1"
        release_link="$2"
    else
        Say "${REDct}**ERROR**${NOct}: No firmware release URL was found for [$PRODUCT_ID] router model."
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        return 1
    fi

    # Extracting the first octet to use in the curl
    firstOctet="$(echo "$release_version" | cut -d'.' -f1)"
    # Inserting dots between each number
    dottedVersion="$(echo "$firstOctet" | sed 's/./&./g' | sed 's/.$//')"

    if ! _CheckTimeToUpdateFirmware_ "$current_version" "$release_version"
    then
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        return 0
    fi

    ## Check for Login Credentials ##
    credsBase64="$(Get_Custom_Setting credentials_base64)"
    if [ -z "$credsBase64" ] || [ "$credsBase64" = "TBD" ]
    then
        Say "${REDct}**ERROR**${NOct}: No login credentials have been saved. Use the Main Menu to save login credentials."
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        return 1
    fi

    ##---------------------------------------##
    ## Added by ExtremeFiretop [2023-Dec-09] ##
    ##---------------------------------------##
    # Get the required memory for the firmware download and extraction
    requiredRAM_kb="$(_GetRequiredRAM_KB_ "$release_link")"
    if ! _HasRouterMoreThan256MBtotalRAM_ && [ "$requiredRAM_kb" -gt 51200 ]
    then
        if ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR" 1
        then
            Say "${REDct}**ERROR**${NOct}: A USB drive is required for the F/W update due to limited RAM."
            "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
            return 1
        fi
    fi

    freeRAM_kb="$(_GetFreeRAM_KB_)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$requiredRAM_kb" "$availableRAM_kb"

    # Compare versions before deciding to download
    if [ "$releaseVersionNum" -gt "$currentVersionNum" ]
    then
        ##------------------------------------------##
        ## Modified by ExtremeFiretop [2024-Mar-20] ##
        ##------------------------------------------##
        # Check for the presence of backupmon.sh script
        if [ -f "/jffs/scripts/backupmon.sh" ]
        then
            local current_backup_settings="$(Get_Custom_Setting "FW_Auto_Backupmon")"
            if [ "$current_backup_settings" = "ENABLED" ]
            then
                # Extract version number from backupmon.sh
                BM_VERSION="$(grep "^Version=" /jffs/scripts/backupmon.sh | awk -F'"' '{print $2}')"

                # Adjust version format from 1.46 to 1.4.6 if needed
                DOT_COUNT="$(echo "$BM_VERSION" | tr -cd '.' | wc -c)"
                if [ "$DOT_COUNT" -eq 0 ]; then
                    # If there's no dot, it's a simple version like "1" (unlikely but let's handle it)
                    BM_VERSION="${BM_VERSION}.0.0"
                elif [ "$DOT_COUNT" -eq 1 ]; then
                    # For versions like 1.46, insert a dot before the last two digits
                    BM_VERSION="$(echo "$BM_VERSION" | sed 's/\.\([0-9]\)\([0-9]\)/.\1.\2/')"
                fi

                # Convert version strings to comparable numbers
                current_version="$(_ScriptVersionStrToNum_ "$BM_VERSION")"
                required_version="$(_ScriptVersionStrToNum_ "1.5.3")"

                # Check if BACKUPMON version is greater than or equal to 1.5.3
                if [ "$current_version" -ge "$required_version" ]; then
                    # Execute the backup script if it exists #
                    echo ""
                    Say "Backup Started (by BACKUPMON)"
                    sh /jffs/scripts/backupmon.sh -backup >/dev/null
                    BE=$?
                    Say "Backup Finished"
                    echo ""
                    if [ $BE -eq 0 ]; then
                        Say "Backup Completed Successfully"
                        echo ""
                    else
                        Say "Backup Failed"
                        echo ""
                        _SendEMailNotification_ NEW_BM_BACKUP_FAILED
                        _DoCleanUp_ 1
                        if "$isInteractive"
                        then
                            printf "\n${REDct}**IMPORTANT NOTICE**:${NOct}\n"
                            printf "The firmware flash has been ${REDct}CANCELLED${NOct} due to a failed backup from BACKUPMON.\n"
                            printf "Please fix the BACKUPMON configuration, or consider uninstalling it to proceed flash.\n"
                            printf "Resolving the BACKUPMON configuration is HIGHLY recommended for safety of the upgrade.\n"
                            _WaitForEnterKey_ "$mainMenuReturnPromptStr"
                            return 1
                        else
                            _DoExit_ 1
                        fi
                    fi
                else
                    # BACKUPMON version is not sufficient
                    echo ""
                    Say "${REDct}**IMPORTANT NOTICE**:${NOct}"
                    echo ""
                    Say "Backup script (BACKUPMON) is installed; but version $BM_VERSION does not meet the minimum required version of 1.5.3."
                    Say "Skipping backup. Please update your version of BACKUPMON."
                    echo ""
                fi
            else
                Say "Backup script (BACKUPMON) is disabled in the advanced options. Skipping backup."
                echo ""
            fi
        else
            Say "Backup script (BACKUPMON) is not installed. Skipping backup."
            echo ""
        fi

        # Background function to create a blinking LED effect #
        Toggle_LEDs 2 & Toggle_LEDs_PID=$!

        Say "Latest release version is ${GRNct}${release_version}${NOct}."
        Say "Downloading ${GRNct}${release_link}${NOct}"
        echo

        ##----------------------------------------##
        ## Modified by Martinski W. [2024-Feb-28] ##
        ##----------------------------------------##
        # Avoid error message about HSTS database #
        wgetHstsFile="/tmp/home/root/.wget-hsts"
        [ -f "$wgetHstsFile" ] && chmod 0644 "$wgetHstsFile"

        wget -O "$FW_ZIP_FPATH" "$release_link"
    fi

    if [ ! -f "$FW_ZIP_FPATH" ]
    then
        Say "${REDct}**ERROR**${NOct}: Firmware ZIP file [$FW_ZIP_FPATH] was not downloaded."
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        return 1
    fi

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Feb-18] ##
    ##------------------------------------------##
    freeRAM_kb="$(_GetFreeRAM_KB_)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$requiredRAM_kb" "$availableRAM_kb"

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Mar-19] ##
    ##------------------------------------------##
    Say "-----------------------------------------------------------"
    # List & log the contents of the ZIP file #
    unzip -l "$FW_ZIP_FPATH" 2>&1 | \
    while IFS= read -r uzLINE ; do Say "$uzLINE" ; done
    Say "-----------------------------------------------------------"

    # Extracting the firmware binary image #
    if unzip -o "$FW_ZIP_FPATH" -d "$FW_BIN_DIR" -x README* 2>&1 | \
    while IFS= read -r line ; do Say "$line" ; done
    then
        Say "-----------------------------------------------------------"
        #---------------------------------------------------------------#
        # Check if ZIP file was downloaded to a USB-attached drive.
        # Take into account special case for Entware "/opt/" paths.
        #---------------------------------------------------------------#
        if ! echo "$FW_ZIP_FPATH" | grep -qE "^(/tmp/mnt/|/tmp/opt/|/opt/)"
        then
            # It's not on a USB drive, so it's safe to delete it #
            rm -f "$FW_ZIP_FPATH"
        elif ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR" 1
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
        _SendEMailNotification_ FAILED_FW_UNZIP_STATUS
        Say "${REDct}**ERROR**${NOct}: Unable to decompress the firmware ZIP file [$FW_ZIP_FPATH]."
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        return 1
    fi

    freeRAM_kb="$(_GetFreeRAM_KB_)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$requiredRAM_kb" "$availableRAM_kb"

    # Navigate to the firmware directory
    cd "$FW_BIN_DIR"

    ##----------------------------------------##
    ## Modified by Martinski W. [2024-Mar-16] ##
    ##----------------------------------------##
    local checkChangeLogSetting="$(Get_Custom_Setting "CheckChangeLog")"

    if [ "$checkChangeLogSetting" = "ENABLED" ]
    then
        # Get the correct Changelog filename (Changelog-[386|NG].txt) based on the "build number" #
        if echo "$release_version" | grep -q "386"; then
            changeLogTag="386"
        else
            changeLogTag="NG"
        fi
        changeLogFile="$(/usr/bin/find -L "${FW_BIN_DIR}" -name "Changelog-${changeLogTag}.txt" -print)"

        if [ ! -f "$changeLogFile" ]
        then
            Say "Change-log file [${FW_BIN_DIR}/$Changelog-${changeLogTag}.txt] does NOT exist."
            _DoCleanUp_
            "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
            return 1
        else
            # Use awk to format the version based on the number of initial digits
            formatted_current_version=$(echo "$current_version" | awk -F. '{
                if ($1 ~ /^[0-9]{4}$/) {  # Check for a four-digit prefix
                    if (NF == 4 && $4 == "0") {
                        printf "%s.%s", $2, $3  # For version like 3004.388.5.0, remove the last .0
                    } else if (NF == 4) {
                        printf "%s.%s.%s", $2, $3, $4  # For version like 3004.388.5.2, keep the last digit
                    }
                } else if (NF == 3) {  # For version without a four-digit prefix
                    if ($3 == "0") {
                        printf "%s.%s", $1, $2  # For version like 388.5.0, remove the last .0
                    } else {
                        printf "%s.%s.%s", $1, $2, $3  # For version like 388.5.2, keep the last digit
                    }
                }
            }')

            formatted_release_version=$(echo "$release_version" | awk -F. '{
                if ($1 ~ /^[0-9]{4}$/) {  # Check for a four-digit prefix
                    if (NF == 4 && $4 == "0") {
                        printf "%s.%s", $2, $3  # For version like 3004.388.5.0, remove the last .0
                    } else if (NF == 4) {
                        printf "%s.%s.%s", $2, $3, $4  # For version like 3004.388.5.2, keep the last digit
                    }
                } else if (NF == 3) {  # For version without a four-digit prefix
                    if ($3 == "0") {
                        printf "%s.%s", $1, $2  # For version like 388.5.0, remove the last .0
                    } else {
                        printf "%s.%s.%s", $1, $2, $3  # For version like 388.5.2, keep the last digit
                    }
                }
            }')

            # Define regex patterns for both versions
            release_version_regex="$formatted_release_version \([0-9]{1,2}-[A-Za-z]{3}-[0-9]{4}\)"
            current_version_regex="$formatted_current_version \([0-9]{1,2}-[A-Za-z]{3}-[0-9]{4}\)"

            # Check if the current version is present in the changelog
            if ! grep -Eq "$current_version_regex" "$changeLogFile"; then
                Say "Current version not found in change-log. Bypassing change-log verification for this run."
            else
                # Extract log contents between two firmware versions
                changelog_contents="$(awk "/$release_version_regex/,/$current_version_regex/" "$changeLogFile")"
                # Define high-risk terms as a single string separated by '|'
                high_risk_terms="factory default reset|features are disabled|break backward compatibility|must be manually|strongly recommended"

                # Search for high-risk terms in the extracted log contents
                if echo "$changelog_contents" | grep -Eiq "$high_risk_terms"; then
                    if [ "$inMenuMode" = true ]; then
                        printf "\n ${REDct}Warning: Found high-risk phrases in the change-log.${NOct}"
                        printf "\n ${REDct}Would you like to continue anyways?${NOct}"
                        if ! _WaitForYESorNO_ ; then
                            Say "Exiting for change-log review."
                            _DoCleanUp_ 1 ; return 1
                        fi
                    else
                        Say "Warning: Found high-risk phrases in the change-log."
                        Say "Please run script interactively to approve the upgrade."
                        _SendEMailNotification_ STOP_FW_UPDATE_APPROVAL
                        _DoCleanUp_ 1
                        _DoExit_ 1
                    fi
                else
                    Say "No high-risk phrases found in the change-log."
                fi
            fi
        fi
    else
        Say "Change-logs check disabled."
    fi

    freeRAM_kb="$(_GetFreeRAM_KB_)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$requiredRAM_kb" "$availableRAM_kb"

    rog_file=""
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

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Feb-03] ##
    ##------------------------------------------##
    if [ -f "sha256sum.sha256" ] && [ -f "$firmware_file" ]; then
        fw_sig="$(openssl sha256 "$firmware_file" | cut -d' ' -f2)"
        dl_sig="$(grep "$firmware_file" sha256sum.sha256 | cut -d' ' -f1)"
        if [ "$fw_sig" != "$dl_sig" ]; then
            Say "${REDct}**ERROR**${NOct}: Extracted firmware does not match the SHA256 signature!"
            _DoCleanUp_ 1
            _SendEMailNotification_ FAILED_FW_CHECKSUM_STATUS
            if [ "$inMenuMode" = true ]; then
                _WaitForEnterKey_ "$mainMenuReturnPromptStr"
                return 1
            else
            # Assume non-interactive mode; perform exit.
            _DoExit_ 1
            fi
        fi
    else
        Say "${REDct}**ERROR**${NOct}: SHA256 signature file not found!"
        _DoCleanUp_ 1
        if [ "$inMenuMode" = true ]; then
            _WaitForEnterKey_ "$mainMenuReturnPromptStr"
            return 1
        else
            # Assume non-interactive mode; perform exit.
            _DoExit_ 1
        fi
    fi

    ##----------------------------------------##
    ## Modified by Martinski W. [2024-Mar-16] ##
    ##----------------------------------------##
    freeRAM_kb="$(_GetFreeRAM_KB_)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$requiredRAM_kb" "$availableRAM_kb"

    routerURLstr="$(_GetRouterURL_)"
    Say "Router Web URL is: ${routerURLstr}"

    if "$isInteractive"
    then
        printf "${GRNct}**IMPORTANT**:${NOct}\nThe firmware flash is about to start.\n"
        printf "Press <Enter> to stop now, or type ${GRNct}Y${NOct} to continue.\n"
        printf "Once started, the flashing process CANNOT be interrupted.\n"
        if ! _WaitForYESorNO_ "Continue?"
        then
            Say "F/W Update was cancelled by user."
            _DoCleanUp_ 1 "$keepZIPfile"
            return 1
        fi
    fi

    #------------------------------------------------------------#
    # Restart the WebGUI to make sure nobody else is logged in
    # so that the F/W Update can start without interruptions.
    #------------------------------------------------------------#
    "$isInteractive" && printf "\nRestarting web server... Please wait.\n"
    /sbin/service restart_httpd >/dev/null 2>&1 &
    sleep 5

    # Send last email notification before F/W flash #
    _SendEMailNotification_ START_FW_UPDATE_STATUS

    # Stop Entware services before F/W flash #
    _EntwareServicesHandler_ stop

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Mar-15] ##
    ##------------------------------------------##

    curl_response="$(curl -k "${routerURLstr}/login.cgi" \
    --referer "${routerURLstr}/Main_Login.asp" \
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

    if echo "$curl_response" | grep -Eq 'url=index\.asp|url=GameDashboard\.asp'
    then
        _SendEMailNotification_ POST_REBOOT_FW_UPDATE_SETUP

        Say "Flashing ${GRNct}${firmware_file}${NOct}... ${REDct}Please wait for reboot in about 4 minutes or less.${NOct}"
        echo

        # *WARNING*: No more logging at this point & beyond #
        /sbin/ejusb -1 0 -u 1

        #-------------------------------------------------------
        # Stop toggling LEDs during the F/W flash to avoid
        # modifying NVRAM during the actual flash process.
        #-------------------------------------------------------
        _Reset_LEDs_

        nohup curl -k "${routerURLstr}/upgrade.cgi" \
        --referer "${routerURLstr}/Advanced_FirmwareUpgrade_Content.asp" \
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
        #----------------------------------------------------------#
        sleep 180
        /sbin/service reboot
    else
        Say "${REDct}**ERROR**${NOct}: Login failed. Please try the following:
1. Confirm you are not already logged into the router using a web browser.
2. Update credentials by selecting \"Set Router Login Credentials\" from the Main Menu."

        _SendEMailNotification_ FAILED_FW_UPDATE_STATUS
        _DoCleanUp_ 1 "$keepZIPfile"
        _EntwareServicesHandler_ start
    fi

    "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
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

##-------------------------------------##
## Added by Martinski W. [2024-Feb-18] ##
##-------------------------------------##
_SetEMailFormatType_()
{
   local doReturnToMenu
   local currFormatOpt  nextFormatOpt  currFormatStr

   currFormatOpt="$(Get_Custom_Setting FW_New_Update_EMail_FormatType)"
   if [ -z "$currFormatOpt" ] || [ "$currFormatOpt" = "TBD" ]
   then
       nextFormatOpt=""
       currFormatOpt="$sendEMailFormaType"
   else
       nextFormatOpt="$currFormatOpt"
   fi
   currFormatStr="Current Format: ${GRNct}${currFormatOpt}${NOct}"

   doReturnToMenu=false
   while true
   do
       printf "\n${SEPstr}"
       printf "\nChoose the format type for email notifications:\n"
       printf "\n  ${GRNct}1${NOct}. HTML\n"
       printf "\n  ${GRNct}2${NOct}. Plain Text\n"
       printf "\n  ${GRNct}e${NOct}. Exit to Advanced Menu\n"
       printf "${SEPstr}\n"
       printf "[$currFormatStr] Enter selection:  "
       read -r userInput

       [ -z "$userInput" ] && break

       if echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then doReturnToMenu=true ; break ; fi

       case $userInput in
           1) nextFormatOpt="HTML" ; break
              ;;
           2) nextFormatOpt="Plain Text" ; break
              ;;
           *) echo ; _InvalidMenuSelection_
              ;;
       esac
   done

   "$doReturnToMenu" && return 0

   if [ "$nextFormatOpt" = "$currFormatOpt" ]
   then
       _RunEMailNotificationTest_ && _WaitForEnterKey_ "$advnMenuReturnPromptStr"
       return 0
   fi

   Update_Custom_Settings FW_New_Update_EMail_FormatType "$nextFormatOpt"
   printf "\nThe email format type was updated successfully.\n"

   _RunEMailNotificationTest_
   _WaitForEnterKey_ "$advnMenuReturnPromptStr"
}

##-------------------------------------##
## Added by Martinski W. [2024-Feb-16] ##
##-------------------------------------##
_SetSecondaryEMailAddress_()
{
   local currCC_NameOpt  currCC_AddrOpt
   local nextCC_NameOpt  nextCC_AddrOpt
   local currCC_NameStr="Current Name/Alias:"
   local currCC_AddrStr="Current Address:"
   local clearOptStr="${GRNct}c${NOct}=Clear/Remove Setting"
   local doReturnToMenu  doClearSetting  minCharLen  maxCharLen  curCharLen

   currCC_NameOpt="$(Get_Custom_Setting FW_New_Update_EMail_CC_Name)"
   currCC_AddrOpt="$(Get_Custom_Setting FW_New_Update_EMail_CC_Address)"

   if [ -z "$currCC_AddrOpt" ] || [ "$currCC_AddrOpt" = "TBD" ]
   then
       nextCC_AddrOpt=""  currCC_AddrOpt=""
       currCC_AddrStr="$currCC_AddrStr ${REDct}NONE${NOct}"
   else
       nextCC_AddrOpt="$currCC_AddrOpt"
       currCC_AddrStr="$currCC_AddrStr ${GRNct}${currCC_AddrOpt}${NOct}"
   fi

   userInput=""
   minCharLen=10
   maxCharLen=64
   doReturnToMenu=false
   doClearSetting=false

   while true
   do
       printf "\nEnter a secondary email address to receive email notifications.\n"
       if [ -z "$currCC_AddrOpt" ]
       then printf "[${theADExitStr}] [${currCC_AddrStr}]:  "
       else printf "[${theADExitStr}] [${clearOptStr}] [${currCC_AddrStr}]:  "
       fi
       read -r userInput

       [ -z "$userInput" ] && break

       if echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then doReturnToMenu=true ; break ; fi

       if echo "$userInput" | grep -qE "^(c|C)$"
       then doClearSetting=true ; break ; fi

       if ! echo "$userInput" | grep -qE ".+[@].+"
       then
           printf "${REDct}INVALID input.${NOct} "
           printf "No ampersand character [${GRNct}@${NOct}] is found.\n"
           continue
       fi

       curCharLen="${#userInput}"
       if [ "$curCharLen" -lt "$minCharLen" ] || [ "$curCharLen" -gt "$maxCharLen" ]
       then
           printf "${REDct}INVALID input length${NOct} "
           printf "[Minimum=${GRNct}${minCharLen}${NOct}, Maximum=${GRNct}${maxCharLen}${NOct}]\n"
           continue
       fi

       nextCC_AddrOpt="$userInput"
       break
   done

   if "$doReturnToMenu" || \
      { [ -z "$nextCC_AddrOpt" ] && [ -z "$currCC_AddrOpt" ] ; }
   then return 0 ; fi   ##NO Change##

   if "$doClearSetting" || \
      { [ -z "$nextCC_AddrOpt" ] && [ -n "$currCC_AddrOpt" ] ; }
   then
       Update_Custom_Settings FW_New_Update_EMail_CC_Name "TBD"
       Update_Custom_Settings FW_New_Update_EMail_CC_Address "TBD"
       echo "The secondary email address and associated name/alias were removed successfully."
       _WaitForEnterKey_ "$advnMenuReturnPromptStr"
       return 0
   fi

   if [ -z "$currCC_NameOpt" ] || [ "$currCC_NameOpt" = "TBD" ]
   then
       currCC_NameOpt=""
       nextCC_NameOpt="${nextCC_AddrOpt%%@*}"
       currCC_NameStr="$currCC_NameStr ${GRNct}${nextCC_NameOpt}${NOct}"
   else
       nextCC_NameOpt="$currCC_NameOpt"
       currCC_NameStr="$currCC_NameStr ${GRNct}${currCC_NameOpt}${NOct}"
   fi

   userInput=""
   minCharLen=6
   maxCharLen=64
   doReturnToMenu=false

   while true
   do
       printf "\nEnter a name or alias for the secondary email address.\n"
       printf "[${theADExitStr}] [${currCC_NameStr}]:  "
       read -r userInput

       if [ -z "$userInput" ] || echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then doReturnToMenu=true ; break ; fi

       curCharLen="${#userInput}"
       if [ "$curCharLen" -lt "$minCharLen" ] || [ "$curCharLen" -gt "$maxCharLen" ]
       then
           printf "${REDct}INVALID input length${NOct} "
           printf "[Minimum=${GRNct}${minCharLen}${NOct}, Maximum=${GRNct}${maxCharLen}${NOct}]\n"
           continue
       fi

       nextCC_NameOpt="$userInput"
       break;
   done

   if [ "$nextCC_AddrOpt" = "$currCC_AddrOpt" ] && [ "$nextCC_NameOpt" = "$currCC_NameOpt" ]
   then
       _RunEMailNotificationTest_ && _WaitForEnterKey_ "$advnMenuReturnPromptStr"
       return 0
   fi

   Update_Custom_Settings FW_New_Update_EMail_CC_Name "$nextCC_NameOpt"
   Update_Custom_Settings FW_New_Update_EMail_CC_Address "$nextCC_AddrOpt"
   printf "\nThe secondary email address and associated name/alias were updated successfully.\n"

   _RunEMailNotificationTest_
   _WaitForEnterKey_ "$advnMenuReturnPromptStr"
}

# RegExp for IPv4 address #
readonly IPv4octet_RegEx="([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-5][0-5])"
readonly IPv4addrs_RegEx="((${IPv4octet_RegEx}\.){3}${IPv4octet_RegEx})"
readonly IPv4privt_RegEx="((^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.168\.))"

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-06] ##
##----------------------------------------##
_ValidatePrivateIPv4Address_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || \
      ! echo "$1" | grep -qE "^${IPv4addrs_RegEx}$" || \
      ! echo "$1" | grep -qE "^${IPv4privt_RegEx}"
   then return 1
   else return 0
   fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Apr-30] ##
##------------------------------------------##
_ProcessMeshNodes_()
{
    includeExtraLogic="$1"  # Use '1' to include extra logic, '0' to exclude
    if [ $# -eq 0 ] || [ -z "$1" ]
    then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

    uid=1
    if ! node_list="$(_GetNodeIPv4List_)"
    then node_list="" ; fi

    if "$inRouterSWmode"
    then
        if [ -n "$node_list" ]
        then
            # Iterate over the list of nodes and print information for each node
            for nodeIPv4addr in $node_list
            do
                ! _ValidatePrivateIPv4Address_ "$nodeIPv4addr" && continue
                _GetNodeInfo_ "$nodeIPv4addr"
                if ! Node_FW_NewUpdateVersion="$(_GetLatestFWUpdateVersionFromNode_ 1)"
                then
                    Node_FW_NewUpdateVersion="NONE FOUND"
                else
                    _CheckNodeFWUpdateNotification_ "$Node_combinedVer" "$Node_FW_NewUpdateVersion"
                fi

                # Apply extra logic if flag is '1'
                if [ "$includeExtraLogic" -eq 1 ]; then
                    _PrintNodeInfo "$nodeIPv4addr" "$node_online_status" "$Node_FW_NewUpdateVersion" "$uid"
                    uid="$((uid + 1))"
                fi
            done
            if [ -s "$tempNodeEMailList" ]; then
                _SendEMailNotification_ AGGREGATED_UPDATE_NOTIFICATION
            fi
        else
            if [ "$includeExtraLogic" -eq 1 ]; then
                printf "\n${padStr}${padStr}${padStr}${REDct}No AiMesh Node(s)${NOct}"
            fi
        fi
    fi
}

keepZIPfile=0
trap '_DoCleanUp_ 0 "$keepZIPfile" ; _DoExit_ 0' HUP INT QUIT ABRT TERM

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-28] ##
##----------------------------------------##
# Prevent running this script multiple times simultaneously #
if ! _AcquireLock_
then
    if [ $# -eq 1 ] && [ "$1" = "resetLockFile" ]
    then
        _ReleaseLock_
        Say "Lock file has now been reset. Exiting..."
        exit 0
    fi
    Say "Exiting..." ; exit 1
fi

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
       processNodes) _ProcessMeshNodes_ 0
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
    if ! eval $cronListCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
    then
        logo
        # If CRON job does not exist, ask user for permission to add #
        printf "Do you want to enable automatic firmware update checks?\n"
        printf "This will create a CRON job to check for updates regularly.\n"
        printf "The CRON can be disabled at anytime via the main menu.\n"
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
            printf "Automatic firmware update checks will be ${REDct}DISABLED${NOct}.\n"
            printf "You can enable this feature later via the main menu.\n"
            FW_UpdateCheckState=0
            runfwUpdateCheck=false
            nvram set firmware_check_enable="$FW_UpdateCheckState"
            nvram commit
        fi
    else
        printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' already exists.\n"
        _AddCronJobRunScriptHook_
    fi

    # Check if there's a new F/W update available #
    "$runfwUpdateCheck" && [ -x "$FW_UpdateCheckScript" ] && sh $FW_UpdateCheckScript 2>&1 &
    _WaitForEnterKey_
fi

# menu setup variables #
theExitStr="${GRNct}e${NOct}=Exit to Main Menu"
theADExitStr="${GRNct}e${NOct}=Exit to Advanced Menu"
padStr="      "
SEPstr="-----------------------------------------------------"

FW_RouterProductID="${GRNct}${PRODUCT_ID}${NOct}"
if [ "$PRODUCT_ID" = "$MODEL_ID" ]
then FW_RouterModelID="${FW_RouterProductID}"
else FW_RouterModelID="${FW_RouterProductID}/${GRNct}${MODEL_ID}${NOct}"
fi

FW_InstalledVers="$(_GetCurrentFWInstalledShortVersion_)"
FW_NewUpdateVersion="$(_GetLatestFWUpdateVersionFromRouter_ 1)"
FW_InstalledVersion="${GRNct}$(_GetCurrentFWInstalledLongVersion_)${NOct}"

##-------------------------------------##
## Added by Martinski W. [2024-Mar-20] ##
##-------------------------------------##
_SimpleNotificationDate_()
{
   local notifyTimeStrn  notifyTimeSecs
   notifyTimeStrn="$(echo "$1" | sed 's/_/ /g')"
   notifyTimeSecs="$(date +%s -d "$notifyTimeStrn")"
   echo "$(date -d @$notifyTimeSecs +"%Y-%b-%d %I:%M %p")"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Mar-27] ##
##---------------------------------------##
# Define a function to print information about each AiMesh node
_PrintNodeInfo()
{
    local node_info="$1"
    local node_online_status="$2"
    local Node_FW_NewUpdateVersion="$3"
    local uid="$4"

    # Trim to first word if needed
    local node_productid="$(echo "$node_productid" | cut -d' ' -f1)"
    local node_version="$(echo "$Node_combinedVer" | cut -d' ' -f2)"
    node_info="$(echo "$node_info" | cut -d' ' -f1)"

    # Calculate box width based on the longest line
    local max_length=0
    local line length
    for line in "${node_productid}/${node_lan_hostname}: ${node_info}" "F/W Version Installed: ${node_version}" "F/W Update Available: ${Node_FW_NewUpdateVersion}"; do
        length="$(printf "%s" "$line" | awk '{print length}')"
        [ "$length" -gt "$max_length" ] && max_length="$length"
    done

    local box_width="$((max_length + 0))"  # Adjust box padding here

    # Build the horizontal line without using seq
    local h_line=""
    for i in $(awk "BEGIN{for(i=1;i<=$box_width;i++) print i}"); do
        h_line="${h_line}─"
    done

    # Assume ANSI color codes are used but do not manually adjust padding for them.
    if echo "$node_online_status" | grep -q "$node_info"; then
        printf "\n   ┌─%s─┐" "$h_line"

        # Calculate visual length and determine required padding.
        visible_text_length=$(printf "Node ID: %s" "${uid}" | wc -m)
        padding=$((box_width - visible_text_length))
        # Ensure even padding for left and right by dividing total_padding by 2
        left_padding=$((padding / 2)) # Add 1 to make the division round up in case of an odd number
        printf "\n   │%*s Node ID: ${REDct}${uid}${NOct}%*s │" "$left_padding" "" "$((padding - left_padding))" ""

        # Calculate visual length and determine required padding.
        visible_text_length=$(printf "%s/%s: %s" "$node_productid" "$node_lan_hostname" "$node_info" | wc -m)
        padding=$((box_width - visible_text_length))
        printf "\n   │ %s/%s: ${GRNct}%s${NOct}%*s │" "$node_productid" "$node_lan_hostname" "$node_info" "$padding" ""

        visible_text_length=$(printf "F/W Version Installed: %s" "$node_version" | wc -m)
        padding=$((box_width - visible_text_length))
        printf "\n   │ F/W Version Installed: ${GRNct}%s${NOct}%*s │" "$node_version" "$padding" ""

        #
        if [ -n "$Node_FW_NewUpdateVersion" ]; then
            visible_text_length=$(printf "F/W Update Available: %s" "$Node_FW_NewUpdateVersion" | wc -m)
            padding=$((box_width - visible_text_length))
            if echo "$Node_FW_NewUpdateVersion" | grep -q "NONE FOUND"; then
                printf "\n   │ F/W Update Available: ${REDct}%s${NOct}%*s │" "$Node_FW_NewUpdateVersion" "$padding" ""
            else
                printf "\n   │ F/W Update Available: ${GRNct}%s${NOct}%*s │" "$Node_FW_NewUpdateVersion" "$padding" ""
            fi
        fi

        printf "\n   └─%s─┘" "$h_line"
    else
        visible_text_length=$(printf "Node Offline" | wc -m)
        total_padding=$((box_width - visible_text_length))
        # Ensure even padding for left and right by dividing total_padding by 2
        left_padding=$((total_padding / 2)) # Add 1 to make the division round up in case of an odd number

        printf "\n   ┌─%s─┐" "$h_line"
        # Apply the left padding. The '%*s' uses left_padding as its width specifier to insert spaces before "Node Offline"
        printf "\n   │%*s ${REDct}Node Offline${NOct}%*s │" "$left_padding" "" "$((total_padding - left_padding))" ""
        printf "\n   └─%s─┘" "$h_line"
    fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-May-03] ##
##------------------------------------------##
_ShowMainMenu_()
{
   #-----------------------------------------------------------#
   # Check if router reports a new F/W update is available.
   # If yes, modify the notification settings accordingly.
   #-----------------------------------------------------------#
   FW_NewUpdateVers="$(_GetLatestFWUpdateVersionFromRouter_)" && \
   [ -n "$FW_InstalledVers" ] && [ -n "$FW_NewUpdateVers" ] && \
   _CheckNewUpdateFirmwareNotification_ "$FW_InstalledVers" "$FW_NewUpdateVers"

   clear
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

   arrowStr=" ${REDct}<<---${NOct}"

   notifyDate="$(Get_Custom_Setting FW_New_Update_Notification_Date)"
   if [ "$notifyDate" = "TBD" ]
   then notificationStr="${REDct}NOT SET${NOct}"
   else notificationStr="${GRNct}$(_SimpleNotificationDate_ "$notifyDate")${NOct}"
   fi

   ##------------------------------------------##
   ## Modified by ExtremeFiretop [2024-Mar-27] ##
   ##------------------------------------------##
   printf "${SEPstr}"
   if [ "$HIDE_ROUTER_SECTION" = "false" ]
   then
      if ! FW_NewUpdateVersion="$(_GetLatestFWUpdateVersionFromRouter_ 1)"
      then FW_NewUpdateVersion="${REDct}NONE FOUND${NOct}"
      else FW_NewUpdateVersion="${GRNct}${FW_NewUpdateVersion}${NOct}$arrowStr"
      fi
      printf "\n${padStr}F/W Product/Model ID:  $FW_RouterModelID ${padStr}(H)ide"
      printf "\n${padStr}F/W Update Available:  $FW_NewUpdateVersion"
      printf "\n${padStr}F/W Version Installed: $FW_InstalledVersion"
      printf "\n${padStr}USB Storage Connected: $USBConnected"
   else
      printf "\n${padStr}F/W Product/Model ID:  $FW_RouterModelID ${padStr}(S)how"
   fi

   printf "\n${SEPstr}"

   printf "\n  ${GRNct}1${NOct}.  Run F/W Update Check Now\n"
   printf "\n  ${GRNct}2${NOct}.  Set Router Login Credentials\n"

   # Enable/Disable the ASUS Router's built-in "F/W Update Check" #
   FW_UpdateCheckState="$(nvram get firmware_check_enable)"
   [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
   if [ "$FW_UpdateCheckState" -eq 0 ]
   then
       printf "\n  ${GRNct}3${NOct}.  Toggle F/W Update Check"
       printf "\n${padStr}[Currently ${REDct}DISABLED${NOct}]"
   else
       printf "\n  ${GRNct}3${NOct}.  Toggle F/W Update Check"
       printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}]"
   fi
   printf "\n${padStr}[Last Notification Date: $notificationStr]\n"

   printf "\n  ${GRNct}4${NOct}.  Set F/W Update Postponement Days"
   printf "\n${padStr}[Current Days: ${GRNct}${FW_UpdatePostponementDays}${NOct}]\n"

   printf "\n  ${GRNct}5${NOct}.  Set F/W Update Check Schedule"
   printf "\n${padStr}[Current Schedule: ${GRNct}${FW_UpdateCronJobSchedule}${NOct}]\n"

   # Check for AiMesh Nodes #
   if "$inRouterSWmode" && [ -n "$node_list" ]; then
      printf "\n ${GRNct}mn${NOct}.  AiMesh Node(s) Info\n"
   fi

   # Add selection for "Log Options" sub-menu #
   printf "\n ${GRNct}lo${NOct}.  Log Options Menu\n"

   # Add selection for "Advanced Options" sub-menu #
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

##------------------------------------------##
## Modified by ExtremeFiretop [2024-May-03] ##
##------------------------------------------##
_ShowAdvancedOptionsMenu_()
{
   clear
   logo
   printf "=============== Advanced Options Menu ===============\n"
   printf "${SEPstr}\n"

   printf "\n  ${GRNct}1${NOct}.  Set Directory for F/W Update ZIP File"
   printf "\n${padStr}[Current Path: ${GRNct}${FW_ZIP_DIR}${NOct}]\n"

   local checkChangeLogSetting="$(Get_Custom_Setting "CheckChangeLog")"
   if [ "$checkChangeLogSetting" = "DISABLED" ]
   then
       printf "\n  ${GRNct}2${NOct}.  Toggle Change-log Check"
       printf "\n${padStr}[Currently ${REDct}DISABLED${NOct}]\n"
   else
       printf "\n  ${GRNct}2${NOct}.  Toggle Change-log Check"
       printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}]\n"
   fi

   local BetaProductionSetting="$(Get_Custom_Setting "FW_Allow_Beta_Production_Up")"
   if [ "$BetaProductionSetting" = "DISABLED" ]
   then
       printf "\n  ${GRNct}3${NOct}.  Toggle Beta-to-Release Upgrades"
       printf "\n${padStr}[Currently ${REDct}DISABLED${NOct}]\n"
   else
       printf "\n  ${GRNct}3${NOct}.  Toggle Beta-to-Release Upgrades"
       printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}]\n"
   fi

   if [ -f "/jffs/scripts/backupmon.sh" ]
   then
       # Retrieve the current backup settings
       local current_backup_settings="$(Get_Custom_Setting "FW_Auto_Backupmon")"

       printf "\n ${GRNct}ab${NOct}.  Toggle Automatic Backups"
       if [ "$current_backup_settings" = "DISABLED" ]
       then printf "\n${padStr}[Currently ${REDct}${current_backup_settings}${NOct}]\n"
       else printf "\n${padStr}[Currently ${GRNct}${current_backup_settings}${NOct}]\n"
       fi
   fi

   # Additional Email Notification Options #
   if _CheckEMailConfigFileFromAMTM_ 0
   then
       # F/W Update Email Notifications #
       printf "\n ${GRNct}em${NOct}.  Toggle F/W Update Email Notifications"
       if "$sendEMailNotificationsFlag"
       then
           printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}, Format: ${GRNct}${sendEMailFormaType}${NOct}]\n"
       else
           printf "\n${padStr}[Currently ${REDct}DISABLED${NOct}]\n"
       fi

       if "$sendEMailNotificationsFlag"
       then
           # Format Types: "HTML" or "Plain Text" #
           printf "\n ${GRNct}ef${NOct}.  Set Email Format Type"
           printf "\n${padStr}[Current Format: ${GRNct}${sendEMailFormaType}${NOct}]\n"

           # Secondary Email Address Setup for "CC" option #
           printf "\n ${GRNct}se${NOct}.  Set Email Notifications Secondary Address"
           if [ -n "$CC_NAME" ] && [ -n "$CC_ADDRESS" ]
           then
               printf "\n${padStr}[Current Name/Alias: ${GRNct}${CC_NAME}${NOct}]"
               printf "\n${padStr}[Current 2nd Address: ${GRNct}${CC_ADDRESS}${NOct}]\n"
           else
               echo
           fi
       fi
   fi

   # Retrieve the current build type setting
   local current_build_type="$(Get_Custom_Setting "ROGBuild")"

   # Convert the setting to a descriptive text
   if [ "$current_build_type" = "y" ]; then
       current_build_type_menu="ROG Build"
   elif [ "$current_build_type" = "n" ]; then
       current_build_type_menu="Pure Build"
   else
       current_build_type_menu="NOT SET"
   fi

   if echo "$PRODUCT_ID" | grep -q "^GT-"
   then
       printf "\n ${GRNct}bt${NOct}.  Toggle F/W Build Type"
       if [ "$current_build_type_menu" = "NOT SET" ]
       then printf "\n${padStr}[Current Build Type: ${REDct}${current_build_type_menu}${NOct}]\n"
       else printf "\n${padStr}[Current Build Type: ${GRNct}${current_build_type_menu}${NOct}]\n"
       fi
   fi

   printf "\n  ${GRNct}e${NOct}.  Return to Main Menu\n"
   printf "${SEPstr}"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Apr-02] ##
##---------------------------------------##
_ShowNodesMenu_()
{
   clear
   logo
   printf "============== AiMesh Node(s) Info Menu ==============\n"
   printf "${SEPstr}\n"

   if ! node_online_status="$(_NodeActiveStatus_)"
   then node_online_status="" ; fi

   # Count the number of IP addresses
   local numIPs="$(echo "$node_list" | wc -w)"

   # Print the result
   printf "\n${padStr}${padStr}${padStr}${GRNct} AiMesh Node(s): ${numIPs}${NOct}"

   _ProcessMeshNodes_ 1

   echo ""

   printf "\n  ${GRNct}e${NOct}.  Return to Main Menu\n"
   printf "${SEPstr}"
}

_ShowNodesMenuOptions_()
{
    while true
    do
        _ShowNodesMenu_
        printf "\nEnter selection:  "
        read -r nodesChoice
        echo
        case $nodesChoice in
            e|exit) break
               ;;
            *) _InvalidMenuSelection_
               ;;
        esac
    done
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-May-02] ##
##---------------------------------------##
_DownloadChangelogs_()
{
    changeLogTag="$(echo "$(nvram get buildno)" | grep -qE "^386[.]" && echo "386" || echo "NG")"
    if [ "$changeLogTag" = "386" ]
    then
        wget -O "$FW_BIN_DIR/Changelog-${changeLogTag}.txt" "${CL_URL_386}"
    elif [ "$changeLogTag" = "NG" ]
    then
        wget -O "$FW_BIN_DIR/Changelog-${changeLogTag}.txt" "${CL_URL_NG}"
    fi
    changeLogFile="${FW_BIN_DIR}/Changelog-${changeLogTag}.txt"
    if [ ! -f "$changeLogFile" ]
    then
        Say "Change-log file [$changeLogFile] does NOT exist."
    else
        clear
        printf "\n${GRNct}Changelog is ready to review!${NOct}\n"
        printf "\nPress '${REDct}q${NOct}' to quit when finished.\n"
        _WaitForEnterKey_
        less "$changeLogFile"
    fi
    rm -f "$FW_BIN_DIR/Changelog-${changeLogTag}.txt"
    "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
    return 1
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-May-02] ##
##---------------------------------------##
_ShowLogsMenu_()
{
   clear
   logo
   printf "===================== Logs Menu =====================\n"
   printf "${SEPstr}\n"

   printf "\n  ${GRNct}1${NOct}.  Set Directory for F/W Update Log Files"
   printf "\n${padStr}[Current Path: ${GRNct}${FW_LOG_DIR}${NOct}]\n"

   printf "\n ${GRNct}cl${NOct}.  View latest F/W Changelog\n"

   printf "\n  ${GRNct}e${NOct}.  Return to Main Menu\n"
   printf "${SEPstr}"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-May-02] ##
##---------------------------------------##
_AdvancedLogsOptions_()
{
    while true
    do
        _ShowLogsMenu_
        printf "\nEnter selection:  "
        read -r nodesChoice
        echo
        case $nodesChoice in
            1) _Set_FW_UpdateLOG_DirectoryPath_
               ;;
            cl) _DownloadChangelogs_
               ;;
            e|exit) break
               ;;
            *) _InvalidMenuSelection_
               ;;
        esac
    done
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-18] ##
##----------------------------------------##
_InvalidMenuSelection_()
{
   printf "${REDct}INVALID selection.${NOct} Please try again."
   _WaitForEnterKey_
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-May-03] ##
##------------------------------------------##
_advanced_options_menu_()
{
    while true
    do
        _ShowAdvancedOptionsMenu_
        printf "\nEnter selection:  "
        read -r advancedChoice
        echo
        case $advancedChoice in
            1) _Set_FW_UpdateZIP_DirectoryPath_
               ;;
            2) _toggle_change_log_check_
               ;;
            3) _toggle_beta_updates_
               ;;
           ab) if [ -f "/jffs/scripts/backupmon.sh" ]
               then _Toggle_Auto_Backups_
               else _InvalidMenuSelection_
               fi
               ;;
           em) if "$isEMailConfigEnabledInAMTM"
               then _Toggle_FW_UpdateEmailNotifications_
               else _InvalidMenuSelection_
               fi
               ;;
           ef) if "$isEMailConfigEnabledInAMTM" && \
                  "$sendEMailNotificationsFlag"
               then _SetEMailFormatType_
               else _InvalidMenuSelection_
               fi
               ;;
           se) if "$isEMailConfigEnabledInAMTM" && \
                  "$sendEMailNotificationsFlag"
               then _SetSecondaryEMailAddress_
               else _InvalidMenuSelection_
               fi
               ;;
           bt) if echo "$PRODUCT_ID" | grep -q "^GT-"
               then change_build_type
               else _InvalidMenuSelection_
               fi
               ;;
       e|exit) break
               ;;
            *) _InvalidMenuSelection_
               ;;
        esac
    done
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-May-03] ##
##------------------------------------------##
# Main Menu loop
inMenuMode=true
HIDE_ROUTER_SECTION=false
if ! node_list="$(_GetNodeIPv4List_)"
then node_list="" ; fi

while true
do
   # Check if the directory exists again before attempting to navigate to it
   [ -d "$FW_BIN_DIR" ] && cd "$FW_BIN_DIR"

   _ShowMainMenu_
   printf "Enter selection:  " ; read -r userChoice
   echo
   case $userChoice in
       s|S|h|H)
          if [ "$userChoice" = "s" ] || [ "$userChoice" = "S" ]; then
              HIDE_ROUTER_SECTION=false
          elif [ "$userChoice" = "h" ] || [ "$userChoice" = "H" ]; then
              HIDE_ROUTER_SECTION=true
          fi
          ;;
       1) _RunFirmwareUpdateNow_
          ;;
       2) _GetLoginCredentials_
          ;;
       3) _Toggle_FW_UpdateCheckSetting_
          ;;
       4) _Set_FW_UpdatePostponementDays_
          ;;
       5) _Set_FW_UpdateCronSchedule_
          ;;
      mn) if "$inRouterSWmode" && [ -n "$node_list" ]
          then _ShowNodesMenuOptions_
          else _InvalidMenuSelection_
          fi
          ;;
      lo) _AdvancedLogsOptions_
          ;;
      ad) _advanced_options_menu_
          ;;
      up) _SCRIPTUPDATE_
          ;;
      un) _DoUninstall_ && _WaitForEnterKey_
          ;;
  e|exit) _DoExit_ 0
          ;;
       *) _InvalidMenuSelection_
          ;;
   esac
done

#EOF#
