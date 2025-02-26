<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<!-- Use router-provided CSS -->
<meta http-equiv="X-UA-Compatible" content="IE=Edge" />
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Pragma" content="no-cache" />
<meta http-equiv="Expires" content="-1" />
<link rel="shortcut icon" href="images/favicon.png" />
<link rel="icon" href="images/favicon.png" />
<link rel="stylesheet" type="text/css" href="index_style.css" />
<link rel="stylesheet" type="text/css" href="form_style.css" />
<title>MerlinAU add-on for ASUSWRT-Merlin Firmware</title>
<style>
.SettingsTable .Invalid {background-color: red !important;}
.SettingsTable .Disabled {background-color:#ccc;color:#888}
</style>
<!-- Native built-in JS files -->
<script language="JavaScript" type="text/javascript" src="/js/jquery.js"></script>
<script language="JavaScript" type="text/javascript" src="/js/httpApi.js"></script>
<script language="JavaScript" type="text/javascript" src="/state.js"></script>
<script language="JavaScript" type="text/javascript" src="/general.js"></script>
<script language="JavaScript" type="text/javascript" src="/popup.js"></script>
<script language="JavaScript" type="text/javascript" src="/help.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmhist.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmmenu.js"></script>
<script language="JavaScript" type="text/javascript" src="/client_function.js"></script>
<script language="JavaScript" type="text/javascript" src="/validator.js"></script>
<script language="JavaScript" type="text/javascript">

/**----------------------------**/
/** Last Modified: 2025-Feb-25 **/
/** Intended for 1.4.0 Release **/
/**----------------------------**/

// Separate variables for shared and AJAX settings //
var advanced_settings = {};
var custom_settings = {};
var shared_custom_settings = {};
var ajax_custom_settings = {};
let isFormSubmitting = false;
let FW_NewUpdateVersAvailable = '';

// Order of NVRAM keys to search for 'Model ID' and 'Product ID' //
const modelKeys = ["nvram_odmpid", "nvram_wps_modelnum", "nvram_model", "nvram_build_name"];
const productKeys = ["nvram_productid", "nvram_build_name", "nvram_odmpid"];

// Define color formatting //
const CYANct = "<span style='color:cyan;'>";
const REDct = "<span style='color:red;'>";
const GRNct = "<span style='color:green;'>";
const NOct = "</span>";

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-05] **/
/**-------------------------------------**/
const InvGRNct = '<span style="margin-left:4px; background-color:#229652; color:#f2f2f2;">&nbsp;'
const InvREDct = '<span style="margin-left:4px; background-color:#C81927; color:#f2f2f2;">&nbsp;'
const InvYLWct = '<span style="margin-left:4px; background-color:yellow; color:black;">&nbsp;'
const InvCYNct = '<span style="margin-left:4px; background-color:cyan; color:black;">&nbsp;'
const InvCLEAR = '&nbsp;</span>'

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-25] **/
/**----------------------------------------**/
var externalCheckID = 0x00;
var externalCheckOK = true;
var externalCheckMsg = '';
var defaultFWUpdateZIPdirPath = '/home/root';
var isEMailConfigEnabledInAMTM = false;
var scriptAutoUpdateCronSchedHR = 'TBD';
var fwAutoUpdateCheckCronSchedHR = 'TBD';

const validationErrorMsg = 'Validation failed. Please correct invalid value and try again.';

/**-------------------------------------**/
/** Added by Martinski W. [2025-Feb-21] **/
/**-------------------------------------**/
/** Set to false for Production Release **/
var doConsoleLogDEBUG = false;
function ConsoleLogDEBUG (debugMsg, debugVar)
{
   if (!doConsoleLogDEBUG) { return ; }
   if (debugVar === null || typeof debugVar === 'undefined')
   { console.log(debugMsg); }
   else
   { console.log(debugMsg, debugVar); }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-13] **/
/**-------------------------------------**/
// To support 'fwUpdatePostponement' element //
const fwPostponedDays =
{
   minVal: 0, maxVal: 199, maxLen: 3,
   ErrorMsg: function()
   {
      return (`The number of postponement days for F/W updates is INVALID.\nThe value must be between ${this.minVal} and ${this.maxVal} days.`);
   },
   LabelText: function()
   {
      return (`F/W Update Postponement (${this.minVal} to ${this.maxVal} days)`);
   },
   ValidateNumber: function(formField)
   {
      const inputVal = (formField.value * 1);
      const inputLen = formField.value.length;
      if (inputLen === 0 || inputLen > this.maxLen ||
          inputVal < this.minVal || inputVal > this.maxVal)
      { return false; }
      else
      { return true; }
   }
};

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-13] **/
/**-------------------------------------**/
function ValidatePostponedDays (formField)
{
   if (fwPostponedDays.ValidateNumber(formField))
   {
       $(formField).removeClass('Invalid');
       $(formField).off('mouseover');
       return true;
   }
   else
   {
       formField.focus();
       $(formField).addClass('Invalid');
       $(formField).on('mouseover',function(){return overlib(fwPostponedDays.ErrorMsg(),0,0);});
       $(formField)[0].onmouseout = nd;
       return false;
   }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-05] **/
/**-------------------------------------**/
function FormatNumericSetting (formInput)
{
   let inputValue = (formInput.value * 1);
   if (formInput.value.length === 0 || isNaN(inputValue))
   { return false; }
   else
   {
       formInput.value = parseInt(formInput.value, 10);
       return true;
   }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-24] **/
/**-------------------------------------**/
const numberRegExp = '^[0-9]+$';
const daysOfWeekNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const daysOfWeekRexpN = '([S|s]un|[M|m]on|[T|t]ue|[W|w]ed|[T|t]hu|[F|f]ri|[S|s]at)';
const daysOfWeekRexp1 = `${daysOfWeekRexpN}|[0-6]`;
const daysOfWeekRexp2 = `${daysOfWeekRexpN}[-]${daysOfWeekRexpN}|[0-6][-][0-6]`;
const daysOfWeekRexp3 = `${daysOfWeekRexpN}([,]${daysOfWeekRexpN})+|[0-6]([,][0-6])+`;
const daysOfWeekRegEx = `(${daysOfWeekRexp1}|${daysOfWeekRexp2}|${daysOfWeekRexp3})`;

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-24] **/
/**-------------------------------------**/
const fwScheduleTime =
{
   ValidateHOUR: function (theHOURstr)
   {
       if (theHOURstr === null ||
           theHOURstr.length == 0 ||
           theHOURstr.length >= 3 ||
           theHOURstr.match (`${numberRegExp}`) === null)
       { return false; }
       let theHOURnum = parseInt(theHOURstr, 10);
       if (theHOURnum < 0 || theHOURnum > 23)
       { return false; }
       else
       { return true; }
   },
   ValidateMINS: function (theMINSstr)
   {
       if (theMINSstr === null ||
           theMINSstr.length == 0 ||
           theMINSstr.length >= 3 ||
           theMINSstr.match (`${numberRegExp}`) === null)
       { return false; }
       let theMINSNum = parseInt(theMINSstr, 10);
       if (theMINSNum < 0 || theMINSNum > 59)
       { return false; }
       else
       { return true; }
   },
   ValidateDAYS: function (theXDAYSstr)
   {
       if (theXDAYSstr === null ||
           theXDAYSstr.length == 0 ||
           theXDAYSstr.length >= 3 ||
           theXDAYSstr.match (`${numberRegExp}`) === null)
       { return false; }
       let theXDAYSnum = parseInt(theXDAYSstr, 10);
       if (theXDAYSnum < 2 || theXDAYSnum > 15)
       { return false; }
       else
       { return true; }
   },
   ValidateTime: function (formField, timeInput)
   {
       if (timeInput === 'HOUR') { return (this.ValidateHOUR (formField.value)); }
       if (timeInput === 'MINS') { return (this.ValidateMINS (formField.value)); }
       if (timeInput === 'DAYS') { return (this.ValidateDAYS (formField.value)); }
       return (false);
   },
   ErrorMsgHOUR: function()
   {
       return ('The schedule Hour is INVALID.\nThe Hour value must be between 0 and 23.');
   },
   ErrorMsgMINS: function()
   {
       return ('The schedule Minutes are INVALID.\nThe Minutes value must be between 0 and 59.');
   },
   ErrorMsgDAYS: function()
   {
       return ('The schedule Days interval is INVALID.\nThe Days interval value must be between 2 and 15.');
   },
   ErrorMsg: function (timeInput)
   {
       if (timeInput === 'HOUR') { return (this.ErrorMsgHOUR()); }
       if (timeInput === 'MINS') { return (this.ErrorMsgMINS()); }
       if (timeInput === 'DAYS') { return (this.ErrorMsgDAYS()); }
       return 'INVALID input';
   }
};

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-24] **/
/**-------------------------------------**/
function ValidateFWUpdateTime (formField, timeInput)
{
   if (fwScheduleTime.ValidateTime (formField, timeInput))
   {
       $(formField).removeClass('Invalid');
       $(formField).off('mouseover');
       return true;
   }
   else
   {
       formField.focus();
       $(formField).addClass('Invalid');
       $(formField).on('mouseover',function(){return overlib(fwScheduleTime.ErrorMsg(timeInput),0,0);});
       $(formField)[0].onmouseout = nd;
       return false;
   }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-24] **/
/**-------------------------------------**/
function ValidateFWUpdateXDays (formField, timeInput)
{
   if (fwScheduleTime.ValidateTime (formField, timeInput))
   {
       $(formField).removeClass('Invalid');
       $(formField).off('mouseover');
       return true;
   }
   else
   {
       formField.focus();
       $(formField).addClass('Invalid');
       $(formField).on('mouseover',function(){return overlib(fwScheduleTime.ErrorMsg(timeInput),0,0);});
       $(formField)[0].onmouseout = nd;
       return false;
   }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-24] **/
/**-------------------------------------**/
function ToggleDaysOfWeek (isEveryXDayChecked, numberOfDays)
{
   let numOfDays = ['1', 'X'];
   if (isEveryXDayChecked)
   {
       for (var indx = 0; indx < daysOfWeekNames.length; indx++)
       { $('#fwSched_' + daysOfWeekNames[indx].toUpperCase()).prop('disabled', true); }
       if (numberOfDays === 'X')
       { $('#fwScheduleXDAYS').prop('disabled', false); }
       else
       { $('#fwScheduleXDAYS').prop('disabled', true); }
   }
   else
   {
       for (var indx = 0; indx < daysOfWeekNames.length; indx++)
       { $('#fwSched_' + daysOfWeekNames[indx].toUpperCase()).prop('disabled', false); }
       if (numberOfDays === 'X')
       { $('#fwScheduleXDAYS').prop('disabled', true); }
   }
   for (var indx = 0; indx < numOfDays.length; indx++)
   {
       if (numOfDays[indx] !== numberOfDays)
       {
           $('#fwSchedBoxDAYS' + numOfDays[indx]).prop('checked', false);
           $('#fwSchedBoxDAYS' + numOfDays[indx]).prop('disabled', false);
       }
   }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-24] **/
/**-------------------------------------**/
function ValidateScheduleHOUR (theHOURstr)
{
   if (theHOURstr === null ||
       theHOURstr.length == 0 ||
       theHOURstr.length >= 3 ||
       theHOURstr.match (`${numberRegExp}`) === null)
   { return false; }
   let theHOURnum = parseInt(theHOURstr, 10);
   if (theHOURnum < 0 || theHOURnum > 23)
   { return false; }
   else
   { return true; }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-24] **/
/**-------------------------------------**/
function ValidateScheduleMINS (theMINSstr)
{
   if (theMINSstr === null ||
       theMINSstr.length == 0 ||
       theMINSstr.length >= 3 ||
       theMINSstr.match (`${numberRegExp}`) === null)
   { return false; }
   let theMINSNum = parseInt(theMINSstr, 10);
   if (theMINSNum < 0 || theMINSNum > 59)
   { return false; }
   else
   { return true; }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-24] **/
/**-------------------------------------**/
function ValidateScheduleDAYofWEEK (cronDAYofWEEK)
{
   if (cronDAYofWEEK === null || cronDAYofWEEK.length == 0)
   { return false; }
   if (cronDAYofWEEK === '*' ||
       cronDAYofWEEK === '*/2' ||
       cronDAYofWEEK === '*/3' ||
       cronDAYofWEEK.match (`${daysOfWeekRegEx}`) !== null)
   { return true; }
   else
   { return false; }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-25] **/
/**-------------------------------------**/
function GetListFromRangeDAYofWEEK (cronRangeDAYofWEEK)
{
   let theDaysArray = [];
   let theDaysRange = cronRangeDAYofWEEK.split ('-');
   let indexMin = daysOfWeekNames.indexOf (theDaysRange[0]);
   let indexMax = daysOfWeekNames.indexOf (theDaysRange[1]);
   for (var indx = indexMin; indx <= indexMax; indx++)
   { theDaysArray.push (daysOfWeekNames[indx]) ; }
   return (theDaysArray.toString());
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-25] **/
/**-------------------------------------**/
function GetCronDAYofWEEK (daysOfWeekIndex, daysOfWeekArray)
{
   let theDaysOfWeek = '';
   let isNumericSeqOK = false;
   let arrayLength = daysOfWeekIndex.length;

   if (arrayLength <= 2)
   { return (daysOfWeekArray.toString()); }

   for (var indx = 1; indx < arrayLength; indx++)
   {
       if ((daysOfWeekIndex[indx-1] + 1) === daysOfWeekIndex[indx])
       { isNumericSeqOK = true; }
       else
       { isNumericSeqOK = false; break; }
   }
   if (!isNumericSeqOK)
   { theDaysOfWeek = daysOfWeekArray.toString(); }
   else
   { theDaysOfWeek = daysOfWeekArray[0] + '-' + daysOfWeekArray[arrayLength-1]; }
   return (theDaysOfWeek);
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-25] **/
/**-------------------------------------**/
function SetScheduleDAYofWEEK (cronDAYofWEEK)
{
   let fwScheduleDAYS1, fwSchedBoxDAYSX, fwScheduleXDAYS;
   let fwScheduleMON, fwScheduleTUE, fwScheduleWED;
   let fwScheduleTHU, fwScheduleFRI, fwScheduleSAT, fwScheduleSUN;

   if (cronDAYofWEEK.match ('[*]/[2-3]') !== null)
   {
       ToggleDaysOfWeek (true, 'X');
       fwSchedBoxDAYSX = document.getElementById('fwSchedBoxDAYSX');
       fwSchedBoxDAYSX.checked = true;
       fwSchedBoxDAYSX.disabled = false;
       fwScheduleXDAYS = document.getElementById('fwScheduleXDAYS');
       let tempArray = cronDAYofWEEK.split('/');
       if (tempArray.length > 1)
       { fwScheduleXDAYS.value = tempArray[1]; }
       return;
   }
   if (cronDAYofWEEK === '*')
   {
       ToggleDaysOfWeek (true, '1');
       fwScheduleDAYS1 = document.getElementById('fwSchedBoxDAYS1');
       fwScheduleDAYS1.checked = true;
       fwScheduleDAYS1.disabled = false;
       return;
   }
   //Toggle OFF 'Every X Days'//
   ToggleDaysOfWeek (false, 'X');
   let theDAYofWEEK = cronDAYofWEEK;

   if (cronDAYofWEEK.match (`${daysOfWeekRexpN}[-]${daysOfWeekRexpN}`) !== null)
   {
       theDAYofWEEK = GetListFromRangeDAYofWEEK (cronDAYofWEEK);
   }
   if (theDAYofWEEK.match ('[,]?[M|m]on[,]?') !== null)
   {
       fwScheduleMON = document.getElementById('fwSched_MON');
       fwScheduleMON.checked = true;
       fwScheduleMON.disabled = false;
   }
   if (theDAYofWEEK.match ('[,]?[T|t]ue[,]?') !== null)
   {
       fwScheduleTUE = document.getElementById('fwSched_TUE');
       fwScheduleTUE.checked = true;
       fwScheduleTUE.disabled = false;
   }
   if (theDAYofWEEK.match ('[,]?[W|w]ed[,]?') !== null)
   {
       fwScheduleWED = document.getElementById('fwSched_WED');
       fwScheduleWED.checked = true;
       fwScheduleWED.disabled = false;
   }
   if (theDAYofWEEK.match ('[,]?[T|t]hu[,]?') !== null)
   {
       fwScheduleTHU = document.getElementById('fwSched_THU');
       fwScheduleTHU.checked = true;
       fwScheduleTHU.disabled = false;
   }
   if (theDAYofWEEK.match ('[,]?[F|f]ri[,]?') !== null)
   {
       fwScheduleFRI = document.getElementById('fwSched_FRI');
       fwScheduleFRI.checked = true;
       fwScheduleFRI.disabled = false;
   }
   if (theDAYofWEEK.match ('[,]?[S|s]at[,]?') !== null)
   {
       fwScheduleSAT = document.getElementById('fwSched_SAT');
       fwScheduleSAT.checked = true;
       fwScheduleSAT.disabled = false;
   }
   if (theDAYofWEEK.match ('[,]?[S|s]un[,]?') !== null)
   {
       fwScheduleSUN = document.getElementById('fwSched_SUN');
       fwScheduleSUN.checked = true;
       fwScheduleSUN.disabled = false;
   }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-24] **/
/**-------------------------------------**/
// FW_New_Update_Cron_Job_Schedule //
function FWConvertCronScheduleToWebUISettings (rawCronSchedule)
{
   let fwRawCronSched = rawCronSchedule.split(' ');
   let fwScheduleHOUR = document.getElementById('fwScheduleHOUR');
   let fwScheduleMINS = document.getElementById('fwScheduleMINS');
   let fwScheduleDAYS1, fwSchedBoxDAYSX, fwScheduleXDAYS;

   if (rawCronSchedule === 'TBD' || fwRawCronSched.length < 5)
   {
       ToggleDaysOfWeek (true, '1');
       fwScheduleDAYS1 = document.getElementById('fwSchedBoxDAYS1');
       fwScheduleDAYS1.checked = true;
       fwScheduleDAYS1.disabled = false;
       fwScheduleHOUR.value = '0';
       fwScheduleMINS.value = '0';
       return;
   }
   let rawSchedMINS = fwRawCronSched[0];
   let rawSchedHOUR = fwRawCronSched[1];
   let rawSchedDAYM = fwRawCronSched[2];
   let rawSchedMNTH = fwRawCronSched[3];
   let rawSchedDAYW = fwRawCronSched[4];

   if (ValidateScheduleMINS (rawSchedMINS))
   {
       fwScheduleMINS.value = rawSchedMINS;
       fwScheduleMINS.disabled = false;
   }
   else
   {   // Show value but DISABLED for now //
       fwScheduleMINS.value = rawSchedMINS;
       fwScheduleMINS.disabled = true;
   }
   if (ValidateScheduleHOUR (rawSchedHOUR))
   {
       fwScheduleHOUR.value = rawSchedHOUR;
       fwScheduleHOUR.disabled = false;
   }
   else
   {   // Show value but DISABLED for now //
       fwScheduleHOUR.value = rawSchedHOUR;
       fwScheduleHOUR.disabled = true;
   }
   if (rawSchedDAYM.match ('[*]/([2-9]|1[0-5])') !== null)
   {
       ToggleDaysOfWeek (true, 'X');
       fwSchedBoxDAYSX = document.getElementById('fwSchedBoxDAYSX');
       fwSchedBoxDAYSX.checked = true;
       fwSchedBoxDAYSX.disabled = false;
       fwScheduleXDAYS = document.getElementById('fwScheduleXDAYS');
       let tempArray = rawSchedDAYM.split('/');
       if (tempArray.length > 1)
       { fwScheduleXDAYS.value = tempArray[1]; }
       return;
   }
   else if (rawSchedDAYW.match ('[*]/[2-3]') !== null)
   {
       ToggleDaysOfWeek (true, 'X');
       fwSchedBoxDAYSX = document.getElementById('fwSchedBoxDAYSX');
       fwSchedBoxDAYSX.checked = true;
       fwSchedBoxDAYSX.disabled = false;
       fwScheduleXDAYS = document.getElementById('fwScheduleXDAYS');
       let tempArray = rawSchedDAYW.split('/');
       if (tempArray.length > 1)
       { fwScheduleXDAYS.value = tempArray[1]; }
       return;
   }
   else if (rawSchedDAYM === '*' && rawSchedDAYW === '*')
   {
       ToggleDaysOfWeek (true, '1');
       fwScheduleDAYS1 = document.getElementById('fwSchedBoxDAYS1');
       fwScheduleDAYS1.checked = true;
       fwScheduleDAYS1.disabled = false;
       return;
   }
   else if (rawSchedDAYM != '*' || rawSchedMNTH != '*')
   {   /**------------------------------------------------------**/
       /** We do NOT yet handle schedules with different Months **/
       /** or intervals, lists or ranges of "Days of the Month" **/
       /**------------------------------------------------------**/
       // Toggle OFF checkboxes for now //
       ToggleDaysOfWeek (true, '0');
       return;
   }
   if (ValidateScheduleDAYofWEEK (rawSchedDAYW))
   { SetScheduleDAYofWEEK (rawSchedDAYW); }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-25] **/
/**-------------------------------------**/
function FWConvertWebUISettingsToCronSchedule (oldRawCronSchedule)
{
   let newRawCronSchedule = '';
   let theFWRawCronSched = oldRawCronSchedule.split(' ');

   //Temporary delimiter is replaced later by shell script//
   const delimChar = '|';
   const defaultSchedule = '0|0|*|*|*';

   if (oldRawCronSchedule === 'TBD' || theFWRawCronSched.length < 5)
   {   //Default CRON Schedule//
       newRawCronSchedule = defaultSchedule;
       return (newRawCronSchedule);
   }

   let fwRawSchedMINS = theFWRawCronSched[0];
   let fwRawSchedHOUR = theFWRawCronSched[1];
   let fwRawSchedDAYM = theFWRawCronSched[2];
   let fwRawSchedMNTH = theFWRawCronSched[3];
   let fwRawSchedDAYW = theFWRawCronSched[4];
   let fwScheduleHOUR = document.getElementById('fwScheduleHOUR');
   let fwScheduleMINS = document.getElementById('fwScheduleMINS');
   let fwScheduleDAYS1 = document.getElementById('fwSchedBoxDAYS1');
   let fwSchedBoxDAYSX = document.getElementById('fwSchedBoxDAYSX');
   let fwScheduleXDAYS = document.getElementById('fwScheduleXDAYS');
   let fwScheduleMON = document.getElementById('fwSched_MON');
   let fwScheduleTUE = document.getElementById('fwSched_TUE');
   let fwScheduleWED = document.getElementById('fwSched_WED');
   let fwScheduleTHU = document.getElementById('fwSched_THU');
   let fwScheduleFRI = document.getElementById('fwSched_FRI');
   let fwScheduleSAT = document.getElementById('fwSched_SAT');
   let fwScheduleSUN = document.getElementById('fwSched_SUN');

   if (fwScheduleMINS.disabled === false)
   { fwRawSchedMINS = fwScheduleMINS.value; }

   if (fwScheduleHOUR.disabled === false)
   { fwRawSchedHOUR = fwScheduleHOUR.value; }

   if (fwScheduleDAYS1.checked &&
       fwScheduleDAYS1.disabled === false)
   {
       fwRawSchedDAYM = '*';
       fwRawSchedDAYW = '*';
   }
   else if (fwSchedBoxDAYSX.checked &&
            fwSchedBoxDAYSX.disabled === false)
   {
       if (fwRawSchedDAYW.match ('[*]/[2-3]') !== null &&
           (fwScheduleXDAYS.value == 2 || fwScheduleXDAYS.value == 3))
       {
           fwRawSchedDAYM = '*';
           fwRawSchedDAYW = '*/' + fwScheduleXDAYS.value;
       }
       else
       {
           fwRawSchedDAYW = '*';
           fwRawSchedDAYM = '*/' + fwScheduleXDAYS.value;
       }
   }
   else
   {
       let daysOfWeekArray = [], daysOfWeekIndex = [];
       if (fwScheduleSUN.checked && fwScheduleSUN.disabled === false)
       {
           daysOfWeekIndex.push(0);
           daysOfWeekArray.push('Sun');
       }
       if (fwScheduleMON.checked && fwScheduleMON.disabled === false)
       {
           daysOfWeekIndex.push(1);
           daysOfWeekArray.push('Mon');
       }
       if (fwScheduleTUE.checked && fwScheduleTUE.disabled === false)
       {
           daysOfWeekIndex.push(2);
           daysOfWeekArray.push('Tue');
       }
       if (fwScheduleWED.checked && fwScheduleWED.disabled === false)
       {
           daysOfWeekIndex.push(3);
           daysOfWeekArray.push('Wed');
       }
       if (fwScheduleTHU.checked && fwScheduleTHU.disabled === false)
       {
           daysOfWeekIndex.push(4);
           daysOfWeekArray.push('Thu');
       }
       if (fwScheduleFRI.checked && fwScheduleFRI.disabled === false)
       {
           daysOfWeekIndex.push(5);
           daysOfWeekArray.push('Fri');
       }
       if (fwScheduleSAT.checked && fwScheduleSAT.disabled === false)
       {
           daysOfWeekIndex.push(6);
           daysOfWeekArray.push('Sat');
       }
       if (daysOfWeekArray.length > 0)
       {
           fwRawSchedDAYM = '*';
           fwRawSchedMNTH = '*';
           if (daysOfWeekArray.length == 7)
           { fwRawSchedDAYW = '*'; }
           else
           { fwRawSchedDAYW = GetCronDAYofWEEK (daysOfWeekIndex, daysOfWeekArray); }
       }
   }
   newRawCronSchedule = fwRawSchedMINS + delimChar +
                        fwRawSchedHOUR + delimChar +
                        fwRawSchedDAYM + delimChar +
                        fwRawSchedMNTH + delimChar +
                        fwRawSchedDAYW;

   return (newRawCronSchedule);
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-23] **/
/**----------------------------------------**/
// To support 'Directory Path' elements //
const fwUpdateDirPath =
{
   minLen: 5, maxLen: 220,
   ZIPpathLen: 0, ZIPpathStr: '', ZIPdirHasValidChars: true,
   LOGpathLen: 0, LOGpathStr: '', LOGdirHasValidChars: true,
   extCheckZIPdirID: 0x01, extCheckZIPdirOK: true, extCheckZIPdirMSG: '',
   extCheckLOGdirID: 0x02, extCheckLOGdirOK: true, extCheckLOGdirMSG: '',
   pathRegExp: '^(/[a-zA-Z0-9 ._#-]+)(/[a-zA-Z0-9 ._#-]+)+$',

   ErrorMsg: function(dirType)
   {
      let thePathLength = 0, hasValidChars = true;
      const errStr = 'The directory path is INVALID.';

      if (dirType === 'ZIP')
      {
          thePathLength = this.ZIPpathLen;
          hasValidChars = this.ZIPdirHasValidChars;
      }
      else if (dirType === 'LOG')
      {
          thePathLength = this.LOGpathLen;
          hasValidChars = this.LOGdirHasValidChars;
      }
      if (thePathLength < this.minLen)
      {
         const excMinLen = (this.minLen - 1);
         return (`${errStr}\nThe path string must be greater than ${excMinLen} characters.`);
      }
      if (thePathLength > this.maxLen)
      {
         const excMaxLen = (this.maxLen + 1);
         return (`${errStr}\nThe path string must be less than ${excMaxLen} characters.`);
      }
      if (!hasValidChars)
      {
         return (`${errStr}\nThe path string does not meet syntax requirements.`);
      }
      if (dirType === 'ZIP' &&
          !this.extCheckZIPdirOK &&
          this.extCheckZIPdirMSG !== 'OK' &&
          this.extCheckZIPdirMSG.length > 0)
      {
         return (`${errStr}\n\n${this.extCheckZIPdirMSG}\n`);
      }
      if (dirType === 'LOG' &&
          !this.extCheckLOGdirOK &&
          this.extCheckLOGdirMSG !== 'OK' &&
          this.extCheckLOGdirMSG.length > 0)
      {
         return (`${errStr}\n\n${this.extCheckLOGdirMSG}\n`);
      }
      return (`${errStr}`);
   },
   ValidatePath: function(formField, dirType)
   {
      const inputVal = formField.value;
      const inputLen = formField.value.length;

      let dirHasValidChars = true;
      let foundMatch = inputVal.match (`${this.pathRegExp}`);
      if (foundMatch === null) { dirHasValidChars = false; }

      if (dirType === 'ZIP')
      {
          this.ZIPpathLen = inputLen;
          this.ZIPpathStr = inputVal;
          this.ZIPdirHasValidChars = dirHasValidChars;
      }
      else if (dirType === 'LOG')
      {
          this.LOGpathLen = inputLen;
          this.LOGpathStr = inputVal;
          this.LOGdirHasValidChars = dirHasValidChars;
      }

      if (inputLen < this.minLen || inputLen > this.maxLen) { return false; }
      if (!dirHasValidChars) { return false; }

      if (dirType === 'ZIP' &&
          !this.extCheckZIPdirOK &&
          this.extCheckZIPdirMSG !== 'OK' &&
          this.extCheckZIPdirMSG.length > 0)
      { return false; }

      if (dirType === 'LOG' &&
          !this.extCheckLOGdirOK &&
          this.extCheckLOGdirMSG !== 'OK' &&
          this.extCheckLOGdirMSG.length > 0)
      { return false; }

      return true;
   },
   ResetExtCheckVars: function()
   {   //Reset for Next Check//
       this.extCheckZIPdirOK = true;
       this.extCheckLOGdirOK = true;
       this.extCheckZIPdirMSG = 'OK';
       this.extCheckLOGdirMSG = 'OK';
   }
};

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-23] **/
/**----------------------------------------**/
function ValidateDirectoryPath (formField, dirType)
{
   if (formField === null) { return false; }

   if (fwUpdateDirPath.ValidatePath(formField, dirType))
   {
      $(formField).removeClass('Invalid');
      $(formField).off('mouseover');
      return true;
   }
   else
   {
      formField.focus();
      $(formField).addClass('Invalid');
      $(formField).on('mouseover',function(){return overlib(fwUpdateDirPath.ErrorMsg(dirType),0,0);});
      $(formField)[0].onmouseout = nd;
      return false;
   }
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-25] **/
/**----------------------------------------**/
function GetExternalCheckResults()
{
    $.ajax({
        url: '/ext/MerlinAU/CheckHelper.js',
        dataType: 'script',
        timeout: 5000,
        error: function(xhr){
            setTimeout(GetExternalCheckResults,1000);
        },
        success: function()
        {
            document.getElementById('Script_AutoUpdate_SchedText').textContent = 'Schedule: '+scriptAutoUpdateCronSchedHR;
            document.getElementById('FW_AutoUpdate_CheckSchedText').textContent = 'Schedule: '+fwAutoUpdateCheckCronSchedHR;
            SetUpEmailNotificationFields();
            FWUpdateDirZIPHint = FWUpdateDirZIPHint.replace(/DefaultPATH/, defaultFWUpdateZIPdirPath);

            // Skip during form submission //
            if (isFormSubmitting) { return true ; }
            let validationFailed = false;
            let validationStatus = '';

            if (externalCheckOK)
            {
               fwUpdateDirPath.ResetExtCheckVars();
               return true;
            }
            let fwUpdateZIPdirectory = document.getElementById('fwUpdateZIPDirectory');
            let fwUpdateLOGdirectory = document.getElementById('fwUpdateLOGDirectory');

            if ((externalCheckID & fwUpdateDirPath.extCheckZIPdirID) > 0)
            {
                fwUpdateDirPath.extCheckZIPdirOK = false;
                fwUpdateDirPath.extCheckZIPdirMSG = externalCheckMsg;

                if (fwUpdateZIPdirectory !== null &&
                    typeof fwUpdateZIPdirectory !== 'undefined' &&
                    !ValidateDirectoryPath (fwUpdateZIPdirectory, 'ZIP'))
                {
                    validationFailed = true;
                    validationStatus = fwUpdateDirPath.ErrorMsg('ZIP');
                }
            }
            if ((externalCheckID & fwUpdateDirPath.extCheckLOGdirID) > 0)
            {
                fwUpdateDirPath.extCheckLOGdirOK = false;
                fwUpdateDirPath.extCheckLOGdirMSG = externalCheckMsg;

                if (fwUpdateLOGdirectory !== null &&
                    typeof fwUpdateLOGdirectory !== 'undefined' &&
                    !ValidateDirectoryPath (fwUpdateLOGdirectory, 'LOG'))
                {
                    validationFailed = true;
                    validationStatus = fwUpdateDirPath.ErrorMsg('LOG');
                }
            }
            if (validationFailed)
            {
                externalCheckOK = true; //Reset for Next Check//
                fwUpdateDirPath.ResetExtCheckVars();
                alert('Validation failed.\n' + validationStatus);
                setTimeout(ValidateDirectoryPath, 3000, fwUpdateZIPdirectory, 'ZIP');
                setTimeout(ValidateDirectoryPath, 3000, fwUpdateLOGdirectory, 'LOG');
                return false;
            }
        }
    });
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-13] **/
/**-------------------------------------**/
// To support 'routerPassword' element //
const loginPassword =
{
   minLen: 5, maxLen: 64, currLen: 0,
   ErrorMsg: function()
   {
      const errStr = 'The password string is INVALID.';
      if (this.currLen < this.minLen)
      {
         const excMinLen = (this.minLen - 1);
         return (`${errStr}\nThe string length must be greater than ${excMinLen} characters.`);
      }
      if (this.currLen > this.maxLen)
      {
         const excMaxLen = (this.maxLen + 1);
         return (`${errStr}\nThe string length must be less than ${excMaxLen} characters.`);
      }
   },
   ValidateString: function(formField)
   {
      const inputVal = formField.value;
      const inputLen = formField.value.length;
      this.currLen = inputLen;
      if (inputLen < this.minLen || inputLen > this.maxLen)
      { return false; }
      else
      { return true; }
   }
};

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-13] **/
/**-------------------------------------**/
function ValidatePasswordString (formField)
{
   if (loginPassword.ValidateString(formField))
   {
      $(formField).removeClass('Invalid');
      $(formField).off('mouseover');
      return true;
   }
   else
   {
      formField.focus();
      $(formField).addClass('Invalid');
      $(formField).on('mouseover',function(){return overlib(loginPassword.ErrorMsg(),0,0);});
      $(formField)[0].onmouseout = nd;
      return false;
   }
}

function togglePassword()
{
    const passInput = document.getElementById('routerPassword');
    const eyeDiv = document.getElementById('eyeToggle');

    if (passInput.type === 'password')
    {
        passInput.type = 'text';
        eyeDiv.style.background = "url('/images/icon-invisible@2x.png') no-repeat center";
    } 
    else
    {
        passInput.type = 'password';
        eyeDiv.style.background = "url('/images/icon-visible@2x.png') no-repeat center";
    }
    eyeDiv.style.backgroundSize = 'contain';
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-26] **/
/**----------------------------------------**/
// Converts F/W version string with the format: "3006.102.5.2" //
// to a number of the format: '30061020502'  //
function FWVersionStrToNum (verStr)
{
    if (verStr === null ||
        verStr.length === 0 ||
        verStr === 'TBD')
    { return 0; }

    let nonProductionVersionWeight = 0;
    let foundAlphaBetaVersion = verStr.match (/([Aa]lpha|[Bb]eta)/);
    if (foundAlphaBetaVersion == null)
    { nonProductionVersionWeight = 0; }
    else
    {
       nonProductionVersionWeight = 100;
       verStr = verStr.replace (/([Aa]lpha|[Bb]eta)[0-9]*/,'0');
    }

    // Remove everything after the first non-numeric-and-dot character //
    // e.g. "3006.102.1.alpha1" => "3006.102.1" //
    verStr = verStr.split(/[^\d.]/, 1)[0];

    let segments = verStr.split('.');
    let partNum=0, partStr='', verNumStr='';

    for (var index=0 ; index < segments.length ; index++)
    {
        if (segments[index].length > 2)
        { partStr = segments[index]; }
        else
        { partStr = segments[index].padStart(2, '0'); }
        verNumStr = (verNumStr + partStr);
    }
    let verNum = (parseInt(verNumStr, 10) - nonProductionVersionWeight);

    return (verNum);
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-21] **/
/**----------------------------------------**/
function LoadCustomSettings()
{
    shared_custom_settings = <% get_custom_settings(); %>;
    for (var prop in shared_custom_settings)
    {
        if (Object.prototype.hasOwnProperty.call(shared_custom_settings, prop))
        {
            // Remove any old entries that may have been left behind //
            if (prop.indexOf('MerlinAU') != -1 && prop.indexOf('MerlinAU_version_') == -1)
            { eval('delete shared_custom_settings.' + prop); }
        }
    }
    ConsoleLogDEBUG("Shared Custom Settings Loaded:", shared_custom_settings);
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-18] **/
/**-------------------------------------**/
function GetScriptVersion (versionType)
{
    var versionProp;
    if (versionType == 'local')
    { versionProp = shared_custom_settings.MerlinAU_version_local; }
    else if (versionType == 'server')
    { versionProp = shared_custom_settings.MerlinAU_version_server; }

    if (versionProp === null || typeof versionProp === 'undefined')
    { return 'N/A'; }
    else
    { return versionProp; }
}

function PrefixCustomSettings (settings, prefix)
{
    let prefixedSettings = {};
    for (let key in settings)
    {
        if (settings.hasOwnProperty(key))
        { prefixedSettings[prefix + key] = settings[key]; }
    }
    return prefixedSettings;
}

// Function to handle the visibility of the ROG and TUF F/W Build Type rows
function handleROGFWBuildTypeVisibility()
{
    // Get the router model from the hidden input //
    var firmwareProductModelElement = document.getElementById('firmwareProductModelID');
    var routerModel = firmwareProductModelElement ? firmwareProductModelElement.textContent.trim() : '';

    // ROG Model Check //
    var isROGModel = routerModel.includes('GT-');
    var hasROGFWBuildType = custom_settings.hasOwnProperty('ROGBuild');
    var rogFWBuildRow = document.getElementById('rogFWBuildRow');

    if (!isROGModel || !hasROGFWBuildType)
    {  // Hide //
        if (rogFWBuildRow) { rogFWBuildRow.style.display = 'none'; }
    }
    else
    {  // Show //
        if (rogFWBuildRow) { rogFWBuildRow.style.display = ''; }
    }

    // TUF Model Check //
    var isTUFModel = routerModel.includes('TUF-');
    var hasTUFWBuildType = custom_settings.hasOwnProperty('TUFBuild');
    var tufFWBuildRow = document.getElementById('tuffFWBuildRow');

    if (!isTUFModel || !hasTUFWBuildType)
    {  // Hide //
        if (tufFWBuildRow) { tufFWBuildRow.style.display = 'none'; }
    }
    else
    {  // Show //
        if (tufFWBuildRow) { tufFWBuildRow.style.display = ''; }
    }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-27] **/
/**-------------------------------------**/
function ToggleEmailDependents (isEmailNotifyChecked)
{
   let emailFormat = document.getElementById('emailFormat');
   let secondaryEmail = document.getElementById('secondaryEmail');

   if (isEmailNotifyChecked)
   {
       emailFormat.disabled = false;
       secondaryEmail.disabled = false;
       SetStatusForGUI ('emailNotificationsStatus', 'ENABLED');
   }
   else
   {
       emailFormat.disabled = true;
       secondaryEmail.disabled = true;
       SetStatusForGUI ('emailNotificationsStatus', 'DISABLED');
   }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-27] **/
/**-------------------------------------**/
function SetUpEmailNotificationFields()
{
    let emailFormat = document.getElementById('emailFormat');
    let secondaryEmail = document.getElementById('secondaryEmail');
    let emailNotificationsEnabled = document.getElementById('emailNotificationsEnabled');

    if (emailFormat)
    { emailFormat.value = custom_settings.FW_New_Update_EMail_FormatType || 'HTML'; }
    if (secondaryEmail)
    { secondaryEmail.value = custom_settings.FW_New_Update_EMail_CC_Address || 'TBD'; }

    if (emailNotificationsEnabled && emailFormat && secondaryEmail)
    {
        if (isEMailConfigEnabledInAMTM &&
            custom_settings.hasOwnProperty('FW_New_Update_EMail_Notification'))
        {
            emailNotificationsEnabled.disabled = false;
            emailNotificationsEnabled.checked = (custom_settings.FW_New_Update_EMail_Notification === 'ENABLED');
            ToggleEmailDependents (emailNotificationsEnabled.checked);
        }
        else
        {
            emailNotificationsEnabled.disabled = true;
            emailNotificationsEnabled.checked = false;
            ToggleEmailDependents (false);
        }
    }
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-25] **/
/**----------------------------------------**/
const emailNotifyHint = 'The Email Notifications option requires the AMTM email configuration settings to be enabled and set up.';

const autoBackupsHint = 'The Automatic Backups option requires the BACKUPMON script to be installed on the router.';

const addonAutoUpdatesHint = 'The daily schedule for automatic updates of MerlinAU is always configured to be 15 minutes *before* the scheduled time for automatic F/W Update checks.';

let FWUpdateDirZIPHint = "This is the base directory path where the subdirectory <br><b>MerlinAU.d/[RouterID]_firmware</b></br> will be located to download and store the new firmware update files.<br>Default base path:</br><b>DefaultPATH</b>";

const FWUpdateDirLOGHint = 'This is the base directory path where the subdirectory <br><b>MerlinAU.d/logs</b></br> will be located to store the log files of the firmware update process.';

const betaToReleaseHint = 'Enabling this option allows the F/W update process to detect an installed Beta version and proceed to update to the latest production release version.';

const allowVPNAccessHint = 'Enabling this option allows Tailscale and ZeroTier VPN services (if installed) to remain active during the firmware update process. This may be needed when doing a firmware update to a router while connected remotely via a VPN.';

const ROG_BuildTypeMsg = 'The ROG build type preference will apply only if a compatible ROG firmware image is available. Otherwise, the Pure Non-ROG build will be used instead.';

const TUF_BuildTypeMsg = 'The TUF build type preference will apply only if a compatible TUF firmware image is available. Otherwise, the Pure Non-TUF build will be used instead.';

const changelogCheckHint = 'Enable verification check to look out for high-risk phrases in the F/W update changelog.';

const approveChangelogHint ='Approve F/W update with changelog containing high-risk phrases.';
const approveChangelogMsge = 'High-risk phrases were found in the latest F/W changelog. Are you sure you want to approve this changelog and allow the F/W update to proceed?';

const blockChangelogHint = 'Block F/W update with changelog containing high-risk phrases.';
const blockChangelogMsge = 'High-risk phrases were found in the latest F/W changelog. Are you sure you want to block this changelog and *not* allow the F/W update to proceed?';

function ShowHintMsg (formField)
{
   let theHintMsg;
   switch (formField.name)
   {
       case 'FW_UPDATE_ZIPDIR':
           theHintMsg = FWUpdateDirZIPHint;
           break;
       case 'FW_UPDATE_LOGDIR':
           theHintMsg = FWUpdateDirLOGHint;
           break;
       case 'ROG_BUILDTYPE':
           theHintMsg = ROG_BuildTypeMsg;
           break;
       case 'TUF_BUILDTYPE':
           theHintMsg = TUF_BuildTypeMsg;
           break;
       case 'CHANGELOG_CHECK':
           theHintMsg = changelogCheckHint;
           break;
       case 'BETA_TO_RELEASE':
           theHintMsg = betaToReleaseHint;
           break;
       case 'ALLOW_VPN_ACCESS':
           theHintMsg = allowVPNAccessHint;
           break;
       case 'AUTOMATIC_BACKUPS':
           theHintMsg = autoBackupsHint;
           break;
       case 'ADDON_AUTO_UPDATES':
           theHintMsg = addonAutoUpdatesHint;
           break;
       case 'EMAIL_NOTIFICATION':
           theHintMsg = emailNotifyHint;
           break;
       default:
           theHintMsg = '';
           break;
   }
   if (theHintMsg.length > 0)
   {
       $(formField)[0].onmouseout = nd;
       return overlib(theHintMsg,0,0);
   }
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-21] **/
/**----------------------------------------**/
function ApproveChangelog()
{
   console.log("Approving Changelog...");

   if (!confirm (approveChangelogMsge)) { return; }
   document.form.action_script.value = 'start_MerlinAUapprovechangelog';
   document.form.action_wait.value = 10;
   showLoading();
   document.form.submit();
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-21] **/
/**----------------------------------------**/
function BlockChangelog()
{
    console.log("Blocking Changelog...");

    if (!confirm (blockChangelogMsge)) { return; }
    document.form.action_script.value = 'start_MerlinAUblockchangelog';
    document.form.action_wait.value = 10;
    showLoading();
    document.form.submit();
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-23] **/
/**----------------------------------------**/
function InitializeFields()
{
    console.log("Initializing fields...");
    let changelogCheckEnabled = document.getElementById('changelogCheckEnabled');
    let fwNotificationsDate = document.getElementById('fwNotificationsDate');
    let routerPassword = document.getElementById('routerPassword');
    let fwUpdatePostponement = document.getElementById('fwUpdatePostponement');
    let autobackupEnabled = document.getElementById('autobackupEnabled');
    let rogFWBuildType = document.getElementById('rogFWBuildType');
    let tuffFWBuildType = document.getElementById('tuffFWBuildType');
    let tailscaleVPNEnabled = document.getElementById('tailscaleVPNEnabled');
    let script_AutoUpdate_Check = document.getElementById('Script_AutoUpdate_Check');
    let betaToReleaseUpdatesEnabled = document.getElementById('betaToReleaseUpdatesEnabled');
    let fwUpdateZIPdirectory = document.getElementById('fwUpdateZIPDirectory');
    let fwUpdateLOGdirectory = document.getElementById('fwUpdateLOGDirectory');

    // Instead of reading from firmware_check_enable, read from the custom_settings //
    let storedFwUpdateEnabled = custom_settings.FW_Update_Check || 'DISABLED'; 
    // fallback to 'DISABLED' if custom_settings.FW_Update_Check is missing //

    $('#KeepConfigFile').prop('checked',false);
    $('#BypassPostponedDays').prop('checked',false);

    let FW_AutoUpdate_Check = document.getElementById('FW_AutoUpdate_Check');
    let fwUpdateCheckStatus = document.getElementById('fwUpdateCheckStatus');

    // Set the checkbox state based on "ENABLED" vs. "DISABLED" vs. "TBD"
    if (FW_AutoUpdate_Check)
    { FW_AutoUpdate_Check.checked = (storedFwUpdateEnabled === 'ENABLED'); }

    // Update the Firmware Status display //
    if (fwUpdateCheckStatus)
    {  // Pass the raw string ('ENABLED', 'DISABLED', or 'TBD') //
       SetStatusForGUI('fwUpdateCheckStatus', storedFwUpdateEnabled);
    }

    // Safe value assignments //
    if (custom_settings)
    {
        if (routerPassword)
        { routerPassword.value = custom_settings.routerPassword || ''; }

        if (fwUpdatePostponement)
        {
            fwPosptonedDaysLabel = document.getElementById('fwUpdatePostponementLabel');
            fwPosptonedDaysLabel.textContent = fwPostponedDays.LabelText();
            fwUpdatePostponement.value = custom_settings.FW_New_Update_Postponement_Days || '15'; 
        }

        let fwUpdateRawCronSchedule = custom_settings.FW_New_Update_Cron_Job_Schedule || 'TBD';
        FWConvertCronScheduleToWebUISettings (fwUpdateRawCronSchedule);

        SetUpEmailNotificationFields();

        if (rogFWBuildType)
        { rogFWBuildType.value = custom_settings.ROGBuild || 'ROG'; }

        if (tuffFWBuildType)
        { tuffFWBuildType.value = custom_settings.TUFBuild || 'TUF'; }

        if (changelogCheckEnabled)
        { changelogCheckEnabled.checked = (custom_settings.CheckChangeLog === 'ENABLED'); }

        if (autobackupEnabled)
        {
            if (custom_settings.hasOwnProperty('FW_Auto_Backupmon'))
            {
                // If the setting exists, enable the checkbox and set its state
                autobackupEnabled.disabled = false;
                autobackupEnabled.checked = (custom_settings.FW_Auto_Backupmon === 'ENABLED');
                autobackupEnabled.style.opacity = '1'; // Fully opaque
            }
            else
            {
                // If the setting is missing, disable and gray out the checkbox
                autobackupEnabled.disabled = true;
                autobackupEnabled.checked = false; // Optionally uncheck
                autobackupEnabled.style.opacity = '0.5'; // Grayed out appearance
            }
        }

        if (tailscaleVPNEnabled)
        { tailscaleVPNEnabled.checked = (custom_settings.Allow_Updates_OverVPN === 'ENABLED'); }

        if (script_AutoUpdate_Check)
        { script_AutoUpdate_Check.checked = (custom_settings.Allow_Script_Auto_Update === 'ENABLED'); }

        if (betaToReleaseUpdatesEnabled)
        { betaToReleaseUpdatesEnabled.checked = (custom_settings.FW_Allow_Beta_Production_Up === 'ENABLED'); }

        if (fwUpdateZIPdirectory !== null && typeof fwUpdateZIPdirectory !== 'undefined')
        { fwUpdateZIPdirectory.value = custom_settings.FW_New_Update_ZIP_Directory_Path || ''; }

        if (fwUpdateLOGdirectory !== null && typeof fwUpdateLOGdirectory !== 'undefined')
        { fwUpdateLOGdirectory.value = custom_settings.FW_New_Update_LOG_Directory_Path || ''; }

        // Update Settings Status Table //
        SetStatusForGUI('changelogCheckStatus', custom_settings.CheckChangeLog);
        SetStatusForGUI('betaToReleaseUpdatesStatus', custom_settings.FW_Allow_Beta_Production_Up);
        SetStatusForGUI('tailscaleVPNAccessStatus', custom_settings.Allow_Updates_OverVPN);
        SetStatusForGUI('autoUpdatesScriptEnabledStatus', custom_settings.Allow_Script_Auto_Update);
        SetStatusForGUI('autobackupEnabledStatus', custom_settings.FW_Auto_Backupmon);

        // Handle fwNotificationsDate as a date //
        let notifyFullDateStr, notifyDateTimeStr;
        if (fwNotificationsDate && custom_settings.FW_New_Update_Notifications_Date)
        {
            notifyFullDateStr = custom_settings.FW_New_Update_Notifications_Date;
            if (notifyFullDateStr.includes('_'))
            {
                notifyDateTimeStr = notifyFullDateStr.split ('_');
                notifyFullDateStr = notifyDateTimeStr[0] + ' ' + notifyDateTimeStr[1];
            }
            fwNotificationsDate.innerHTML = InvYLWct + notifyFullDateStr + InvCLEAR;
        }
        else if (fwNotificationsDate)
        { fwNotificationsDate.innerHTML = InvYLWct + "TBD" + InvCLEAR; }

        // **Handle fwUpdateEstimatedRunDate Separately**
        var fwUpdateEstimatedRunDateElement = document.getElementById('fwUpdateEstimatedRunDate');

        // **Handle fwUpdateAvailable with Version Comparison**
        var fwUpdateAvailableElement = document.getElementById('fwUpdateAvailable');
        var fwVersionInstalledElement = document.getElementById('fwVersionInstalled');

        var isFwUpdateAvailable = false; // Initialize the flag //
        if (fwUpdateAvailableElement && fwVersionInstalledElement)
        {
            var fwUpdateAvailable = FW_NewUpdateVersAvailable;
            var fwVersionInstalled = fwVersionInstalledElement.textContent.trim();

            // Convert both to numeric forms //
            var verNumAvailable = FWVersionStrToNum(fwUpdateAvailable);
            var verNumInstalled = FWVersionStrToNum(fwVersionInstalled);

            // If verNumAvailable is 0, maybe treat as "NONE FOUND" //
            if (verNumAvailable === 0)
            {
                fwUpdateAvailableElement.innerHTML = InvYLWct + "NONE FOUND" + InvCLEAR;
                isFwUpdateAvailable = false;
            }
            else if (verNumAvailable > verNumInstalled)
            {   // Update available //
                fwUpdateAvailableElement.innerHTML = InvYLWct + fwUpdateAvailable + InvCLEAR;
                isFwUpdateAvailable = true;
            } 
            else // No update //
            {
                fwUpdateAvailableElement.innerHTML = InvYLWct + "NONE FOUND" + InvCLEAR;
                isFwUpdateAvailable = false;
            }
        }
        else
        { console.error("Required elements for firmware version comparison not found."); }

        // **Update fwUpdateEstimatedRunDate Based on fwUpdateAvailable** //
        if (fwUpdateEstimatedRunDateElement)
        {
            if (isFwUpdateAvailable && fwUpdateAvailable !== '')
            { fwUpdateEstimatedRunDateElement.innerHTML = InvYLWct + fwUpdateEstimatedRunDate + InvCLEAR; }
            else
            { fwUpdateEstimatedRunDateElement.innerHTML = InvYLWct + "TBD" + InvCLEAR; }
        }

        // **Handle Changelog Approval Display** //
        var changelogApprovalElement = document.getElementById('changelogApproval');
        if (changelogApprovalElement)
        {   // Default to "Disabled" if missing //
            var approvalStatus = custom_settings.hasOwnProperty('FW_New_Update_Changelog_Approval') ? custom_settings.FW_New_Update_Changelog_Approval : "Disabled";
            SetStatusForGUI('changelogApproval', approvalStatus);
        }

        // **Control "Approve/Block Changelog" Button State** //
        var approveBlockChangelogBtn = document.getElementById('approveBlockChangeLogBtn');
        if (approveBlockChangelogBtn)
        {
            var isChangelogCheckEnabled = (custom_settings.CheckChangeLog === 'ENABLED');
            var changelogApprovalValue = custom_settings.FW_New_Update_Changelog_Approval;

            approveBlockChangelogBtn.style.display = 'inline-block';

            // Decide whether we want "Approve" or "Block" //
            if (changelogApprovalValue === 'APPROVED')
            {   // Toggle functionality //
                approveBlockChangelogBtn.value = "Block Changelog";
                approveBlockChangelogBtn.title = blockChangelogHint;
                approveBlockChangelogBtn.onclick = function() {
                    BlockChangelog();
                    return false;  // Prevent default form submission
                };

                approveBlockChangelogBtn.disabled = false; 
                approveBlockChangelogBtn.style.opacity = '1'; 
                approveBlockChangelogBtn.style.cursor = 'pointer';
            }
            else if (changelogApprovalValue === 'BLOCKED')
            {   // Toggle functionality //
                approveBlockChangelogBtn.value = "Approve Changelog";
                approveBlockChangelogBtn.title = approveChangelogHint;
                approveBlockChangelogBtn.onclick = function() {
                    ApproveChangelog();
                    return false;
                };
                approveBlockChangelogBtn.disabled = false; 
            }
            else
            {
                approveBlockChangelogBtn.value = "Approve Changelog";

                // Condition: Enable button only if
                // 1. Changelog Check is enabled
                // 2. Changelog Approval is neither empty nor "TBD"
                if (isChangelogCheckEnabled && changelogApprovalValue && changelogApprovalValue !== 'TBD')
                {
                    approveBlockChangelogBtn.title = approveChangelogHint;
                    approveBlockChangelogBtn.disabled = false;
                    approveBlockChangelogBtn.style.opacity = '1';
                    approveBlockChangelogBtn.style.cursor = 'pointer';
                }
                else
                {
                    approveBlockChangelogBtn.title = '';
                    approveBlockChangelogBtn.disabled = true;
                    approveBlockChangelogBtn.style.opacity = '0.5';
                    approveBlockChangelogBtn.style.cursor = 'not-allowed';
                }
            }
        }

        // **New Logic to Update "F/W Variant Detected" Based on "extendno"** //
        var extendnoElement = document.getElementById('extendno');
        var extendno = extendnoElement ? extendnoElement.value.trim() : '';

        var fwVariantDetectedElement = document.getElementById('fwVariantDetected');

        if (fwVariantDetectedElement)
        {   // Case-insensitive check for "gnuton" //
            if (/gnuton/i.test(extendno))
            { fwVariantDetectedElement.innerHTML = InvCYNct + "Gnuton" + InvCLEAR; }
            else
            { fwVariantDetectedElement.innerHTML = InvCYNct + "Merlin" + InvCLEAR; }
        }
        else
        { console.error("Element with id 'fwVariantDetected' not found."); }

        // Call the visibility handler //
        handleROGFWBuildTypeVisibility();
        updateTUFROGAvailText();
        console.log("Initializing was completed successfully.");
    }
    else
    { console.error("Custom settings NOT loaded."); }
}

// Tokenize input line string, respecting quoted substrings //
function Tokenize (inputStr)
{
    var regex = /(?:[^\s"]+|"[^"]*")+/g;
    return inputStr.match(regex) || [];
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-21] **/
/**----------------------------------------**/
function GetConfigSettings()
{
    $.ajax({
        url: '/ext/MerlinAU/config.htm',
        dataType: 'text',
        error: function(xhr)
        {
            console.error("Failed to fetch config.htm:", xhr.statusText);
            setTimeout(GetConfigSettings, 1000);
        },
        success: function(data)
        {
            let keyName, keyValue;
            let tokenList, tokenStr;
            let configLines = data.split('\n');

            for (var jIndx = 0; jIndx < configLines.length; jIndx++)
            {
                if (configLines[jIndx].length === 0 ||
                    configLines[jIndx].match('^[ ]*#') !== null)
                { continue; }  //Skip comments & empty lines//

                tokenList = Tokenize (configLines[jIndx]);

                for (var kIndx = 0; kIndx < tokenList.length; kIndx++)
                {
                    tokenStr = tokenList[kIndx];

                    if (tokenStr.includes('='))
                    {
                        // Handle "key=value" pair format //
                        var splitIndex = tokenStr.indexOf('=');
                        keyName = tokenStr.substring(0, splitIndex).trim();
                        keyValue = tokenStr.substring(splitIndex + 1).trim();

                        // Remove surrounding quotes if present //
                        if (keyValue.startsWith('"') && keyValue.endsWith('"'))
                        { keyValue = keyValue.substring(1, keyValue.length - 1); }

                        AssignAjaxSetting(keyName, keyValue);
                    }
                    else
                    {
                        // Handle "key value" pair format //
                        keyName = tokenStr.trim();
                        keyValue = '';

                        // Ensure there's a next token for the value //
                        if (kIndx + 1 < tokenList.length)
                        {
                            keyValue = tokenList[kIndx + 1].trim();

                            // Remove surrounding quotes if present //
                            if (keyValue.startsWith('"') && keyValue.endsWith('"'))
                            { keyValue = keyValue.substring(1, keyValue.length - 1); }

                            AssignAjaxSetting(keyName, keyValue);
                            kIndx++; // Skip next token as it's already processed //
                        }
                        else
                        { console.warn(`No value found for keyName: ${keyName}`); }
                    }
                }
            }
            ConsoleLogDEBUG("AJAX Custom Settings Loaded:", ajax_custom_settings);

            // Merge both server and AJAX settings //
            custom_settings = Object.assign({}, shared_custom_settings, ajax_custom_settings);
            ConsoleLogDEBUG("Merged Custom Settings:", custom_settings);

            // Initialize fields with the merged settings //
            InitializeFields();
            GetExternalCheckResults();
        }
    });
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-23] **/
/**----------------------------------------**/
// Helper function to assign settings based on key //
function AssignAjaxSetting (keyName, keyValue)
{
   // Normalize key to uppercase for case-insensitive comparison //
   var keyUpper = keyName.toUpperCase();

   switch (true)
   {
       case keyUpper === 'FW_NEW_UPDATE_POSTPONEMENT_DAYS':
           ajax_custom_settings.FW_New_Update_Postponement_Days = keyValue;
           break;

       // NOTE: Use for display purposes ONLY //
       case keyUpper === 'FW_NEW_UPDATE_EXPECTED_RUN_DATE':
           fwUpdateEstimatedRunDate = keyValue;
           break;

       case keyUpper === 'FW_NEW_UPDATE_EMAIL_NOTIFICATION':
           ajax_custom_settings.FW_New_Update_EMail_Notification = convertToStatus(keyValue);
           break;

       case keyUpper === 'FW_NEW_UPDATE_EMAIL_FORMATTYPE':
           ajax_custom_settings.FW_New_Update_EMail_FormatType = keyValue;
           break;

       case keyUpper === 'FW_NEW_UPDATE_ZIP_DIRECTORY_PATH':
           ajax_custom_settings.FW_New_Update_ZIP_Directory_Path = keyValue;
           break;

       case keyUpper === 'FW_NEW_UPDATE_LOG_DIRECTORY_PATH':
           ajax_custom_settings.FW_New_Update_LOG_Directory_Path = keyValue;
           break;

       case keyUpper === 'ALLOW_UPDATES_OVERVPN':
           ajax_custom_settings.Allow_Updates_OverVPN = convertToStatus(keyValue);
           break;

       case keyUpper === 'FW_NEW_UPDATE_NOTIFICATION_VERS':
           FW_NewUpdateVersAvailable = keyValue.trim();
           break;

       case keyUpper === 'FW_NEW_UPDATE_EMAIL_CC_ADDRESS':
           ajax_custom_settings.FW_New_Update_EMail_CC_Address = keyValue;
           break;

       case keyUpper === 'CHECKCHANGELOG':
           ajax_custom_settings.CheckChangeLog = convertToStatus(keyValue);
           break;

       case keyUpper === 'FW_UPDATE_CHECK':
           ajax_custom_settings.FW_Update_Check = convertToStatus(keyValue);
           break;

       case keyUpper === 'ALLOW_SCRIPT_AUTO_UPDATE':
           ajax_custom_settings.Allow_Script_Auto_Update = convertToStatus(keyValue);
           break;

       case keyUpper === 'FW_NEW_UPDATE_CHANGELOG_APPROVAL':
           ajax_custom_settings.FW_New_Update_Changelog_Approval = keyValue; // Store as-is for display
           break;

       case keyUpper === 'FW_ALLOW_BETA_PRODUCTION_UP':
           ajax_custom_settings.FW_Allow_Beta_Production_Up = convertToStatus(keyValue);
           break;

       case keyUpper === 'FW_AUTO_BACKUPMON':
           ajax_custom_settings.FW_Auto_Backupmon = convertToStatus(keyValue);
           break;

       case keyUpper === 'CREDENTIALS_BASE64':
           try
           {
               var decoded = atob(keyValue);
               var password = decoded.split(':')[1] || '';
               ajax_custom_settings.routerPassword = password;
           }
           catch (e)
           {
               console.error("Error decoding credentials_base64:", e);
           }
           break;

       case keyUpper === 'ROGBUILD':
           ajax_custom_settings.ROGBuild = (keyValue === 'ENABLED') ? 'ROG' : 'Pure';
           break;

       case keyUpper === 'TUFBUILD':
           ajax_custom_settings.TUFBuild = (keyValue === 'ENABLED') ? 'TUF' : 'Pure';
           break;

       case keyUpper === 'FW_NEW_UPDATE_NOTIFICATION_DATE':
           ajax_custom_settings.FW_New_Update_Notifications_Date = keyValue;
           break;

       case keyUpper === 'FW_NEW_UPDATE_CRON_JOB_SCHEDULE':
           ajax_custom_settings.FW_New_Update_Cron_Job_Schedule = keyValue;
           break;

       // Additional AJAX settings can be handled here //

       default:
           // Optionally handle or log unknown settings //
           break;
   }
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-21] **/
/**----------------------------------------**/
// Helper function to set status with color //
function SetStatusForGUI (elementId, statusValue)
{
    let element = document.getElementById(elementId);
    if (element)
    {
        switch (statusValue)
        {
            case 'ENABLED':
                element.innerHTML = InvGRNct + "Enabled" + InvCLEAR;
                break;
            case 'APPROVED':
                element.innerHTML = InvGRNct + "Approved" + InvCLEAR;
                break;
            case 'DISABLED':
                element.innerHTML = InvREDct + "Disabled" + InvCLEAR;
                break;
            case 'BLOCKED':
                element.innerHTML = InvREDct + "Blocked" + InvCLEAR;
                break;
            case 'TBD':
                element.innerHTML = InvYLWct + "TBD" + InvCLEAR;
                break;
            default:
                // Fallback if some unexpected string appears //
                element.innerHTML = InvREDct + "Disabled" + InvCLEAR;
                break;
        }
    }
}

function SetCurrentPage()
{
    /* Set the proper return pages */
    document.form.next_page.value = window.location.pathname.substring(1);
    document.form.current_page.value = window.location.pathname.substring(1);
}

function convertToStatus(value)
{
    if (typeof value === 'boolean') return value ? 'ENABLED' : 'DISABLED';
    if (typeof value === 'string')
    { return (value.toLowerCase() === 'true' || value.toLowerCase() === 'enabled') ? 'ENABLED' : 'DISABLED'; }
    return 'DISABLED';
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-18] **/
/**-------------------------------------**/
function UpdateScriptVersion()
{
    var localVers = GetScriptVersion('local');
    var serverVers = GetScriptVersion('server');

    $('#headerTitle').text ('MerlinAU Dashboard v' + localVers);
    $('#footerTitle').text ('MerlinAU v' + localVers + ' by ExtremeFiretop & Martinski W.');
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-20] **/
/**----------------------------------------**/
function initial()
{
    isFormSubmitting = false;
    SetCurrentPage();
    LoadCustomSettings();
    GetConfigSettings();
    show_menu();
    UpdateScriptVersion();
    showhide('Script_AutoUpdate_SchedText',true);
    showhide('FW_AutoUpdate_CheckSchedText',true);

    // Debugging iframe behavior //
    var hiddenFrame = document.getElementById('hidden_frame');
    if (hiddenFrame)
    {
        hiddenFrame.onload = function()
        {
            console.log("Hidden frame loaded with server response.");
        };
        initializeCollapsibleSections();
    }
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-23] **/
/**----------------------------------------**/
function SaveActionsConfig()
{
    // Clear amng_custom for any existing content before saving
    document.getElementById('amng_custom').value = '';

    // Collect Action form-specific settings //
    var passwordStr = document.getElementById('routerPassword')?.value || '';
    var usernameElement = document.getElementById('http_username');
    var username = usernameElement ? usernameElement.value.trim() : 'admin';

    // Validate that username is not empty //
    if (!username)
    {
        console.error("HTTP username is missing.");
        alert("HTTP username is not set. Please contact your administrator.");
        return false;
    }
    if (!ValidatePasswordString (document.getElementById('routerPassword')))
    {
        alert(`${validationErrorMsg}\n\n` + loginPassword.ErrorMsg());
        return false;
    }
    if (!ValidatePostponedDays (document.form.fwUpdatePostponement))
    {
        alert(`${validationErrorMsg}\n\n` + fwPostponedDays.ErrorMsg());
        return false;
    }
    if (document.form.fwScheduleHOUR.disabled === false &&
        !ValidateFWUpdateTime (document.form.fwScheduleHOUR, 'HOUR'))
    {
        alert(`${validationErrorMsg}\n\n` + fwScheduleTime.ErrorMsg('HOUR'));
        return false;
    }
    if (document.form.fwScheduleMINS.disabled === false &&
        !ValidateFWUpdateTime (document.form.fwScheduleMINS, 'MINS'))
    {
        alert(`${validationErrorMsg}\n\n` + fwScheduleTime.ErrorMsg('MINS'));
        return false;
    }
    if (document.getElementById('fwSchedBoxDAYSX').checked &&
        !ValidateFWUpdateXDays (document.form.fwScheduleXDAYS, 'DAYS'))
    {
        alert(`${validationErrorMsg}\n\n` + fwScheduleTime.ErrorMsg('DAYS'));
        return false;
    }
    let fwUpdateRawCronSchedule = custom_settings.FW_New_Update_Cron_Job_Schedule;
    fwUpdateRawCronSchedule = FWConvertWebUISettingsToCronSchedule (fwUpdateRawCronSchedule);

    // Encode credentials in Base64 //
    var credentials = username + ':' + passwordStr;
    var encodedCredentials = btoa(credentials);

    // Collect only Action form-specific settings //
    var action_settings =
    {
        credentials_base64: encodedCredentials,
        FW_New_Update_Cron_Job_Schedule: fwUpdateRawCronSchedule,
        FW_New_Update_Postponement_Days: document.getElementById('fwUpdatePostponement')?.value || '0',
        CheckChangeLog: document.getElementById('changelogCheckEnabled').checked ? 'ENABLED' : 'DISABLED',
        FW_Update_Check: document.getElementById('FW_AutoUpdate_Check').checked ? 'ENABLED' : 'DISABLED'
    };
    // Prefix only Action settings //
    var prefixedActionSettings = PrefixCustomSettings(action_settings, 'MerlinAU_');

    // ***** FIX BUG WHERE MerlinAU_FW_Auto_Backupmon is saved from the wrong button *****
    // ***** Only when the Advanced Options section is saved first, and then Actions Section is saved second *****
    var ADVANCED_KEYS = [
        "MerlinAU_FW_Auto_Backupmon",
        "MerlinAU_FW_Allow_Beta_Production_Up",
        "MerlinAU_FW_New_Update_ZIP_Directory_Path",
        "MerlinAU_FW_New_Update_LOG_Directory_Path",
        "MerlinAU_FW_New_Update_EMail_Notification",
        "MerlinAU_FW_New_Update_EMail_FormatType",
        "MerlinAU_FW_New_Update_EMail_CC_Address",
        "MerlinAU_Allow_Updates_OverVPN",
        "MerlinAU_Allow_Script_Auto_Update",
        "MerlinAU_ROGBuild",
        "MerlinAU_TUFBuild"
    ];
    ADVANCED_KEYS.forEach(function (key){
        if (shared_custom_settings.hasOwnProperty(key))
        { delete shared_custom_settings[key]; }
    });

    // Merge Server Custom Settings and prefixed Action form settings //
    var updatedSettings = Object.assign({}, shared_custom_settings, prefixedActionSettings);
    ConsoleLogDEBUG("Actions Config Form submitted with settings:", updatedSettings);

    // Save merged settings to the hidden input field //
    document.getElementById('amng_custom').value = JSON.stringify(updatedSettings);

    // Apply the settings //
    document.form.action_script.value = 'start_MerlinAUconfig';
    document.form.action_wait.value = 10;
    showLoading();
    document.form.submit();
    isFormSubmitting = true;
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-23] **/
/**----------------------------------------**/
function SaveAdvancedConfig()
{
    // Clear amng_custom for any existing content before saving //
    document.getElementById('amng_custom').value = '';

    // F/W Update Email Notifications - only if NOT disabled //
    let emailFormat = document.getElementById('emailFormat');
    let secondaryEmail = document.getElementById('secondaryEmail');
    let emailNotificationsEnabled = document.getElementById('emailNotificationsEnabled');

    // If the box is enabled, we save these fields //
    if (emailNotificationsEnabled && !emailNotificationsEnabled.disabled)
    { advanced_settings.FW_New_Update_EMail_Notification = emailNotificationsEnabled.checked ? 'ENABLED' : 'DISABLED'; }

    if (emailFormat && !emailFormat.disabled)
    { advanced_settings.FW_New_Update_EMail_FormatType = emailFormat.value || 'HTML'; }

    if (secondaryEmail && !secondaryEmail.disabled)
    { advanced_settings.FW_New_Update_EMail_CC_Address = secondaryEmail.value || 'TBD'; }

    // F/W Update ZIP Directory (more checks are made in the shell script) //
    let fwUpdateZIPdirectory = document.getElementById('fwUpdateZIPDirectory');
    if (fwUpdateZIPdirectory !== null && typeof fwUpdateZIPdirectory !== 'undefined')
    {
        if (ValidateDirectoryPath (fwUpdateZIPdirectory, 'ZIP'))
        { advanced_settings.FW_New_Update_ZIP_Directory_Path = fwUpdateZIPdirectory.value; }
        else
        {
            alert(`${validationErrorMsg}\n\n` + fwUpdateDirPath.ErrorMsg('ZIP'));
            return false;
        }
    }

    // F/W Update LOG Directory (more checks are made in the shell script) //
    let fwUpdateLOGdirectory = document.getElementById('fwUpdateLOGDirectory');
    if (fwUpdateLOGdirectory !== null && typeof fwUpdateLOGdirectory !== 'undefined')
    {
        if (ValidateDirectoryPath (fwUpdateLOGdirectory, 'LOG'))
        { advanced_settings.FW_New_Update_LOG_Directory_Path = fwUpdateLOGdirectory.value; }
        else
        {
            alert(`${validationErrorMsg}\n\n` + fwUpdateDirPath.ErrorMsg('LOG'));
            return false;
        }
    }

    // Tailscale/ZeroTier VPN Access - only if not disabled //
    let tailscaleVPNEnabled = document.getElementById('tailscaleVPNEnabled');
    if (tailscaleVPNEnabled && !tailscaleVPNEnabled.disabled)
    { advanced_settings.Allow_Updates_OverVPN = tailscaleVPNEnabled.checked ? 'ENABLED' : 'DISABLED'; }

    // Automatic Updates for Script - only if not disabled //
    let script_AutoUpdate_Check = document.getElementById('Script_AutoUpdate_Check');
    if (script_AutoUpdate_Check && !script_AutoUpdate_Check.disabled)
    { advanced_settings.Allow_Script_Auto_Update = script_AutoUpdate_Check.checked ? 'ENABLED' : 'DISABLED'; }

    // Beta-to-Release Updates - only if not disabled //
    let betaToReleaseUpdatesEnabled = document.getElementById('betaToReleaseUpdatesEnabled');
    if (betaToReleaseUpdatesEnabled && !betaToReleaseUpdatesEnabled.disabled)
    { advanced_settings.FW_Allow_Beta_Production_Up = betaToReleaseUpdatesEnabled.checked ? 'ENABLED' : 'DISABLED'; }

    // Automatic Backups - only if not disabled //
    let autobackupEnabled = document.getElementById('autobackupEnabled');
    if (autobackupEnabled && !autobackupEnabled.disabled)
    { advanced_settings.FW_Auto_Backupmon = autobackupEnabled.checked ? 'ENABLED' : 'DISABLED'; }

    // ROG/TUF F/W Build Type - handle conditional rows if visible //
    let rogFWBuildRow = document.getElementById('rogFWBuildRow');
    let rogFWBuildType = document.getElementById('rogFWBuildType');
    if (rogFWBuildRow && rogFWBuildRow.style.display !== 'none' && rogFWBuildType)
    { advanced_settings.ROGBuild = (rogFWBuildType.value === 'ROG') ? 'ENABLED' : 'DISABLED'; }

    let tufFWBuildRow = document.getElementById('tuffFWBuildRow');
    let tuffFWBuildType = document.getElementById('tuffFWBuildType');
    if (tufFWBuildRow && tufFWBuildRow.style.display !== 'none' && tuffFWBuildType)
    { advanced_settings.TUFBuild = (tuffFWBuildType.value === 'TUF') ? 'ENABLED' : 'DISABLED'; }

    // Prefix only Advanced settings //
    var prefixedAdvancedSettings = PrefixCustomSettings(advanced_settings, 'MerlinAU_');

    // Remove any action keys from shared_custom_settings to avoid overwriting //
    var ACTION_KEYS = [
        "MerlinAU_credentials_base64",
        "MerlinAU_FW_New_Update_Postponement_Days",
        "MerlinAU_CheckChangeLog",
        "MerlinAU_FW_Update_Check",
        "FW_New_Update_Cron_Job_Schedule"
    ];
    ACTION_KEYS.forEach(function (key){
        if (shared_custom_settings.hasOwnProperty(key))
        { delete shared_custom_settings[key]; }
    });

    // Merge Server Custom Settings and prefixed Advanced settings
    var updatedSettings = Object.assign({}, shared_custom_settings, prefixedAdvancedSettings);
    ConsoleLogDEBUG("Advanced Config Form submitted with settings:", updatedSettings);

    // Save merged settings to the hidden input field //
    document.getElementById('amng_custom').value = JSON.stringify(updatedSettings);

    // Apply the settings //
    document.form.action_script.value = 'start_MerlinAUconfig';
    document.form.action_wait.value = 10;
    showLoading();
    document.form.submit();
    isFormSubmitting = true;
    setTimeout(GetExternalCheckResults,4000);
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-22] **/
/**----------------------------------------**/
function Uninstall()
{
   console.log("Uninstalling MerlinAU...");

   if (!confirm("Are you sure you want to completely uninstall MerlinAU?"))
   { return; }

   let actionScriptVal;
   let keepConfigFile = document.getElementById('KeepConfigFile');
   if (!keepConfigFile.checked)
   { actionScriptVal = 'start_MerlinAUuninstall'; }
   else
   { actionScriptVal = 'start_MerlinAUuninstall_keepConfig'; }

   document.form.action_script.value = actionScriptVal;
   document.form.action_wait.value = 10;
   showLoading();
   document.form.submit();
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-22] **/
/**----------------------------------------**/
function CheckFirmwareUpdate()
{
   console.log("Initiating F/W Update Check...");

   let actionScriptVal;
   let bypassPostponedDays = document.getElementById('BypassPostponedDays');
   if (!bypassPostponedDays.checked)
   {
       actionScriptVal = 'start_MerlinAUcheckupdate';
       if (!confirm("NOTE:\nIf you have no postponement days set or remaining, the firmware may flash NOW!\nThis means logging you out of the WebUI and rebooting the router.\nContinue to check for firmware updates now?"))
       { return; }
   }
   else
   {
       actionScriptVal = 'start_MerlinAUcheckupdate_bypassDays';
       if (!confirm("NOTE:\nThe firmware may flash NOW!\nThis means logging you out of the WebUI and rebooting the router.\nContinue to check for firmware updates now?"))
       { return; }
   }

   document.form.action_script.value = actionScriptVal;
   document.form.action_wait.value = 60;
   showLoading();
   document.form.submit();
}

// Get first non-empty value from a list of element IDs //
function GetFirstNonEmptyValue(elemIDs)
{
    for (var indx = 0; indx < elemIDs.length; indx++)
    {
        var elem = document.getElementById(elemIDs[indx]);
        if (elem)
        {
            var value = elem.value.trim();
            if (value.length > 0) { return value; }
        }
    }
    return '';
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-05] **/
/**----------------------------------------**/
// Function to format and display the Router IDs //
function FormatRouterIDs()
{
    let MODEL_ID = GetFirstNonEmptyValue(modelKeys);
    let PRODUCT_ID = GetFirstNonEmptyValue(productKeys);

    // Convert to uppercase for comparison //
    var MODEL_ID_UPPER = MODEL_ID.toUpperCase();

    // Determine FW_RouterModelID based on comparison //
    var FW_RouterModelID = "";
    if (PRODUCT_ID === MODEL_ID_UPPER)
    { FW_RouterModelID = InvCYNct + PRODUCT_ID + InvCLEAR; }
    else
    { FW_RouterModelID = InvCYNct + PRODUCT_ID + ' / ' + MODEL_ID + InvCLEAR; }

    var productModelCell = document.getElementById('firmwareProductModelID');
    if (productModelCell)
    { productModelCell.innerHTML = FW_RouterModelID; }

    // Update the consolidated 'firmver' hidden input //
    var firmverInput = document.getElementById('firmver');
    if (firmverInput)
    {  // Optionally strip HTML tags //
       firmverInput.value = stripHTML(FW_RouterModelID);
    }
}

// Optional: Function to strip HTML tags from a string (to store plain text in hidden input)
function stripHTML(html)
{
    var tmp = document.createElement("DIV");
    tmp.innerHTML = html;
    return tmp.textContent || tmp.innerText || "";
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-05] **/
/**----------------------------------------**/
// Function to format the Firmware Version Installed //
function FormatFirmwareVersion()
{
    var fwVersionElement = document.getElementById('fwVersionInstalled');
    if (fwVersionElement)
    {
        var version = fwVersionElement.textContent.trim();
        var parts = version.split('.');
        if (parts.length >= 4)
        {
            // Combine the first four parts without dots
            var firstPart = parts.slice(0, 4).join('');
            // Combine the remaining parts with dots
            var remainingParts = parts.slice(4).join('.');
            // Construct the formatted version
            var formattedVersion = firstPart + '.' + remainingParts;
            // Update the table cell with the formatted version
            fwVersionElement.innerHTML = InvCYNct + formattedVersion + InvCLEAR;
        }
        else
        { console.warn("Unexpected firmware version format:", version); }
    }
    else
    { console.error("Element with id 'fwVersionInstalled' not found."); }
}

// Modify the existing DOMContentLoaded event listener to include the new function
document.addEventListener("DOMContentLoaded", function()
{
    FormatRouterIDs();
    FormatFirmwareVersion();
});

function updateTUFROGAvailText()
{
    // ROG build //
    let rogSelect = document.getElementById('rogFWBuildType');
    let rogMsgSpan = document.getElementById('rogFWBuildTypeAvailMsg');
    if (rogSelect && rogMsgSpan)
    {
        if (rogSelect.value === 'ROG')
        { rogMsgSpan.style.display = 'inline-block'; }
        else
        { rogMsgSpan.style.display = 'none'; }
    }

    // TUF build //
    let tufSelect = document.getElementById('tuffFWBuildType');
    let tufMsgSpan = document.getElementById('tuffFWBuildTypeAvailMsg');
    if (tufSelect && tufMsgSpan)
    {
        if (tufSelect.value === 'TUF')
        { tufMsgSpan.style.display = 'inline-block'; }
        else
        { tufMsgSpan.style.display = 'none'; }
    }
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Feb-18] **/
/**----------------------------------------**/
function handleTUFROGChange (selectElem)
{
    if (selectElem.id === 'rogFWBuildType')
    {
        let rogMsgSpan = document.getElementById('rogFWBuildTypeAvailMsg');
        if (selectElem.value === 'ROG')
        {
            alert(ROG_BuildTypeMsg);
            rogMsgSpan.style.display = 'inline-block';
        }
        else
        { rogMsgSpan.style.display = 'none'; }
    }
    else if (selectElem.id === 'tuffFWBuildType')
    {
        let tufMsgSpan = document.getElementById('tuffFWBuildTypeAvailMsg');
        if (selectElem.value === 'TUF')
        {
            alert(TUF_BuildTypeMsg);
            tufMsgSpan.style.display = 'inline-block';
        }
        else
        { tufMsgSpan.style.display = 'none'; }
    }
}

function initializeCollapsibleSections()
{
    if (typeof jQuery !== 'undefined')
    {
        $('.collapsible-jquery').each(function()
        {
            // Ensure sections are expanded by default //
            $(this).addClass('active');  // Add 'active' class to indicate expanded state
            $(this).next('tbody').show();  // Make sure content is visible

            // Add a cursor pointer for better UX
            $(this).css('cursor', 'pointer');

            // Toggle logic on click
            $(this).on('click', function() {
                $(this).toggleClass('active');
                $(this).next('tbody').slideToggle();
            });
        });
    }
    else
    { console.error("jQuery is not loaded. Collapsible sections will not work."); }
}
</script>
</head>
<body onload="initial();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

<form method="post" name="form" action="start_apply.htm" target="hidden_frame">
<input type="hidden" name="action_script" value="start_MerlinAUconfig" />
<input type="hidden" name="current_page" value="" />
<input type="hidden" name="next_page" value="" />
<input type="hidden" name="modified" value="0" />
<input type="hidden" name="action_mode" value="apply" />
<input type="hidden" name="action_wait" value="90" />
<input type="hidden" name="first_time" value="">
<input type="hidden" id="http_username" value="<% nvram_get("http_username"); %>" />
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>" />
<!-- Consolidated firmver input -->
<input type="hidden" name="extendno" id="extendno" value="<% nvram_get("extendno"); %>" />
<input type="hidden" name="firmver" id="firmver" value="<% nvram_get('firmver'); %>.<% nvram_get('buildno'); %>.<% nvram_get('extendno'); %>" />
<input type="hidden" id="nvram_odmpid" value="<% nvram_get("odmpid"); %>" />
<input type="hidden" id="nvram_wps_modelnum" value="<% nvram_get("wps_modelnum"); %>" />
<input type="hidden" id="nvram_model" value="<% nvram_get("model"); %>" />
<input type="hidden" id="nvram_build_name" value="<% nvram_get("build_name"); %>" />
<input type="hidden" id="nvram_productid" value="<% nvram_get("productid"); %>" />
<input type="hidden" name="installedfirm" value="<% nvram_get("innerver"); %>" />
<input type="hidden" name="amng_custom" id="amng_custom" value="" />

<table class="content" cellpadding="0" cellspacing="0" style="margin:0 auto;">
<tr>
<td width="17">&nbsp;</td>
<td width="202" valign="top">
   <div id="mainMenu"></div>
   <div id="subMenu"></div>
</td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>

<table width="98%" border="0" cellpadding="0" cellspacing="0">
<tr>
<td valign="top">
<table width="760px" cellpadding="4" cellspacing="0" class="FormTitle" style="height: 1169px;">
<tbody>
<tr style="background-color:#4D595D;">
<td valign="top">
<div>&nbsp;</div>
<div class="formfonttitle" id="headerTitle" style="text-align:center;">MerlinAU</div>
<div style="margin:10px 0 10px 5px;" class="splitLine"></div>
<div class="formfontdesc">This is the MerlinAU add-on integrated into the router WebUI
<span style="margin-left:8px;" id="WikiURL"">[
   <a style="font-weight:bolder; text-decoration:underline; cursor:pointer;"
      href="https://github.com/ExtremeFiretop/MerlinAutoUpdate-Router/wiki"
      title="Go to MerlinAU Wiki page" target="_blank">Wiki</a> ]
</span>
</div>
<div style="line-height:10px;">&nbsp;</div>

<!-- Parent Table to Arrange Firmware and Settings Status Side by Side -->
<table width="100%" cellpadding="0" cellspacing="0" style="border: none; background-color: transparent;">
<tr>
<!-- Firmware Status Column -->
<td valign="top" width="57%" style="padding-right: 5px;">
<!-- Firmware Status Section -->
<table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
<thead class="collapsible-jquery" id="firmwareStatusSection">
   <tr>
      <!-- Adjust colspan to match the number of internal tables -->
      <td colspan="2">Firmware Status (click to expand/collapse)</td>
   </tr>
</thead>
<tbody>
<tr>
<!-- First internal table in the first column -->
<td style="vertical-align: top; width: 50%;">
<table style="margin: 0; text-align: left; width: 100%; border: none;">
<tr>
   <td style="padding: 4px; width: 165px;"><strong>F/W Product/Model ID:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="firmwareProductModelID"></td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>F/W Variant Detected:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwVariantDetected">Unknown</td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>F/W Version Installed:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwVersionInstalled">
      <% nvram_get("firmver"); %>.<% nvram_get("buildno"); %>.<% nvram_get("extendno"); %>
   </td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>F/W Update Available:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwUpdateAvailable">NONE FOUND</td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>Estimated Update Time:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwUpdateEstimatedRunDate">TBD</td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>Last Notification Date:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwNotificationsDate">TBD</td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>F/W Update Check:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwUpdateCheckStatus">Disabled</td>
</tr>
</table></td></tr></tbody></table></td>

<!-- Settings Status Column -->
<td valign="top" width="43%" style="padding-left: 5px;">
<!-- Settings Status Section -->
<table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
<thead class="collapsible-jquery" id="settingsStatusSection">
   <tr>
      <!-- Adjust colspan to match the number of internal tables -->
      <td colspan="2">Settings Status (click to expand/collapse)</td>
   </tr>
</thead>
<tbody>
<tr>
<!-- Second internal table in the second column -->
<td style="vertical-align: top; width: 50%;">
<table style="margin: 0; text-align: left; width: 100%; border: none;">
<tr>
   <td style="padding: 4px; width: 180px;"><strong>Changelog Approval:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="changelogApproval">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 180px;"><strong>Changelog Check:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="changelogCheckStatus">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 180px;"><strong>Beta-to-Release Updates:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="betaToReleaseUpdatesStatus">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 180px;"><strong>Tailscale VPN Access:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="tailscaleVPNAccessStatus">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 180px;"><strong>Automatic Backups:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="autobackupEnabledStatus">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 180px;"><strong>Auto-Updates for MerlinAU:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="autoUpdatesScriptEnabledStatus">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 180px;"><strong>Email Notifications:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="emailNotificationsStatus">Disabled</td>
</tr>
</table></td></tr></tbody></table></td></tr></table>

<div style="line-height:10px;">&nbsp;</div>

<!-- Actions Section -->
<table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
<thead class="collapsible-jquery" id="actionsSection">
   <tr><td colspan="2">Actions (click to expand/collapse)</td></tr>
</thead>
<tbody><tr><td colspan="2">
<div style="text-align: center; margin-top: 3px;">
<table width="100%" border="0" cellpadding="10" cellspacing="0" style="table-layout: fixed; border-collapse: collapse; background-color: transparent;">
<colgroup>
   <col style="width: 33%;" />
   <col style="width: 33%;" />
   <col style="width: 33%;" />
</colgroup>
<tr>
<td style="text-align: right; border: none;">
   <input type="submit" id="FWUpdateCheckButton" onclick="CheckFirmwareUpdate();
    return false;" value="F/W Update Check" class="button_gen savebutton" name="button">
   <br>
   <label style="color:#FFCC00; margin-top: 5px; margin-bottom:8x">
   <input type="checkbox" checked="" id="BypassPostponedDays" name="BypassPostponedDays"
    style="padding:0; vertical-align:middle; position:relative; margin-left:-5px; margin-top:5px; margin-bottom:8px"/>Bypass postponed days</label>
   </br>
</td>
<td style="text-align: center; border: none;" id="approveChangelogCell">
   <input type="submit" class="button_gen savebutton" id="approveBlockChangeLogBtn"
    onclick="ApproveChangelog(); return false;"
    value="Approve Changelog" title="" name="button">
   <br><label style="margin-top: 5px; margin-bottom:8x"></br>
</td>
<td style="text-align: left; border: none;">
   <input type="submit" id="UninstallButton" onclick="Uninstall(); return false;"
    value="Uninstall" class="button_gen savebutton" name="button">
   <br>
   <label style="color:#FFCC00; margin-top: 5px; margin-bottom:8x">
   <input type="checkbox" checked="" id="KeepConfigFile" name="KeepConfigFile"
    style="padding:0; vertical-align:middle; position:relative; margin-left:-3px; margin-top:5px; margin-bottom:8px"/>Keep configuration file</label>
   </br>
</td>
</tr>
</table>
</div>
<form id="actionsForm">
<table class="FormTable SettingsTable" width="100%" border="0" cellpadding="5" cellspacing="5" style="table-layout: fixed;">
<colgroup>
   <col style="width: 37%;" />
   <col style="width: 63%;" />
</colgroup>
<tr>
   <td style="text-align: left;">
     <label for="routerPassword">Router Login Password</label>
   </td>
   <td>
      <div style="display: inline-block;">
         <input
           type="password"
           id="routerPassword"
           name="routerPassword"
           placeholder="Enter password"
           style="width: 278px; display: inline-block;"
           maxlength="64"
           onKeyPress="return validator.isString(this, event)"
           onblur="ValidatePasswordString(this)"
           onkeyup="ValidatePasswordString(this)"/>
         <div
             id="eyeToggle"
             onclick="togglePassword();"
             style="
               position: absolute;
               display: inline-block; 
               margin-left: 5px;
               vertical-align: middle;
               width:24px; height:24px; 
               background:url('/images/icon-visible@2x.png') no-repeat center;
               background-size: contain;
               cursor: pointer;"></div>
      </div>
   </td>
</tr>
<tr>
   <td style="text-align: left;"><label for="FW_AutoUpdate_Check">Enable Automatic F/W Update Checks</label></td>
   <td>
      <input type="checkbox" id="FW_AutoUpdate_Check" name="FW_AutoUpdate_Check"/>
      <span id="FW_AutoUpdate_CheckSchedText" style="margin-left:10px; display:none; font-size: 12px; font-weight: bolder;"></span>
   </td>
</tr>
<tr>
   <td style="text-align: left;">
   <label id="fwUpdatePostponementLabel" for="fwUpdatePostponement">F/W Update Postponement</label>
   </td>
   <td>
   <input autocomplete="off" type="text"
     id="fwUpdatePostponement" name="fwUpdatePostponement"
     style="width: 7%;" maxlength="3"
     onKeyPress="return validator.isNumber(this,event)"
     onkeyup="ValidatePostponedDays(this)"
     onblur="ValidatePostponedDays(this);FormatNumericSetting(this)"/>
   </td>
</tr>
<tr>
   <td style="text-align: left;">
      <label for="changelogCheckEnabled">
      <a class="hintstyle" name="CHANGELOG_CHECK" href="javascript:void(0);"
         onclick="ShowHintMsg(this);">Enable F/W Changelog Check</a>
      </label>
   </td>
   <td><input type="checkbox" id="changelogCheckEnabled" name="changelogCheckEnabled" /></td>
</tr>
<!--
** F/W Update Check Cron Schedule **
-->
<tr>
   <td style="text-align: left;">
   <label id="fwUpdateCheckScheduleLabel" for="fwUpdateCheckSchedule">Schedule for F/W Update Checks</label>
   </td>
   <td>
     <div id="fwCronScheduleDAYofWEEK">
     <span style="margin-left:1px; margin-top:5px; font-size: 12px; font-weight: bolder;">Days:</span>
     <label style="margin-left:-3px;">
       <input type="checkbox" name="fwSchedDAYWEEK" id="fwSchedBoxDAYS1" value="Every day" class="input"
        style="margin-left:22px; margin-top:1px;" onclick="ToggleDaysOfWeek(this.checked,'1');"/>Every day</label>
     <label style="margin-left:-3px;">
       <input type="checkbox" name="fwSchedDAYWEEK" id="fwSchedBoxDAYSX" value="Every X Days" class="input"
        style="margin-left:28px; margin-top:1px;" onclick="ToggleDaysOfWeek(this.checked,'X');"/>Every</label>
       <input type="text" autocomplete="off" autocapitalize="off" data-lpignore="true"
        style="width: 5%; margin-left: 2px; margin-top:3px; margin-bottom:7px" maxlength="2"
		id="fwScheduleXDAYS" name="fwScheduleXDAYS" value="2"
        onKeyPress="return validator.isNumber(this,event)"
        onkeyup="ValidateFWUpdateXDays(this,'DAYS')"
		onblur="ValidateFWUpdateXDays(this,'DAYS');FormatNumericSetting(this)"/>
      <label style="margin-left:2px; margin-top:3px; font-size: 12px;">days</label>
     <br>
     <label style="margin-left:0px;">
       <input type="checkbox" name="fwSchedDAYWEEK" id="fwSched_SUN" value="Sun"
        class="input" style="margin-left:55px; margin-bottom:7px"/>Sun</label>
     <label style="margin-left:0px;">
       <input type="checkbox" name="fwSchedDAYWEEK" id="fwSched_MON" value="Mon"
        class="input" style="margin-left:14px; margin-bottom:7px"/>Mon</label>
     <label style="margin-left:0px;">
       <input type="checkbox" name="fwSchedDAYWEEK" id="fwSched_TUE" value="Tue"
        class="input" style="margin-left:14px; margin-bottom:7px"/>Tue</label>
     <label style="margin-left:0px;">
       <input type="checkbox" name="fwSchedDAYWEEK" id="fwSched_WED" value="Wed"
        class="input" style="margin-left:14px; margin-bottom:7px"/>Wed</label>
     <label style="margin-left:0px;">
       <input type="checkbox" name="fwSchedDAYWEEK" id="fwSched_THU" value="Thu"
        class="input" style="margin-left:14px; margin-bottom:7px"/>Thu</label>
     <label style="margin-left:0px;">
       <input type="checkbox" name="fwSchedDAYWEEK" id="fwSched_FRI" value="Fri"
        class="input" style="margin-left:14px; margin-bottom:7px"/>Fri</label>
     <label style="margin-left:0px;">
       <input type="checkbox" name="fwSchedDAYWEEK" id="fwSched_SAT" value="Sat"
        class="input" style="margin-left:14px; margin-bottom:7px"/>Sat</label>
     </br>
     </div>
     <div id="fwCronScheduleHOUR">
       <span style="margin-left:1px; margin-top:10px; font-size: 12px; font-weight: bolder;">Hour:</span>
       <input type="text" autocomplete="off" autocapitalize="off" data-lpignore="true"
        style="width: 7%; margin-left: 20px; margin-top:10px; margin-bottom:7px" maxlength="2"
		id="fwScheduleHOUR" name="fwScheduleHOUR" value="0"
        onKeyPress="return validator.isNumber(this,event)"
		onkeyup="ValidateFWUpdateTime(this,'HOUR')"
		onblur="ValidateFWUpdateTime(this,'HOUR');FormatNumericSetting(this)"/>
     </div>
     <div id="fwCronScheduleMINS">
       <span style="margin-left:1px; margin-top:10px; font-size: 12px; font-weight: bolder;">Minutes:</span>
       <input type="text" autocomplete="off" autocapitalize="off" data-lpignore="true"
        style="width: 7%; margin-left: 1px; margin-top:7px; margin-bottom:10px" maxlength="2"
		id="fwScheduleMINS" name="fwScheduleMINS" value="0"
        onKeyPress="return validator.isNumber(this,event)"
		onkeyup="ValidateFWUpdateTime(this,'MINS')"
		onblur="ValidateFWUpdateTime(this,'MINS');FormatNumericSetting(this)"/>
     </div>
   </td>
</tr>
</table>
<div style="text-align: center; margin-top: 10px;">
   <input type="submit" onclick="return SaveActionsConfig();"
    value="Save" class="button_gen savebutton" name="button">
</div>
</form>
</td>
</tr>
</tbody>
</table>

<div style="line-height:10px;">&nbsp;</div>

<!-- Advanced Options Section -->
<table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
<thead class="collapsible-jquery" id="advancedOptionsSection">
   <tr><td colspan="2">Advanced Options (click to expand/collapse)</td></tr>
</thead>
<tbody>
<tr>
<td colspan="2">
<form id="advancedOptionsForm">
<table class="FormTable SettingsTable" width="100%" border="0" cellpadding="5" cellspacing="5" style="table-layout: fixed;">
<colgroup>
   <col style="width: 37%;" />
   <col style="width: 63%;" />
</colgroup>
<tr>
   <td style="text-align: left;">
      <label for="fwUpdateZIPDirectory">
      <a class="hintstyle" name="FW_UPDATE_ZIPDIR" href="javascript:void(0);"
         onclick="ShowHintMsg(this);">Directory for F/W Update File</a>
      </label>
   </td>
   <td>
   <input autocomplete="off" type="text"
     id="fwUpdateZIPDirectory" name="fwUpdateZIPDirectory"
     style="width: 275px;" maxlength="200"
     onKeyPress="return validator.isString(this, event)"
     onblur="ValidateDirectoryPath(this,'ZIP')"
     onkeyup="ValidateDirectoryPath(this,'ZIP')"/>
   </td>
</tr>
<tr>
   <td style="text-align: left;">
      <label for="fwUpdateLOGDirectory">
      <a class="hintstyle" name="FW_UPDATE_LOGDIR" href="javascript:void(0);"
         onclick="ShowHintMsg(this);">Directory for F/W Update Log File</a>
      </label>
   </td>
   <td>
   <input autocomplete="off" type="text"
     id="fwUpdateLOGDirectory" name="fwUpdateLOGDirectory"
     style="width: 275px;" maxlength="200"
     onKeyPress="return validator.isString(this, event)"
     onblur="ValidateDirectoryPath(this,'LOG')"
     onkeyup="ValidateDirectoryPath(this,'LOG')"/>
   </td>
</tr>
<tr>
   <td style="text-align: left;">
      <label for="betaToReleaseUpdatesEnabled">
      <a class="hintstyle" name="BETA_TO_RELEASE" href="javascript:void(0);"
         onclick="ShowHintMsg(this);">Beta-to-Release F/W Updates</a>
      </label>
   </td>
   <td><input type="checkbox" id="betaToReleaseUpdatesEnabled" name="betaToReleaseUpdatesEnabled" /></td>
</tr>
<tr>
   <td style="text-align: left;">
      <label for="tailscaleVPNEnabled">
      <a class="hintstyle" name="ALLOW_VPN_ACCESS" href="javascript:void(0);"
         onclick="ShowHintMsg(this);">Tailscale/ZeroTier VPN Access</a>
      </label>
   </td>
   <td><input type="checkbox" id="tailscaleVPNEnabled" name="tailscaleVPNEnabled" /></td>
</tr>
<tr>
   <td style="text-align: left;">
      <label for="autobackupEnabled">
      <a class="hintstyle" name="AUTOMATIC_BACKUPS" href="javascript:void(0);"
         onclick="ShowHintMsg(this);">Enable Automatic Backups</a>
      </label>
   </td>
   <td><input type="checkbox" id="autobackupEnabled" name="autobackupEnabled" /></td>
</tr>
<tr>
   <td style="text-align: left;">
      <label for="Script_AutoUpdate_Check">
      <a class="hintstyle" name="ADDON_AUTO_UPDATES" href="javascript:void(0);"
         onclick="ShowHintMsg(this);">Enable Auto-Updates for MerlinAU</a>
      </label>
   </td>
   <td>
      <input type="checkbox" id="Script_AutoUpdate_Check" name="Script_AutoUpdate_Check"/>
      <span id="Script_AutoUpdate_SchedText" style="margin-left:10px; display:none; font-size: 12px; font-weight: bolder;"></span>
   </td>
</tr>
<tr id="rogFWBuildRow">
   <td style="text-align: left;">
      <label for="rogFWBuildType">
      <a class="hintstyle" name="ROG_BUILDTYPE" href="javascript:void(0);"
         onclick="ShowHintMsg(this);">F/W Build Type Preference</a>
      </label>
   </td>
   <td>
      <select id="rogFWBuildType" name="rogFWBuildType" style="width: 20%;" onchange="handleTUFROGChange(this)">
         <option value="ROG">ROG</option>
         <option value="Pure">Pure</option>
      </select>
    <span id="rogFWBuildTypeAvailMsg"
          style="margin-left:10px; display:none; font-size:12px; font-weight:bolder;">
      NOTE: Applies only if available
    </span>
   </td>
</tr>
<tr id="tuffFWBuildRow">
   <td style="text-align: left;">
      <label for="tuffFWBuildType">
      <a class="hintstyle" name="TUF_BUILDTYPE" href="javascript:void(0);"
         onclick="ShowHintMsg(this);">F/W Build Type Preference</a>
      </label>
   </td>
   <td>
      <select id="tuffFWBuildType" name="tuffFWBuildType" style="width: 20%;" onchange="handleTUFROGChange(this)">
         <option value="TUF">TUF</option>
         <option value="Pure">Pure</option>
      </select>
    <span id="tuffFWBuildTypeAvailMsg"
          style="margin-left:10px; display:none; font-size:12px; font-weight:bolder;">
      NOTE: Applies only if available
    </span>
   </td>
</tr>
<tr>
   <td style="text-align: left;">
      <label for="emailNotificationsEnabled">
      <a class="hintstyle" name="EMAIL_NOTIFICATION" href="javascript:void(0);"
         onclick="ShowHintMsg(this);">Enable F/W Update Email Notifications</a>
      </label>
   </td>
   <td><input type="checkbox" id="emailNotificationsEnabled" name="emailNotificationsEnabled"
       onclick="ToggleEmailDependents(this.checked);"/></td>
</tr>
<tr>
   <td style="text-align: left;"><label for="emailFormat">Email Notification Format</label></td>
   <td>
      <select id="emailFormat" name="emailFormat" style="width: 21%;">
         <option value="HTML">HTML</option>
         <option value="PlainText">Plain Text</option>
      </select>
   </td>
</tr>
<tr>
   <td style="text-align: left;"><label for="secondaryEmail">Secondary Email for Notifications</label></td>
   <td><input type="email" id="secondaryEmail" name="secondaryEmail" style="width: 275px;" /></td>
</tr>
</table>
<div style="text-align: center; margin-top: 10px;">
   <input type="submit" onclick="SaveAdvancedConfig(); return false;"
    value="Save" class="button_gen savebutton" name="button">
</div>
</form></td></tr></tbody></table>
<div id="footerTitle" style="margin-top:10px;text-align:center;">MerlinAU</div>
</td></tr></tbody></table></td></tr></table></td>
<td width="10"></td>
</tr></table></form>
<div id="footer"></div>
</body>
</html>
